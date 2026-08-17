import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

import '../models/graph_edge.dart';
import '../models/source_location.dart';
import 'symbol_table.dart';

/// Discovered call or reference relationship from source code.
class DiscoveredCall {
  final String callerId;
  final String targetSymbolName;
  final String? targetReceiverType;
  final String? resolvedTargetId;
  final EdgeKind kind;
  final ConfidenceRating confidence;
  final SourceLocation location;

  DiscoveredCall({
    required this.callerId,
    required this.targetSymbolName,
    this.targetReceiverType,
    this.resolvedTargetId,
    this.kind = EdgeKind.calls,
    this.confidence = ConfidenceRating.confirmed,
    required this.location,
  });
}

/// Resolves method invocations, constructor calls, and references in Dart files.
class CallResolver {
  final SymbolTable symbolTable;

  CallResolver({required this.symbolTable});

  /// Analyzes a file's AST and extracts all resolved calls and references.
  List<DiscoveredCall> resolveCalls(String filePath, [String? fileContent]) {
    final normalizedPath = p.normalize(p.absolute(filePath));
    String content;
    if (fileContent != null) {
      content = fileContent;
    } else {
      final file = File(normalizedPath);
      if (file.existsSync()) {
        try {
          content = file.readAsStringSync();
        } catch (_) {
          return const [];
        }
      } else {
        return const [];
      }
    }

    try {
      final parseResult = parseString(
        content: content,
        path: normalizedPath,
        throwIfDiagnostics: false,
      );

      final visitor = _CallAstVisitor(
        filePath: normalizedPath,
        lineInfo: parseResult.lineInfo,
        symbolTable: symbolTable,
      );

      parseResult.unit.accept(visitor);
      return visitor.discoveredCalls;
    } catch (_) {
      return const [];
    }
  }
}

