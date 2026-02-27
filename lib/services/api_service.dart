import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static Map<String, String> _headers({bool jsonBody = false, String? token}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> _decodeJson(
    http.Response response,
  ) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Server error (${response.statusCode}): ${response.body}',
      );
    }

    final contentType = response.headers['content-type'];
    if (contentType == null || !contentType.contains('application/json')) {
      throw Exception('Invalid response from server');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Unexpected JSON format');
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({'email': email, 'password': password}),
    );

    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> me({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers(token: token),
    );

    return _decodeJson(response);
  }

  static Future<void> logout({required String token}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: _headers(token: token),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to logout: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchLayouts({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/layouts'),
      headers: _headers(token: token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Server error (${response.statusCode}): ${response.body}',
      );
    }

    final contentType = response.headers['content-type'];
    if (contentType == null || !contentType.contains('application/json')) {
      throw Exception('Invalid response from server');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected JSON format');
    }

    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchLayoutById(
    int id, {
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/layouts/$id'),
      headers: _headers(token: token),
    );
    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> saveLayout({
    required String token,
    required String name,
    required int floors,
    required List<Map<String, dynamic>> rooms,
    required List<Map<String, dynamic>> structures,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/layouts'),
      headers: _headers(jsonBody: true, token: token),
      body: jsonEncode({
        'name': name,
        'floors': floors,
        'rooms': rooms,
        'structures': structures,
      }),
    );

    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> updateLayout({
    required String token,
    required int id,
    required String name,
    required int floors,
    required List<Map<String, dynamic>> rooms,
    required List<Map<String, dynamic>> structures,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/layouts/$id'),
      headers: _headers(jsonBody: true, token: token),
      body: jsonEncode({
        'name': name,
        'floors': floors,
        'rooms': rooms,
        'structures': structures,
      }),
    );

    return _decodeJson(response);
  }

  static Future<void> deleteLayout(int id, {required String token}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/layouts/$id'),
      headers: _headers(token: token),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete layout: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> generateHouse(Map data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/generate'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(data),
    );

    return _decodeJson(response);
  }
}
