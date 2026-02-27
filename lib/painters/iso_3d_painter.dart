import 'package:flutter/material.dart';
import 'dart:math';
import '../models/room_model.dart';
import '../models/structure_model.dart';

class Iso3DPainter extends CustomPainter {
  final List<RoomModel> rooms;
  final List<StructureModel> structures;
  final double rotation;
  final double scale;
  final Offset pan;

  Iso3DPainter({
    required this.rooms,
    required this.structures,
    required this.rotation,
    required this.scale,
    required this.pan,
  });

  // -------- ISOMETRIC PROJECTION --------
  Offset iso(Offset p) {
    final x = p.dx * scale;
    final y = p.dy * scale;

    final rx = x * cos(rotation) - y * sin(rotation);
    final ry = x * sin(rotation) + y * cos(rotation);

    return Offset(rx - ry, (rx + ry) / 2);
  }

  Color roomColor(RoomType type) {
    switch (type) {
      case RoomType.bedroom:
        return Colors.brown.shade300;
      case RoomType.kitchen:
        return Colors.grey.shade300;
      case RoomType.bathroom:
        return Colors.blue.shade200;
      case RoomType.living:
        return Colors.green.shade300;
      default:
        return Colors.blueGrey.shade300;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2 + pan.dx, 80 + pan.dy);

    for (final r in rooms) {
      final base = iso(Offset(r.x, r.y));
      final w = r.width * scale;
      final d = r.height * scale;
      final h = r.height3D * 20 * scale;

      // SHADOW
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final shadow = Path()
        ..moveTo(base.dx + 6, base.dy + 6)
        ..lineTo(base.dx + w / 2 + 6, base.dy + d / 2 + 6)
        ..lineTo(base.dx + 6, base.dy + d + 6)
        ..lineTo(base.dx - w / 2 + 6, base.dy + d / 2 + 6)
        ..close();

      canvas.drawPath(shadow, shadowPaint);

      final baseColor = roomColor(r.type);
      final top = Paint()..color = baseColor;
      final left = Paint()..color = Color.lerp(baseColor, Colors.black, 0.2)!;
      final right = Paint()..color = Color.lerp(baseColor, Colors.black, 0.35)!;

      // TOP
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy - h)
          ..lineTo(base.dx + w / 2, base.dy - h + d / 2)
          ..lineTo(base.dx, base.dy - h + d)
          ..lineTo(base.dx - w / 2, base.dy - h + d / 2)
          ..close(),
        top,
      );

      // LEFT
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - w / 2, base.dy - h + d / 2)
          ..lineTo(base.dx, base.dy - h + d)
          ..lineTo(base.dx, base.dy + d)
          ..lineTo(base.dx - w / 2, base.dy + d / 2)
          ..close(),
        left,
      );

      // RIGHT
      canvas.drawPath(
        Path()
          ..moveTo(base.dx + w / 2, base.dy - h + d / 2)
          ..lineTo(base.dx, base.dy - h + d)
          ..lineTo(base.dx, base.dy + d)
          ..lineTo(base.dx + w / 2, base.dy + d / 2)
          ..close(),
        right,
      );

      // DOORS / WINDOWS (simple)
      for (final s in structures.where((e) => e.floor == r.floor)) {
        if (s.x < r.x ||
            s.x > r.x + r.width ||
            s.y < r.y ||
            s.y > r.y + r.height) {
          continue;
        }

        final paint = Paint()
          ..color = s.type == StructureType.door
              ? Colors.brown
              : Colors.lightBlueAccent.withValues(alpha: 0.6);

        canvas.drawRect(
          Rect.fromLTWH(base.dx + w / 2 - 12, base.dy + 10, 12, 30),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
