import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../models/structure_model.dart';
import '../models/wall_model.dart';
import '../controllers/room_controller.dart';
import '../painters/floor_plan_painter.dart';

enum EditMode { move, resize, structureMove, structureRotate }

class EditableFloorView extends StatefulWidget {
  const EditableFloorView({
    super.key,
    required this.rooms,
    required this.structures,
    required this.walls,
    required this.onLayoutChanged,
    required this.onDeleteRoom,
    required this.onDeleteStructure,
    required this.useMeters,
    required this.wallThickness,
    required this.darkMode,
    this.canvasSize = const Size(360, 360),
  });

  final List<RoomModel> rooms;
  final List<StructureModel> structures;
  final List<WallModel> walls;
  final bool useMeters;
  final VoidCallback onLayoutChanged;
  final ValueChanged<RoomModel> onDeleteRoom;
  final ValueChanged<StructureModel> onDeleteStructure;
  final double wallThickness;
  final bool darkMode;
  final Size canvasSize;

  @override
  State<EditableFloorView> createState() => EditableFloorViewState();
}

class EditableFloorViewState extends State<EditableFloorView> {
  late RoomController controller;

  final Set<RoomModel> selectedRooms = {};
  RoomModel? activeRoom;
  StructureModel? selectedStructure;
  EditMode? editMode;

  double _startPointerAngle = 0;
  double _startStructureRotation = 0;

  @override
  void initState() {
    super.initState();
    controller = RoomController(widget.rooms, widget.structures);
  }

  @override
  void didUpdateWidget(covariant EditableFloorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller = RoomController(widget.rooms, widget.structures);
    if (selectedStructure != null &&
        !widget.structures.contains(selectedStructure)) {
      selectedStructure = null;
    }
  }

  RoomModel? _hitTestRoom(Offset pos) {
    for (final r in widget.rooms) {
      if (pos.dx >= r.x &&
          pos.dx <= r.x + r.width &&
          pos.dy >= r.y &&
          pos.dy <= r.y + r.height) {
        return r;
      }
    }
    return null;
  }

  StructureModel? _hitTestStructure(Offset pos) {
    for (final s in widget.structures.reversed) {
      if (_isPointInsideRotatedStructure(pos, s, inflate: 12)) {
        return s;
      }
    }
    return null;
  }

  bool _isPointInsideRotatedStructure(
    Offset point,
    StructureModel s, {
    double inflate = 0,
  }) {
    final center = Offset(s.x + s.width / 2, s.y + s.height / 2);
    final local = _rotatePoint(point, center, -s.rotation);
    final rect = Rect.fromLTWH(s.x, s.y, s.width, s.height).inflate(inflate);
    return rect.contains(local);
  }

