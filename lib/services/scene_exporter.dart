import '../models/scene_3d.dart';
import '../models/room_model.dart';
import '../models/wall_model.dart';
import 'dart:math';

class SceneExporter {
  static Scene3D buildScene({
    required List<RoomModel> rooms,
    required List<WallModel> walls,
    required double wallThickness,
  }) {
    // ---------- ROOMS (2D → 3D) ----------
    final room3D = rooms.map((r) {
      return Room3D(
        id: r.customName ?? r.type.name,
        type: r.type.name,
        x: r.x,
        y: 0,
        z: r.y,
        width: r.width,
        depth: r.height,
        height: r.height3D,
      );
    }).toList();

    // ---------- WALLS (2D → 3D) ----------
    final wall3D = walls.map((w) {
      final dx = w.end.dx - w.start.dx;
      final dz = w.end.dy - w.start.dy;

      final length = sqrt(dx * dx + dz * dz);

      return Wall3D(
        x: min(w.start.dx, w.end.dx),
        y: 0,
        z: min(w.start.dy, w.end.dy),
        width: length,
        height: rooms.isNotEmpty ? rooms.first.height3D : 3.0,
        thickness: w.thickness,
      );
    }).toList();

    return Scene3D(
      rooms: room3D,
      walls: wall3D,
    );
  }
}