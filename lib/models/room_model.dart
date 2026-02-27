enum RoomType {
  bedroom,
  kitchen,
  bathroom,
  living,
  dining,
  guestRoom,
  studyRoom,
  poojaRoom,
  balcony,
  utility,
  storeRoom,
  garage,
  office,
  kidsRoom,
  stairs,
  other,
}

extension RoomTypeMeta on RoomType {
  String get label {
    switch (this) {
      case RoomType.bedroom:
        return 'Bedroom';
      case RoomType.kitchen:
        return 'Kitchen';
      case RoomType.bathroom:
        return 'Bathroom';
      case RoomType.living:
        return 'Living Room';
      case RoomType.dining:
        return 'Dining Room';
      case RoomType.guestRoom:
        return 'Guest Room';
      case RoomType.studyRoom:
        return 'Study Room';
      case RoomType.poojaRoom:
        return 'Pooja Room';
      case RoomType.balcony:
        return 'Balcony';
      case RoomType.utility:
        return 'Utility';
      case RoomType.storeRoom:
        return 'Store Room';
      case RoomType.garage:
        return 'Garage';
      case RoomType.office:
        return 'Office';
      case RoomType.kidsRoom:
        return 'Kids Room';
      case RoomType.stairs:
        return 'Stairs';
      case RoomType.other:
        return 'Other';
    }
  }
}

class RoomModel {
  String name;
  RoomType type;
  double x;
  double y;
  double width;
  double height;
  int floor;
  String? customName;
  double height3D; // meters

  RoomModel({
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.floor,
    this.customName,
    this.height3D = 3.0,
  });

  /// Area in **canvas units** (pixels)
  double get area => width * height;

  // ---------- JSON ----------
  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'customName': customName,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'floor': floor,
    'height3D': height3D,
  };

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      name: json['name'],
      type: RoomType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RoomType.other,
      ),
      customName: json['customName'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      floor: (json['floor'] as num?)?.toInt() ?? 0,
      height3D: (json['height3D'] as num?)?.toDouble() ?? 3.0,
    );
  }

  /// Used for undo/redo cloning
  RoomModel copy() => RoomModel(
    name: name,
    type: type,
    x: x,
    y: y,
    width: width,
    height: height,
    floor: floor,
    customName: customName,
    height3D: height3D,
  );
}
