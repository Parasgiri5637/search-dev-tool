import 'dart:io';
import 'package:flutter_code_map_analyzer/flutter_code_map.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Incremental Cache', () {
    late Directory tempDir;
    late SymbolTable symbolTable;
    late KnowledgeGraph graph;
    late ProjectCache cache;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cache_test_');
      symbolTable = SymbolTable();
      graph = KnowledgeGraph();
      cache = ProjectCache();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('updates graph and symbol table on incremental file change', () {
      final fileA = File(p.join(tempDir.path, 'user.dart'));
      fileA.writeAsStringSync('class User { String name = ""; }');

      cache.indexFiles([fileA.path], symbolTable: symbolTable, graph: graph);

      expect(symbolTable.findByName('User').isNotEmpty, isTrue);
      expect(symbolTable.findByName('Admin').isEmpty, isTrue);

      // Modify file to rename User to Admin
      fileA.writeAsStringSync('class Admin { String role = ""; }');

      cache.updateFile(fileA.path, symbolTable: symbolTable, graph: graph);

      expect(symbolTable.findByName('User').isEmpty, isTrue);
      expect(symbolTable.findByName('Admin').isNotEmpty, isTrue);
    });
  });
}
