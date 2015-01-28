// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

final _bytesToJson = UTF8.decoder.fuse(JSON.decoder);

class ApiConfigMethod {
  final Symbol symbol;
  final String id;
  final String name;
  final String path;
  final String httpMethod;
  final String description;

  final InstanceMirror _instance;
  final List<String> _pathParams;
  final Map<String, Symbol> _queryParamTypes;
  final ApiConfigSchema _requestSchema;
  final ApiConfigSchema _responseSchema;
  final UriParser _parser;

  ApiConfigMethod(this.id, this._instance, this.symbol, this.name, this.path,
                  this.httpMethod, this.description, this._pathParams,
                  this._queryParamTypes, this._requestSchema,
                  this._responseSchema, this._parser);

  bool matches(ParsedHttpApiRequest request) {
    UriMatch match = _parser.match(request.methodUri);
    if (match == null) {
      return false;
    }
    assert(match.rest.path.length == 0);
    request.pathParameters = match.parameters;
    return true;
  }

  discovery.RestMethod get asDiscovery {
    var method = new discovery.RestMethod();
    method..id = id
          ..path = path
          ..httpMethod = httpMethod.toUpperCase()
          ..description = description
          ..parameterOrder = _pathParams;
    method.parameters = new Map<String, discovery.JsonSchema>();
    _pathParams.forEach((param) {
      var schema = new discovery.JsonSchema();
      // TODO: Add support for integers.
      schema..type = 'string'
            ..required = true
            ..description = 'Path parameter: \'$param\'.'
            ..location = 'path';
      method.parameters[param] = schema;
    });
    if (_queryParamTypes != null) {
      _queryParamTypes.keys.forEach((String param) {
        var schema = new discovery.JsonSchema();
        // TODO: Add support for integers.
        schema..type = 'string'
              ..required = false
              ..description = 'Query parameter: \'$param\'.'
              ..location = 'query';
        method.parameters[param] = schema;
      });
    }
    if (_requestSchema != null && _requestSchema.hasProperties) {
      method.request =
          new discovery.RestMethodRequest()..P_ref = _requestSchema.schemaName;
    }
    if (_responseSchema != null && _responseSchema.hasProperties) {
      method.response = new discovery.RestMethodResponse()
                            ..P_ref = _responseSchema.schemaName;
    }
    return method;
  }

  Future<HttpApiResponse> invokeHttpRequest(
      ParsedHttpApiRequest request) async {
    var positionalParams = [];
    // Add path parameters to params in the correct order.
    assert(_pathParams != null);
    assert(request.pathParameters != null);
    _pathParams.forEach((paramName) {
      var value = request.pathParameters[paramName];
      if (value == null) {
        return httpErrorResponse(request.originalRequest,
            new BadRequestError('Required parameter: $paramName missing.'));
      }
      positionalParams.add(value);
    });
    // Build named parameter map for query parameters.
    var namedParams = {};
    if (_queryParamTypes != null && request.queryParameters != null) {
      _queryParamTypes.forEach((name, symbol) {
        // Check if there is a parameter value for the given name.
        var value = request.queryParameters[name];
        if (value != null) {
          namedParams[symbol] = value;
        }
        // We ignore query parameters that don't match a named method
        // parameter.
      });
    }
    var apiResult;
    try {
      if (bodyLessMethods.contains(httpMethod)) {
        apiResult = await invokeNoBody(request.body,
                                       positionalParams, namedParams);
      } else {
        apiResult =
            await invokeWithBody(request.body, positionalParams, namedParams);
      }
    } catch (error) {
      // We explicitly catch exceptions thrown by the invoke method, otherwise
      // these exceptions would be shown as 500 Unknown API Error since we
      // cannot distinguish them from e.g. an internal null pointer exception.
      return httpErrorResponse(request.originalRequest,
          new ApplicationError(error), drainRequest: false);
    }
    var result;
    if (_responseSchema != null && apiResult != null &&
        _responseSchema.hasProperties) {
      // TODO: Support other encodings.
      var jsonResult = _responseSchema.toResponse(apiResult);
      var encodedResultIterable = [request.jsonToBytes.convert(jsonResult)];
      result = new Stream.fromIterable(encodedResultIterable);
    } else {
      // Return an empty stream.
      result = new Stream.fromIterable([]);
    }
    var headers = {
      HttpHeaders.CONTENT_TYPE: request.contentType,
      HttpHeaders.CACHE_CONTROL: 'no-cache, no-store, must-revalidate',
      HttpHeaders.PRAGMA: 'no-cache',
      HttpHeaders.EXPIRES: '0'
    };
    return new HttpApiResponse(HttpStatus.OK, result, headers: headers);
  }

  Future<dynamic> invokeNoBody(Stream<List<int>> requestBody,
                               List positionalParams,
                               Map namedParams) async {
    // Drain the request body just in case.
    await requestBody.drain();
    return _instance.invoke(symbol, positionalParams, namedParams).reflectee;
  }

  Future<dynamic> invokeWithBody(Stream<List<int>> requestBody,
                                 List positionalParams,
                                 Map namedParams) async {
    // Decode request body parameters to json.
    // TODO: support other encodings
    var decodedRequest = await requestBody.transform(_bytesToJson).first;
    if (_requestSchema != null && _requestSchema.hasProperties) {
      // The request schema is the last positional parameter, so just adding
      // it to the list of position parameters.
      positionalParams.add(_requestSchema.fromRequest(decodedRequest));
    }
    return _instance.invoke(symbol, positionalParams, namedParams).reflectee;
  }
}
