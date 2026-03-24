import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    final res = await http.post(
      _u('/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _decodeAuth(res);
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await http.post(
      _u('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _decodeAuth(res);
  }

  Future<List<PeerProfile>> fetchPeers(String token) async {
    final res = await http.get(
      _u('/api/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw ApiException('Failed to load users', res.statusCode);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['users'] as List<dynamic>? ?? [];
    return list
        .map((e) => PeerProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _decodeAuth(http.Response res) {
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw ApiException('Bad response');
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        body['error']?.toString() ?? 'Request failed',
        res.statusCode,
      );
    }
    return body;
  }
}
