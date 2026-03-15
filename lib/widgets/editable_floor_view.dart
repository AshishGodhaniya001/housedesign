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
  static const double _gestureActivationDistance = 8.0;

  late RoomController controller;

  final Set<RoomModel> selectedRooms = {};
  RoomModel? activeRoom;
  StructureModel? selectedStructure;
  EditMode? editMode;
  RoomResizeCorner? activeResizeCorner;
  List<_AttachedStructureSnapshot> _activeRoomAttachments = [];
  List<SnapGuideLine> _snapGuides = [];
  _StructureDragSnapshot? _activeStructureDragSnapshot;
  _RoomGeometrySnapshot? _activeRoomDragSnapshot;
  Offset? _dragStartLocalPosition;
  bool _hasExceededGestureSlop = false;

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

  Map<RoomResizeCorner, Offset> _roomHandles(RoomModel room) {
    return {
      RoomResizeCorner.topLeft: Offset(room.x, room.y),
      RoomResizeCorner.topCenter: Offset(room.x + room.width / 2, room.y),
      RoomResizeCorner.topRight: Offset(room.x + room.width, room.y),
      RoomResizeCorner.rightCenter: Offset(
        room.x + room.width,
        room.y + room.height / 2,
      ),
      RoomResizeCorner.bottomRight: Offset(
        room.x + room.width,
        room.y + room.height,
      ),
      RoomResizeCorner.bottomCenter: Offset(
        room.x + room.width / 2,
        room.y + room.height,
      ),
      RoomResizeCorner.bottomLeft: Offset(room.x, room.y + room.height),
      RoomResizeCorner.leftCenter: Offset(
        room.x,
        room.y + room.height / 2,
      ),
    };
  }

  RoomResizeCorner? _detectResizeCorner(RoomModel room, Offset pos) {
    for (final entry in _roomHandles(room).entries) {
      final isSideHandle = switch (entry.key) {
        RoomResizeCorner.topCenter ||
        RoomResizeCorner.rightCenter ||
        RoomResizeCorner.bottomCenter ||
        RoomResizeCorner.leftCenter => true,
        _ => false,
      };
      if (_isNearHandle(pos, entry.value, radius: isSideHandle ? 24 : 26)) {
        return entry.key;
      }
    }
    return null;
  }

  ({RoomModel room, RoomResizeCorner corner})? _hitTestSelectedRoomHandle(
    Offset pos,
  ) {
    if (selectedRooms.isEmpty) return null;
    final room = selectedRooms.first;
    final corner = _detectResizeCorner(room, pos);
    if (corner == null) return null;
    return (room: room, corner: corner);
  }

  EditMode _detectRoomMode(RoomModel r, Offset pos) {
    activeResizeCorner = _detectResizeCorner(r, pos);
    return activeResizeCorner != null ? EditMode.resize : EditMode.move;
  }

  _RoomAttachmentSide? _detectWallAttachmentSide(
    RoomModel room,
    StructureModel structure,
  ) {
    if (structure.floor != room.floor) return null;
    if (structure.type == StructureType.pillar) return null;

    final center = Offset(
      structure.x + structure.width / 2,
      structure.y + structure.height / 2,
    );
    final expanded = Rect.fromLTWH(
      room.x - 28,
      room.y - 28,
      room.width + 56,
      room.height + 56,
    );
    if (!expanded.contains(center)) {
      return null;
    }

    final distances = <_RoomAttachmentSide, double>{
      _RoomAttachmentSide.left: (center.dx - room.x).abs(),
      _RoomAttachmentSide.right: (center.dx - (room.x + room.width)).abs(),
      _RoomAttachmentSide.top: (center.dy - room.y).abs(),
      _RoomAttachmentSide.bottom: (center.dy - (room.y + room.height)).abs(),
    };

    final nearest = distances.entries.reduce(
      (a, b) => a.value <= b.value ? a : b,
    );

    return nearest.value <= 36 ? nearest.key : null;
  }

  bool _isAttachedPillar(RoomModel room, StructureModel structure) {
    if (structure.floor != room.floor ||
        structure.type != StructureType.pillar) {
      return false;
    }

    final center = Offset(
      structure.x + structure.width / 2,
      structure.y + structure.height / 2,
    );

    return Rect.fromLTWH(
      room.x - 12,
      room.y - 12,
      room.width + 24,
      room.height + 24,
    ).contains(center);
  }

  List<_AttachedStructureSnapshot> _captureRoomAttachments(RoomModel room) {
    final snapshots = <_AttachedStructureSnapshot>[];
    for (final structure in widget.structures) {
      if (structure.type == StructureType.pillar) {
        if (!_isAttachedPillar(room, structure)) continue;

        const pad = 8.0;
        final insetX = math.min(
          pad,
          math.max(0.0, (room.width - structure.width) / 2),
        );
        final insetY = math.min(
          pad,
          math.max(0.0, (room.height - structure.height) / 2),
        );
        final availableWidth = math.max(
          1.0,
          room.width - structure.width - (insetX * 2),
        );
        final availableHeight = math.max(
          1.0,
          room.height - structure.height - (insetY * 2),
        );

        snapshots.add(
          _AttachedStructureSnapshot(
            structure: structure,
            mode: _RoomAttachmentMode.inside,
            xRatio:
                ((structure.x - room.x - insetX) / availableWidth).clamp(
                  0.0,
                  1.0,
                ),
            yRatio:
                ((structure.y - room.y - insetY) / availableHeight).clamp(
                  0.0,
                  1.0,
                ),
            baseWidth: structure.width,
            baseHeight: structure.height,
            baseRotation: structure.rotation,
          ),
        );
        continue;
      }

      final side = _detectWallAttachmentSide(room, structure);
      if (side == null) continue;

      final center = Offset(
        structure.x + structure.width / 2,
        structure.y + structure.height / 2,
      );
      final wallOffset = switch (side) {
        _RoomAttachmentSide.left || _RoomAttachmentSide.right =>
          center.dy - room.y,
        _RoomAttachmentSide.top || _RoomAttachmentSide.bottom =>
          center.dx - room.x,
      };

      snapshots.add(
        _AttachedStructureSnapshot(
          structure: structure,
          mode: _RoomAttachmentMode.wall,
          side: side,
          wallOffset: wallOffset,
          baseWidth: structure.width,
          baseHeight: structure.height,
          baseRotation: structure.rotation,
        ),
      );
    }
    return snapshots;
  }

  Iterable<StructureModel> _attachedStructures(
    List<_AttachedStructureSnapshot> attachments,
  ) => attachments.map((attachment) => attachment.structure);

  void _applyRoomAttachmentsForMove(
    RoomModel room,
    List<_AttachedStructureSnapshot> attachments,
  ) {
    for (final attachment in attachments) {
      if (attachment.mode == _RoomAttachmentMode.inside) {
        _positionInsideAttachment(room, attachment);
      } else {
        _positionWallAttachment(room, attachment, allowResize: false);
      }
    }
  }

  void _applyRoomAttachmentsForResize(
    RoomModel room,
    List<_AttachedStructureSnapshot> attachments,
  ) {
    for (final attachment in attachments) {
      if (attachment.mode == _RoomAttachmentMode.inside) {
        _positionInsideAttachment(room, attachment);
      } else {
        _positionWallAttachment(room, attachment, allowResize: true);
      }
    }
  }

  void _positionWallAttachment(
    RoomModel room,
    _AttachedStructureSnapshot attachment, {
    required bool allowResize,
  }) {
    if (attachment.side == null) return;

    const pad = 8.0;
    final structure = attachment.structure;
    if (!widget.structures.contains(structure)) return;

    final edgeLength = switch (attachment.side!) {
      _RoomAttachmentSide.left || _RoomAttachmentSide.right => room.height,
      _RoomAttachmentSide.top || _RoomAttachmentSide.bottom => room.width,
    };
    final span = allowResize
        ? math.min(
            attachment.baseWidth,
            math.max(24.0, edgeLength - (pad * 2)),
          )
        : attachment.baseWidth;
    final safePad = math.min(pad, math.max(0.0, (edgeLength - span) / 2));
    final minCenter = (span / 2) + safePad;
    final maxCenter = math.max(minCenter, edgeLength - safePad - (span / 2));
    final centerAlong = attachment.wallOffset.clamp(minCenter, maxCenter);

    structure
      ..width = span
      ..height = attachment.baseHeight;

    switch (attachment.side!) {
      case _RoomAttachmentSide.left:
        structure.rotation = math.pi / 2;
        structure.x = room.x - structure.width / 2;
        structure.y = room.y + centerAlong - structure.height / 2;
        break;
      case _RoomAttachmentSide.right:
        structure.rotation = math.pi / 2;
        structure.x = room.x + room.width - structure.width / 2;
        structure.y = room.y + centerAlong - structure.height / 2;
        break;
      case _RoomAttachmentSide.top:
        structure.rotation = 0;
        structure.x = room.x + centerAlong - structure.width / 2;
        structure.y = room.y - structure.height / 2;
        break;
      case _RoomAttachmentSide.bottom:
        structure.rotation = 0;
        structure.x = room.x + centerAlong - structure.width / 2;
        structure.y = room.y + room.height - structure.height / 2;
        break;
    }

    structure.x = structure.x.clamp(
      0.0,
      widget.canvasSize.width - structure.width,
    );
    structure.y = structure.y.clamp(
      0.0,
      widget.canvasSize.height - structure.height,
    );
  }

  void _positionInsideAttachment(
    RoomModel room,
    _AttachedStructureSnapshot attachment,
  ) {
    const pad = 8.0;
    final structure = attachment.structure;
    if (!widget.structures.contains(structure)) return;

    final insetX = math.min(
      pad,
      math.max(0.0, (room.width - attachment.baseWidth) / 2),
    );
    final insetY = math.min(
      pad,
      math.max(0.0, (room.height - attachment.baseHeight) / 2),
    );
    final availableWidth = math.max(
      0.0,
      room.width - attachment.baseWidth - (insetX * 2),
    );
    final availableHeight = math.max(
      0.0,
      room.height - attachment.baseHeight - (insetY * 2),
    );

    structure
      ..width = attachment.baseWidth
      ..height = attachment.baseHeight
      ..rotation = attachment.baseRotation
      ..x = room.x + insetX + (availableWidth * attachment.xRatio)
      ..y = room.y + insetY + (availableHeight * attachment.yRatio);

    structure.x = structure.x.clamp(
      room.x,
      room.x + math.max(0.0, room.width - structure.width),
    );
    structure.y = structure.y.clamp(
      room.y,
      room.y + math.max(0.0, room.height - structure.height),
    );
    structure.x = structure.x.clamp(
      0.0,
      widget.canvasSize.width - structure.width,
    );
    structure.y = structure.y.clamp(
      0.0,
      widget.canvasSize.height - structure.height,
    );
  }

  void _moveStructureSafe(StructureModel s, Offset delta) {
    s.x = (s.x + delta.dx).clamp(0.0, widget.canvasSize.width - s.width);
    s.y = (s.y + delta.dy).clamp(0.0, widget.canvasSize.height - s.height);
  }

  void _beginGesture(Offset localPosition) {
    _dragStartLocalPosition = localPosition;
    _hasExceededGestureSlop = false;
    _snapGuides = [];
  }

  bool _shouldActivateGesture(Offset localPosition) {
    final start = _dragStartLocalPosition;
    if (start == null) return true;
    if (_hasExceededGestureSlop) return true;
    final distance = (localPosition - start).distance;
    if (distance < _gestureActivationDistance) {
      return false;
    }
    _hasExceededGestureSlop = true;
    return true;
  }

  Offset _gestureDeltaFromStart(Offset localPosition) {
    final start = _dragStartLocalPosition;
    if (start == null) return Offset.zero;
    return localPosition - start;
  }

  List<SnapGuideLine> _buildSnapGuidesForRoom(RoomModel room) {
    const threshold = 14.0;
    _GuideCandidate? verticalCandidate;
    _GuideCandidate? horizontalCandidate;

    final roomRect = Rect.fromLTWH(room.x, room.y, room.width, room.height);
    final roomAnchorsX = <double>[
      roomRect.left,
      roomRect.center.dx,
      roomRect.right,
    ];
    final roomAnchorsY = <double>[
      roomRect.top,
      roomRect.center.dy,
      roomRect.bottom,
    ];

    for (final other in widget.rooms) {
      if (other == room || other.floor != room.floor) continue;
      final otherRect = Rect.fromLTWH(other.x, other.y, other.width, other.height);
      final otherAnchorsX = <double>[
        otherRect.left,
        otherRect.center.dx,
        otherRect.right,
      ];
      final otherAnchorsY = <double>[
        otherRect.top,
        otherRect.center.dy,
        otherRect.bottom,
      ];

      for (final roomX in roomAnchorsX) {
        for (final otherX in otherAnchorsX) {
          final delta = (roomX - otherX).abs();
          if (delta > threshold) continue;
          if (verticalCandidate == null || delta < verticalCandidate.delta) {
            verticalCandidate = _GuideCandidate(
              delta: delta,
              line: SnapGuideLine(
                start: Offset(
                  otherX,
                  math.max(0.0, math.min(roomRect.top, otherRect.top) - 24),
                ),
                end: Offset(
                  otherX,
                  math.min(
                    widget.canvasSize.height,
                    math.max(roomRect.bottom, otherRect.bottom) + 24,
                  ),
                ),
              ),
            );
          }
        }
      }

      for (final roomY in roomAnchorsY) {
        for (final otherY in otherAnchorsY) {
          final delta = (roomY - otherY).abs();
          if (delta > threshold) continue;
          if (horizontalCandidate == null || delta < horizontalCandidate.delta) {
            horizontalCandidate = _GuideCandidate(
              delta: delta,
              line: SnapGuideLine(
                start: Offset(
                  math.max(0.0, math.min(roomRect.left, otherRect.left) - 24),
                  otherY,
                ),
                end: Offset(
                  math.min(
                    widget.canvasSize.width,
                    math.max(roomRect.right, otherRect.right) + 24,
                  ),
                  otherY,
                ),
              ),
            );
          }
        }
      }
    }

    return [
      if (verticalCandidate != null) verticalCandidate.line,
      if (horizontalCandidate != null) horizontalCandidate.line,
    ];
  }

  bool _isStructureMostlyVertical(StructureModel structure) {
    final normalizedTurns = (structure.rotation / (math.pi / 2)).round();
    return normalizedTurns.isOdd;
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

  void _snapStructureWithoutResizing(StructureModel s) {
    final room = _nearestRoomForStructure(s);
    if (room == null) return;

    final center = Offset(s.x + s.width / 2, s.y + s.height / 2);
    const pad = 8.0;

    if (s.type == StructureType.pillar) {
      s.rotation = 0;
      s.x = s.x.clamp(room.x + pad, room.x + room.width - s.width - pad);
      s.y = s.y.clamp(room.y + pad, room.y + room.height - s.height - pad);
      return;
    }

    if (_isStructureMostlyVertical(s)) {
      final leftDist = (center.dx - room.x).abs();
      final rightDist = (center.dx - (room.x + room.width)).abs();
      final wallX = leftDist <= rightDist ? room.x : room.x + room.width;
      s.rotation = math.pi / 2;
      s.x = wallX - s.width / 2;
      s.y = (center.dy - s.height / 2).clamp(
        room.y + pad,
        room.y + room.height - s.height - pad,
      );
    } else {
      final topDist = (center.dy - room.y).abs();
      final bottomDist = (center.dy - (room.y + room.height)).abs();
      final wallY = topDist <= bottomDist ? room.y : room.y + room.height;
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

            final selectedHandle = _hitTestSelectedRoomHandle(d.localPosition);
            if (selectedHandle != null) {
              setState(() {
                selectedStructure = null;
                selectedRooms
                  ..clear()
                  ..add(selectedHandle.room);
              });
              return;
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
            final selectedHandle = _hitTestSelectedRoomHandle(d.localPosition);
            if (selectedHandle != null) {
              activeRoom = selectedHandle.room;
              selectedStructure = null;
              activeResizeCorner = selectedHandle.corner;
              editMode = EditMode.resize;
              _activeRoomDragSnapshot = _RoomGeometrySnapshot.fromRoom(
                selectedHandle.room,
              );
              _activeRoomAttachments = _captureRoomAttachments(activeRoom!);
              _beginGesture(d.localPosition);
              return;
            }

            if (selectedStructure != null) {
              final handles = _structureHandles(selectedStructure!);
              if (_isNearHandle(d.localPosition, handles.rotate)) {
                editMode = EditMode.structureRotate;
                _activeStructureDragSnapshot = _StructureDragSnapshot(
                  width: selectedStructure!.width,
                  height: selectedStructure!.height,
                  rotation: selectedStructure!.rotation,
                  x: selectedStructure!.x,
                  y: selectedStructure!.y,
                );
                _beginGesture(d.localPosition);
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
                _activeStructureDragSnapshot = _StructureDragSnapshot(
                  width: selectedStructure!.width,
                  height: selectedStructure!.height,
                  rotation: selectedStructure!.rotation,
                  x: selectedStructure!.x,
                  y: selectedStructure!.y,
                );
                _beginGesture(d.localPosition);
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
              _activeStructureDragSnapshot = _StructureDragSnapshot(
                width: tappedStructure.width,
                height: tappedStructure.height,
                rotation: tappedStructure.rotation,
                x: tappedStructure.x,
                y: tappedStructure.y,
              );
              _beginGesture(d.localPosition);
              return;
            }

            activeRoom = _hitTestRoom(d.localPosition);
            if (activeRoom != null) {
              selectedStructure = null;
              editMode = _detectRoomMode(activeRoom!, d.localPosition);
              _activeRoomDragSnapshot = _RoomGeometrySnapshot.fromRoom(
                activeRoom!,
              );
              _activeRoomAttachments = _captureRoomAttachments(activeRoom!);
              _beginGesture(d.localPosition);
            } else {
              activeResizeCorner = null;
              _activeRoomAttachments = [];
              _snapGuides = [];
              _activeRoomDragSnapshot = null;
              _dragStartLocalPosition = null;
            }
          },
          onPanUpdate: (d) {
            setState(() {
              if (!_shouldActivateGesture(d.localPosition)) {
                return;
              }
              final totalDelta = _gestureDeltaFromStart(d.localPosition);

              if (selectedStructure != null &&
                  editMode == EditMode.structureMove) {
                if (_activeStructureDragSnapshot != null) {
                  selectedStructure!
                    ..width = _activeStructureDragSnapshot!.width
                    ..height = _activeStructureDragSnapshot!.height
                    ..rotation = _activeStructureDragSnapshot!.rotation
                    ..x = _activeStructureDragSnapshot!.x
                    ..y = _activeStructureDragSnapshot!.y;
                }
                _moveStructureSafe(selectedStructure!, totalDelta);
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
                if (activeResizeCorner == null) return;
                if (_activeRoomDragSnapshot != null) {
                  _activeRoomDragSnapshot!.applyTo(activeRoom!);
                }
                controller.resizeRoomFromCornerSafe(
                  activeRoom!,
                  activeResizeCorner!,
                  totalDelta,
                  widget.canvasSize,
                  ignoredStructures: _attachedStructures(_activeRoomAttachments),
                );
                if (_activeRoomAttachments.isNotEmpty) {
                  _applyRoomAttachmentsForResize(
                    activeRoom!,
                    _activeRoomAttachments,
                  );
                }
                _snapGuides = _buildSnapGuidesForRoom(activeRoom!);
              } else if (editMode == EditMode.move) {
                if (_activeRoomDragSnapshot != null) {
                  _activeRoomDragSnapshot!.applyTo(activeRoom!);
                }
                activeRoom!
                  ..x = (activeRoom!.x + totalDelta.dx).clamp(
                    0.0,
                    widget.canvasSize.width - activeRoom!.width,
                  )
                  ..y = (activeRoom!.y + totalDelta.dy).clamp(
                    0.0,
                    widget.canvasSize.height - activeRoom!.height,
                  );
                if (_activeRoomAttachments.isNotEmpty) {
                  _applyRoomAttachmentsForMove(
                    activeRoom!,
                    _activeRoomAttachments,
                  );
                }
                _snapGuides = _buildSnapGuidesForRoom(activeRoom!);
              }
            });
          },
          onPanEnd: (_) {
            if (selectedStructure != null) {
              setState(() {
                if (editMode == EditMode.structureMove && _hasExceededGestureSlop) {
                  if (_activeStructureDragSnapshot != null) {
                    selectedStructure!
                      ..width = _activeStructureDragSnapshot!.width
                      ..height = _activeStructureDragSnapshot!.height
                      ..rotation = _activeStructureDragSnapshot!.rotation;
                  }
                  selectedStructure!
                    ..x = (selectedStructure!.x / 20).round() * 20
                    ..y = (selectedStructure!.y / 20).round() * 20;
                  _snapStructureWithoutResizing(selectedStructure!);
                }

                if (editMode == EditMode.structureRotate &&
                    _hasExceededGestureSlop) {
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
                if (!_hasExceededGestureSlop && _activeRoomDragSnapshot != null) {
                  _activeRoomDragSnapshot!.applyTo(activeRoom!);
                } else if (editMode == EditMode.move) {
                  controller.snapRoomPosition(
                    activeRoom!,
                    widget.canvasSize,
                    ignoredStructures: _attachedStructures(
                      _activeRoomAttachments,
                    ),
                  );
                  controller.snapToNearby(activeRoom!);
                } else if (editMode == EditMode.resize) {
                  controller.snapRoomGeometry(
                    activeRoom!,
                    widget.canvasSize,
                    ignoredStructures: _attachedStructures(
                      _activeRoomAttachments,
                    ),
                  );
                }
                if (_activeRoomAttachments.isNotEmpty) {
                  if (editMode == EditMode.resize) {
                    _applyRoomAttachmentsForResize(
                      activeRoom!,
                      _activeRoomAttachments,
                    );
                  } else {
                    _applyRoomAttachmentsForMove(
                      activeRoom!,
                      _activeRoomAttachments,
                    );
                  }
                }
                _snapGuides = [];
              });
              widget.onLayoutChanged();
            }

            activeRoom = null;
            editMode = null;
            activeResizeCorner = null;
            _activeRoomAttachments = [];
            _snapGuides = [];
            _activeStructureDragSnapshot = null;
            _activeRoomDragSnapshot = null;
            _dragStartLocalPosition = null;
            _hasExceededGestureSlop = false;
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
              snapGuides: _snapGuides,
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

enum _RoomAttachmentSide { left, right, top, bottom }
enum _RoomAttachmentMode { wall, inside }

class _AttachedStructureSnapshot {
  const _AttachedStructureSnapshot({
    required this.structure,
    required this.mode,
    this.side,
    this.wallOffset = 0,
    this.xRatio = 0.5,
    this.yRatio = 0.5,
    required this.baseWidth,
    required this.baseHeight,
    required this.baseRotation,
  });

  final StructureModel structure;
  final _RoomAttachmentMode mode;
  final _RoomAttachmentSide? side;
  final double wallOffset;
  final double xRatio;
  final double yRatio;
  final double baseWidth;
  final double baseHeight;
  final double baseRotation;
}

class _StructureDragSnapshot {
  const _StructureDragSnapshot({
    required this.width,
    required this.height,
    required this.rotation,
    required this.x,
    required this.y,
  });

  final double width;
  final double height;
  final double rotation;
  final double x;
  final double y;
}

class _RoomGeometrySnapshot {
  const _RoomGeometrySnapshot({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory _RoomGeometrySnapshot.fromRoom(RoomModel room) {
    return _RoomGeometrySnapshot(
      x: room.x,
      y: room.y,
      width: room.width,
      height: room.height,
    );
  }

  final double x;
  final double y;
  final double width;
  final double height;

  void applyTo(RoomModel room) {
    room
      ..x = x
      ..y = y
      ..width = width
      ..height = height;
  }
}

class _GuideCandidate {
  const _GuideCandidate({required this.delta, required this.line});

  final double delta;
  final SnapGuideLine line;
}
