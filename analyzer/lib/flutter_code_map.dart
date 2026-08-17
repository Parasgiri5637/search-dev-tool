/// Flutter Code Map analyzer library.
///
/// Provides AST scanning, parsing, symbol models, knowledge graphs,
/// call resolution, Flutter detectors, and deterministic query tools.
library flutter_code_map;

export 'src/ai/ai_interface.dart';
export 'src/analyzer_engine.dart';
export 'src/cache/project_cache.dart';
export 'src/detectors/flutter_detector.dart';
export 'src/detectors/route_detector.dart';
export 'src/detectors/state_management_detector.dart';
export 'src/detectors/widget_detector.dart';
export 'src/graph/graph_builder.dart';
export 'src/graph/knowledge_graph.dart';
export 'src/models/ast_element.dart';
export 'src/models/file_analysis_result.dart';
export 'src/models/graph_edge.dart';
export 'src/models/graph_node.dart';
export 'src/models/source_location.dart';
export 'src/models/symbol.dart';
export 'src/parser/ast_parser.dart';
export 'src/parser/ast_visitor.dart';
export 'src/query/query_engine.dart';
export 'src/query/query_intent.dart';
export 'src/query/query_result.dart';
export 'src/resolver/call_resolver.dart';
export 'src/resolver/symbol_table.dart';
export 'src/scanner/project_scanner.dart';
