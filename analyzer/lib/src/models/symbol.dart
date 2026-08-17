import 'package:meta/meta.dart';
import 'source_location.dart';

/// The specific classification of a code symbol.
enum SymbolKind {
  classSymbol,
  enumSymbol,
  mixinSymbol,
  extensionSymbol,
  functionSymbol,
  methodSymbol,
  constructorSymbol,
  fieldSymbol,
  topLevelVariableSymbol,
  widgetSymbol,
  blocSymbol,
  cubitSymbol,
  providerSymbol,
  routeSymbol,
}

/// Represents a resolved code symbol in the workspace.
@immutable
class CodeSymbol {
  /// Unique identifier across the project, e.g. `lib/auth/auth_bloc.dart#AuthBloc.login`.
  final String id;

  /// Display name of the symbol, e.g. `login` or `AuthBloc`.
  final String name;

  /// Fully qualified name, e.g. `AuthBloc.login` or `LoginPage`.
  final String qualifiedName;

  /// Classification of the symbol.
  final SymbolKind kind;

  /// Parent symbol identifier if enclosed (e.g. class name for a method).
  final String? parentName;

  /// Return type or variable type if applicable.
  final String? returnType;

  /// Exact source location where this symbol is declared.
  final SourceLocation location;

  /// Additional metadata properties (e.g. isStatic, isWidget, routePath, etc.).
  final Map<String, dynamic> metadata;

  const CodeSymbol({
    required this.id,
    required this.name,
    required this.qualifiedName,
    required this.kind,
    this.parentName,
    this.returnType,
    required this.location,
    this.metadata = const {},
  });

  /// The file path containing this symbol.
  String get filePath => location.filePath;

  /// 1-based line number.
  int get line => location.line;

  /// 1-based column number.
  int get column => location.column;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'qualifiedName': qualifiedName,
        'kind': kind.name,
        'parentName': parentName,
        'returnType': returnType,
        'location': location.toJson(),
        'metadata': metadata,
      };

  factory CodeSymbol.fromJson(Map<String, dynamic> json) {
    return CodeSymbol(
      id: json['id'] as String,
      name: json['name'] as String,
      qualifiedName: json['qualifiedName'] as String,
      kind: SymbolKind.values.firstWhere((k) => k.name == json['kind']),
      parentName: json['parentName'] as String?,
      returnType: json['returnType'] as String?,
      location:
          SourceLocation.fromJson(json['location'] as Map<String, dynamic>),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  String toString() => '$qualifiedName ($kind) at $location';
}
