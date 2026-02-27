enum StructureType { door, window, pillar }

class StructureModel {
  final StructureType type;
  double x;
  double y;
  double width;
  double height;
  final int floor;
  double rotation;

  StructureModel({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.floor,
    this.rotation = 0,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'floor': floor,
    'rotation': rotation,
  };

  factory StructureModel.fromJson(Map<String, dynamic> json) {
    return StructureModel(
      type: StructureType.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (json['type'] ?? '').toString().toLowerCase(),
        orElse: () => StructureType.door,
      ),
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 40,
      height: (json['height'] as num?)?.toDouble() ?? 6,
      floor: (json['floor'] as num?)?.toInt() ?? 0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    );
  }
}
