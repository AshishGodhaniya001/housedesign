import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SessionStorage {
  static const String _fileName = 'session.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final file = await _file();
    await file.writeAsString(jsonEncode({'token': token, 'user': user}));
  }

  static Future<Map<String, dynamic>?> loadSession() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<String?> getToken() async {
    final session = await loadSession();
    final token = session?['token'];
    if (token is String && token.isNotEmpty) {
      return token;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final session = await loadSession();
    final user = session?['user'];
    if (user is Map) {
      return user.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static Future<void> clearSession() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
