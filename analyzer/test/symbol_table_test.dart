import 'package:flutter_code_map_analyzer/flutter_code_map.dart';
import 'package:test/test.dart';

void main() {
  group('SymbolTable', () {
    late SymbolTable table;

    setUp(() {
      table = SymbolTable();
    });

    test('registers and retrieves symbols by ID, name, and qualified name', () {
      const loc = SourceLocation(
        filePath: 'lib/auth_bloc.dart',
        line: 10,
        column: 5,
        offset: 100,
        length: 20,
        endLine: 10,
        endColumn: 25,
      );

      final symbol = CodeSymbol(
        id: 'lib/auth_bloc.dart#AuthBloc.login',
        name: 'login',
        qualifiedName: 'AuthBloc.login',
        kind: SymbolKind.methodSymbol,
        parentName: 'AuthBloc',
        location: loc,
      );

      table.register(symbol);

      expect(table.findById('lib/auth_bloc.dart#AuthBloc.login'), equals(symbol));
      expect(table.findByName('login'), contains(symbol));
      expect(table.findByQualifiedName('AuthBloc.login'), contains(symbol));
      expect(table.findByFile('lib/auth_bloc.dart'), contains(symbol));
      expect(table.findByKind(SymbolKind.methodSymbol), contains(symbol));
    });

    test('searches symbols case-insensitively', () {
      const loc = SourceLocation(
        filePath: 'lib/login_page.dart',
        line: 1,
        column: 1,
        offset: 0,
        length: 50,
        endLine: 5,
        endColumn: 1,
      );

      final sym1 = CodeSymbol(
        id: 'lib/login_page.dart#LoginPage',
        name: 'LoginPage',
        qualifiedName: 'LoginPage',
        kind: SymbolKind.classSymbol,
        location: loc,
      );

      final sym2 = CodeSymbol(
        id: 'lib/login_page.dart#LoginForm',
        name: 'LoginForm',
        qualifiedName: 'LoginForm',
        kind: SymbolKind.classSymbol,
        location: loc,
      );

      table.register(sym1);
      table.register(sym2);

      final results = table.search('login');
      expect(results.length, equals(2));
      expect(results, containsAll([sym1, sym2]));
    });

    test('removes all symbols for a specific file on update', () {
      const loc1 = SourceLocation(
        filePath: 'lib/a.dart',
        line: 1,
        column: 1,
        offset: 0,
        length: 10,
        endLine: 1,
        endColumn: 10,
      );
      const loc2 = SourceLocation(
        filePath: 'lib/b.dart',
        line: 1,
        column: 1,
        offset: 0,
        length: 10,
        endLine: 1,
        endColumn: 10,
      );

      final s1 = CodeSymbol(
        id: 'lib/a.dart#ClassA',
        name: 'ClassA',
        qualifiedName: 'ClassA',
        kind: SymbolKind.classSymbol,
        location: loc1,
      );
      final s2 = CodeSymbol(
        id: 'lib/b.dart#ClassB',
        name: 'ClassB',
        qualifiedName: 'ClassB',
        kind: SymbolKind.classSymbol,
        location: loc2,
      );

      table.register(s1);
      table.register(s2);

      expect(table.allSymbols.length, equals(2));
      table.removeFile('lib/a.dart');

      expect(table.allSymbols.length, equals(1));
      expect(table.findById('lib/a.dart#ClassA'), isNull);
      expect(table.findById('lib/b.dart#ClassB'), equals(s2));
    });
  });
}
