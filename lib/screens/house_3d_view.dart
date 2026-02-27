import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';

class House3DView extends StatefulWidget {
  final List rooms;
  final int floors;

  const House3DView({
    super.key,
    required this.rooms,
    required this.floors,
  });

  @override
  State<House3DView> createState() => _House3DViewState();
}

class _House3DViewState extends State<House3DView> {
  late Scene _scene;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("3D House View")),
      body: Cube(
        onSceneCreated: (Scene scene) {
          _scene = scene;
          scene.camera.zoom = 10;
          scene.camera.position.setValues(0, 20, 40);

          _buildHouse();
        },
      ),
    );
  }

  void _buildHouse() {
    double yOffset = 0;
    const floorHeight = 6.0;

    for (int f = 0; f < widget.floors; f++) {
      double xOffset = 0;

      for (var room in widget.rooms) {
        final area = (room["area"] as num).toDouble();
        final size = sqrt(area) / 3;

        final cube = Object(
          scale: Vector3(size, floorHeight, size),
          position: Vector3(xOffset, yOffset, 0),
        );

        _scene.world.add(cube);
        xOffset += size * 1.5;
      }

      yOffset += floorHeight;
    }
  }
}
