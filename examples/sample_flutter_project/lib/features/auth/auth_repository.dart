import 'api_service.dart';

class AuthRepository {
  final ApiService apiService;

  AuthRepository({required this.apiService});

  Future<bool> login(String username, String password) async {
    final response = await apiService.post('/auth/login', {
      'username': username,
      'password': password,
    });
    return response['status'] == 'success';
  }
}
