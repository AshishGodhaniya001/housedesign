import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static final String baseUrl = _resolveBaseUrl();
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const String _lanBaseUrl = String.fromEnvironment(
    'API_LAN_BASE_URL',
    defaultValue: '',
  );
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String _resolveBaseUrl() {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _configuredBaseUrl.trim();
    }

    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8000/api';
    }
  }

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

  static Future<http.Response> _send(
    String path,
    Future<http.Response> Function(Uri uri) request,
  ) async {
    Object? lastError;
    for (final base in _candidateBaseUrls()) {
      final uri = Uri.parse('$base$path');
      try {
        return await request(uri).timeout(_requestTimeout);
      } on TimeoutException {
        lastError = Exception('Request timed out at $base');
      } on http.ClientException catch (error) {
        lastError = Exception(
          'Cannot connect to server at $base. ${error.message}',
        );
      }
    }

    if (lastError != null) {
      throw Exception('$lastError. Tried: ${_candidateBaseUrls().join(', ')}');
    }

    throw Exception('Request failed for $path');
  }

  static List<String> _candidateBaseUrls() {
    final values = <String>[];

    if (_configuredBaseUrl.trim().isNotEmpty) {
      values.add(_configuredBaseUrl.trim());
    }

    if (kIsWeb) {
      values.addAll(['http://localhost:8000/api', 'http://127.0.0.1:8000/api']);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      if (_lanBaseUrl.trim().isNotEmpty) {
        values.add(_lanBaseUrl.trim());
      }
      values.add('http://10.0.2.2:8000/api');
    } else {
      values.addAll([
        'http://localhost:8000/api',
        'http://127.0.0.1:8000/api',
        _lanBaseUrl,
      ]);
    }

    if (values.isEmpty) {
      values.add(baseUrl);
    }

    final seen = <String>{};
    final deduped = <String>[];
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      deduped.add(normalized);
    }
    return deduped;
  }

  static Map<String, dynamic> _decodeJson(http.Response response) {
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
    final response = await _send(
      '/auth/register',
      (uri) => http.post(
        uri,
        headers: _headers(jsonBody: true),
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ),
    );

    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      '/auth/login',
      (uri) => http.post(
        uri,
        headers: _headers(jsonBody: true),
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );

    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> sendForgotPasswordOtp({
    required String email,
  }) async {
    final response = await _send(
      '/auth/forgot-password/send-otp',
      (uri) => http.post(
        uri,
        headers: _headers(jsonBody: true),
        body: jsonEncode({'email': email}),
      ),
    );

    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> verifyForgotPasswordOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _send(
      '/auth/forgot-password/verify-otp',
      (uri) => http.post(
        uri,
        headers: _headers(jsonBody: true),
        body: jsonEncode({'email': email, 'otp': otp}),
      ),
    );

    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> resetForgotPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await _send(
      '/auth/forgot-password/reset',
      (uri) => http.post(
        uri,
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          'email': email,
          'resetToken': resetToken,
          'newPassword': newPassword,
        }),
      ),
    );

    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> me({required String token}) async {
    final response = await _send(
      '/auth/me',
      (uri) => http.get(uri, headers: _headers(token: token)),
    );

    return _decodeJson(response);
  }

  static Future<void> logout({required String token}) async {
    final response = await _send(
      '/auth/logout',
      (uri) => http.post(uri, headers: _headers(token: token)),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to logout: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchLayouts({
    required String token,
  }) async {
    final response = await _send(
      '/layouts',
      (uri) => http.get(uri, headers: _headers(token: token)),
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
    final response = await _send(
      '/layouts/$id',
      (uri) => http.get(uri, headers: _headers(token: token)),
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
    final response = await _send(
      '/layouts',
      (uri) => http.post(
        uri,
        headers: _headers(jsonBody: true, token: token),
        body: jsonEncode({
          'name': name,
          'floors': floors,
          'rooms': rooms,
          'structures': structures,
        }),
      ),
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
    final response = await _send(
      '/layouts/$id',
      (uri) => http.put(
        uri,
        headers: _headers(jsonBody: true, token: token),
        body: jsonEncode({
          'name': name,
          'floors': floors,
          'rooms': rooms,
          'structures': structures,
        }),
      ),
    );

    return _decodeJson(response);
  }

  static Future<void> deleteLayout(int id, {required String token}) async {
    final response = await _send(
      '/layouts/$id',
      (uri) => http.delete(uri, headers: _headers(token: token)),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete layout: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> generateHouse(Map data) async {
    final response = await _send(
      '/generate',
      (uri) => http.post(
        uri,
        headers: _headers(jsonBody: true),
        body: jsonEncode(data),
      ),
    );

    return _decodeJson(response);
  }
}
