import 'package:go_router/go_router.dart';
import 'features/auth/api_service.dart';
import 'features/auth/auth_bloc.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_page.dart';

class AppRouter {
  static final authService = ApiService();
  static final authRepository = AuthRepository(apiService: authService);
  static final authBloc = AuthBloc(authRepository: authRepository);

  static final router = GoRouter(
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(authBloc: authBloc),
      ),
    ],
  );
}
