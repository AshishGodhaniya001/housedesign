import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../models/structure_model.dart';
import '../models/wall_model.dart';

class FloorPlanPainter extends CustomPainter {
  final List<RoomModel> rooms;
  final List<StructureModel> structures;
  final List<WallModel> walls;
  final List<SnapGuideLine> snapGuides;
  final RoomModel? selectedRoom;
  final StructureModel? selectedStructure;
  final bool useMeters;
  final double wallThickness;
  final bool darkMode;

  FloorPlanPainter(
    this.rooms,
    this.structures, {
    required this.walls,
    this.snapGuides = const [],
    this.selectedRoom,
    this.selectedStructure,
    required this.useMeters,
    required this.wallThickness,
    this.darkMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGrid(canvas, size);
    _drawRooms(canvas);
    _drawSnapGuides(canvas);
    if (selectedRoom != null) {
      _drawRoomHandles(canvas, selectedRoom!);
    }
    _drawWalls(canvas);
    _drawStructures(canvas);
    if (selectedStructure != null) {
      _drawStructureHandles(canvas, selectedStructure!);
    }
  }

  ({TextPainter painter, double scaleX}) _fitSingleLineText(
    String text,
    TextStyle style,
    double maxWidth, {
    double minFontSize = 7,
  }) {
    final safeWidth = maxWidth.clamp(6.0, double.infinity).toDouble();
    var fontSize = style.fontSize ?? 12;

    TextPainter build(double fs) => TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: fs)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    var tp = build(fontSize);
    while (tp.width > safeWidth && fontSize > minFontSize) {
      fontSize -= 0.5;
      tp = build(fontSize);
    }

    final scaleX = tp.width > safeWidth ? (safeWidth / tp.width) : 1.0;
    return (painter: tp, scaleX: scaleX);
  }

