import 'package:flutter_code_map_analyzer/flutter_code_map.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AstParser', () {
    const parser = AstParser();
    final fixturesPath = p.join(
      p.current,
      'test',
      'fixtures',
    );

    test('extracts imports, combinators, prefixes, and exports', () {
      final sampleFile = p.join(fixturesPath, 'sample_code.dart');
      final result = parser.parseFile(sampleFile);

      expect(result.hasErrors, isFalse);
      expect(result.imports.length, equals(3));

      // dart:async import
      final asyncImport =
          result.imports.firstWhere((i) => i.uri == 'dart:async');
      expect(asyncImport.prefix, equals('async_lib'));

      // package:meta import with show
      final metaImport =
          result.imports.firstWhere((i) => i.uri == 'package:meta/meta.dart');
      expect(
        metaImport.showCombinators,
        containsAll(['immutable', 'visibleForTesting']),
      );

      // flutter widgets with hide
      final flutterImport = result.imports
          .firstWhere((i) => i.uri == 'package:flutter/widgets.dart');
      expect(flutterImport.hideCombinators, contains('Container'));

      // Exports
      expect(result.exports.length, equals(1));
      expect(result.exports.first.uri, equals('dart:math'));
      expect(result.exports.first.showCombinators, contains('Random'));
    });

    test('extracts classes, hierarchy, annotations, and members', () {
      final sampleFile = p.join(fixturesPath, 'sample_code.dart');
      final result = parser.parseFile(sampleFile);

      expect(result.classes.length, equals(3));

      // BaseService
      final baseService =
          result.classes.firstWhere((c) => c.name == 'BaseService');
      expect(baseService.isAbstract, isTrue);
      expect(
        baseService.annotations.any((a) => a.name == 'immutable'),
        isTrue,
      );
      expect(baseService.constructors.length, equals(1));
      expect(baseService.constructors.first.isConst, isTrue);
      expect(baseService.methods.length, equals(1));
      expect(baseService.methods.first.name, equals('connect'));
      expect(baseService.fields.length, equals(1));
      expect(baseService.fields.first.name, equals('serviceUrl'));

      // AuthService
      final authService =
          result.classes.firstWhere((c) => c.name == 'AuthService');
      expect(authService.superclass, equals('BaseService'));
      expect(authService.mixins, contains('LogMixin'));
      expect(authService.interfaces, contains('Disposable'));

      // AuthService constructors
      expect(authService.constructors.length, equals(3));
      final defaultCtor =
          authService.constructors.firstWhere((c) => c.name == '');
      expect(defaultCtor.displayName, equals('AuthService'));

      final customCtor =
          authService.constructors.firstWhere((c) => c.name == 'custom');
      expect(customCtor.displayName, equals('AuthService.custom'));
      expect(customCtor.parameters.length, equals(2));
      expect(customCtor.parameters.any((p) => p.name == 'url' && p.isRequired),
          isTrue);

      final factoryCtor =
          authService.constructors.firstWhere((c) => c.name == 'create');
      expect(factoryCtor.isFactory, isTrue);

      // AuthService methods & getters/setters
      expect(
        authService.methods.any((m) => m.name == 'isAuthenticated' && m.isGetter),
        isTrue,
      );
      expect(
        authService.methods.any((m) => m.name == 'token' && m.isSetter),
        isTrue,
      );
      final connectMethod =
          authService.methods.firstWhere((m) => m.name == 'connect');
      expect(connectMethod.isAsync, isTrue);
      expect(
        connectMethod.annotations.any((a) => a.name == 'override'),
        isTrue,
      );

      // AuthService fields
      expect(
        authService.fields
            .any((f) => f.name == 'version' && f.isStatic && f.isConst),
        isTrue,
      );
      expect(
        authService.fields.any((f) => f.name == '_token' && f.isLate),
        isTrue,
      );
    });

    test('extracts enums, mixins, extensions, and top-level declarations', () {
      final sampleFile = p.join(fixturesPath, 'sample_code.dart');
      final result = parser.parseFile(sampleFile);

      // Enums
      expect(result.enums.length, equals(1));
      final authStatus = result.enums.first;
      expect(authStatus.name, equals('AuthStatus'));
      expect(
        authStatus.constants,
        containsAll(['unauthenticated', 'authenticating', 'authenticated']),
      );
      expect(authStatus.methods.any((m) => m.name == 'isDone'), isTrue);

      // Mixins
      expect(result.mixins.length, equals(1));
      final logMixin = result.mixins.first;
      expect(logMixin.name, equals('LogMixin'));
      expect(logMixin.superclassConstraints, contains('Object'));
      expect(logMixin.methods.any((m) => m.name == 'log'), isTrue);

      // Extensions
      expect(result.extensions.length, equals(1));
      final strExt = result.extensions.first;
      expect(strExt.name, equals('StringValidation'));
      expect(strExt.extendedType, equals('String'));
      expect(strExt.methods.any((m) => m.name == 'isValidEmail'), isTrue);

      // Top-level functions
      expect(result.functions.length, equals(1));
      final calcFunc = result.functions.first;
      expect(calcFunc.name, equals('calculateTotal'));
      expect(calcFunc.isAsync, isTrue);
      expect(calcFunc.returnType, equals('Future<int>'));
      expect(calcFunc.parameters.length, equals(2));
      expect(calcFunc.parameters[0].name, equals('a'));
      expect(calcFunc.parameters[1].name, equals('b'));
      expect(calcFunc.parameters[1].defaultValue, equals('0'));

      // Top-level variables (captured as fields without parent)
      final topVars = result.elements
          .whereType<FieldElement>()
          .where((f) => f.parent == null)
          .toList();
      expect(topVars.length, equals(1));
      expect(topVars.first.name, equals('defaultTimeout'));
      expect(topVars.first.isConst, isTrue);
    });

    test('captures valid source locations for all elements', () {
      final sampleFile = p.join(fixturesPath, 'sample_code.dart');
      final result = parser.parseFile(sampleFile);

      for (final el in result.elements) {
        expect(el.file, equals(sampleFile));
        expect(el.line, greaterThan(0));
        expect(el.column, greaterThan(0));
        expect(el.location.offset, greaterThanOrEqualTo(0));
        expect(el.location.length, greaterThan(0));
        expect(el.location.endLine, greaterThanOrEqualTo(el.line));
      }
    });

    test('gracefully handles malformed Dart files without crashing', () {
      final malformedFile = p.join(fixturesPath, 'malformed_code.dart');
      final result = parser.parseFile(malformedFile);

      expect(result.hasErrors, isTrue);
      expect(result.errors.isNotEmpty, isTrue);

      // Check error details
      final firstError = result.errors.first;
      expect(firstError.message.isNotEmpty, isTrue);
      expect(firstError.location.line, greaterThan(0));

      // Resilient: partial AST is still recovered
      expect(result.classes.any((c) => c.name == 'BrokenClass'), isTrue);
    });

    test('handles missing file gracefully with FILE_NOT_FOUND', () {
      final result = parser.parseFile('/non/existent/path/dummy.dart');
      expect(result.hasErrors, isTrue);
      expect(result.errors.first.errorCode, equals('FILE_NOT_FOUND'));
    });

    test('supports JSON serialization of results', () {
      final sampleFile = p.join(fixturesPath, 'sample_code.dart');
      final result = parser.parseFile(sampleFile);
      final json = result.toJson();

      expect(json['filePath'], equals(sampleFile));
      expect(json['hasErrors'], isFalse);
      expect(json['elements'], isA<List<dynamic>>());
      expect((json['elements'] as List<dynamic>).isNotEmpty, isTrue);
    });
  });
}
