import 'dart:io';
import 'package:flutter_code_map_analyzer/flutter_code_map.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ProjectScanner', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('code_map_scanner_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    void createFakeFile(String relativePath, [String content = '']) {
      final file = File(p.join(tempDir.path, relativePath));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    test('finds Dart files in arbitrary nested directories', () {
      createFakeFile('lib/main.dart');
      createFakeFile('lib/src/core/utils.dart');
      createFakeFile('lib/features/auth/login_page.dart');
      createFakeFile('custom_module/sub/helper.dart');
      createFakeFile('README.md');
      createFakeFile('pubspec.yaml');

      final scanner = const ProjectScanner();
      final files = scanner.scan(tempDir.path);

      expect(files.length, equals(4));
      expect(
        files.any((f) => f.endsWith(p.join('lib', 'main.dart'))),
        isTrue,
      );
      expect(
        files.any((f) => f.endsWith(p.join('lib', 'src', 'core', 'utils.dart'))),
        isTrue,
      );
      expect(
        files.any((f) =>
            f.endsWith(p.join('lib', 'features', 'auth', 'login_page.dart'))),
        isTrue,
      );
      expect(
        files.any(
            (f) => f.endsWith(p.join('custom_module', 'sub', 'helper.dart'))),
        isTrue,
      );
    });

    test('ignores standard build, cache, and VCS directories', () {
      createFakeFile('lib/app.dart');
      createFakeFile('.dart_tool/package_config.json');
      createFakeFile('.dart_tool/some_generated.dart');
      createFakeFile('build/app/outputs/main.dart');
      createFakeFile('.git/hooks/pre-commit.dart');
      createFakeFile('.fvm/flutter_sdk/bin/cache/dart.dart');
      createFakeFile('.idea/workspace.xml');
      createFakeFile('.vscode/settings.json');
      createFakeFile('ios/Pods/Pods.xcodeproj/dummy.dart');
      createFakeFile('android/.gradle/caches/dummy.dart');

      final scanner = const ProjectScanner();
      final files = scanner.scan(tempDir.path);

      expect(files.length, equals(1));
      expect(files.first.endsWith(p.join('lib', 'app.dart')), isTrue);
    });

    test('respects custom filters in ScannerOptions', () {
      createFakeFile('lib/user.dart');
      createFakeFile('lib/user.g.dart');
      createFakeFile('lib/user.freezed.dart');

      final scanner = ProjectScanner(
        options: ScannerOptions(
          customFilters: [
            (path) => path.endsWith('.g.dart') || path.endsWith('.freezed.dart'),
          ],
        ),
      );

      final files = scanner.scan(tempDir.path);
      expect(files.length, equals(1));
      expect(files.first.endsWith('user.dart'), isTrue);
    });

    test('returns empty list for non-existent directory', () {
      final scanner = const ProjectScanner();
      final files =
          scanner.scan(p.join(tempDir.path, 'does_not_exist_xyz_12345'));
      expect(files, isEmpty);
    });
  });
}
