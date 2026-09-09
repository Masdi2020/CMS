import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  String? _token;

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  void setToken(String? token) => _token = token;
  void close() => _client.close();

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body);

  Future<dynamic> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(
      method,
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path'),
    );
    request.headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 20));
      if (response.statusCode == 204) return null;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          payload['message'] as String? ?? 'Permintaan gagal.',
          response.statusCode,
        );
      }
      return payload['data'];
    } on TimeoutException {
      throw const ApiException('Koneksi timeout. Silakan coba lagi.');
    } on http.ClientException {
      throw const ApiException('Tidak dapat terhubung ke server. Periksa koneksi dan alamat API.');
    } on FormatException {
      throw const ApiException('Respons server tidak valid.');
    }
  }
}
