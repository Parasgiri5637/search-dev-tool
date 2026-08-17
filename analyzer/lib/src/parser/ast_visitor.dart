import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../models/ast_element.dart';
import '../models/source_location.dart';

/// Traverses an AST [CompilationUnit] and extracts structured [AstElement] models.
class CodeMapAstVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final LineInfo lineInfo;

  final List<AstElement> elements = [];

  CodeMapAstVisitor({
    required this.filePath,
    required this.lineInfo,
  });

  SourceLocation _createLocation(int offset, int length) {
    final startLoc = lineInfo.getLocation(offset);
    final endLoc = lineInfo.getLocation(offset + length);
    return SourceLocation(
      filePath: filePath,
      line: startLoc.lineNumber,
      column: startLoc.columnNumber,
      offset: offset,
      length: length,
      endLine: endLoc.lineNumber,
      endColumn: endLoc.columnNumber,
    );
  }

  List<AnnotationElement> _extractAnnotations(List<Annotation> metadata) {
    return metadata.map((ann) {
      final args = ann.arguments?.arguments.map((a) => a.toSource()).toList() ??
          const <String>[];
      return AnnotationElement(
        name: ann.name.name,
        arguments: args,
        location: _createLocation(ann.offset, ann.length),
      );
    }).toList();
  }

  List<ParameterElement> _extractParameters(FormalParameterList? paramList) {
    if (paramList == null) return const [];
    return paramList.parameters.map((param) {
      String? paramType;
      String paramName = '';
      String? defaultValue;
      final isNamed = param.isNamed;
      final isPositional = param.isPositional;
      final isRequired = param.isRequired;

      final actualParam =
          param is DefaultFormalParameter ? param.parameter : param;

      if (param is DefaultFormalParameter && param.defaultValue != null) {
        defaultValue = param.defaultValue!.toSource();
      }

      if (actualParam is SimpleFormalParameter) {
        paramName = actualParam.name?.lexeme ?? '';
        paramType = actualParam.type?.toSource();
      } else if (actualParam is FieldFormalParameter) {
        paramName = actualParam.name.lexeme;
        paramType = actualParam.type?.toSource();
      } else if (actualParam is FunctionTypedFormalParameter) {
        paramName = actualParam.name.lexeme;
        paramType = actualParam.returnType?.toSource();
      } else if (actualParam is SuperFormalParameter) {
        paramName = actualParam.name.lexeme;
        paramType = actualParam.type?.toSource();
      } else {
        paramName = actualParam.name?.lexeme ?? actualParam.toSource();
      }

      return ParameterElement(
        name: paramName,
        type: paramType,
        isRequired: isRequired,
        isNamed: isNamed,
        isPositional: isPositional,
        defaultValue: defaultValue,
        location: _createLocation(param.offset, param.length),
      );
    }).toList();
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue ?? node.uri.toSource();
    final prefix = node.prefix?.name;
    final showCombinators = <String>[];
    final hideCombinators = <String>[];

    for (final comb in node.combinators) {
      if (comb is ShowCombinator) {
        showCombinators.addAll(comb.shownNames.map((id) => id.name));
      } else if (comb is HideCombinator) {
        hideCombinators.addAll(comb.hiddenNames.map((id) => id.name));
      }
    }

    elements.add(
      ImportElement(
        uri: uri,
        prefix: prefix,
        showCombinators: showCombinators,
        hideCombinators: hideCombinators,
        isDeferred: node.deferredKeyword != null,
        location: _createLocation(node.offset, node.length),
        annotations: _extractAnnotations(node.metadata),
      ),
    );

    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    final uri = node.uri.stringValue ?? node.uri.toSource();
    final showCombinators = <String>[];
    final hideCombinators = <String>[];

    for (final comb in node.combinators) {
      if (comb is ShowCombinator) {
        showCombinators.addAll(comb.shownNames.map((id) => id.name));
      } else if (comb is HideCombinator) {
        hideCombinators.addAll(comb.hiddenNames.map((id) => id.name));
      }
    }

    elements.add(
      ExportElement(
        uri: uri,
        showCombinators: showCombinators,
        hideCombinators: hideCombinators,
        location: _createLocation(node.offset, node.length),
        annotations: _extractAnnotations(node.metadata),
      ),
    );

    super.visitExportDirective(node);
  }

  @override
  void visitPartDirective(PartDirective node) {
    final uri = node.uri.stringValue ?? node.uri.toSource();
    elements.add(
      PartElement(
        uri: uri,
        location: _createLocation(node.offset, node.length),
        annotations: _extractAnnotations(node.metadata),
      ),
    );
    super.visitPartDirective(node);
  }

  @override
  void visitPartOfDirective(PartOfDirective node) {
    final uri = node.uri?.stringValue;
    final libraryName = node.libraryName?.name;
    elements.add(
      PartOfElement(
        uri: uri,
        libraryName: libraryName,
        location: _createLocation(node.offset, node.length),
        annotations: _extractAnnotations(node.metadata),
      ),
    );
    super.visitPartOfDirective(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.name.lexeme;
    final superclass = node.extendsClause?.superclass.toSource();
    final mixins =
        node.withClause?.mixinTypes.map((t) => t.toSource()).toList() ??
            const <String>[];
    final interfaces =
        node.implementsClause?.interfaces.map((t) => t.toSource()).toList() ??
            const <String>[];

    final constructors = <ConstructorElement>[];
    final methods = <MethodElement>[];
    final fields = <FieldElement>[];

    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        final ctorName = member.name?.lexeme ?? '';
        final ctorParams = _extractParameters(member.parameters);
        final redirected = member.redirectedConstructor?.toSource();
        final ctorLoc = _createLocation(member.offset, member.length);
        constructors.add(
          ConstructorElement(
            name: ctorName,
            parent: className,
            isFactory: member.factoryKeyword != null,
            isConst: member.constKeyword != null,
            parameters: ctorParams,
            redirectedConstructor: redirected,
            location: ctorLoc,
            annotations: _extractAnnotations(member.metadata),
          ),
        );
      } else if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        final methodParams = _extractParameters(member.parameters);
        final methodLoc = _createLocation(member.offset, member.length);
        methods.add(
          MethodElement(
            name: methodName,
            parent: className,
            returnType: member.returnType?.toSource(),
            parameters: methodParams,
            isStatic: member.isStatic,
            isAbstract: member.isAbstract,
            isGetter: member.isGetter,
            isSetter: member.isSetter,
            isAsync: member.body.isAsynchronous,
            location: methodLoc,
            annotations: _extractAnnotations(member.metadata),
          ),
        );
      } else if (member is FieldDeclaration) {
        final fieldType = member.fields.type?.toSource();
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          final fieldLoc = _createLocation(variable.offset, variable.length);
          fields.add(
            FieldElement(
              name: fieldName,
              parent: className,
              type: fieldType,
              isStatic: member.isStatic,
              isFinal: member.fields.isFinal,
              isConst: member.fields.isConst,
              isLate: member.fields.isLate,
              location: fieldLoc,
              annotations: _extractAnnotations(member.metadata),
            ),
          );
        }
      }
    }

    final classElement = ClassElement(
      name: className,
      isAbstract: node.abstractKeyword != null,
      isSealed: node.sealedKeyword != null,
      isBase: node.baseKeyword != null,
      isInterface: node.interfaceKeyword != null,
      isFinal: node.finalKeyword != null,
      isMixinClass: node.mixinKeyword != null,
      superclass: superclass,
      mixins: mixins,
      interfaces: interfaces,
      constructors: constructors,
      methods: methods,
      fields: fields,
      location: _createLocation(node.offset, node.length),
      annotations: _extractAnnotations(node.metadata),
    );

    elements.add(classElement);
    // Add child elements to the flat element list as well for easy indexing
    elements.addAll(constructors);
    elements.addAll(methods);
    elements.addAll(fields);

    // Continue visiting if necessary
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final enumName = node.name.lexeme;
    final constants = node.constants.map((c) => c.name.lexeme).toList();
    final mixins =
        node.withClause?.mixinTypes.map((t) => t.toSource()).toList() ??
            const <String>[];
    final interfaces =
        node.implementsClause?.interfaces.map((t) => t.toSource()).toList() ??
            const <String>[];

    final constructors = <ConstructorElement>[];
    final methods = <MethodElement>[];
    final fields = <FieldElement>[];

    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        final ctorName = member.name?.lexeme ?? '';
        final ctorParams = _extractParameters(member.parameters);
        final ctorLoc = _createLocation(member.offset, member.length);
        constructors.add(
          ConstructorElement(
            name: ctorName,
            parent: enumName,
            isFactory: member.factoryKeyword != null,
            isConst: member.constKeyword != null,
            parameters: ctorParams,
            location: ctorLoc,
            annotations: _extractAnnotations(member.metadata),
          ),
        );
      } else if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        final methodParams = _extractParameters(member.parameters);
        final methodLoc = _createLocation(member.offset, member.length);
        methods.add(
          MethodElement(
            name: methodName,
            parent: enumName,
            returnType: member.returnType?.toSource(),
            parameters: methodParams,
            isStatic: member.isStatic,
            isAbstract: member.isAbstract,
            isGetter: member.isGetter,
            isSetter: member.isSetter,
            isAsync: member.body.isAsynchronous,
            location: methodLoc,
            annotations: _extractAnnotations(member.metadata),
          ),
        );
      } else if (member is FieldDeclaration) {
        final fieldType = member.fields.type?.toSource();
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          final fieldLoc = _createLocation(variable.offset, variable.length);
          fields.add(
            FieldElement(
              name: fieldName,
              parent: enumName,
              type: fieldType,
              isStatic: member.isStatic,
              isFinal: member.fields.isFinal,
              isConst: member.fields.isConst,
              isLate: member.fields.isLate,
              location: fieldLoc,
              annotations: _extractAnnotations(member.metadata),
            ),
          );
        }
      }
    }

    final enumElement = EnumElement(
      name: enumName,
      constants: constants,
      mixins: mixins,
      interfaces: interfaces,
      constructors: constructors,
      methods: methods,
      fields: fields,
      location: _createLocation(node.offset, node.length),
      annotations: _extractAnnotations(node.metadata),
    );

    elements.add(enumElement);
    elements.addAll(constructors);
    elements.addAll(methods);
    elements.addAll(fields);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final mixinName = node.name.lexeme;
    final superclassConstraints = node.onClause?.superclassConstraints
            .map((t) => t.toSource())
            .toList() ??
        const <String>[];
    final interfaces =
        node.implementsClause?.interfaces.map((t) => t.toSource()).toList() ??
            const <String>[];

    final methods = <MethodElement>[];
    final fields = <FieldElement>[];

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        final methodParams = _extractParameters(member.parameters);
        final methodLoc = _createLocation(member.offset, member.length);
        methods.add(
          MethodElement(
            name: methodName,
            parent: mixinName,
            returnType: member.returnType?.toSource(),
            parameters: methodParams,
            isStatic: member.isStatic,
            isAbstract: member.isAbstract,
            isGetter: member.isGetter,
            isSetter: member.isSetter,
            isAsync: member.body.isAsynchronous,
            location: methodLoc,
            annotations: _extractAnnotations(member.metadata),
          ),
        );
      } else if (member is FieldDeclaration) {
        final fieldType = member.fields.type?.toSource();
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          final fieldLoc = _createLocation(variable.offset, variable.length);
          fields.add(
            FieldElement(
              name: fieldName,
              parent: mixinName,
              type: fieldType,
              isStatic: member.isStatic,
              isFinal: member.fields.isFinal,
              isConst: member.fields.isConst,
              isLate: member.fields.isLate,
              location: fieldLoc,
              annotations: _extractAnnotations(member.metadata),
            ),
          );
        }
      }
    }

    final mixinElement = MixinElement(
      name: mixinName,
      superclassConstraints: superclassConstraints,
      interfaces: interfaces,
      methods: methods,
      fields: fields,
      location: _createLocation(node.offset, node.length),
      annotations: _extractAnnotations(node.metadata),
    );

    elements.add(mixinElement);
    elements.addAll(methods);
    elements.addAll(fields);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final extName = node.name?.lexeme ?? '<unnamed>';
    final extendedType = node.extendedType.toSource();
    final methods = <MethodElement>[];
    final fields = <FieldElement>[];

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        final methodParams = _extractParameters(member.parameters);
        final methodLoc = _createLocation(member.offset, member.length);
        methods.add(
          MethodElement(
            name: methodName,
            parent: extName,
            returnType: member.returnType?.toSource(),
            parameters: methodParams,
            isStatic: member.isStatic,
            isAbstract: member.isAbstract,
            isGetter: member.isGetter,
            isSetter: member.isSetter,
            isAsync: member.body.isAsynchronous,
            location: methodLoc,
            annotations: _extractAnnotations(member.metadata),
          ),
        );
      } else if (member is FieldDeclaration) {
        final fieldType = member.fields.type?.toSource();
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          final fieldLoc = _createLocation(variable.offset, variable.length);
          fields.add(
            FieldElement(
              name: fieldName,
              parent: extName,
              type: fieldType,
              isStatic: member.isStatic,
              isFinal: member.fields.isFinal,
              isConst: member.fields.isConst,
              isLate: member.fields.isLate,
              location: fieldLoc,
              annotations: _extractAnnotations(member.metadata),
            ),
          );
        }
      }
    }

    final extElement = ExtensionElement(
      name: extName,
      extendedType: extendedType,
      methods: methods,
      fields: fields,
      location: _createLocation(node.offset, node.length),
      annotations: _extractAnnotations(node.metadata),
    );

    elements.add(extElement);
    elements.addAll(methods);
    elements.addAll(fields);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Only capture top-level functions here (node.parent is CompilationUnit)
    if (node.parent is CompilationUnit) {
      final funcName = node.name.lexeme;
      final params = _extractParameters(node.functionExpression.parameters);
      final isAsync = node.functionExpression.body.isAsynchronous;
      final returnType = node.returnType?.toSource();

      elements.add(
        FunctionElement(
          name: funcName,
          returnType: returnType,
          parameters: params,
          isAsync: isAsync,
          isGetter: node.isGetter,
          isSetter: node.isSetter,
          location: _createLocation(node.offset, node.length),
          annotations: _extractAnnotations(node.metadata),
        ),
      );
    }
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final fieldType = node.variables.type?.toSource();
    for (final variable in node.variables.variables) {
      final varName = variable.name.lexeme;
      final varLoc = _createLocation(variable.offset, variable.length);
      elements.add(
        FieldElement(
          name: varName,
          parent: null,
          type: fieldType,
          isStatic: false,
          isFinal: node.variables.isFinal,
          isConst: node.variables.isConst,
          isLate: node.variables.isLate,
          location: varLoc,
          annotations: _extractAnnotations(node.metadata),
        ),
      );
    }
  }
}
