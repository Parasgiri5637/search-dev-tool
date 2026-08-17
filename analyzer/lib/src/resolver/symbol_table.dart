import '../models/ast_element.dart';
import '../models/symbol.dart';

/// Central registry indexing all declared symbols across the project.
class SymbolTable {
  final Map<String, CodeSymbol> _symbolsById = {};
  final Map<String, List<CodeSymbol>> _symbolsByName = {};
  final Map<String, List<CodeSymbol>> _symbolsByQualifiedName = {};
  final Map<String, List<CodeSymbol>> _symbolsByFile = {};

  SymbolTable();

  /// All registered symbols.
  List<CodeSymbol> get allSymbols => _symbolsById.values.toList();

  /// Registers a symbol in the table (replacing previous symbol with the same ID).
  void register(CodeSymbol symbol) {
    if (_symbolsById.containsKey(symbol.id)) {
      // Replace existing
      final old = _symbolsById[symbol.id]!;
      _symbolsByName[old.name]?.removeWhere((s) => s.id == old.id);
      _symbolsByQualifiedName[old.qualifiedName]
          ?.removeWhere((s) => s.id == old.id);
      _symbolsByFile[old.filePath]?.removeWhere((s) => s.id == old.id);
    }

    _symbolsById[symbol.id] = symbol;

    _symbolsByName.putIfAbsent(symbol.name, () => []).add(symbol);
    _symbolsByQualifiedName
        .putIfAbsent(symbol.qualifiedName, () => [])
        .add(symbol);
    _symbolsByFile.putIfAbsent(symbol.filePath, () => []).add(symbol);
  }

  /// Registers multiple symbols.
  void registerAll(Iterable<CodeSymbol> symbols) {
    for (final s in symbols) {
      register(s);
    }
  }

  /// Registers all elements extracted from an AST result.
  void registerFromAstElements(List<AstElement> elements) {
    for (final element in elements) {
      final symbol = _createSymbolFromAstElement(element);
      if (symbol != null) {
        register(symbol);
      }
    }
  }

  CodeSymbol? _createSymbolFromAstElement(AstElement el) {
    if (el is ClassElement) {
      return CodeSymbol(
        id: '${el.file}#${el.name}',
        name: el.name,
        qualifiedName: el.name,
        kind: SymbolKind.classSymbol,
        location: el.location,
        metadata: {
          'isAbstract': el.isAbstract,
          'superclass': el.superclass,
          'mixins': el.mixins,
          'interfaces': el.interfaces,
        },
      );
    } else if (el is EnumElement) {
      return CodeSymbol(
        id: '${el.file}#${el.name}',
        name: el.name,
        qualifiedName: el.name,
        kind: SymbolKind.enumSymbol,
        location: el.location,
        metadata: {'constants': el.constants},
      );
    } else if (el is MixinElement) {
      return CodeSymbol(
        id: '${el.file}#${el.name}',
        name: el.name,
        qualifiedName: el.name,
        kind: SymbolKind.mixinSymbol,
        location: el.location,
      );
    } else if (el is ExtensionElement) {
      return CodeSymbol(
        id: '${el.file}#${el.name}',
        name: el.name,
        qualifiedName: el.name,
        kind: SymbolKind.extensionSymbol,
        location: el.location,
        metadata: {'extendedType': el.extendedType},
      );
    } else if (el is FunctionElement) {
      return CodeSymbol(
        id: '${el.file}#${el.name}',
        name: el.name,
        qualifiedName: el.name,
        kind: SymbolKind.functionSymbol,
        returnType: el.returnType,
        location: el.location,
        metadata: {'isAsync': el.isAsync},
      );
    } else if (el is MethodElement) {
      final qName = '${el.parent}.${el.name}';
      return CodeSymbol(
        id: '${el.file}#$qName',
        name: el.name,
        qualifiedName: qName,
        kind: SymbolKind.methodSymbol,
        parentName: el.parent,
        returnType: el.returnType,
        location: el.location,
        metadata: {
          'isStatic': el.isStatic,
          'isGetter': el.isGetter,
          'isSetter': el.isSetter,
          'isAsync': el.isAsync,
        },
      );
    } else if (el is ConstructorElement) {
      final qName = el.displayName;
      return CodeSymbol(
        id: '${el.file}#$qName',
        name: el.name.isEmpty ? el.parent : el.name,
        qualifiedName: qName,
        kind: SymbolKind.constructorSymbol,
        parentName: el.parent,
        location: el.location,
        metadata: {
          'isFactory': el.isFactory,
          'isConst': el.isConst,
        },
      );
    } else if (el is FieldElement) {
      final qName = el.parent != null ? '${el.parent}.${el.name}' : el.name;
      return CodeSymbol(
        id: '${el.file}#$qName',
        name: el.name,
        qualifiedName: qName,
        kind: el.parent != null
            ? SymbolKind.fieldSymbol
            : SymbolKind.topLevelVariableSymbol,
        parentName: el.parent,
        returnType: el.type,
        location: el.location,
        metadata: {
          'isStatic': el.isStatic,
          'isFinal': el.isFinal,
          'isConst': el.isConst,
        },
      );
    }
    return null;
  }

  /// Finds a symbol by its exact ID.
  CodeSymbol? findById(String id) => _symbolsById[id];

  /// Finds all symbols matching the exact name (e.g., `login`).
  List<CodeSymbol> findByName(String name) => _symbolsByName[name] ?? const [];

  /// Finds all symbols matching the exact qualified name (e.g., `AuthBloc.login`).
  List<CodeSymbol> findByQualifiedName(String qName) =>
      _symbolsByQualifiedName[qName] ?? const [];

  /// Finds all symbols in a specific file.
  List<CodeSymbol> findByFile(String filePath) =>
      _symbolsByFile[filePath] ?? const [];

  /// Finds all symbols of a particular kind.
  List<CodeSymbol> findByKind(SymbolKind kind) {
    return _symbolsById.values.where((s) => s.kind == kind).toList();
  }

  /// Case-insensitive search across symbol names and qualified names.
  List<CodeSymbol> search(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return const [];

    return _symbolsById.values.where((s) {
      return s.name.toLowerCase().contains(lower) ||
          s.qualifiedName.toLowerCase().contains(lower);
    }).toList();
  }

  /// Removes all symbols belonging to a specific file (for incremental cache updates).
  void removeFile(String filePath) {
    final symbols = _symbolsByFile.remove(filePath);
    if (symbols == null) return;

    for (final s in symbols) {
      _symbolsById.remove(s.id);

      final byName = _symbolsByName[s.name];
      if (byName != null) {
        byName.removeWhere((item) => item.id == s.id);
        if (byName.isEmpty) _symbolsByName.remove(s.name);
      }

      final byQName = _symbolsByQualifiedName[s.qualifiedName];
      if (byQName != null) {
        byQName.removeWhere((item) => item.id == s.id);
        if (byQName.isEmpty) _symbolsByQualifiedName.remove(s.qualifiedName);
      }
    }
  }

  /// Clears the symbol table.
  void clear() {
    _symbolsById.clear();
    _symbolsByName.clear();
    _symbolsByQualifiedName.clear();
    _symbolsByFile.clear();
  }
}
