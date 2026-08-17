// Sample Dart file for AST extraction testing
import 'dart:async' as async_lib;
import 'package:meta/meta.dart' show immutable, visibleForTesting;
import 'package:flutter/widgets.dart' hide Container;

export 'dart:math' show Random;

@immutable
abstract class BaseService {
  final String serviceUrl;

  const BaseService(this.serviceUrl);

  Future<void> connect();
}

class AuthService extends BaseService with LogMixin implements Disposable {
  static const String version = '1.0.0';
  late final String _token;

  AuthService(super.serviceUrl);

  AuthService.custom({required String url, String? token})
      : _token = token ?? '',
        super(url);

  factory AuthService.create() {
    return AuthService('https://api.example.com');
  }

  bool get isAuthenticated => _token.isNotEmpty;

  set token(String value) {
    _token = value;
  }

  @override
  Future<void> connect() async {
    // connect logic
  }

  @override
  void dispose() {}
}

enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated;

  bool get isDone => this == AuthStatus.authenticated;
}

mixin LogMixin on Object {
  void log(String message) {
    // log message
  }
}

abstract class Disposable {
  void dispose();
}

extension StringValidation on String {
  bool get isValidEmail => contains('@');
}

Future<int> calculateTotal(int a, [int b = 0]) async {
  return a + b;
}

const int defaultTimeout = 30;
