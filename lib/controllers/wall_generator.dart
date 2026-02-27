import '../models/room_model.dart';
import '../models/wall_model.dart';
import 'dart:ui';

class WallGenerator {
  static List<WallModel> fromRooms(
    List<RoomModel> rooms,
    double thickness,
    int floor,
  ) {
    final walls = <WallModel>[];
    final seen = <String>{};

    void addWall(Offset a, Offset b) {
      final key = '${a.dx},${a.dy}-${b.dx},${b.dy}';
      final rev = '${b.dx},${b.dy}-${a.dx},${a.dy}';
      if (seen.contains(key) || seen.contains(rev)) return;
      seen.add(key);

      walls.add(
        WallModel(
          start: a,
          end: b,
          thickness: thickness,
          floor: floor,
        ),
      );
    }

    for (final r in rooms.where((e) => e.floor == floor)) {
      addWall(
        Offset(r.x, r.y),
        Offset(r.x + r.width, r.y),
      ); // top

      addWall(
        Offset(r.x, r.y + r.height),
        Offset(r.x + r.width, r.y + r.height),
      ); // bottom

      addWall(
        Offset(r.x, r.y),
        Offset(r.x, r.y + r.height),
      ); // left

      addWall(
        Offset(r.x + r.width, r.y),
        Offset(r.x + r.width, r.y + r.height),
      ); // right
    }

    return walls;
  }
}