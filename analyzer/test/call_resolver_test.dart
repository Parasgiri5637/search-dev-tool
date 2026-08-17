import 'package:flutter_code_map_analyzer/flutter_code_map.dart';
import 'package:test/test.dart';

void main() {
  group('CallResolver', () {
    late SymbolTable symbolTable;
    late CallResolver callResolver;

    setUp(() {
      symbolTable = SymbolTable();
      callResolver = CallResolver(symbolTable: symbolTable);
    });

    test('resolves typed method invocations with confirmed confidence', () {
      const authBlocLoc = SourceLocation(
        filePath: 'lib/auth_bloc.dart',
        line: 1,
        column: 1,
        offset: 0,
        length: 100,
        endLine: 10,
        endColumn: 1,
      );

      symbolTable.register(
        const CodeSymbol(
          id: 'lib/auth_bloc.dart#AuthBloc.login',
          name: 'login',
          qualifiedName: 'AuthBloc.login',
          kind: SymbolKind.methodSymbol,
          parentName: 'AuthBloc',
          location: authBlocLoc,
        ),
      );

      const callerCode = '''
class LoginPage {
  final AuthBloc authBloc;
  LoginPage(this.authBloc);

  void submit() {
    authBloc.login('user', 'pass');
  }
}
''';

      final calls = callResolver.resolveCalls('lib/login_page.dart', callerCode);

      expect(calls.isNotEmpty, isTrue);
      final loginCall = calls.firstWhere((c) => c.targetSymbolName == 'AuthBloc.login');
      expect(loginCall.resolvedTargetId, equals('lib/auth_bloc.dart#AuthBloc.login'));
      expect(loginCall.confidence, equals(ConfidenceRating.confirmed));
    });

    test('resolves constructor creation calls', () {
      const formLoc = SourceLocation(
        filePath: 'lib/login_form.dart',
        line: 1,
        column: 1,
        offset: 0,
        length: 50,
        endLine: 5,
        endColumn: 1,
      );

      symbolTable.register(
        const CodeSymbol(
          id: 'lib/login_form.dart#LoginForm',
          name: 'LoginForm',
          qualifiedName: 'LoginForm',
          kind: SymbolKind.classSymbol,
          location: formLoc,
        ),
      );

      const pageCode = '''
class LoginPage {
  Widget build() {
    return LoginForm();
  }
}
''';

      final calls = callResolver.resolveCalls('lib/login_page.dart', pageCode);

      final createCall = calls.firstWhere((c) => c.kind == EdgeKind.creates);
      expect(createCall.targetSymbolName, equals('LoginForm'));
      expect(createCall.resolvedTargetId, equals('lib/login_form.dart#LoginForm'));
    });
  });
}
