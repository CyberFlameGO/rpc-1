// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.utils;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';

import 'package:logging/logging.dart';

import 'config.dart';
import 'errors.dart';
import 'message.dart';

// Global constants
const List<String> bodyLessMethods = const ['GET', 'DELETE'];

final Logger rpcLogger = new Logger('rpc');

// Utility method for creating an HTTP error response given an expcetion.
// Optionally drains the request body.
Future<HttpApiResponse> httpErrorResponse(HttpApiRequest request,
                                          Exception error,
                                          {StackTrace stack,
                                           bool drainRequest: true}) async {
  // TODO support more encodings.
  var headers = {
    HttpHeaders.CONTENT_TYPE: ContentType.JSON.toString(),
    HttpHeaders.CACHE_CONTROL: 'no-cache, no-store, must-revalidate',
    HttpHeaders.PRAGMA: 'no-cache',
    HttpHeaders.EXPIRES: '0'
  };
  var response;
  if (error is RpcError) {
    response =
        new HttpApiResponse.error(error.code, error.msg, headers, error, stack);
  } else {
    response =
        new HttpApiResponse.error(HttpStatus.INTERNAL_SERVER_ERROR,
                                  'Unknown API Error.', headers, error, stack);
  }
  if (drainRequest) {
    // Drain the request before responding.
    try {
      await request.body.drain();
    } catch(e) {
      rpcLogger.warning(
          'Failed to drain request body when creating error response.');
      // Ignore any errors and return the original response generated above.
    }
  }
  logResponse(response, null, Level.WARNING);
  return response;
}

void _logHeaders(StringBuffer msg, Map<String, dynamic> headers) {
  var headerKeys = headers.keys.toList();
  headerKeys.sort();
  headerKeys.forEach((String key) => msg.writeln('    $key: ${headers[key]}'));
}

void logRequest(ParsedHttpApiRequest request, dynamic jsonBody,
                [Level level = Level.FINE]) {
  if (!rpcLogger.isLoggable(level)) {
    return;
  }
  var msg = new StringBuffer();
  msg..writeln('\nRequest for API ${request.apiKey}:')
     ..writeln('  Method: ${request.httpMethod}')
     ..writeln('  Path: ${request.path}')
     // TODO: Change to print all headers once added to request class.
     ..writeln('  Content-Type: ${request.contentType}');
  if (jsonBody != null) {
    msg.writeln('  Body:\n    $jsonBody');
  }
  rpcLogger.log(level, msg.toString());
}

void logResponse(HttpApiResponse response, dynamic jsonBody,
                 [Level level = Level.FINE]) {
  if (!rpcLogger.isLoggable(level)) {
    return;
  }
  var msg = new StringBuffer();
  msg..writeln('\nResponse')
     ..writeln('  Status Code: ${response.status}')
     ..writeln('  Headers:');
  _logHeaders(msg, response.headers);
  if (jsonBody != null) {
    msg.writeln('  Body:\n    $jsonBody');
  }
  if (response.exception == null) {
    rpcLogger.log(level, msg.toString());
  } else {
    msg.writeln('  Exception:\n    ${response.exception}');
    rpcLogger.log(level, msg.toString(), null, response.stack);
  }
}

void logMethodInvocation(Symbol symbol,
                         List<dynamic> positionalParams,
                         Map<Symbol, dynamic> namedParams) {
  if (!rpcLogger.isLoggable(Level.FINER)) {
    return;
  }
  assert(positionalParams != null);
  assert(namedParams != null);
  var msg = new StringBuffer();
  msg..writeln('\nInvoking method: ${MirrorSystem.getName(symbol)} with:')
     ..writeln('  Positional Parameters:');
  positionalParams.forEach((value) => msg.writeln('    $value'));
  msg.writeln('  Named Parameters:');
  namedParams.forEach((symbol, value) =>
      msg.writeln('    ${MirrorSystem.getName(symbol)}: $value'));
  rpcLogger.finer(msg.toString());
}