class _CallAstVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final LineInfo lineInfo;
  final SymbolTable symbolTable;

  final List<DiscoveredCall> discoveredCalls = [];

  String? _currentClass;
  String? _currentMethod;

  // Local variable and field type scopes
  final Map<String, String> _fieldTypes = {};
  final Map<String, String> _localTypes = {};

  _CallAstVisitor({
    required this.filePath,
    required this.lineInfo,
    required this.symbolTable,
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

  String get _currentCallerId {
    if (_currentClass != null) {
      if (_currentMethod != null && _currentMethod!.isNotEmpty) {
        return '$filePath#$_currentClass.$_currentMethod';
      }
      return '$filePath#$_currentClass';
    }
    if (_currentMethod != null && _currentMethod!.isNotEmpty) {
      return '$filePath#$_currentMethod';
    }
    return filePath;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _currentClass = node.name.lexeme;
    _fieldTypes.clear();

    // Register field types in the class
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        var typeName = member.fields.type?.toSource();
        for (final v in member.fields.variables) {
          if (typeName != null) {
            _fieldTypes[v.name.lexeme] = typeName;
          } else if (v.initializer != null) {
            final init = v.initializer;
            if (init is InstanceCreationExpression) {
              _fieldTypes[v.name.lexeme] = init.constructorName.type.toSource();
            } else if (init is MethodInvocation &&
                init.target == null &&
                init.methodName.name.isNotEmpty &&
                init.methodName.name[0].toUpperCase() == init.methodName.name[0]) {
              _fieldTypes[v.name.lexeme] = init.methodName.name;
            }
          }
        }
      }
    }

    super.visitClassDeclaration(node);
    _currentClass = null;
    _fieldTypes.clear();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _currentMethod = node.name.lexeme;
    _localTypes.clear();

    // Register method parameters
    if (node.parameters != null) {
      for (final param in node.parameters!.parameters) {
        final actualParam =
            param is DefaultFormalParameter ? param.parameter : param;
        if (actualParam is SimpleFormalParameter &&
            actualParam.name != null &&
            actualParam.type != null) {
          _localTypes[actualParam.name!.lexeme] = actualParam.type!.toSource();
        }
      }
    }

    super.visitMethodDeclaration(node);
    _currentMethod = null;
    _localTypes.clear();
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _currentMethod = node.name?.lexeme ?? '';
    _localTypes.clear();

    for (final param in node.parameters.parameters) {
      final actualParam =
          param is DefaultFormalParameter ? param.parameter : param;
      if (actualParam is SimpleFormalParameter &&
          actualParam.name != null &&
          actualParam.type != null) {
        _localTypes[actualParam.name!.lexeme] = actualParam.type!.toSource();
      }
    }

    super.visitConstructorDeclaration(node);
    _currentMethod = null;
    _localTypes.clear();
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) {
      _currentMethod = node.name.lexeme;
      _localTypes.clear();

      final params = node.functionExpression.parameters;
      if (params != null) {
        for (final param in params.parameters) {
          final actualParam =
              param is DefaultFormalParameter ? param.parameter : param;
          if (actualParam is SimpleFormalParameter &&
              actualParam.name != null &&
              actualParam.type != null) {
            _localTypes[actualParam.name!.lexeme] =
                actualParam.type!.toSource();
          }
        }
      }

      super.visitFunctionDeclaration(node);
      _currentMethod = null;
      _localTypes.clear();
    } else {
      super.visitFunctionDeclaration(node);
    }
  }

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    final typeName = node.variables.type?.toSource();
    for (final v in node.variables.variables) {
      if (typeName != null) {
        _localTypes[v.name.lexeme] = typeName;
      } else if (v.initializer != null) {
        final init = v.initializer;
        if (init is InstanceCreationExpression) {
          _localTypes[v.name.lexeme] = init.constructorName.type.toSource();
        } else if (init is MethodInvocation &&
            init.target == null &&
            init.methodName.name.isNotEmpty &&
            init.methodName.name[0].toUpperCase() == init.methodName.name[0]) {
          _localTypes[v.name.lexeme] = init.methodName.name;
        } else if (init is AwaitExpression &&
            init.expression is MethodInvocation) {
          final invocation = init.expression as MethodInvocation;
          final target = invocation.target;
          if (target is SimpleIdentifier) {
            final recType =
                _localTypes[target.name] ?? _fieldTypes[target.name];
            if (recType != null) {
              final qName = '$recType.${invocation.methodName.name}';
              final syms = symbolTable.findByQualifiedName(qName);
              if (syms.isNotEmpty && syms.first.returnType != null) {
                _localTypes[v.name.lexeme] = syms.first.returnType!;
              }
            }
          }
        }
      }
    }
    super.visitVariableDeclarationStatement(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toSource();
    final ctorName = node.constructorName.name?.name;
    final fullTargetName =
        ctorName != null && ctorName.isNotEmpty ? '$typeName.$ctorName' : typeName;

    String? targetId;
    var confidence = ConfidenceRating.confirmed;

    final symbols = symbolTable.findByQualifiedName(fullTargetName);
    if (symbols.isNotEmpty) {
      targetId = symbols.first.id;
    } else {
      final classSymbols = symbolTable.findByName(typeName);
      if (classSymbols.isNotEmpty) {
        targetId = classSymbols.first.id;
      } else {
        targetId = typeName;
        confidence = ConfidenceRating.inferred;
      }
    }

    discoveredCalls.add(
      DiscoveredCall(
        callerId: _currentCallerId,
        targetSymbolName: fullTargetName,
        targetReceiverType: typeName,
        resolvedTargetId: targetId,
        kind: EdgeKind.creates,
        confidence: confidence,
        location: _createLocation(node.offset, node.length),
      ),
    );

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    final target = node.target;

    String? receiverType;
    String? resolvedTargetId;
    var confidence = ConfidenceRating.unknown;
    var kind = EdgeKind.calls;

    if (target is SimpleIdentifier) {
      final targetVarName = target.name;
      receiverType = _localTypes[targetVarName] ?? _fieldTypes[targetVarName];

      if (receiverType == null) {
        // Target could be a Class name for static method (e.g. ApiService.post())
        final classSymbols = symbolTable.findByName(targetVarName);
        if (classSymbols.isNotEmpty) {
          receiverType = targetVarName;
        }
      }
    } else if (target is ThisExpression || target is SuperExpression) {
      receiverType = _currentClass;
    } else if (target == null &&
        methodName.isNotEmpty &&
        methodName[0].toUpperCase() == methodName[0]) {
      // Identifier(...) without target is a constructor call without `new` or `const`
      receiverType = methodName;
      kind = EdgeKind.creates;
      final classSymbols = symbolTable.findByName(methodName);
      if (classSymbols.isNotEmpty) {
        resolvedTargetId = classSymbols.first.id;
        confidence = ConfidenceRating.confirmed;
      } else {
        resolvedTargetId = methodName;
        confidence = ConfidenceRating.inferred;
      }
    }

    if (receiverType != null && resolvedTargetId == null) {
      final cleanType = receiverType.contains('<')
          ? receiverType.substring(0, receiverType.indexOf('<'))
          : receiverType;

      final qualifiedMethod = '$cleanType.$methodName';
      final exactMatches = symbolTable.findByQualifiedName(qualifiedMethod);
      if (exactMatches.isNotEmpty) {
        resolvedTargetId = exactMatches.first.id;
        confidence = ConfidenceRating.confirmed;
      } else {
        final classMatches = symbolTable.findByName(cleanType);
        if (classMatches.isNotEmpty) {
          resolvedTargetId = '${classMatches.first.id}#$methodName';
          confidence = ConfidenceRating.inferred;
        }
      }
    } else if (target == null && _currentClass != null && resolvedTargetId == null) {
      // Same-class invocation
      final localMatches =
          symbolTable.findByQualifiedName('$_currentClass.$methodName');
      if (localMatches.isNotEmpty) {
        resolvedTargetId = localMatches.first.id;
        confidence = ConfidenceRating.confirmed;
      }
    }

    if (resolvedTargetId == null) {
      final matches = symbolTable.findByName(methodName);
      if (matches.isNotEmpty) {
        resolvedTargetId = matches.first.id;
        confidence = ConfidenceRating.inferred;
      }
    }

    if (resolvedTargetId != null || receiverType != null) {
      discoveredCalls.add(
        DiscoveredCall(
          callerId: _currentCallerId,
          targetSymbolName: receiverType != null
              ? (kind == EdgeKind.creates ? receiverType : '$receiverType.$methodName')
              : methodName,
          targetReceiverType: receiverType,
          resolvedTargetId: resolvedTargetId ?? methodName,
          kind: kind,
          confidence: confidence,
          location: _createLocation(node.offset, node.length),
        ),
      );
    }

    super.visitMethodInvocation(node);
  }
}
