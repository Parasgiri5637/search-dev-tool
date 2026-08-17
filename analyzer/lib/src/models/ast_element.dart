import 'package:meta/meta.dart';
import 'source_location.dart';

/// The kind of AST element.
enum AstElementKind {
  compilationUnit,
  importDirective,
  exportDirective,
  partDirective,
  partOfDirective,
  classDeclaration,
  enumDeclaration,
  mixinDeclaration,
  extensionDeclaration,
  functionDeclaration,
  methodDeclaration,
  constructorDeclaration,
  fieldDeclaration,
  topLevelVariableDeclaration,
  enumConstantDeclaration,
  parameterDeclaration,
  annotation,
}

/// Base class for all discovered AST elements.
@immutable
abstract class AstElement {
  /// The identifier/name of the element (e.g. class name, method name, or URI for directives).
  String get name;

  /// The element kind.
  AstElementKind get kind;

  /// The parent identifier (e.g., class name for methods/fields, library name, or null).
  String? get parent;

  /// Exact source code location.
  SourceLocation get location;

  /// List of annotations attached to this element.
  List<AnnotationElement> get annotations;

  /// The file path where this element is declared.
  String get file => location.filePath;

  /// 1-based starting line number.
  int get line => location.line;

  /// 1-based starting column number.
  int get column => location.column;

  const AstElement();

  /// Converts the element into a JSON-encodable map.
  Map<String, dynamic> toJson();
}

/// An annotation on an element (e.g., `@override`, `@immutable`, `@Route('/')`).
@immutable
class AnnotationElement {
  final String name;
  final List<String> arguments;
  final SourceLocation location;

