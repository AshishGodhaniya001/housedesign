import 'dart:ui';

enum WallOrientation { horizontal, vertical }

class WallModel {
  final Offset start;
  final Offset end;
  final double thickness;
  final int floor;

  WallModel({
    required this.start,
    required this.end,
    required this.thickness,
    required this.floor,
  });
}