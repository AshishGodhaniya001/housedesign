class Scene3D {
  final List<Room3D> rooms;
  final List<Wall3D> walls;

  Scene3D({
    required this.rooms,
    required this.walls,
  });

  Map<String, dynamic> toJson() => {
        'rooms': rooms.map((r) => r.toJson()).toList(),
        'walls': walls.map((w) => w.toJson()).toList(),
      };
}

class Room3D {
  final String id;
  final String type;
  final double x;
  final double y;
  final double z;
  final double width;
  final double depth;
  final double height;

  Room3D({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.depth,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'position': {'x': x, 'y': y, 'z': z},
        'size': {'width': width, 'depth': depth, 'height': height},
      };
}

class Wall3D {
  final double x;
  final double y;
  final double z;
  final double width;
  final double height;
  final double thickness;

  Wall3D({
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.height,
    required this.thickness,
  });

  Map<String, dynamic> toJson() => {
        'position': {'x': x, 'y': y, 'z': z},
        'size': {
          'width': width,
          'height': height,
          'thickness': thickness
        },
      };
}