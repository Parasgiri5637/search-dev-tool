class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'https://api.example.com'});

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    // Perform HTTP POST request
    return {'status': 'success', 'token': 'mock_token_12345'};
  }
}
