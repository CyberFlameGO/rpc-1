// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:unittest/unittest.dart';

import 'src/test_api.dart';

main () {
  group('api_config_misconfig', () {

    test('no_apiclass_annotation', () {
      expect(
        () => new ApiConfig(new NoAnnotation()),
        throwsA(new isInstanceOf<ApiConfigError>('ApiConfigError'))
      );
    });

    List _noversionApis = [new NoVersion1(), new NoVersion2()];
    _noversionApis.forEach((api) {
      test(api.runtimeType.toString(), () {
        var apiConfig = new ApiConfig(api);
        expect(apiConfig.isValid, isFalse);
      });
    });

    List ambiguousPaths = [new AmbiguousMethodPaths1(),
                           new AmbiguousMethodPaths2(),
                           new AmbiguousMethodPaths3(),
                           new AmbiguousMethodPaths4(),
                           new AmbiguousMethodPaths5(),
                           new AmbiguousMethodPaths6(),
                           new AmbiguousMethodPaths7()];
    ambiguousPaths.forEach((ambiguous) {
      test(ambiguous.toString(), () {
        var apiConfig = new ApiConfig(ambiguous);
        expect(apiConfig.isValid, isFalse);
        var config = apiConfig.toJson('rootUrl/');
        expect(config['version'], 'test');
      });
    });
  });

  group('api_config_correct', () {

    test('correct_simple', () {
      var apiConfig = new ApiConfig(new Tester());
      expect(apiConfig.isValid, isTrue);
      Map expectedJson = {
        'kind': 'discovery#restDescription',
        'etag': '9a0bdcd569d244abfc83d507ea2e78031d5c7db9',
        'discoveryVersion': 'v1',
        'id': 'Tester:v1test',
        'name': 'Tester',
        'version': 'v1test',
        'revision': '0',
        'title': 'Tester',
        'description': '',
        'protocol': 'rest',
        'baseUrl': 'http://localhost:8080/Tester/v1test/',
        'basePath': '/Tester/v1test/',
        'rootUrl': 'http://localhost:8080/',
        'servicePath': 'Tester/v1test/',
        'parameters': {},
        'schemas': {},
        'methods': {},
        'resources': {}
      };
      var json = apiConfig.toJson('http://localhost:8080/');
      expect(json, expectedJson);
    });

    test('correct_simple2', () {
      var apiConfig = new ApiConfig(new CorrectSimple());
      expect(apiConfig.isValid, isTrue);
      Map expectedSchemas = {
        'TestMessage1': {
          'id': 'TestMessage1',
          'type': 'object',
          'properties': {
            'count': {'type': 'integer', 'format': 'int32'},
            'message': {'type': 'string'},
            'value': {'type': 'number', 'format': 'double'},
            'check': {'type': 'boolean'},
            'date': {'type': 'string', 'format': 'date-time'},
            'messages': {'type': 'array', 'items': {'type': 'string'}},
            'submessage': {'\$ref': 'TestMessage2'},
            'submessages':
                {'type': 'array', 'items': {'\$ref': 'TestMessage2'}},
            'enumValue': {'type': 'string'},
            'defaultValue':
                {'type': 'integer', 'format': 'int32', 'default': 10},
            'limit': {'type': 'integer', 'format': 'int32'}
          }
        },
        'TestMessage2': {
          'id': 'TestMessage2',
          'type': 'object',
          'properties': {'count': {'type': 'integer', 'format': 'int32'}}
        }
      };
      Map expectedMethods = {
        'simple1': {
          'id': 'CorrectSimple.simple1',
          'path': 'test1/{path}',
          'httpMethod': 'GET',
          'description': null,
          'parameters': {
            'path': {
              'type': 'string',
              'required': true,
              'description': 'Path parameter: \'path\'.',
              'location': 'path'
            }
          },
          'parameterOrder': ['path']
        },
        'simple2': {
          'id': 'CorrectSimple.simple2',
          'path': 'test2',
          'httpMethod': 'POST',
          'description': null,
          'parameters': {},
          'parameterOrder': [],
          'request': {'\$ref': 'TestMessage1'},
          'response': {'\$ref': 'TestMessage1'}
        }
      };
      var json = apiConfig.toJson('http://localhost:8080/');
      expect(json['schemas'], expectedSchemas);
      expect(json['methods'], expectedMethods);
    });

    test('correct_extended', () {
      var apiConfig = new ApiConfig(new CorrectMethods());
      expect(apiConfig.isValid, isTrue);
      var config = apiConfig.toJson('rootUrl/');
      expect(config['name'], 'correct');
      expect(config['version'], 'v1');
      expect(config['schemas'].keys.length, 2);
      expect(config['methods'].keys.length, 13);
    });
  });

  group('api_config_resources_misconfig', () {

    test('multiple_method_annotations', () {
      var tester = new ApiConfig(new Tester());
      var resource = new MultipleResourceMethodAnnotations();
      var resourceMirror = reflect(resource);
      new ApiConfigResource(resourceMirror, null, 'multiMethodAnnotations',
                            tester);
      expect(tester.isValid, isFalse);
    });

    test('multiple_resource_annotations', () {
      var tester = new ApiConfig(new TesterWithMultipleResourceAnnotations());
      expect(tester.isValid, isFalse);
    });

    test('duplicate_resources', () {
      var tester = new ApiConfig(new TesterWithDuplicateResourceNames());
      expect(tester.isValid, isFalse);
    });
  });

  group('api_config_resources_correct', () {

    test('simple', () {
      var tester = new ApiConfig(new TesterWithOneResource());
      expect(tester.isValid, isTrue);
      var json = tester.toJson('http://localhost:8080/');
      Map expectedResources = {
        'someResource': {
          'methods': {
            'method1': {
              'id': 'SomeResource.method1',
              'path': 'someResourceMethod',
              'httpMethod': 'GET',
              'description': null,
              'parameters': {},
              'parameterOrder': []
            }
          },
          'resources': {}
        }
      };
      expect(json['resources'], expectedResources);
    });

    test('two_resources', () {
      var tester = new ApiConfig(new TesterWithTwoResources());
      expect(tester.isValid, isTrue);
      var expectedResources = {
        'someResource': {
          'methods': {
            'method1': {
              'id': 'SomeResource.method1',
              'path': 'someResourceMethod',
              'httpMethod': 'GET',
              'description': null,
              'parameters': {},
              'parameterOrder': []
            }
          },
          'resources': {}
        },
        'nice_name': {
          'methods': {
            'method1': {
              'id': 'NamedResource.method1',
              'path': 'namedResourceMethod',
              'httpMethod': 'GET',
              'description': null,
              'parameters': {},
              'parameterOrder': []
            }
          },
          'resources': {}
        }
      };
      var json = tester.toJson('http://localhost:8080/');
      expect(json['resources'], expectedResources);
    });

    test('nested_resources', () {
      var tester = new ApiConfig(new TesterWithNestedResources());
      expect(tester.isValid, isTrue);
      var expectedResources = {
        'resourceWithNested': {
          'methods': {},
          'resources': {
            'nestedResource': {
              'methods': {
                'method1': {
                  'id': 'NestedResource.method1',
                  'path': 'nestedResourceMethod',
                  'httpMethod': 'GET',
                  'description': null,
                  'parameters': {},
                  'parameterOrder': []
                }
              },
              'resources': {}
            }
          }
        }
      };
      var json = tester.toJson('http://localhost:8080/');
      expect(json['resources'], expectedResources);
    });
  });

  group('api_config_methods', () {

    test('misconfig', () {
      var testMirror = reflectClass(WrongMethods);
      var tester = new ApiConfig(new Tester());
      var methods = testMirror.declarations.values.where(
        (dm) => dm is MethodMirror &&
                dm.isRegularMethod &&
                dm.metadata.length > 0 &&
                dm.metadata.first.reflectee.runtimeType == ApiMethod
      );
      methods.forEach((MethodMirror mm) {
        var metadata = mm.metadata.first.reflectee;
        expect(metadata.runtimeType, ApiMethod);
        expect(
          () => new ApiConfigMethod(
              mm, metadata, tester.id, tester, reflect(tester)),
          throwsA(new isInstanceOf<ApiConfigError>('ApiConfigError'))
        );
      });
    });

    test('recursion', () {
      var testMirror = reflectClass(RecursiveGet);
      var tester = new ApiConfig(new Tester());
      var methods = testMirror.declarations.values.where(
        (dm) => dm is MethodMirror &&
                dm.isRegularMethod &&
                dm.metadata.length > 0 &&
                dm.metadata.first.reflectee.runtimeType == ApiMethod
      );
      methods.forEach((MethodMirror mm) {
        var metadata = mm.metadata.first.reflectee;
        expect(metadata.runtimeType, ApiMethod);
        expect(
          () => new ApiConfigMethod(
              mm, metadata, tester.id, tester, reflect(tester)),
          throwsA(new isInstanceOf<ApiConfigError>('ApiConfigError'))
        );
      });
    });

    test('correct', () {
      var testMirror = reflectClass(CorrectMethods);
      var tester = new ApiConfig(new Tester());
      var methods = testMirror.declarations.values.where(
        (dm) => dm is MethodMirror &&
                dm.isRegularMethod &&
                dm.metadata.length > 0 &&
                dm.metadata.first.reflectee.runtimeType == ApiMethod
      );
      methods.forEach((MethodMirror mm) {
        var metadata = mm.metadata.first.reflectee;
        expect(metadata.runtimeType, ApiMethod);
        expect(
            () => new ApiConfigMethod(
                mm, metadata, tester.id, tester, reflect(tester)),
            returnsNormally);
      });
    });
  });

  group('api_config_schema', () {

    group('misconfig', () {
      List _wrongSchemas = [WrongSchema1];
      _wrongSchemas.forEach((schema) {
        test(schema.toString(), () {
          var tester = new ApiConfig(new Tester());
          expect(
            () => new ApiConfigSchema(reflectClass(schema), tester),
            throwsA(new isInstanceOf<ApiConfigError>())
          );
        });
      });

      test('double_name1', () {
        var tester = new ApiConfig(new Tester());
        new ApiConfigSchema(reflectClass(TestMessage1), tester, name: "MyMessage");
        expect(
          () => new ApiConfigSchema(reflectClass(TestMessage2), tester, name: "MyMessage"),
          throwsA(new isInstanceOf<ApiConfigError>())
        );
      });
    });

    test('recursion', () {
      expect(new Future.sync(() {
        var tester = new ApiConfig(new Tester());
        var m1 = new ApiConfigSchema(reflectClass(RecursiveMessage1), tester);
      }), completes);
      expect(new Future.sync(() {
        var tester = new ApiConfig(new Tester());
        var m2 = new ApiConfigSchema(reflectClass(RecursiveMessage2), tester);
      }), completes);
      expect(new Future.sync(() {
        var tester = new ApiConfig(new Tester());
        var m3 = new ApiConfigSchema(reflectClass(RecursiveMessage3), tester);
      }), completes);
      expect(new Future.sync(() {
        var tester = new ApiConfig(new Tester());
        var m2 = new ApiConfigSchema(reflectClass(RecursiveMessage2), tester);
        var m3 = new ApiConfigSchema(reflectClass(RecursiveMessage3), tester);
      }), completes);
    });

    test('variants', () {
      var tester = new ApiConfig(new Tester());
      var message = new ApiConfigSchema(reflectClass(TestMessage3), tester);
      var instance = message.fromRequest({'count32': 1, 'count32u': 2, 'count64': '3', 'count64u': '4'});
      expect(instance.count32, 1);
      expect(instance.count32u, 2);
      expect(instance.count64, 3);
      expect(instance.count64u, 4);
      var json = message.toResponse(instance);
      expect(json['count32'], 1);
      expect(json['count32u'], 2);
      expect(json['count64'], '3');
      expect(json['count64u'], '4');
    });

    test('request-parsing', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage1), tester);
      var instance = m1.fromRequest({'requiredValue': 10});
      expect(instance, new isInstanceOf<TestMessage1>());
      instance = m1.fromRequest({
        'count': 1,
        'message': 'message',
        'value': 12.3,
        'check': true,
        'messages': ['1', '2', '3'],
        'date': '2014-01-23T11:12:13.456Z',
        'submessage': {
          'count': 4
        },
        'submessages': [
          {'count': 5},
          {'count': 6},
          {'count': 7}
        ],
        'enumValue': 'test1',
        'limit': 50,
      });
      expect(instance, new isInstanceOf<TestMessage1>());
      expect(instance.count, 1);
      expect(instance.message, 'message');
      expect(instance.value, 12.3);
      expect(instance.messages, ['1', '2', '3']);
      expect(instance.date.isUtc, true);
      expect(instance.date.year, 2014);
      expect(instance.date.month, 1);
      expect(instance.date.day, 23);
      expect(instance.date.hour, 11);
      expect(instance.date.minute, 12);
      expect(instance.date.second, 13);
      expect(instance.date.millisecond, 456);
      expect(instance.submessage, new isInstanceOf<TestMessage2>());
      expect(instance.submessage.count, 4);
      expect(instance.submessages, new isInstanceOf<List<TestMessage2>>());
      expect(instance.submessages.length, 3);
      expect(instance.submessages[0].count, 5);
      expect(instance.submessages[1].count, 6);
      expect(instance.submessages[2].count, 7);
      expect(instance.enumValue, 'test1');
      expect(instance.defaultValue, 10);
    });

    test('required', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage4), tester);
      expect(() => m1.fromRequest({'requiredValue': 1}), returnsNormally);
    });

    test('bad-request-creation', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage1), tester);
      var requests = [
        {'count': 'x'},
        {'date': 'x'},
        {'value': 'x'},
        {'messages': 'x'},
        {'submessage': 'x'},
        {'submessage': {'count': 'x'}},
        {'submessages': ['x']},
        {'submessages': [{'count': 'x'}]},
        {'enumValue': 'x'},
        {'limit': 1},
        {'limit': 1000}
      ];
      requests.forEach((request) {
        expect(
          () => m1.fromRequest(request),
          throwsA(new isInstanceOf<BadRequestError>())
        );
      });
    });

    test('missing-required', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage4), tester);
      var requests = [{}, {'count': 1}];
      requests.forEach((request) {
        expect(
          () => m1.fromRequest(request),
          throwsA(new isInstanceOf<BadRequestError>())
        );
      });
    });

    test('response-creation', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage1), tester);
      var instance = new TestMessage1();
      instance.count = 1;
      instance.message = 'message';
      instance.value = 12.3;
      instance.check = true;
      instance.messages = ['1', '2', '3'];
      instance.enumValue = 'test1';
      var date = new DateTime.now();
      var utcDate = date.toUtc();
      instance.date = date;
      var instance2 = new TestMessage2();
      instance2.count = 4;
      instance.submessage = instance2;
      var instance3 = new TestMessage2();
      instance3.count = 5;
      var instance4 = new TestMessage2();
      instance4.count = 6;
      var instance5 = new TestMessage2();
      instance5.count = 7;
      instance.submessages = [instance3, instance4, instance5];

      var response = m1.toResponse(instance);
      expect(response, new isInstanceOf<Map>());
      expect(response['count'], 1);
      expect(response['message'], 'message');
      expect(response['value'], 12.3);
      expect(response['check'], true);
      expect(response['messages'], ['1', '2', '3']);
      expect(response['date'], utcDate.toIso8601String());
      expect(response['submessage'], new isInstanceOf<Map>());
      expect(response['submessage']['count'], 4);
      expect(response['submessages'], new isInstanceOf<List>());
      expect(response['submessages'].length, 3);
      expect(response['submessages'][0]['count'], 5);
      expect(response['submessages'][1]['count'], 6);
      expect(response['submessages'][2]['count'], 7);
      expect(response['enumValue'], 'test1');
    });
  });
}
