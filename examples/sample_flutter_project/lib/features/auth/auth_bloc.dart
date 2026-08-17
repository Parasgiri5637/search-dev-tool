import 'auth_repository.dart';

abstract class AuthEvent {}

class LoginSubmitted extends AuthEvent {
  final String username;
  final String password;
  LoginSubmitted(this.username, this.password);
}

abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSuccess extends AuthState {}
class AuthFailure extends AuthState {}

class AuthBloc {
  final AuthRepository authRepository;
  AuthState state = AuthInitial();

  AuthBloc({required this.authRepository});

  Future<void> login(String username, String password) async {
    state = AuthLoading();
    try {
      final success = await authRepository.login(username, password);
      if (success) {
        state = AuthSuccess();
      } else {
        state = AuthFailure();
      }
    } catch (_) {
      state = AuthFailure();
    }
  }
}
