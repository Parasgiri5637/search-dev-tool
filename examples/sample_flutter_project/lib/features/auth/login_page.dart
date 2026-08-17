import 'package:flutter/material.dart';
import 'auth_bloc.dart';
import 'login_form.dart';

class LoginPage extends StatelessWidget {
  final AuthBloc authBloc;

  const LoginPage({super.key, required this.authBloc});

  void login() {
    authBloc.login('user@example.com', 'pass123');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: LoginForm(authBloc: authBloc),
    );
  }
}
