import 'package:flutter/material.dart';
import 'auth_bloc.dart';

class LoginForm extends StatelessWidget {
  final AuthBloc authBloc;

  const LoginForm({super.key, required this.authBloc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              authBloc.login('user@example.com', 'secret');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
