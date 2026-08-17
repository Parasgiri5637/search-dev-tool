import 'package:meta/meta.dart';

/// Represents a source location in a Dart file.
@immutable
class SourceLocation {
  /// The normalized absolute or workspace-relative path to the file.
  final String filePath;

  /// 1-based line number where the element starts.
  final int line;

  /// 1-based column number where the element starts.
  final int column;

  /// 0-based character offset from the start of the file.
  final int offset;

  /// The character length of the element declaration.
  final int length;

  /// 1-based line number where the element ends.
  final int endLine;

  /// 1-based column number where the element ends.
  final int endColumn;

  const SourceLocation({
    required this.filePath,
    required this.line,
    required this.column,
    required this.offset,
    required this.length,
    required this.endLine,
    required this.endColumn,
  });

  /// Formats the source location as `filePath:line:column`.
  String get displayString => '$filePath:$line:$column';

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'line': line,
        'column': column,
        'offset': offset,
        'length': length,
        'endLine': endLine,
        'endColumn': endColumn,
      };

  factory SourceLocation.fromJson(Map<String, dynamic> json) {
    return SourceLocation(
      filePath: json['filePath'] as String,
      line: json['line'] as int,
      column: json['column'] as int,
      offset: json['offset'] as int,
      length: json['length'] as int,
      endLine: json['endLine'] as int? ?? json['line'] as int,
      endColumn: json['endColumn'] as int? ?? json['column'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceLocation &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath &&
          line == other.line &&
          column == other.column &&
          offset == other.offset &&
          length == other.length &&
          endLine == other.endLine &&
          endColumn == other.endColumn;

  @override
  int get hashCode => Object.hash(
        filePath,
        line,
        column,
        offset,
        length,
        endLine,
        endColumn,
      );

  @override
  String toString() => displayString;
}
