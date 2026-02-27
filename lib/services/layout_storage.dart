import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/room_model.dart';

class LayoutStorage {
  static const String _fileName = 'floor_layout.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> save(List<RoomModel> rooms) async {
    final file = await _file();
    final jsonStr = jsonEncode(rooms.map((r) => r.toJson()).toList());
    await file.writeAsString(jsonStr);
  }

  static Future<List<RoomModel>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final jsonStr = await file.readAsString();
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => RoomModel.fromJson(e)).toList();
  }
}