  const AnnotationElement({
    required this.name,
    this.arguments = const [],
    required this.location,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'arguments': arguments,
        'location': location.toJson(),
      };

  factory AnnotationElement.fromJson(Map<String, dynamic> json) {
    return AnnotationElement(
      name: json['name'] as String,
      arguments: (json['arguments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      location:
          SourceLocation.fromJson(json['location'] as Map<String, dynamic>),
    );
  }
}

/// Parameter definition for functions, methods, and constructors.
@immutable
class ParameterElement {
  final String name;
  final String? type;
  final bool isRequired;
  final bool isNamed;
  final bool isPositional;
  final String? defaultValue;
  final SourceLocation location;

  const ParameterElement({
    required this.name,
    this.type,
    this.isRequired = false,
    this.isNamed = false,
    this.isPositional = true,
    this.defaultValue,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'isRequired': isRequired,
        'isNamed': isNamed,
        'isPositional': isPositional,
        'defaultValue': defaultValue,
        'location': location.toJson(),
      };

  factory ParameterElement.fromJson(Map<String, dynamic> json) {
    return ParameterElement(
      name: json['name'] as String,
      type: json['type'] as String?,
      isRequired: json['isRequired'] as bool? ?? false,
      isNamed: json['isNamed'] as bool? ?? false,
      isPositional: json['isPositional'] as bool? ?? true,
      defaultValue: json['defaultValue'] as String?,
      location:
          SourceLocation.fromJson(json['location'] as Map<String, dynamic>),
    );
  }
}

/// An import directive in a Dart file.
@immutable
class ImportElement extends AstElement {
  final String uri;
  final String? prefix;
  final List<String> showCombinators;
  final List<String> hideCombinators;
  final bool isDeferred;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  String get name => uri;

  @override
  AstElementKind get kind => AstElementKind.importDirective;

  @override
  String? get parent => null;

  const ImportElement({
    required this.uri,
    this.prefix,
    this.showCombinators = const [],
    this.hideCombinators = const [],
    this.isDeferred = false,
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'uri': uri,
        'prefix': prefix,
        'showCombinators': showCombinators,
        'hideCombinators': hideCombinators,
        'isDeferred': isDeferred,
        'file': file,
        'line': line,
        'column': column,
        'parent': parent,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// An export directive in a Dart file.
@immutable
class ExportElement extends AstElement {
  final String uri;
  final List<String> showCombinators;
  final List<String> hideCombinators;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  String get name => uri;

  @override
  AstElementKind get kind => AstElementKind.exportDirective;

  @override
  String? get parent => null;

  const ExportElement({
    required this.uri,
    this.showCombinators = const [],
    this.hideCombinators = const [],
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'uri': uri,
        'showCombinators': showCombinators,
        'hideCombinators': hideCombinators,
        'file': file,
        'line': line,
        'column': column,
        'parent': parent,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// A part directive in a Dart file (`part 'foo.dart';`).
@immutable
class PartElement extends AstElement {
  final String uri;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  String get name => uri;

  @override
  AstElementKind get kind => AstElementKind.partDirective;

  @override
  String? get parent => null;

  const PartElement({
    required this.uri,
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'uri': uri,
        'file': file,
        'line': line,
        'column': column,
        'parent': parent,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// A part-of directive in a Dart file (`part of 'foo.dart';` or `part of foo_lib;`).
@immutable
class PartOfElement extends AstElement {
  final String? uri;
  final String? libraryName;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  String get name => uri ?? libraryName ?? '';

  @override
  AstElementKind get kind => AstElementKind.partOfDirective;

  @override
  String? get parent => null;

  const PartOfElement({
    this.uri,
    this.libraryName,
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'uri': uri,
        'libraryName': libraryName,
        'file': file,
        'line': line,
        'column': column,
        'parent': parent,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// A class declaration.
@immutable
class ClassElement extends AstElement {
  @override
  final String name;

  final bool isAbstract;
  final bool isSealed;
  final bool isBase;
  final bool isInterface;
  final bool isFinal;
  final bool isMixinClass;

  /// Superclass name (e.g. `StatelessWidget`, `Object`), if any.
  final String? superclass;

  /// List of mixins applied with `with` (e.g. `['SingleTickerProviderStateMixin']`).
  final List<String> mixins;

  /// List of interfaces implemented with `implements` (e.g. `['Disposable']`).
  final List<String> interfaces;

  /// Class constructors.
  final List<ConstructorElement> constructors;

  /// Class methods.
  final List<MethodElement> methods;

  /// Class fields/properties.
  final List<FieldElement> fields;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  AstElementKind get kind => AstElementKind.classDeclaration;

  @override
  String? get parent => null;

  const ClassElement({
    required this.name,
    this.isAbstract = false,
    this.isSealed = false,
    this.isBase = false,
    this.isInterface = false,
    this.isFinal = false,
    this.isMixinClass = false,
    this.superclass,
    this.mixins = const [],
    this.interfaces = const [],
    this.constructors = const [],
    this.methods = const [],
    this.fields = const [],
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'isAbstract': isAbstract,
        'isSealed': isSealed,
        'isBase': isBase,
        'isInterface': isInterface,
        'isFinal': isFinal,
        'isMixinClass': isMixinClass,
        'superclass': superclass,
        'mixins': mixins,
        'interfaces': interfaces,
        'constructors': constructors.map((c) => c.toJson()).toList(),
        'methods': methods.map((m) => m.toJson()).toList(),
        'fields': fields.map((f) => f.toJson()).toList(),
        'file': file,
        'line': line,
        'column': column,
        'parent': parent,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// An enum declaration.
@immutable
class EnumElement extends AstElement {
  @override
  final String name;

  final List<String> constants;
  final List<String> mixins;
  final List<String> interfaces;
  final List<ConstructorElement> constructors;
  final List<MethodElement> methods;
  final List<FieldElement> fields;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  AstElementKind get kind => AstElementKind.enumDeclaration;

  @override
  String? get parent => null;

  const EnumElement({
    required this.name,
    this.constants = const [],
    this.mixins = const [],
    this.interfaces = const [],
    this.constructors = const [],
    this.methods = const [],
    this.fields = const [],
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'constants': constants,
        'mixins': mixins,
        'interfaces': interfaces,
        'constructors': constructors.map((c) => c.toJson()).toList(),
        'methods': methods.map((m) => m.toJson()).toList(),
        'fields': fields.map((f) => f.toJson()).toList(),
        'file': file,
        'line': line,
        'column': column,
        'parent': parent,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// A mixin declaration.
@immutable
class MixinElement extends AstElement {
  @override
  final String name;

  final List<String> superclassConstraints;
  final List<String> interfaces;
  final List<MethodElement> methods;
  final List<FieldElement> fields;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  AstElementKind get kind => AstElementKind.mixinDeclaration;

  @override
  String? get parent => null;

  const MixinElement({
    required this.name,
    this.superclassConstraints = const [],
    this.interfaces = const [],
    this.methods = const [],
    this.fields = const [],
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'superclassConstraints': superclassConstraints,
        'interfaces': interfaces,
        'methods': methods.map((m) => m.toJson()).toList(),
        'fields': fields.map((f) => f.toJson()).toList(),
        'file': file,
        'line': line,
        'column': column,
        'parent': parent,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// An extension declaration.
@immutable
class ExtensionElement extends AstElement {
  @override
  final String name;

  final String? extendedType;
  final List<MethodElement> methods;
  final List<FieldElement> fields;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  AstElementKind get kind => AstElementKind.extensionDeclaration;

  @override
  String? get parent => null;

  const ExtensionElement({
    required this.name,
    this.extendedType,
    this.methods = const [],
    this.fields = const [],
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'extendedType': extendedType,
        'methods': methods.map((m) => m.toJson()).toList(),
        'fields': fields.map((f) => f.toJson()).toList(),
        'file': file,
        'line': line,
        'column': column,
        'parent': parent,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// A top-level function declaration.
@immutable
class FunctionElement extends AstElement {
  @override
  final String name;

  final String? returnType;
  final List<ParameterElement> parameters;
  final bool isAsync;
  final bool isGetter;
  final bool isSetter;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  AstElementKind get kind => AstElementKind.functionDeclaration;

  @override
  String? get parent => null;

  const FunctionElement({
    required this.name,
    this.returnType,
    this.parameters = const [],
    this.isAsync = false,
    this.isGetter = false,
    this.isSetter = false,
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'returnType': returnType,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'isAsync': isAsync,
        'isGetter': isGetter,
        'isSetter': isSetter,
        'file': file,
        'line': line,
        'column': column,
        'parent': parent,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// A method declaration inside a class, enum, mixin, or extension.
@immutable
class MethodElement extends AstElement {
  @override
  final String name;

  @override
  final String parent;

  final String? returnType;
  final List<ParameterElement> parameters;
  final bool isStatic;
  final bool isAbstract;
  final bool isGetter;
  final bool isSetter;
  final bool isAsync;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  AstElementKind get kind => AstElementKind.methodDeclaration;

  const MethodElement({
    required this.name,
    required this.parent,
    this.returnType,
    this.parameters = const [],
    this.isStatic = false,
    this.isAbstract = false,
    this.isGetter = false,
    this.isSetter = false,
    this.isAsync = false,
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'parent': parent,
        'returnType': returnType,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'isStatic': isStatic,
        'isAbstract': isAbstract,
        'isGetter': isGetter,
        'isSetter': isSetter,
        'isAsync': isAsync,
        'file': file,
        'line': line,
        'column': column,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// A constructor declaration inside a class or enum.
@immutable
class ConstructorElement extends AstElement {
  @override
  final String name;

  @override
  final String parent;

  final bool isFactory;
  final bool isConst;
  final List<ParameterElement> parameters;
  final String? redirectedConstructor;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  AstElementKind get kind => AstElementKind.constructorDeclaration;

  /// Returns full constructor name, e.g. `LoginPage` or `LoginPage.named`.
  String get displayName => name.isEmpty ? parent : '$parent.$name';

  const ConstructorElement({
    required this.name,
    required this.parent,
    this.isFactory = false,
    this.isConst = false,
    this.parameters = const [],
    this.redirectedConstructor,
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'displayName': displayName,
        'parent': parent,
        'isFactory': isFactory,
        'isConst': isConst,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'redirectedConstructor': redirectedConstructor,
        'file': file,
        'line': line,
        'column': column,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}

/// A field or property declaration inside a class, enum, mixin, or extension.
@immutable
class FieldElement extends AstElement {
  @override
  final String name;

  @override
  final String? parent;

  final String? type;
  final bool isStatic;
  final bool isFinal;
  final bool isConst;
  final bool isLate;

  @override
  final SourceLocation location;

  @override
  final List<AnnotationElement> annotations;

  @override
  AstElementKind get kind => AstElementKind.fieldDeclaration;

  const FieldElement({
    required this.name,
    this.parent,
    this.type,
    this.isStatic = false,
    this.isFinal = false,
    this.isConst = false,
    this.isLate = false,
    required this.location,
    this.annotations = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'name': name,
        'parent': parent,
        'type': type,
        'isStatic': isStatic,
        'isFinal': isFinal,
        'isConst': isConst,
        'isLate': isLate,
        'file': file,
        'line': line,
        'column': column,
        'location': location.toJson(),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };
}
