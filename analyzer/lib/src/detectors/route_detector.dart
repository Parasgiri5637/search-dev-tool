import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../graph/knowledge_graph.dart';
import '../models/file_analysis_result.dart';
import '../models/graph_edge.dart';
import '../models/graph_node.dart';
import '../models/source_location.dart';
import '../resolver/symbol_table.dart';
import 'flutter_detector.dart';

/// Detects Route configurations and navigations (GoRouter, Navigator.push, named routes).
class RouteDetector implements FlutterDetector {
  @override
  String get name => 'RouteDetector';

  @override
  DetectorResult detect({
    required List<FileAnalysisResult> fileResults,
    required SymbolTable symbolTable,
    required KnowledgeGraph graph,
  }) {
    final routesFound = <String>[];

    for (final fileResult in fileResults) {
      final routesInFile = _extractRoutesFromFile(fileResult.filePath);
      for (final r in routesInFile) {
        final routeNodeId = 'route:${r.path}';
        routesFound.add(r.path);

        final routeNode = GraphNode(
          id: routeNodeId,
          label: 'Route: ${r.path}',
          kind: NodeKind.routeNode,
          location: r.location,
          metadata: {
            'path': r.path,
            'targetPage': r.targetPage,
            'routeType': r.routeType,
            'filePath': fileResult.filePath,
          },
        );
        graph.addNode(routeNode);

        if (r.targetPage != null) {
          final targetSymbols = symbolTable.findByName(r.targetPage!);
          if (targetSymbols.isNotEmpty) {
            graph.addEdge(
              GraphEdge(
                sourceId: routeNodeId,
                targetId: targetSymbols.first.id,
                kind: EdgeKind.routeTo,
                confidence: ConfidenceRating.confirmed,
                location: r.location,
              ),
            );
          }
        }
      }
    }

    return DetectorResult(
      detectorName: name,
      detectedFeatures: routesFound,
      metadata: {'totalRoutes': routesFound.length},
    );
  }

  List<_DiscoveredRoute> _extractRoutesFromFile(String filePath) {
    final file = File(p.normalize(filePath));
    if (!file.existsSync()) return const [];

    try {
      final content = file.readAsStringSync();
      final parseResult = parseString(
        content: content,
        path: file.path,
        throwIfDiagnostics: false,
      );

      final visitor = _RouteAstVisitor(filePath);
      parseResult.unit.accept(visitor);
      return visitor.discoveredRoutes;
    } catch (_) {
      return const [];
    }
  }
}

class _DiscoveredRoute {
  final String path;
  final String? targetPage;
  final String routeType;
  final SourceLocation location;

  _DiscoveredRoute({
    required this.path,
    this.targetPage,
    required this.routeType,
    required this.location,
  });
}

class _RouteAstVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<_DiscoveredRoute> discoveredRoutes = [];

  _RouteAstVisitor(this.filePath);

  void _checkGoRoute(List<Expression> arguments, int offset, int length) {
    String? routePath;
    String? targetPage;

    for (final arg in arguments) {
      if (arg is NamedExpression) {
        final paramName = arg.name.label.name;
        if (paramName == 'path') {
          final expr = arg.expression;
          if (expr is SimpleStringLiteral) {
            routePath = expr.value;
          }
        } else if (paramName == 'builder') {
          final expr = arg.expression;
          if (expr is FunctionExpression) {
            final body = expr.body;
            if (body is ExpressionFunctionBody) {
              final bodyExpr = body.expression;
              if (bodyExpr is InstanceCreationExpression) {
                targetPage = bodyExpr.constructorName.type.toSource();
              } else if (bodyExpr is MethodInvocation &&
                  bodyExpr.target == null) {
                targetPage = bodyExpr.methodName.name;
              }
            }
          }
        }
      }
    }

    if (routePath != null) {
      discoveredRoutes.add(
        _DiscoveredRoute(
          path: routePath,
          targetPage: targetPage,
          routeType: 'GoRoute',
          location: SourceLocation(
            filePath: p.normalize(filePath),
            line: 1,
            column: 1,
            offset: offset,
            length: length,
            endLine: 1,
            endColumn: 1,
          ),
        ),
      );
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toSource();
    if (typeName == 'GoRoute') {
      _checkGoRoute(node.argumentList.arguments, node.offset, node.length);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    if (methodName == 'GoRoute') {
      _checkGoRoute(node.argumentList.arguments, node.offset, node.length);
    } else if (methodName == 'pushNamed' || methodName == 'pushReplacementNamed') {
      final args = node.argumentList.arguments;
      if (args.length >= 2) {
        final routeNameArg = args[1];
        if (routeNameArg is SimpleStringLiteral) {
          discoveredRoutes.add(
            _DiscoveredRoute(
              path: routeNameArg.value,
              routeType: 'Navigator.pushNamed',
              location: SourceLocation(
                filePath: p.normalize(filePath),
                line: 1,
                column: 1,
                offset: node.offset,
                length: node.length,
                endLine: 1,
                endColumn: 1,
              ),
            ),
          );
        }
      }
    }

    super.visitMethodInvocation(node);
  }
}
