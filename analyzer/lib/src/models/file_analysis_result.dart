import 'package:meta/meta.dart';
import 'ast_element.dart';
import 'source_location.dart';

/// Represents a syntax or analyzer error encountered during parsing.
@immutable
class AnalysisError {
  final String message;
  final String? errorCode;
  final SourceLocation location;

  const AnalysisError({
    required this.message,
    this.errorCode,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'errorCode': errorCode,
        'location': location.toJson(),
      };

  factory AnalysisError.fromJson(Map<String, dynamic> json) {
    return AnalysisError(
      message: json['message'] as String,
      errorCode: json['errorCode'] as String?,
      location:
          SourceLocation.fromJson(json['location'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() => '$location: $message (${errorCode ?? 'error'})';
}

/// Analysis result for a single parsed Dart file.
@immutable
class FileAnalysisResult {
  /// The path to the analyzed file.
  final String filePath;

  /// All top-level and member AST elements discovered in the file.
  final List<AstElement> elements;

  /// Any parse/syntax errors encountered while parsing the file.
  final List<AnalysisError> errors;

  const FileAnalysisResult({
    required this.filePath,
    required this.elements,
    this.errors = const [],
  });

  /// Whether the file had any errors during parsing.
  bool get hasErrors => errors.isNotEmpty;

  /// All import directives.
  List<ImportElement> get imports => elements.whereType<ImportElement>().toList();

  /// All export directives.
  List<ExportElement> get exports => elements.whereType<ExportElement>().toList();

  /// All part directives.
  List<PartElement> get parts => elements.whereType<PartElement>().toList();

  /// All part-of directives.
  List<PartOfElement> get partOfs => elements.whereType<PartOfElement>().toList();

  /// All class declarations.
  List<ClassElement> get classes => elements.whereType<ClassElement>().toList();

  /// All enum declarations.
  List<EnumElement> get enums => elements.whereType<EnumElement>().toList();

  /// All mixin declarations.
  List<MixinElement> get mixins => elements.whereType<MixinElement>().toList();

  /// All extension declarations.
  List<ExtensionElement> get extensions =>
      elements.whereType<ExtensionElement>().toList();

  /// All top-level function declarations.
  List<FunctionElement> get functions =>
      elements.whereType<FunctionElement>().toList();

  /// Converts the file analysis result to JSON.
  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'hasErrors': hasErrors,
        'errors': errors.map((e) => e.toJson()).toList(),
        'elements': elements.map((e) => e.toJson()).toList(),
      };
}
