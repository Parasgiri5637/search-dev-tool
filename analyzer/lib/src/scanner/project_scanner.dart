import 'dart:io';
import 'package:path/path.dart' as p;

/// Options configuring how [ProjectScanner] discovers Dart source files.
class ScannerOptions {
  /// Directory names that are ignored by default.
  static const Set<String> defaultIgnoredDirectories = {
    '.dart_tool',
    'build',
    '.git',
    '.fvm',
    '.idea',
    '.vscode',
    '.svn',
    '.hg',
    'Pods',
    '.symlinks',
    '.gradle',
    '.pub-cache',
    'node_modules',
  };

  /// File name patterns that are ignored by default.
  static const Set<String> defaultIgnoredFiles = {
    '.DS_Store',
  };

  /// Set of directory names to skip during traversal.
  final Set<String> ignoredDirectories;

  /// Custom path predicates or ignore filters.
  final List<bool Function(String path)> customFilters;

  const ScannerOptions({
    this.ignoredDirectories = defaultIgnoredDirectories,
    this.customFilters = const [],
  });
}

/// Recursively scans a Flutter or Dart project root for all Dart source files.
class ProjectScanner {
  final ScannerOptions options;

  const ProjectScanner({this.options = const ScannerOptions()});

  /// Scans the directory at [rootPath] and returns a sorted list of normalized Dart file paths.
  List<String> scan(String rootPath) {
    final rootDir = Directory(p.normalize(p.absolute(rootPath)));
    if (!rootDir.existsSync()) {
      return const [];
    }

    final dartFiles = <String>[];
    final visitedDirectories = <String>{};

    void scanDirectory(Directory dir) {
      final canonicalPath = dir.path;
      if (visitedDirectories.contains(canonicalPath)) {
        return;
      }
      visitedDirectories.add(canonicalPath);

      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } catch (_) {
        // Skip unreadable directories gracefully
        return;
      }

      for (final entry in entries) {
        final baseName = p.basename(entry.path);

        if (entry is Directory) {
          if (options.ignoredDirectories.contains(baseName)) {
            continue;
          }
          if (_isIgnoredByCustomFilter(entry.path)) {
            continue;
          }
          scanDirectory(entry);
        } else if (entry is File) {
          if (baseName.endsWith('.dart')) {
            if (!_isIgnoredByCustomFilter(entry.path)) {
              dartFiles.add(p.normalize(entry.path));
            }
          }
        }
      }
    }

    scanDirectory(rootDir);
    dartFiles.sort();
    return dartFiles;
  }

  bool _isIgnoredByCustomFilter(String path) {
    for (final filter in options.customFilters) {
      if (filter(path)) {
        return true;
      }
    }
    return false;
  }
}
