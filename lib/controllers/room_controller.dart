import 'dart:ui';
import 'dart:math';

import '../models/room_model.dart';
import '../models/structure_model.dart';

enum RoomResizeCorner {
  topLeft,
  topCenter,
  topRight,
  rightCenter,
  bottomRight,
  bottomCenter,
  bottomLeft,
  leftCenter,
}

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
  bool _hitsStructure(
    Rect roomRect, {
    Iterable<StructureModel> ignoredStructures = const [],
  }) {
    final ignored = ignoredStructures.toSet();
    for (final s in structures) {
      if (ignored.contains(s)) {
        continue;
      }
      if (s.type != StructureType.pillar) {
        continue;
      }
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
  void moveRoomSafe(
    RoomModel room,
    double dx,
    double dy,
    Size canvas, {
    Iterable<StructureModel> ignoredStructures = const [],
  }) {
    final nx = _snap(room.x + dx);
    final ny = _snap(room.y + dy);

    final next = Rect.fromLTWH(nx, ny, room.width, room.height);
    if (!_withinCanvas(next, canvas)) return;
    if (_hitsStructure(next, ignoredStructures: ignoredStructures)) return;

    room.x = nx;
    room.y = ny;
  }

  // ---------- RESIZE (SAFE + SNAP) ----------
  void resizeRoomSafe(
    RoomModel room,
    double dw,
    double dh,
    Size canvas, {
    Iterable<StructureModel> ignoredStructures = const [],
  }) {
    final double newW = max(60.0, room.width + dw);
    final double newH = max(60.0, room.height + dh);

    final next = Rect.fromLTWH(room.x, room.y, newW, newH);
    if (!_withinCanvas(next, canvas)) return;
    if (_hitsStructure(next, ignoredStructures: ignoredStructures)) return;

    room.width = newW;
    room.height = newH;
  }

  void resizeRoomFromCornerSafe(
    RoomModel room,
    RoomResizeCorner corner,
    Offset delta,
    Size canvas, {
    Iterable<StructureModel> ignoredStructures = const [],
  }
  ) {
    const minSize = 60.0;

    final left = room.x;
    final top = room.y;
    final right = room.x + room.width;
    final bottom = room.y + room.height;

    double newLeft = left;
    double newTop = top;
    double newRight = right;
    double newBottom = bottom;

    switch (corner) {
      case RoomResizeCorner.topLeft:
        newLeft = left + delta.dx;
        newTop = top + delta.dy;
        newLeft = min(newLeft, right - minSize);
        newTop = min(newTop, bottom - minSize);
        break;
      case RoomResizeCorner.topCenter:
        newTop = top + delta.dy;
        newTop = min(newTop, bottom - minSize);
        break;
      case RoomResizeCorner.topRight:
        newRight = right + delta.dx;
        newTop = top + delta.dy;
        newRight = max(newRight, left + minSize);
        newTop = min(newTop, bottom - minSize);
        break;
      case RoomResizeCorner.rightCenter:
        newRight = right + delta.dx;
        newRight = max(newRight, left + minSize);
        break;
      case RoomResizeCorner.bottomRight:
        newRight = right + delta.dx;
        newBottom = bottom + delta.dy;
        newRight = max(newRight, left + minSize);
        newBottom = max(newBottom, top + minSize);
        break;
      case RoomResizeCorner.bottomCenter:
        newBottom = bottom + delta.dy;
        newBottom = max(newBottom, top + minSize);
        break;
      case RoomResizeCorner.bottomLeft:
        newLeft = left + delta.dx;
        newBottom = bottom + delta.dy;
        newLeft = min(newLeft, right - minSize);
        newBottom = max(newBottom, top + minSize);
        break;
      case RoomResizeCorner.leftCenter:
        newLeft = left + delta.dx;
        newLeft = min(newLeft, right - minSize);
        break;
    }

    final next = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
    if (!_withinCanvas(next, canvas)) return;
    if (_hitsStructure(next, ignoredStructures: ignoredStructures)) return;

    room
      ..x = next.left
      ..y = next.top
      ..width = next.width
      ..height = next.height;
  }

  void snapRoomGeometry(
    RoomModel room,
    Size canvas, {
    Iterable<StructureModel> ignoredStructures = const [],
  }) {
    const minSize = 60.0;

    double left = _snap(room.x);
    double top = _snap(room.y);
    double right = _snap(room.x + room.width);
    double bottom = _snap(room.y + room.height);

    if (right - left < minSize) {
      right = left + minSize;
    }
    if (bottom - top < minSize) {
      bottom = top + minSize;
    }

    if (right > canvas.width) {
      final overflow = right - canvas.width;
      right -= overflow;
      left -= overflow;
    }
    if (bottom > canvas.height) {
      final overflow = bottom - canvas.height;
      bottom -= overflow;
      top -= overflow;
    }

    left = left.clamp(0.0, canvas.width - minSize);
    top = top.clamp(0.0, canvas.height - minSize);
    right = right.clamp(left + minSize, canvas.width);
    bottom = bottom.clamp(top + minSize, canvas.height);

    final next = Rect.fromLTRB(left, top, right, bottom);
    if (!_withinCanvas(next, canvas)) return;
    if (_hitsStructure(next, ignoredStructures: ignoredStructures)) return;

    room
      ..x = next.left
      ..y = next.top
      ..width = next.width
      ..height = next.height;
  }

  void snapRoomPosition(
    RoomModel room,
    Size canvas, {
    Iterable<StructureModel> ignoredStructures = const [],
  }) {
    final snappedX = _snap(room.x).clamp(0.0, canvas.width - room.width);
    final snappedY = _snap(room.y).clamp(0.0, canvas.height - room.height);

    final next = Rect.fromLTWH(snappedX, snappedY, room.width, room.height);
    if (!_withinCanvas(next, canvas)) return;
    if (_hitsStructure(next, ignoredStructures: ignoredStructures)) return;

    room
      ..x = next.left
      ..y = next.top;
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