  Offset _rotatePoint(Offset point, Offset center, double angle) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final rx = dx * math.cos(angle) - dy * math.sin(angle);
    final ry = dx * math.sin(angle) + dy * math.cos(angle);
    return Offset(center.dx + rx, center.dy + ry);
  }

  ({Offset move, Offset rotate, Offset delete}) _structureHandles(
    StructureModel s,
  ) {
    final rect = Rect.fromLTWH(s.x, s.y, s.width, s.height);
    final center = rect.center;

    final move = _rotatePoint(
      Offset(center.dx, rect.top - 22),
      center,
      s.rotation,
    );
    final rotate = _rotatePoint(
      Offset(rect.right + 22, center.dy),
      center,
      s.rotation,
    );
    final delete = _rotatePoint(
      Offset(rect.left - 22, center.dy),
      center,
      s.rotation,
    );

    return (move: move, rotate: rotate, delete: delete);
  }

  bool _isNearHandle(Offset point, Offset handleCenter, {double radius = 16}) {
    return (point - handleCenter).distance <= radius;
  }

  EditMode _detectRoomMode(RoomModel r, Offset pos) {
    const handle = 20.0;
    final resizeRect = Rect.fromLTWH(
      r.x + r.width - handle,
      r.y + r.height - handle,
      handle,
      handle,
    );
    return resizeRect.contains(pos) ? EditMode.resize : EditMode.move;
  }

  void _moveStructureSafe(StructureModel s, Offset delta) {
    s.x = (s.x + delta.dx).clamp(0.0, widget.canvasSize.width - s.width);
    s.y = (s.y + delta.dy).clamp(0.0, widget.canvasSize.height - s.height);
  }

  RoomModel? _nearestRoomForStructure(StructureModel s) {
    if (widget.rooms.isEmpty) return null;

    final center = Offset(s.x + s.width / 2, s.y + s.height / 2);
    RoomModel? bestRoom;
    double bestDistance = double.infinity;

    for (final room in widget.rooms) {
      final rect = Rect.fromLTWH(room.x, room.y, room.width, room.height);
      final expanded = rect.inflate(28);
      if (expanded.contains(center)) {
        return room;
      }

      final nearestX = center.dx.clamp(rect.left, rect.right).toDouble();
      final nearestY = center.dy.clamp(rect.top, rect.bottom).toDouble();
      final distance = (center - Offset(nearestX, nearestY)).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestRoom = room;
      }
    }

    return bestRoom;
  }

  void _snapStructureToNearestRoomWall(StructureModel s) {
    final room = _nearestRoomForStructure(s);
    if (room == null) return;

    final center = Offset(s.x + s.width / 2, s.y + s.height / 2);
    final leftDist = (center.dx - room.x).abs();
    final rightDist = (center.dx - (room.x + room.width)).abs();
    final topDist = (center.dy - room.y).abs();
    final bottomDist = (center.dy - (room.y + room.height)).abs();

    final minDist = [leftDist, rightDist, topDist, bottomDist].reduce(math.min);
    final pad = 8.0;

    if (s.type == StructureType.pillar) {
      s.rotation = 0;
      s.x = (s.x).clamp(room.x + pad, room.x + room.width - s.width - pad);
      s.y = (s.y).clamp(room.y + pad, room.y + room.height - s.height - pad);
      return;
    }

    if (minDist == leftDist || minDist == rightDist) {
      final wallX = minDist == leftDist ? room.x : room.x + room.width;
      s.rotation = math.pi / 2;
      s.x = wallX - s.width / 2;
      s.y = (center.dy - s.height / 2).clamp(
        room.y + pad,
        room.y + room.height - s.height - pad,
      );
    } else {
      final wallY = minDist == topDist ? room.y : room.y + room.height;
      s.rotation = 0;
      s.y = wallY - s.height / 2;
      s.x = (center.dx - s.width / 2).clamp(
        room.x + pad,
        room.x + room.width - s.width - pad,
      );
    }

    s.x = s.x.clamp(0.0, widget.canvasSize.width - s.width);
    s.y = s.y.clamp(0.0, widget.canvasSize.height - s.height);
  }

  Offset _roomDeleteButtonPosition(RoomModel room) {
    final x = (room.x + room.width + 6)
        .clamp(4.0, widget.canvasSize.width - 36.0)
        .toDouble();
    final y = (room.y - 6)
        .clamp(4.0, widget.canvasSize.height - 36.0)
        .toDouble();
    return Offset(x, y);
  }

  Offset _structureDeleteButtonPosition(StructureModel s) {
    final center = Offset(s.x + s.width / 2, s.y + s.height / 2);
    final anchor = _rotatePoint(
      Offset(s.x + s.width + 12, s.y - 8),
      center,
      s.rotation,
    );
    final x = anchor.dx.clamp(4.0, widget.canvasSize.width - 36.0).toDouble();
    final y = anchor.dy.clamp(4.0, widget.canvasSize.height - 36.0).toDouble();
    return Offset(x, y);
  }

  void _deleteSelectedRoom() {
    final target = selectedRooms.isNotEmpty ? selectedRooms.first : null;
    if (target == null) return;
    widget.onDeleteRoom(target);
    setState(() {
      selectedRooms.clear();
      activeRoom = null;
    });
  }

  void _deleteSelectedStructure() {
    final target = selectedStructure;
    if (target == null) return;
    widget.onDeleteStructure(target);
    setState(() {
      selectedStructure = null;
      editMode = null;
    });
  }

  bool get hasMultiSelection => selectedRooms.length >= 2;

  void alignLeft() => setState(() => controller.alignLeft(selectedRooms));
  void alignCenterX() => setState(() => controller.alignCenterX(selectedRooms));
  void alignRight() => setState(() => controller.alignRight(selectedRooms));
  void alignTop() => setState(() => controller.alignTop(selectedRooms));
  void alignCenterY() => setState(() => controller.alignCenterY(selectedRooms));
  void alignBottom() => setState(() => controller.alignBottom(selectedRooms));

  @override
  Widget build(BuildContext context) {
    final roomDeletePos = selectedStructure == null && selectedRooms.isNotEmpty
        ? _roomDeleteButtonPosition(selectedRooms.first)
        : null;
    final structureDeletePos = selectedStructure != null
        ? _structureDeleteButtonPosition(selectedStructure!)
        : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTapDown: (d) {
            if (selectedStructure != null) {
              final handles = _structureHandles(selectedStructure!);
              if (_isNearHandle(d.localPosition, handles.delete)) {
                _deleteSelectedStructure();
                widget.onLayoutChanged();
                return;
              }
            }

            final structure = _hitTestStructure(d.localPosition);
            if (structure != null) {
              setState(() {
                selectedStructure = structure;
                selectedRooms.clear();
              });
              return;
            }

            final hit = _hitTestRoom(d.localPosition);
            setState(() {
              selectedStructure = null;
              selectedRooms
                ..clear()
                ..addAll(hit != null ? [hit] : []);
            });
          },
          onLongPressStart: (d) {
            final hit = _hitTestRoom(d.localPosition);
            if (hit != null) {
              setState(() {
                selectedStructure = null;
                selectedRooms.contains(hit)
                    ? selectedRooms.remove(hit)
                    : selectedRooms.add(hit);
              });
            }
          },
          onPanStart: (d) {
            if (selectedStructure != null) {
              final handles = _structureHandles(selectedStructure!);
              if (_isNearHandle(d.localPosition, handles.rotate)) {
                editMode = EditMode.structureRotate;
                final center = Offset(
                  selectedStructure!.x + selectedStructure!.width / 2,
                  selectedStructure!.y + selectedStructure!.height / 2,
                );
                _startPointerAngle = math.atan2(
                  d.localPosition.dy - center.dy,
                  d.localPosition.dx - center.dx,
                );
                _startStructureRotation = selectedStructure!.rotation;
                return;
              }
              if (_isNearHandle(d.localPosition, handles.move) ||
                  _isPointInsideRotatedStructure(
                    d.localPosition,
                    selectedStructure!,
                  )) {
                editMode = EditMode.structureMove;
                return;
              }
            }

            final tappedStructure = _hitTestStructure(d.localPosition);
            if (tappedStructure != null) {
              setState(() {
                selectedStructure = tappedStructure;
                selectedRooms.clear();
              });
              editMode = EditMode.structureMove;
              return;
            }

            activeRoom = _hitTestRoom(d.localPosition);
            if (activeRoom != null) {
              selectedStructure = null;
              editMode = _detectRoomMode(activeRoom!, d.localPosition);
            }
          },
          onPanUpdate: (d) {
            setState(() {
              if (selectedStructure != null &&
                  editMode == EditMode.structureMove) {
                _moveStructureSafe(selectedStructure!, d.delta);
                return;
              }

              if (selectedStructure != null &&
                  editMode == EditMode.structureRotate) {
                final center = Offset(
                  selectedStructure!.x + selectedStructure!.width / 2,
                  selectedStructure!.y + selectedStructure!.height / 2,
                );
                final currentAngle = math.atan2(
                  d.localPosition.dy - center.dy,
                  d.localPosition.dx - center.dx,
                );
                selectedStructure!.rotation =
                    _startStructureRotation +
                    (currentAngle - _startPointerAngle);
                return;
              }

              if (activeRoom == null || editMode == null) return;

              if (editMode == EditMode.resize) {
                controller.resizeRoomSafe(
                  activeRoom!,
                  d.delta.dx,
                  d.delta.dy,
                  widget.canvasSize,
                );
              } else if (editMode == EditMode.move) {
                activeRoom!
                  ..x += d.delta.dx
                  ..y += d.delta.dy;
              }
            });
          },
          onPanEnd: (_) {
            if (selectedStructure != null) {
              setState(() {
                if (editMode == EditMode.structureMove) {
                  selectedStructure!
                    ..x = (selectedStructure!.x / 20).round() * 20
                    ..y = (selectedStructure!.y / 20).round() * 20;
                  _snapStructureToNearestRoomWall(selectedStructure!);
                }

                if (editMode == EditMode.structureRotate) {
                  final step = math.pi / 12;
                  selectedStructure!.rotation =
                      (selectedStructure!.rotation / step).round() * step;
                  _snapStructureToNearestRoomWall(selectedStructure!);
                }
              });
              widget.onLayoutChanged();
            }

            if (activeRoom != null) {
              setState(() {
                activeRoom!
                  ..x = (activeRoom!.x / 20).round() * 20
                  ..y = (activeRoom!.y / 20).round() * 20;

                controller.snapToNearby(activeRoom!);
              });
              widget.onLayoutChanged();
            }

            activeRoom = null;
            editMode = null;
          },
          onDoubleTapDown: (d) async {
            final structure = _hitTestStructure(d.localPosition);
            if (structure != null) {
              setState(() {
                selectedStructure = structure;
                structure.rotation += math.pi / 2;
              });
              widget.onLayoutChanged();
              return;
            }

            final room = _hitTestRoom(d.localPosition);
            if (room == null) return;

            final textCtrl = TextEditingController(text: room.customName ?? '');

            final result = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Rename Room'),
                content: TextField(
                  controller: textCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Enter room name',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, textCtrl.text.trim()),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );

            if (result != null && result.isNotEmpty) {
              setState(() => room.customName = result);
            }
          },
          child: CustomPaint(
            size: widget.canvasSize,
            painter: FloorPlanPainter(
              widget.rooms,
              widget.structures,
              walls: widget.walls,
              selectedRoom: selectedRooms.isEmpty ? null : selectedRooms.first,
              selectedStructure: selectedStructure,
              useMeters: widget.useMeters,
              wallThickness: widget.wallThickness,
              darkMode: widget.darkMode,
            ),
          ),
        ),
        if (roomDeletePos != null)
          Positioned(
            left: roomDeletePos.dx,
            top: roomDeletePos.dy,
            child: _DeleteChip(
              onTap: () {
                _deleteSelectedRoom();
                widget.onLayoutChanged();
              },
            ),
          ),
        if (structureDeletePos != null)
          Positioned(
            left: structureDeletePos.dx,
            top: structureDeletePos.dy,
            child: _DeleteChip(
              onTap: () {
                _deleteSelectedStructure();
                widget.onLayoutChanged();
              },
            ),
          ),
      ],
    );
  }
}

class _DeleteChip extends StatelessWidget {
  const _DeleteChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD00000),
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
