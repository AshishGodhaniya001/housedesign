import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../models/structure_model.dart';
import '../painters/iso_3d_painter.dart';

class Preview3DScreen extends StatefulWidget {
  final List<RoomModel> rooms;
  final List<StructureModel> structures;
  final double wallThickness;

  const Preview3DScreen({
    super.key,
    required this.rooms,
    required this.structures,
    required this.wallThickness,
  });

  @override
  State<Preview3DScreen> createState() => _Preview3DScreenState();
}

class _Preview3DScreenState extends State<Preview3DScreen> {
  double rotation = 0;
  double scale = 1;
  Offset pan = Offset.zero;

  double _r = 0;
  double _s = 1;
  Offset _p = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("3D Preview")),
      body: GestureDetector(
        onScaleStart: (d) {
          _r = rotation;
          _s = scale;
          _p = pan;
        },
        onScaleUpdate: (d) {
          setState(() {
            if (d.pointerCount == 1) {
              rotation = _r + d.focalPointDelta.dx * 0.01;
            } else {
              scale = (_s * d.scale).clamp(0.4, 2.5);
              pan = _p + d.focalPointDelta;
            }
          });
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: Iso3DPainter(
            rooms: widget.rooms,
            structures: widget.structures,
            rotation: rotation,
            scale: scale,
            pan: pan,
          ),
        ),
      ),
    );
  }
}