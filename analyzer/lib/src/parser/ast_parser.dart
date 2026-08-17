import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;

import '../models/file_analysis_result.dart';
import '../models/source_location.dart';
import 'ast_visitor.dart';

/// Parses Dart source code and files into structured [FileAnalysisResult] models.
class AstParser {
  const AstParser();

  /// Parses a Dart source file from [filePath].
  FileAnalysisResult parseFile(String filePath) {
    final normalizedPath = p.normalize(p.absolute(filePath));
    final file = File(normalizedPath);

    if (!file.existsSync()) {
      return FileAnalysisResult(
        filePath: normalizedPath,
        elements: const [],
        errors: [
          AnalysisError(
            message: 'File does not exist: $filePath',
            errorCode: 'FILE_NOT_FOUND',
            location: SourceLocation(
              filePath: normalizedPath,
              line: 1,
              column: 1,
              offset: 0,
              length: 0,
              endLine: 1,
              endColumn: 1,
            ),
          ),
        ],
      );
    }

    String content;
    try {
      content = file.readAsStringSync();
    } catch (e) {
      return FileAnalysisResult(
        filePath: normalizedPath,
        elements: const [],
        errors: [
          AnalysisError(
            message: 'Failed to read file: $e',
            errorCode: 'FILE_READ_ERROR',
            location: SourceLocation(
              filePath: normalizedPath,
              line: 1,
              column: 1,
              offset: 0,
              length: 0,
              endLine: 1,
              endColumn: 1,
            ),
          ),
        ],
      );
    }

    return parseSource(content, filePath: normalizedPath);
  }

  /// Parses Dart source [content] string directly.
  FileAnalysisResult parseSource(
    String content, {
    String filePath = '<memory>',
  }) {
    final normalizedPath = p.normalize(filePath);
    final errors = <AnalysisError>[];

    try {
      final parseResult = parseString(
        content: content,
        path: normalizedPath,
        throwIfDiagnostics: false,
      );

      final unit = parseResult.unit;
      final lineInfo = parseResult.lineInfo;

      for (final err in parseResult.errors) {
        final startLoc = lineInfo.getLocation(err.offset);
        final endLoc = lineInfo.getLocation(err.offset + err.length);
        errors.add(
          AnalysisError(
            message: err.message,
            errorCode: err.errorCode.name,
            location: SourceLocation(
              filePath: normalizedPath,
              line: startLoc.lineNumber,
              column: startLoc.columnNumber,
              offset: err.offset,
              length: err.length,
              endLine: endLoc.lineNumber,
              endColumn: endLoc.columnNumber,
            ),
          ),
        );
      }

      final visitor = CodeMapAstVisitor(
        filePath: normalizedPath,
        lineInfo: lineInfo,
      );
      unit.accept(visitor);

      return FileAnalysisResult(
        filePath: normalizedPath,
        elements: visitor.elements,
        errors: errors,
      );
    } catch (e) {
      return FileAnalysisResult(
        filePath: normalizedPath,
        elements: const [],
        errors: [
          AnalysisError(
            message: 'Unexpected parsing failure: $e',
            errorCode: 'UNEXPECTED_PARSE_EXCEPTION',
            location: SourceLocation(
              filePath: normalizedPath,
              line: 1,
              column: 1,
              offset: 0,
              length: 0,
              endLine: 1,
              endColumn: 1,
            ),
          ),
        ],
      );
    }
  }

  /// Parses a batch of Dart files.
  List<FileAnalysisResult> parseFiles(List<String> filePaths) {
    return filePaths.map(parseFile).toList();
  }
}