  void _paintFittedSingleLine(
    Canvas canvas,
    String text, {
    required TextStyle style,
    required Offset offset,
    required double maxWidth,
    double minFontSize = 7,
  }) {
    final fitted = _fitSingleLineText(
      text,
      style,
      maxWidth,
      minFontSize: minFontSize,
    );
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (fitted.scaleX < 1.0) {
      canvas.scale(fitted.scaleX, 1.0);
    }
    fitted.painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: darkMode
            ? const [Color(0xFF101821), Color(0xFF141E29)]
            : const [Color(0xFFF7F4ED), Color(0xFFEEE7D9)],
      ).createShader(rect);
    canvas.drawRect(rect, base);
  }

  void _drawGrid(Canvas canvas, Size size) {
    const grid = 20.0;
    final minor = Paint()
      ..color = darkMode
          ? const Color(0xFF90A2B8).withValues(alpha: 0.14)
          : const Color(0xFF8B8B8B).withValues(alpha: 0.14)
      ..strokeWidth = 0.7;
    final major = Paint()
      ..color = darkMode
          ? const Color(0xFFB3C1D2).withValues(alpha: 0.2)
          : const Color(0xFF6F6F6F).withValues(alpha: 0.18)
      ..strokeWidth = 1.1;

    for (double x = 0; x <= size.width; x += grid) {
      final paint = (x / grid) % 5 == 0 ? major : minor;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += grid) {
      final paint = (y / grid) % 5 == 0 ? major : minor;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawWalls(Canvas canvas) {
    final base = Paint()
      ..color = darkMode ? const Color(0xFFE4E6EA) : const Color(0xFF3D3D3D)
      ..strokeWidth = wallThickness
      ..strokeCap = StrokeCap.butt;
    final highlight = Paint()
      ..color = darkMode
          ? const Color(0xFF5B6A7D).withValues(alpha: 0.7)
          : const Color(0xFFF9F7F1).withValues(alpha: 0.7)
      ..strokeWidth = (wallThickness * 0.22).clamp(1.0, 2.4)
      ..strokeCap = StrokeCap.butt;

    for (final wall in walls) {
      final start = wall.start;
      final end = wall.end;

      if (start.dy == end.dy) {
        final y = start.dy;
        final x1 = math.min(start.dx, end.dx);
        final x2 = math.max(start.dx, end.dx);

        if (x2 > x1) {
          canvas.drawLine(Offset(x1, y), Offset(x2, y), base);
          canvas.drawLine(
            Offset(x1, y - wallThickness * 0.28),
            Offset(x2, y - wallThickness * 0.28),
            highlight,
          );
        }
      } else if (start.dx == end.dx) {
        final x = start.dx;
        final y1 = math.min(start.dy, end.dy);
        final y2 = math.max(start.dy, end.dy);

        if (y2 > y1) {
          canvas.drawLine(Offset(x, y1), Offset(x, y2), base);
          canvas.drawLine(
            Offset(x - wallThickness * 0.28, y1),
            Offset(x - wallThickness * 0.28, y2),
            highlight,
          );
        }
      }
    }
  }

  void _drawRooms(Canvas canvas) {
    for (final room in rooms) {
      final isSelected = room == selectedRoom;

      final rect = Rect.fromLTWH(room.x, room.y, room.width, room.height);
      final roomColor = _roomColor(room.type);

      final fill = Paint()..color = roomColor;
      canvas.drawRect(rect, fill);

      if (isSelected) {
        _drawSelectedRoomFrame(canvas, rect);
      }

      if (room.type == RoomType.stairs) {
        _drawStairHighlight(canvas, rect, room);
      }

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.4 : 1.3
        ..color = isSelected
            ? const Color(0xFF8EBBFF)
            : (darkMode ? const Color(0xFFBFC8D2) : const Color(0xFF4A4A4A));
      canvas.drawRect(rect, borderPaint);

      _drawRoomName(canvas, room);
      if (isSelected) {
        _drawRoomArea(canvas, room);
        _drawDimensions(canvas, room);
      }
    }
  }

  void _drawDimensions(Canvas canvas, RoomModel room) {
    const pxToFt = 1 / 20;
    const ftToM = 0.3048;

    double w = room.width * pxToFt;
    double h = room.height * pxToFt;

    String unit = 'ft';
    if (useMeters) {
      w *= ftToM;
      h *= ftToM;
      unit = 'm';
    }

    final text = '${w.toStringAsFixed(1)} $unit x ${h.toStringAsFixed(1)} $unit';
    final fitted = _fitSingleLineText(
      text,
      TextStyle(
        fontSize: 11,
        color: darkMode ? Color(0xFFD4DEE9) : Color(0xFF3C3C3C),
        fontWeight: FontWeight.w500,
      ),
      room.width - 8,
      minFontSize: 7,
    );
    final x = room.x + ((room.width - (fitted.painter.width * fitted.scaleX)) / 2);
    final y = math.max(2.0, room.y - fitted.painter.height - 2);
    _paintFittedSingleLine(
      canvas,
      text,
      style: TextStyle(
        fontSize: 11,
        color: darkMode ? Color(0xFFD4DEE9) : Color(0xFF3C3C3C),
        fontWeight: FontWeight.w500,
      ),
      offset: Offset(x, y),
      maxWidth: room.width - 8,
      minFontSize: 7,
    );
  }

  void _drawRoomName(Canvas canvas, RoomModel room) {
    final label = room.customName?.isNotEmpty == true
        ? room.customName!
        : room.type.label.toUpperCase();

    _paintFittedSingleLine(
      canvas,
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: darkMode ? Color(0xFFF2F4F8) : Color(0xFF212121),
      ),
      offset: Offset(room.x + 6, room.y + 6),
      maxWidth: room.width - 12,
      minFontSize: 7,
    );
  }

  void _drawStairHighlight(Canvas canvas, Rect rect, RoomModel room) {
    final inner = rect.deflate(3.0);
    final innerR = RRect.fromRectAndRadius(inner, const Radius.circular(6));

    final glow = Paint()
      ..color = darkMode
          ? const Color(0xFFE2BD74).withValues(alpha: 0.30)
          : const Color(0xFF8B6B2D).withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(innerR, glow);

    final panel = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: darkMode
            ? const [Color(0xFF2A2418), Color(0xFF3A2F1D)]
            : const [Color(0xFFF0E2BF), Color(0xFFE0CB98)],
      ).createShader(inner);
    canvas.drawRRect(innerR, panel);

    canvas.drawRRect(
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = darkMode ? const Color(0xFFF1D89F) : const Color(0xFF7A5B22),
    );

    final glyph = Paint()
      ..color = darkMode ? const Color(0xFFFFE7B8) : const Color(0xFF654A1A)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final treadPaint = Paint()
      ..color = glyph.color.withValues(alpha: 0.9)
      ..strokeWidth = 1.5;
    final treadLeft = inner.left + 6;
    final treadRight = inner.right - 16;
    final treadCount = 6;
    for (int i = 0; i < treadCount; i++) {
      final y = inner.top + 6 + (i * ((inner.height - 12) / (treadCount - 1)));
      canvas.drawLine(Offset(treadLeft, y), Offset(treadRight, y), treadPaint);
    }

    final text = room.customName?.isNotEmpty == true
        ? room.customName!.toUpperCase()
        : room.name.toUpperCase();
    final isDown = text.contains('DOWN');
    final isUp = text.contains('UP');

    final arrowX = inner.right - 8;
    if (!isDown) {
      final upY = inner.top + 9;
      canvas.drawLine(Offset(arrowX, upY + 8), Offset(arrowX, upY - 4), glyph);
      canvas.drawLine(
        Offset(arrowX, upY - 4),
        Offset(arrowX - 4, upY),
        glyph,
      );
      canvas.drawLine(
        Offset(arrowX, upY - 4),
        Offset(arrowX + 4, upY),
        glyph,
      );
    }

    if (!isUp) {
      final downY = inner.bottom - 9;
      canvas.drawLine(
        Offset(arrowX, downY - 8),
        Offset(arrowX, downY + 4),
        glyph,
      );
      canvas.drawLine(
        Offset(arrowX, downY + 4),
        Offset(arrowX - 4, downY),
        glyph,
      );
      canvas.drawLine(
        Offset(arrowX, downY + 4),
        Offset(arrowX + 4, downY),
        glyph,
      );
    }

  }

  void _drawRoomArea(Canvas canvas, RoomModel room) {
    final text = 'Area: ${room.area.toStringAsFixed(0)}';
    final fitted = _fitSingleLineText(
      text,
      TextStyle(
        fontSize: 11,
        color: darkMode ? Color(0xFFC4CDD8) : Color(0xFF4F4F4F),
        fontWeight: FontWeight.w500,
      ),
      room.width - 12,
      minFontSize: 7,
    );
    final y = room.y + room.height - fitted.painter.height - 6;
    _paintFittedSingleLine(
      canvas,
      text,
      style: TextStyle(
        fontSize: 11,
        color: darkMode ? Color(0xFFC4CDD8) : Color(0xFF4F4F4F),
        fontWeight: FontWeight.w500,
      ),
      offset: Offset(room.x + 6, y),
      maxWidth: room.width - 12,
      minFontSize: 7,
    );
  }

  void _drawRoomHandles(Canvas canvas, RoomModel room) {
    final handles = <({Offset point, bool isSideHandle})>[
      (point: Offset(room.x, room.y), isSideHandle: false),
      (point: Offset(room.x + room.width / 2, room.y), isSideHandle: true),
      (point: Offset(room.x + room.width, room.y), isSideHandle: false),
      (
        point: Offset(room.x + room.width, room.y + room.height / 2),
        isSideHandle: true,
      ),
      (
        point: Offset(room.x + room.width, room.y + room.height),
        isSideHandle: false,
      ),
      (
        point: Offset(room.x + room.width / 2, room.y + room.height),
        isSideHandle: true,
      ),
      (point: Offset(room.x, room.y + room.height), isSideHandle: false),
      (
        point: Offset(room.x, room.y + room.height / 2),
        isSideHandle: true,
      ),
    ];

    final glow = Paint()
      ..color = darkMode
          ? const Color(0xFFE2BF73).withValues(alpha: 0.18)
          : const Color(0xFF4C8DFF).withValues(alpha: 0.14);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = darkMode
          ? const Color(0xFFE2BF73)
          : const Color(0xFF2E63C7);
    final fill = Paint()
      ..color = darkMode ? const Color(0xFF132131) : const Color(0xFFFDFEFF);
    final core = Paint()
      ..color = darkMode ? const Color(0xFFE2BF73) : const Color(0xFF2E63C7);

    for (final handle in handles) {
      canvas.drawCircle(handle.point, handle.isSideHandle ? 10 : 12, glow);
      final rect = handle.isSideHandle
          ? Rect.fromCenter(center: handle.point, width: 18, height: 10)
          : Rect.fromCenter(center: handle.point, width: 14, height: 14);
      final innerRect = handle.isSideHandle
          ? Rect.fromCenter(center: handle.point, width: 8, height: 2.8)
          : Rect.fromCenter(center: handle.point, width: 6, height: 6);
      final radius = handle.isSideHandle ? 5.0 : 4.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        outer,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          innerRect,
          Radius.circular(handle.isSideHandle ? 2 : 3),
        ),
        core..color = core.color.withValues(alpha: 0.18),
      );
      core.color = darkMode ? const Color(0xFFE2BF73) : const Color(0xFF2E63C7);
      if (handle.isSideHandle) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(innerRect, const Radius.circular(2)),
          core,
        );
      } else {
        canvas.drawCircle(handle.point, 2.3, core);
      }
    }
  }

  void _drawSelectedRoomFrame(Canvas canvas, Rect rect) {
    final outerRect = rect.inflate(5);
    final glow = Paint()
      ..color = darkMode
          ? const Color(0xFFE1BE74).withValues(alpha: 0.16)
          : const Color(0xFF4C8DFF).withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(10)),
      glow,
    );

    final wash = Paint()
      ..color = darkMode
          ? const Color(0xFFE1BE74).withValues(alpha: 0.06)
          : const Color(0xFF4C8DFF).withValues(alpha: 0.05);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      wash,
    );

    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = darkMode
          ? const Color(0xFFF0D49A).withValues(alpha: 0.7)
          : const Color(0xFF4C8DFF).withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(10)),
      frame,
    );
  }

  void _drawSnapGuides(Canvas canvas) {
    if (snapGuides.isEmpty) return;

    final glow = Paint()
      ..color = darkMode
          ? const Color(0xFFE1BE74).withValues(alpha: 0.18)
          : const Color(0xFF4C8DFF).withValues(alpha: 0.14)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final line = Paint()
      ..color = darkMode ? const Color(0xFFF1D89F) : const Color(0xFF2E63C7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final point = Paint()
      ..color = darkMode ? const Color(0xFFF1D89F) : const Color(0xFF2E63C7);

    for (final guide in snapGuides) {
      canvas.drawLine(guide.start, guide.end, glow);
      canvas.drawLine(guide.start, guide.end, line);
      canvas.drawCircle(guide.start, 3.5, point);
      canvas.drawCircle(guide.end, 3.5, point);
    }
  }

  void _drawStructures(Canvas canvas) {
    for (final s in structures) {
      _drawStructure(canvas, s);
    }
  }

  void _drawStructure(Canvas canvas, StructureModel s) {
    final center = Offset(s.x + s.width / 2, s.y + s.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(s.rotation);

    switch (s.type) {
      case StructureType.door:
        _drawDoor(canvas, Size(s.width, s.height));
        break;
      case StructureType.window:
        _drawWindow(canvas, Size(s.width, s.height));
        break;
      case StructureType.pillar:
        _drawPillar(canvas, Size(s.width, s.height));
        break;
    }

    canvas.restore();
  }

  void _drawStructureHandles(Canvas canvas, StructureModel s) {
    final rect = Rect.fromLTWH(s.x, s.y, s.width, s.height);
    final center = rect.center;
    final moveHandle = _rotatePoint(
      Offset(center.dx, rect.top - 22),
      center,
      s.rotation,
    );
    final rotateHandle = _rotatePoint(
      Offset(rect.right + 22, center.dy),
      center,
      s.rotation,
    );
    final deleteHandle = _rotatePoint(
      Offset(rect.left - 22, center.dy),
      center,
      s.rotation,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(s.rotation);
    final localRect = Rect.fromCenter(
      center: Offset.zero,
      width: s.width,
      height: s.height,
    );
    canvas.drawRect(
      localRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF0052CC)
        ..strokeWidth = 1.6,
    );
    canvas.restore();

    canvas.drawLine(
      center,
      moveHandle,
      Paint()..color = const Color(0xFF0052CC),
    );
    canvas.drawLine(
      center,
      rotateHandle,
      Paint()..color = const Color(0xFF0A8754),
    );
    canvas.drawLine(
      center,
      deleteHandle,
      Paint()..color = const Color(0xFFD00000),
    );

    _drawHandle(canvas, moveHandle, const Color(0xFF0052CC), Icons.open_with);
    _drawHandle(
      canvas,
      rotateHandle,
      const Color(0xFF0A8754),
      Icons.rotate_right,
    );
    _drawHandle(canvas, deleteHandle, const Color(0xFFD00000), Icons.delete);
  }

  void _drawHandle(Canvas canvas, Offset c, Color color, IconData icon) {
    final glow = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final fill = Paint()..color = darkMode ? const Color(0xFF132131) : Colors.white;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;

    canvas.drawCircle(c, 11, glow);
    canvas.drawCircle(c, 8.5, fill);
    canvas.drawCircle(c, 8.5, stroke);

    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 10,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  Offset _rotatePoint(Offset point, Offset center, double angle) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final rx = dx * math.cos(angle) - dy * math.sin(angle);
    final ry = dx * math.sin(angle) + dy * math.cos(angle);
    return Offset(center.dx + rx, center.dy + ry);
  }

  void _drawDoor(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height <= 0 ? 6.0 : size.height;
    final doorLeaf = Paint()
      ..color = const Color(0xFF8B5E3C)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final sweep = Paint()
      ..color = const Color(0xFF8B5E3C).withValues(alpha: 0.35)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final hinge = Offset(-w / 2, 0);
    final radius = w.abs().clamp(16.0, 34.0);

    canvas.drawLine(hinge, Offset(hinge.dx + radius, hinge.dy), doorLeaf);
    canvas.drawArc(
      Rect.fromCircle(center: hinge, radius: radius),
      -1.57,
      1.57,
      false,
      sweep,
    );

    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF74492E),
    );
  }

  void _drawWindow(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );

    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF2E5B74);
    final glass = Paint()
      ..color = const Color(0xFF9FD8F2).withValues(alpha: 0.55);

    canvas.drawRect(rect, glass);
    canvas.drawRect(rect, frame);
    canvas.drawLine(rect.topCenter, rect.bottomCenter, frame);
    canvas.drawLine(rect.centerLeft, rect.centerRight, frame);
  }

  void _drawPillar(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) / 2).clamp(5.0, 14.0);

    final fill = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFE7E7E7), Color(0xFF9E9E9E)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF5F5F5F);

    canvas.drawCircle(Offset.zero, radius, fill);
    canvas.drawCircle(Offset.zero, radius, stroke);
  }

  Color _roomColor(RoomType type) {
    if (darkMode) {
      switch (type) {
        case RoomType.bedroom:
          return const Color(0xFF4D596B);
        case RoomType.kitchen:
          return const Color(0xFF405A5A);
        case RoomType.bathroom:
          return const Color(0xFF3E566D);
        case RoomType.living:
          return const Color(0xFF5B5163);
        case RoomType.dining:
          return const Color(0xFF5A5648);
        case RoomType.guestRoom:
          return const Color(0xFF5C5050);
        case RoomType.studyRoom:
          return const Color(0xFF4A5A50);
        case RoomType.poojaRoom:
          return const Color(0xFF63583D);
        case RoomType.balcony:
          return const Color(0xFF4C5E5B);
        case RoomType.utility:
          return const Color(0xFF4E5660);
        case RoomType.storeRoom:
          return const Color(0xFF5A5550);
        case RoomType.garage:
          return const Color(0xFF4D5159);
        case RoomType.office:
          return const Color(0xFF495A52);
        case RoomType.kidsRoom:
          return const Color(0xFF5C4F5D);
      case RoomType.stairs:
        return const Color(0xFF6B5A3A);
        case RoomType.other:
          return const Color(0xFF525964);
      }
    }

    switch (type) {
      case RoomType.bedroom:
        return const Color(0xFFD8C5AD);
      case RoomType.kitchen:
        return const Color(0xFFC8D4D0);
      case RoomType.bathroom:
        return const Color(0xFFBDD4E7);
      case RoomType.living:
        return const Color(0xFFDCCFA7);
      case RoomType.dining:
        return const Color(0xFFE0CFAE);
      case RoomType.guestRoom:
        return const Color(0xFFDABFA8);
      case RoomType.studyRoom:
        return const Color(0xFFC8D0B2);
      case RoomType.poojaRoom:
        return const Color(0xFFF0D7A6);
      case RoomType.balcony:
        return const Color(0xFFC9DDD4);
      case RoomType.utility:
        return const Color(0xFFCBD0D6);
      case RoomType.storeRoom:
        return const Color(0xFFD2C7BC);
      case RoomType.garage:
        return const Color(0xFFBDC0C6);
      case RoomType.office:
        return const Color(0xFFC6D1B4);
      case RoomType.kidsRoom:
        return const Color(0xFFE6C2C2);
      case RoomType.stairs:
        return const Color(0xFFE3D3AF);
      case RoomType.other:
        return const Color(0xFFD3D0C6);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SnapGuideLine {
  const SnapGuideLine({required this.start, required this.end});

  final Offset start;
  final Offset end;
}
