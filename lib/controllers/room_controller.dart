import 'dart:ui';
import 'dart:math';

import '../models/room_model.dart';
import '../models/structure_model.dart';

class RoomController {
  static Offset findAutoPosition({
    required List<RoomModel> rooms,
    required double width,
    required double height,
    required int floor,
    required Size canvas,
  }) {
    const grid = 20.0;

    for (double y = grid; y < canvas.height - height; y += grid) {
      for (double x = grid; x < canvas.width - width; x += grid) {
        final testRect = Rect.fromLTWH(x, y, width, height);

        bool clash = false;

        for (final r in rooms) {
          if (r.floor != floor) continue;

          final rRect = Rect.fromLTWH(r.x, r.y, r.width, r.height);

          if (testRect.overlaps(rRect.inflate(0))) {
            clash = true;
            break;
          }
        }

        if (!clash) {
          return Offset(x, y);
        }
      }
    }

    // fallback
    return const Offset(20, 20);
  }

  final List<RoomModel> rooms;
  final List<StructureModel> structures;

  // Undo/Redo stacks
  final List<List<RoomModel>> _undo = [];
  final List<List<RoomModel>> _redo = [];

  static const double grid = 20.0;

  RoomController(this.rooms, this.structures);

  // ---------- HELPERS ----------
  bool _rectsOverlap(Rect a, Rect b) => a.overlaps(b);
  bool _hitsStructure(Rect roomRect) {
    for (final s in structures) {
      final sRect = Rect.fromLTWH(s.x, s.y, s.width, s.height);
      if (_rectsOverlap(roomRect, sRect)) return true;
    }
    return false;
  }

  bool _withinCanvas(Rect r, Size canvas) =>
      r.left >= 0 &&
      r.top >= 0 &&
      r.right <= canvas.width &&
      r.bottom <= canvas.height;

  double _snap(double v) => (v / grid).round() * grid;

  // ---------- MOVE (SAFE + SNAP) ----------
  void moveRoomSafe(RoomModel room, double dx, double dy, Size canvas) {
    final nx = _snap(room.x + dx);
    final ny = _snap(room.y + dy);

    final next = Rect.fromLTWH(nx, ny, room.width, room.height);
    if (!_withinCanvas(next, canvas)) return;
    if (_hitsStructure(next)) return;

    room.x = nx;
    room.y = ny;
  }

  // ---------- RESIZE (SAFE + SNAP) ----------
  void resizeRoomSafe(RoomModel room, double dw, double dh, Size canvas) {
    final double newW = _snap(max(60.0, room.width + dw));
    final double newH = _snap(max(60.0, room.height + dh));

    final next = Rect.fromLTWH(room.x, room.y, newW, newH);
    if (!_withinCanvas(next, canvas)) return;
    if (_hitsStructure(next)) return;

    room.width = newW;
    room.height = newH;
  }

  // ---------- DELETE ----------
  void deleteRoom(RoomModel room) {
    rooms.remove(room);
  }

  // ---------- UNDO / REDO ----------
  void pushUndo() {
    _undo.add(rooms.map((r) => r.copy()).toList());
    _redo.clear();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(rooms.map((r) => r.copy()).toList());
    rooms
      ..clear()
      ..addAll(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(rooms.map((r) => r.copy()).toList());
    rooms
      ..clear()
      ..addAll(_redo.removeLast());
  }

  // =========================================================
  // ================= ALIGN LOGIC (NEW) =====================
  // =========================================================

  Rect _bounds(Iterable<RoomModel> rs) {
    final left = rs.map((r) => r.x).reduce(min);
    final top = rs.map((r) => r.y).reduce(min);
    final right = rs.map((r) => r.x + r.width).reduce(max);
    final bottom = rs.map((r) => r.y + r.height).reduce(max);

    return Rect.fromLTRB(left, top, right, bottom);
  }

  void alignLeft(Iterable<RoomModel> rs) {
    final b = _bounds(rs);
    for (final r in rs) {
      r.x = b.left;
    }
  }

  void alignRight(Iterable<RoomModel> rs) {
    final b = _bounds(rs);
    for (final r in rs) {
      r.x = b.right - r.width;
    }
  }

  void alignCenterX(Iterable<RoomModel> rs) {
    final b = _bounds(rs);
    final cx = (b.left + b.right) / 2;
    for (final r in rs) {
      r.x = cx - r.width / 2;
    }
  }

  void alignTop(Iterable<RoomModel> rs) {
    final b = _bounds(rs);
    for (final r in rs) {
      r.y = b.top;
    }
  }

  void alignBottom(Iterable<RoomModel> rs) {
    final b = _bounds(rs);
    for (final r in rs) {
      r.y = b.bottom - r.height;
    }
  }

  void alignCenterY(Iterable<RoomModel> rs) {
    final b = _bounds(rs);
    final cy = (b.top + b.bottom) / 2;
    for (final r in rs) {
      r.y = cy - r.height / 2;
    }
  }

  // ---------- ROOM TO ROOM SNAP ----------
  void snapToNearby(RoomModel room, {double threshold = 12}) {
    for (final other in rooms) {
      if (other == room) continue;

      // SNAP LEFT
      if ((room.x - (other.x + other.width)).abs() < threshold) {
        room.x = other.x + other.width;
      }

      // SNAP RIGHT
      if (((room.x + room.width) - other.x).abs() < threshold) {
        room.x = other.x - room.width;
      }

      // SNAP TOP
      if ((room.y - (other.y + other.height)).abs() < threshold) {
        room.y = other.y + other.height;
      }

      // SNAP BOTTOM
      if (((room.y + room.height) - other.y).abs() < threshold) {
        room.y = other.y - room.height;
      }
    }
    room.x = _snap(room.x);
    room.y = _snap(room.y);
  }

  // ---------- AUTO PLACEMENT SUGGESTION ----------
  RoomModel? suggestBestNeighbor(RoomModel room) {
    for (final other in rooms) {
      if (other == room || other.floor != room.floor) continue;

      // Bedroom → Bathroom
      if (room.type == RoomType.bedroom && other.type == RoomType.bathroom) {
        return other;
      }

      // Kitchen → Living / Dining
      if (room.type == RoomType.kitchen &&
          (other.type == RoomType.living || other.type == RoomType.other)) {
        return other;
      }

      // Living → Balcony / Entrance (future)
    }
    return null;
  }
}
