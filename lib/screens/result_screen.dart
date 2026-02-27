import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../controllers/room_controller.dart';
import '../controllers/wall_generator.dart';
import '../models/room_model.dart';
import '../models/structure_model.dart';
import '../models/wall_model.dart';
import '../services/api_service.dart';
import '../services/layout_storage.dart';
import '../services/scene_exporter.dart';
import '../services/session_storage.dart';
import '../utils/pdf_exporter.dart';
import '../widgets/editable_floor_view.dart';
import 'preview_3d_screen.dart';

enum _TopAction {
  zoomIn,
  zoomOut,
  zoomReset,
  togglePanMode,
  exportPdf,
  exportPng,
  save,
  saveAs,
  load,
  toggleUnit,
  export3d,
  preview3d,
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey<EditableFloorViewState> _editorKey =
      GlobalKey<EditableFloorViewState>();
  final TransformationController _zoomController = TransformationController();

  double wallThickness = 6.0;
  bool useMeters = false;

  List<RoomModel> rooms = [];
  List<WallModel> walls = [];
  List<StructureModel> structures = [];
  List<int> floorLevels = [0];
  int currentFloor = 0;
  bool _initialized = false;
  Size _canvasSize = const Size(360, 640);
  double _zoomLevel = 1.0;
  bool _panMode = false;
  int? _currentLayoutId;
  String? _currentLayoutName;

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  List<int> get floors {
    final all = {
      ...floorLevels,
      ...rooms.map((r) => r.floor),
      ...structures.map((s) => s.floor),
    }.toList()..sort();
    return all.isEmpty ? [0] : all;
  }

  List<RoomModel> get roomsOfCurrentFloor =>
      rooms.where((r) => r.floor == currentFloor).toList();

  List<StructureModel> get structuresOfCurrentFloor =>
      structures.where((s) => s.floor == currentFloor).toList();

  List<WallModel> get wallsOfCurrentFloor =>
      WallGenerator.fromRooms(roomsOfCurrentFloor, wallThickness, currentFloor);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    int requestedFloors = 1;
    final rawRooms = <Map<String, dynamic>>[];
    final rawStructures = <Map<String, dynamic>>[];

    if (args is Map) {
      final map = args.map((k, v) => MapEntry(k.toString(), v));
      requestedFloors = (map['floors'] as num?)?.toInt() ?? 1;
      final roomData = map['rooms'];
      final structureData = map['structures'];
      if (roomData is List) {
        for (final item in roomData) {
          if (item is Map) {
            rawRooms.add(item.map((k, v) => MapEntry(k.toString(), v)));
          }
        }
      }
      if (structureData is List) {
        for (final item in structureData) {
          if (item is Map) {
            rawStructures.add(item.map((k, v) => MapEntry(k.toString(), v)));
          }
        }
      }
    } else if (args is List) {
      for (final item in args) {
        if (item is Map) {
          rawRooms.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    }

    floorLevels = List.generate(math.max(requestedFloors, 1), (i) => i);

    final source = rawRooms.isEmpty
        ? [
            {'name': 'Living Room', 'width': 16.0, 'height': 12.0, 'floor': 0},
            {'name': 'Kitchen', 'width': 10.0, 'height': 8.0, 'floor': 0},
            {'name': 'Bedroom', 'width': 12.0, 'height': 10.0, 'floor': 0},
          ]
        : rawRooms;

    final placementCursor = <int, Offset>{};

    rooms = source.map((r) {
      final roomName = (r['name'] ?? 'Room').toString();
      final type = _roomTypeFromRaw(r, fallbackName: roomName);
      final floor = ((r['floor'] as num?)?.toInt() ?? 0).clamp(0, 100);

      final rawWidth = (r['width'] as num?)?.toDouble() ?? 12;
      final rawHeight = (r['height'] as num?)?.toDouble() ?? 10;

      final width = rawWidth <= 30 ? rawWidth * 8 : rawWidth;
      final height = rawHeight <= 30 ? rawHeight * 8 : rawHeight;

      final hasManualPosition = r.containsKey('x') && r.containsKey('y');
      late final double x;
      late final double y;

      if (hasManualPosition) {
        x = (r['x'] as num?)?.toDouble() ?? 20;
        y = (r['y'] as num?)?.toDouble() ?? 20;
      } else {
        final cursor = placementCursor[floor] ?? const Offset(20, 20);
        x = cursor.dx;
        y = cursor.dy;

        placementCursor[floor] = Offset(x + width + 6, y);
        if (placementCursor[floor]!.dx > 320) {
          placementCursor[floor] = Offset(20, y + height + 6);
        }
      }

      if (!floorLevels.contains(floor)) {
        floorLevels.add(floor);
      }

      return RoomModel(
        name: roomName,
        type: type,
        x: x,
        y: y,
        width: width,
        height: height,
        floor: floor,
        customName: (r['customName'] as String?)?.trim().isNotEmpty == true
            ? (r['customName'] as String).trim()
            : null,
      );
    }).toList();

    structures = rawStructures.map((s) {
      final typeName = (s['type'] ?? 'door').toString();
      final type = StructureType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => StructureType.door,
      );

      return StructureModel(
        type: type,
        x: (s['x'] as num?)?.toDouble() ?? 20,
        y: (s['y'] as num?)?.toDouble() ?? 20,
        width: (s['width'] as num?)?.toDouble() ?? 40,
        height: (s['height'] as num?)?.toDouble() ?? wallThickness,
        floor: (s['floor'] as num?)?.toInt() ?? 0,
        rotation: (s['rotation'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    floorLevels.sort();
    currentFloor = floorLevels.first;
    _currentLayoutId = null;
    _currentLayoutName = null;
    _initialized = true;
    _rebuildWalls();
  }

  RoomType _roomTypeFromRaw(
    Map<String, dynamic> raw, {
    required String fallbackName,
  }) {
    final rawType = raw['type'];
    if (rawType is String) {
      return RoomType.values.firstWhere(
        (e) => e.name.toLowerCase() == rawType.toLowerCase(),
        orElse: () => _roomTypeFromName(fallbackName),
      );
    }
    return _roomTypeFromName(fallbackName);
  }

  RoomType _roomTypeFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('kitchen')) return RoomType.kitchen;
    if (n.contains('bath')) return RoomType.bathroom;
    if (n.contains('living') || n.contains('hall')) return RoomType.living;
    if (n.contains('dining')) return RoomType.dining;
    if (n.contains('guest')) return RoomType.guestRoom;
    if (n.contains('study')) return RoomType.studyRoom;
    if (n.contains('pooja') || n.contains('mandir')) return RoomType.poojaRoom;
    if (n.contains('balcony')) return RoomType.balcony;
    if (n.contains('utility')) return RoomType.utility;
    if (n.contains('store')) return RoomType.storeRoom;
    if (n.contains('garage')) return RoomType.garage;
    if (n.contains('office')) return RoomType.office;
    if (n.contains('kids')) return RoomType.kidsRoom;
    if (n.contains('stair')) return RoomType.stairs;
    if (n.contains('bed')) return RoomType.bedroom;
    return RoomType.other;
  }

  Size _defaultRoomSize(RoomType type) {
    switch (type) {
      case RoomType.living:
        return const Size(160, 120);
      case RoomType.kitchen:
        return const Size(120, 96);
      case RoomType.bathroom:
        return const Size(96, 84);
      case RoomType.bedroom:
        return const Size(132, 108);
      case RoomType.dining:
        return const Size(128, 104);
      case RoomType.guestRoom:
      case RoomType.kidsRoom:
        return const Size(120, 100);
      case RoomType.studyRoom:
      case RoomType.office:
        return const Size(110, 92);
      case RoomType.poojaRoom:
        return const Size(80, 80);
      case RoomType.balcony:
        return const Size(110, 70);
      case RoomType.utility:
      case RoomType.storeRoom:
        return const Size(90, 72);
      case RoomType.garage:
        return const Size(170, 110);
      case RoomType.stairs:
        return const Size(100, 70);
      case RoomType.other:
        return const Size(120, 100);
    }
  }

  IconData _roomIcon(RoomType type) {
    switch (type) {
      case RoomType.bedroom:
      case RoomType.guestRoom:
      case RoomType.kidsRoom:
        return Icons.bed;
      case RoomType.kitchen:
        return Icons.kitchen;
      case RoomType.bathroom:
        return Icons.bathtub;
      case RoomType.living:
        return Icons.weekend;
      case RoomType.dining:
        return Icons.table_restaurant;
      case RoomType.studyRoom:
      case RoomType.office:
        return Icons.work;
      case RoomType.poojaRoom:
        return Icons.auto_awesome;
      case RoomType.balcony:
        return Icons.deck;
      case RoomType.utility:
        return Icons.local_laundry_service;
      case RoomType.storeRoom:
        return Icons.inventory_2;
      case RoomType.garage:
        return Icons.garage;
      case RoomType.stairs:
        return Icons.stairs;
      case RoomType.other:
        return Icons.home_work;
    }
  }

  String _floorLabel(int floor) {
    if (floor == 0) return 'Ground';
    if (floor == 1) return '1st';
    if (floor == 2) return '2nd';
    if (floor == 3) return '3rd';
    return '${floor}th';
  }

  Future<void> _addFloor() async {
    final controller = TextEditingController(
      text: (floors.isEmpty ? 1 : floors.last + 1).toString(),
    );

    final floor = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Floor'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Floor Number',
            hintText: '0 = Ground, 1 = 1st',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(context, value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (floor == null) return;

    setState(() {
      if (!floorLevels.contains(floor)) {
        floorLevels.add(floor);
        floorLevels.sort();
      }
      currentFloor = floor;
      _rebuildWalls();
    });
  }

  Future<void> _addCustomRoomDirect() async {
    final widthCtrl = TextEditingController(text: '12');
    final heightCtrl = TextEditingController(text: '10');
    var selectedType = RoomType.other;

    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Custom Room'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<RoomType>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Room Type'),
                items: RoomType.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                    )
                    .toList(),
                onChanged: (v) => selectedType = v ?? RoomType.other,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widthCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Width (ft)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Height (ft)',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add Room'),
          ),
        ],
      ),
    );

    if (created != true) return;

    final w = (double.tryParse(widthCtrl.text.trim()) ?? 12) * 8;
    final h = (double.tryParse(heightCtrl.text.trim()) ?? 10) * 8;

    setState(() {
      final pos = RoomController.findAutoPosition(
        rooms: rooms,
        width: w,
        height: h,
        floor: currentFloor,
        canvas: _canvasSize,
      );

      rooms.add(
        RoomModel(
          name: selectedType.label,
          type: selectedType,
          x: pos.dx,
          y: pos.dy,
          width: w,
          height: h,
          floor: currentFloor,
        ),
      );
      _rebuildWalls();
    });
  }

  Future<void> _addRoom() async {
    final RoomType? selected = await showModalBottomSheet<RoomType>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: RoomType.values
              .map(
                (type) => ListTile(
                  leading: Icon(_roomIcon(type)),
                  title: Text(type.label),
                  subtitle: const Text('Tap to add room'),
                  onTap: () => Navigator.pop(context, type),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selected == null) return;

    setState(() {
      final size = _defaultRoomSize(selected);
      final pos = RoomController.findAutoPosition(
        rooms: rooms,
        width: size.width,
        height: size.height,
        floor: currentFloor,
        canvas: _canvasSize,
      );

      rooms.add(
        RoomModel(
          name: selected.label,
          type: selected,
          x: pos.dx,
          y: pos.dy,
          width: size.width,
          height: size.height,
          floor: currentFloor,
        ),
      );

      _rebuildWalls();
    });
  }

  void _addStructure(StructureType type) {
    setState(() {
      final baseX = roomsOfCurrentFloor.isEmpty
          ? 40.0
          : roomsOfCurrentFloor.first.x + 20;
      final baseY = roomsOfCurrentFloor.isEmpty
          ? 40.0
          : roomsOfCurrentFloor.first.y + 20;

      final dims = switch (type) {
        StructureType.door => Size(42, wallThickness),
        StructureType.window => Size(48, wallThickness),
        StructureType.pillar => const Size(18, 18),
      };

      structures.add(
        StructureModel(
          type: type,
          x: baseX,
          y: baseY,
          width: dims.width,
          height: dims.height,
          floor: currentFloor,
        ),
      );
    });
  }

  Future<void> _showAddMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.meeting_room),
              title: const Text('Add Room (Quick)'),
              subtitle: const Text('Bedroom, kitchen, bathroom, living + more'),
              onTap: () {
                Navigator.pop(context);
                _addRoom();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Add Custom Room'),
              subtitle: const Text('Set room type and size'),
              onTap: () {
                Navigator.pop(context);
                _addCustomRoomDirect();
              },
            ),
            ListTile(
              leading: const Icon(Icons.door_front_door),
              title: const Text('Add Door'),
              onTap: () {
                Navigator.pop(context);
                _addStructure(StructureType.door);
              },
            ),
            ListTile(
              leading: const Icon(Icons.window),
              title: const Text('Add Window'),
              onTap: () {
                Navigator.pop(context);
                _addStructure(StructureType.window);
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle),
              title: const Text('Add Pillar'),
              onTap: () {
                Navigator.pop(context);
                _addStructure(StructureType.pillar);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _rebuildWalls() {
    walls = WallGenerator.fromRooms(
      roomsOfCurrentFloor,
      wallThickness,
      currentFloor,
    );
  }

  void _applyZoom(double next) {
    _zoomLevel = next.clamp(0.4, 6.0);
    _zoomController.value = Matrix4.diagonal3Values(
      _zoomLevel,
      _zoomLevel,
      1.0,
    );
  }

  void _zoomIn() {
    setState(() => _applyZoom(_zoomLevel + 0.3));
  }

  void _zoomOut() {
    setState(() => _applyZoom(_zoomLevel - 0.3));
  }

  void _zoomReset() {
    setState(() => _applyZoom(1.0));
  }

  void _export3DJson() {
    final scene = SceneExporter.buildScene(
      rooms: rooms,
      walls: wallsOfCurrentFloor,
      wallThickness: wallThickness,
    );

    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(scene.toJson());
    debugPrint(jsonString);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _buildLayoutName() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return 'Plan ${now.year}-${pad(now.month)}-${pad(now.day)} ${pad(now.hour)}:${pad(now.minute)}';
  }

  Future<String?> _askLayoutName({String? initial}) async {
    final controller = TextEditingController(
      text: initial ?? _buildLayoutName(),
    );
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Layout Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter layout name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<String?> _cloudToken() async {
    return SessionStorage.getToken();
  }

  Future<bool> _loadLocalLayout() async {
    final loaded = await LayoutStorage.load();
    if (loaded.isEmpty) return false;

    setState(() {
      rooms = loaded;
      structures = [];
      floorLevels = {...rooms.map((e) => e.floor)}.toList()..sort();
      if (floorLevels.isEmpty) {
        floorLevels = [0];
      }
      currentFloor = floors.first;
      _currentLayoutId = null;
      _currentLayoutName = null;
      _rebuildWalls();
    });
    return true;
  }

  Future<void> _saveLayout({bool forceCreate = false}) async {
    final token = await _cloudToken();
    final roomsJson = rooms.map((e) => e.toJson()).toList();
    final structuresJson = structures.map((e) => e.toJson()).toList();

    if (token == null) {
      await LayoutStorage.save(rooms);
      _showMessage('Not logged in. Saved locally.');
      return;
    }

    final initialName = _currentLayoutName ?? _buildLayoutName();
    final requestedName = forceCreate || _currentLayoutName == null
        ? await _askLayoutName(initial: initialName)
        : _currentLayoutName;

    if (requestedName == null || requestedName.trim().isEmpty) {
      return;
    }

    try {
      if (!forceCreate && _currentLayoutId != null) {
        final updated = await ApiService.updateLayout(
          token: token,
          id: _currentLayoutId!,
          name: requestedName,
          floors: floors.length,
          rooms: roomsJson,
          structures: structuresJson,
        );
        setState(() {
          _currentLayoutId =
              (updated['id'] as num?)?.toInt() ?? _currentLayoutId;
          _currentLayoutName = (updated['name'] ?? requestedName).toString();
        });
        _showMessage('Updated layout #${updated['id']}');
      } else {
        final created = await ApiService.saveLayout(
          token: token,
          name: requestedName,
          floors: floors.length,
          rooms: roomsJson,
          structures: structuresJson,
        );
        setState(() {
          _currentLayoutId = (created['id'] as num?)?.toInt();
          _currentLayoutName = (created['name'] ?? requestedName).toString();
        });
        _showMessage('Saved to database (#${created['id']})');
      }
      return;
    } catch (_) {
      await LayoutStorage.save(rooms);
      _showMessage('Cloud save failed. Saved locally.');
    }
  }

  void _applyLoadedLayout({
    required List<dynamic> rawRooms,
    required List<dynamic> rawStructures,
    required int requestedFloors,
  }) {
    setState(() {
      rooms = rawRooms
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .map(RoomModel.fromJson)
          .toList();

      structures = rawStructures
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .map(StructureModel.fromJson)
          .toList();

      floorLevels = List.generate(math.max(requestedFloors, 1), (i) => i);
      floorLevels = {
        ...floorLevels,
        ...rooms.map((e) => e.floor),
        ...structures.map((e) => e.floor),
      }.toList()..sort();
      if (floorLevels.isEmpty) {
        floorLevels = [0];
      }
      currentFloor = floors.first;
      _rebuildWalls();
    });
  }

  Future<Map<String, dynamic>?> _openLayoutManager(
    List<Map<String, dynamic>> layouts,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cloud Layouts'),
        content: SizedBox(
          width: 580,
          child: layouts.isEmpty
              ? const Text('No layouts found.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: layouts.length,
                  itemBuilder: (_, index) {
                    final item = layouts[index];
                    final title = (item['name'] ?? 'Untitled Layout')
                        .toString();
                    final subtitle =
                        'ID ${item['id']} | Floors ${item['floors']} | Rooms ${item['roomsCount'] ?? 0}';
                    final id = (item['id'] as num?)?.toInt();

                    return ListTile(
                      title: Text(title),
                      subtitle: Text(subtitle),
                      onTap: id == null
                          ? null
                          : () => Navigator.pop(context, {
                              'action': 'load',
                              'id': id,
                              'name': title,
                            }),
                      trailing: id == null
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Rename',
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => Navigator.pop(context, {
                                    'action': 'rename',
                                    'id': id,
                                    'name': title,
                                  }),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () => Navigator.pop(context, {
                                    'action': 'delete',
                                    'id': id,
                                    'name': title,
                                  }),
                                ),
                              ],
                            ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSavedLayout() async {
    final token = await _cloudToken();
    if (token == null) {
      final hasLocal = await _loadLocalLayout();
      _showMessage(
        hasLocal ? 'Loaded local layout' : 'Please login to load cloud layouts',
      );
      return;
    }

    try {
      var layouts = await ApiService.fetchLayouts(token: token);
      if (layouts.isEmpty) {
        _showMessage('No cloud layouts found');
        return;
      }

      while (true) {
        final action = await _openLayoutManager(layouts);
        if (action == null) {
          return;
        }

        final selectedId = (action['id'] as num?)?.toInt();
        final selectedName = (action['name'] ?? 'Untitled Layout').toString();
        final kind = (action['action'] ?? '').toString();
        if (selectedId == null) {
          continue;
        }

        if (kind == 'load') {
          final payload = await ApiService.fetchLayoutById(
            selectedId,
            token: token,
          );
          final requestedFloors = (payload['floors'] as num?)?.toInt() ?? 1;
          _applyLoadedLayout(
            rawRooms: payload['rooms'] as List<dynamic>? ?? const [],
            rawStructures: payload['structures'] as List<dynamic>? ?? const [],
            requestedFloors: requestedFloors,
          );
          setState(() {
            _currentLayoutId = selectedId;
            _currentLayoutName = (payload['name'] ?? selectedName).toString();
          });
          _showMessage('Loaded layout #$selectedId');
          return;
        }

        if (kind == 'rename') {
          final renamed = await _askLayoutName(initial: selectedName);
          if (renamed == null || renamed.trim().isEmpty) {
            continue;
          }
          final payload = await ApiService.fetchLayoutById(
            selectedId,
            token: token,
          );
          await ApiService.updateLayout(
            token: token,
            id: selectedId,
            name: renamed,
            floors: (payload['floors'] as num?)?.toInt() ?? 1,
            rooms: (payload['rooms'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                .toList(),
            structures: (payload['structures'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                .toList(),
          );
          if (_currentLayoutId == selectedId) {
            setState(() => _currentLayoutName = renamed);
          }
          layouts = await ApiService.fetchLayouts(token: token);
          _showMessage('Layout renamed');
          continue;
        }

        if (kind == 'delete') {
          if (!mounted) return;
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete Layout'),
              content: Text('Delete "$selectedName"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm != true) {
            continue;
          }
          await ApiService.deleteLayout(selectedId, token: token);
          if (_currentLayoutId == selectedId) {
            setState(() {
              _currentLayoutId = null;
              _currentLayoutName = null;
            });
          }
          layouts = await ApiService.fetchLayouts(token: token);
          if (layouts.isEmpty) {
            _showMessage('Layout deleted. No cloud layouts left');
            return;
          }
          _showMessage('Layout deleted');
        }
      }
    } catch (_) {
      final hasLocal = await _loadLocalLayout();
      _showMessage(
        hasLocal
            ? 'Cloud unavailable. Loaded local layout.'
            : 'Cloud unavailable and no local layout found',
      );
      return;
    }
  }

  void _open3DPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Preview3DScreen(
          rooms: rooms,
          structures: structures,
          wallThickness: wallThickness,
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(_TopAction action) async {
    switch (action) {
      case _TopAction.zoomIn:
        _zoomIn();
        break;
      case _TopAction.zoomOut:
        _zoomOut();
        break;
      case _TopAction.zoomReset:
        _zoomReset();
        break;
      case _TopAction.togglePanMode:
        setState(() => _panMode = !_panMode);
        break;
      case _TopAction.exportPdf:
        await _exportPDF();
        break;
      case _TopAction.exportPng:
        await _exportPNG();
        break;
      case _TopAction.save:
        await _saveLayout();
        break;
      case _TopAction.saveAs:
        await _saveLayout(forceCreate: true);
        break;
      case _TopAction.load:
        await _loadSavedLayout();
        break;
      case _TopAction.toggleUnit:
        setState(() => useMeters = !useMeters);
        break;
      case _TopAction.export3d:
        _export3DJson();
        break;
      case _TopAction.preview3d:
        _open3DPreview();
        break;
    }
  }

  List<Widget> _buildAppBarActions(bool compact) {
    if (compact) {
      return [
        IconButton(
          tooltip: 'Add Floor',
          icon: const Icon(Icons.add_box),
          onPressed: _addFloor,
        ),
        IconButton(
          tooltip: 'Zoom Out',
          icon: const Icon(Icons.zoom_out),
          onPressed: _zoomOut,
        ),
        IconButton(
          tooltip: 'Zoom In',
          icon: const Icon(Icons.zoom_in),
          onPressed: _zoomIn,
        ),
        IconButton(
          tooltip: _panMode ? 'Editing Mode' : 'Move Screen Mode',
          icon: Icon(_panMode ? Icons.pan_tool_alt : Icons.pan_tool_outlined),
          onPressed: () => setState(() => _panMode = !_panMode),
        ),
        PopupMenuButton<_TopAction>(
          tooltip: 'More',
          onSelected: (action) => _handleMenuAction(action),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: _TopAction.zoomReset,
              child: Text('Reset Zoom'),
            ),
            const PopupMenuItem(
              value: _TopAction.exportPdf,
              child: Text('Export PDF'),
            ),
            const PopupMenuItem(
              value: _TopAction.exportPng,
              child: Text('Export PNG'),
            ),
            PopupMenuItem(
              value: _TopAction.save,
              child: Text(
                _currentLayoutId == null ? 'Save (Cloud)' : 'Update Cloud Save',
              ),
            ),
            const PopupMenuItem(
              value: _TopAction.saveAs,
              child: Text('Save As'),
            ),
            const PopupMenuItem(
              value: _TopAction.load,
              child: Text('Manage Cloud Layouts'),
            ),
            PopupMenuItem(
              value: _TopAction.toggleUnit,
              child: Text(useMeters ? 'Use Feet' : 'Use Meter'),
            ),
            PopupMenuItem(
              value: _TopAction.togglePanMode,
              child: Text(
                _panMode ? 'Switch To Edit Mode' : 'Switch To Move Screen',
              ),
            ),
            const PopupMenuItem(
              value: _TopAction.export3d,
              child: Text('Export 3D JSON'),
            ),
            const PopupMenuItem(
              value: _TopAction.preview3d,
              child: Text('Open 3D Preview'),
            ),
          ],
        ),
      ];
    }

    return [
      IconButton(
        tooltip: 'Add Floor',
        icon: const Icon(Icons.add_box),
        onPressed: _addFloor,
      ),
      IconButton(
        tooltip: 'Zoom Out',
        icon: const Icon(Icons.zoom_out),
        onPressed: _zoomOut,
      ),
      IconButton(
        tooltip: 'Zoom In',
        icon: const Icon(Icons.zoom_in),
        onPressed: _zoomIn,
      ),
      IconButton(
        tooltip: _panMode ? 'Editing Mode' : 'Move Screen Mode',
        icon: Icon(_panMode ? Icons.pan_tool_alt : Icons.pan_tool_outlined),
        onPressed: () => setState(() => _panMode = !_panMode),
      ),
      IconButton(
        tooltip: 'Reset Zoom',
        icon: const Icon(Icons.center_focus_strong),
        onPressed: _zoomReset,
      ),
      IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportPDF),
      IconButton(icon: const Icon(Icons.save), onPressed: _saveLayout),
      IconButton(
        tooltip: 'Save As',
        icon: const Icon(Icons.save_as),
        onPressed: () => _saveLayout(forceCreate: true),
      ),
      IconButton(
        icon: const Icon(Icons.folder_open),
        onPressed: _loadSavedLayout,
      ),
      IconButton(icon: const Icon(Icons.download), onPressed: _exportPNG),
      IconButton(
        icon: Text(
          useMeters ? 'm' : 'ft',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => setState(() => useMeters = !useMeters),
      ),
      IconButton(icon: const Icon(Icons.view_in_ar), onPressed: _export3DJson),
      IconButton(
        icon: const Icon(Icons.threed_rotation),
        onPressed: _open3DPreview,
      ),
    ];
  }

  Future<void> _exportPDF() async {
    final originalFloor = currentFloor;
    final pdfPages = <FloorPdfPage>[];

    Future<Uint8List> captureCurrentFloor() async {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    }

    for (final floor in floors) {
      if (!mounted) return;
      setState(() {
        currentFloor = floor;
        _rebuildWalls();
      });

      final imageBytes = await captureCurrentFloor();
      pdfPages.add(
        FloorPdfPage(
          title: '${_floorLabel(floor)} Floor',
          imageBytes: imageBytes,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      currentFloor = originalFloor;
      _rebuildWalls();
    });

    final pdfBytes = await PdfExporter.buildFloorPlanPdf(
      title: '2D Floor Plan',
      pages: pdfPages,
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'floor_plan.pdf');
  }

  Future<void> _exportPNG() async {
    final boundary =
        _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/floor_plan.png');

    await file.writeAsBytes(data!.buffer.asUint8List());

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
  }

  @override
  Widget build(BuildContext context) {
    _rebuildWalls();
    final tabs = floors;
    final compactTopBar = MediaQuery.of(context).size.width < 430;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('2D Floor Editor'),
          bottom: TabBar(
            isScrollable: true,
            onTap: (i) => setState(() => currentFloor = tabs[i]),
            tabs: tabs
                .map((f) => Tab(text: '${_floorLabel(f)} Floor'))
                .toList(),
          ),
          actions: _buildAppBarActions(compactTopBar),
        ),
        body: LayoutBuilder(
          builder: (_, constraints) {
            final workspaceSize = Size(
              constraints.maxWidth * 1.8,
              constraints.maxHeight * 1.8,
            );
            _canvasSize = workspaceSize;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [
                          Color(0xFF0B1119),
                          Color(0xFF131D28),
                          Color(0xFF0E151F),
                        ]
                      : const [
                          Color(0xFFF7F1E4),
                          Color(0xFFEFE5D1),
                          Color(0xFFF6EEDF),
                        ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF17212C).withValues(alpha: 0.92)
                          : Colors.white.withValues(alpha: 0.74),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF5C4A2E)
                            : const Color(0xFFD9C7A4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 18,
                          color: isDark
                              ? const Color(0xFFE8D0A1)
                              : const Color(0xFF253448),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _panMode
                              ? 'Move Screen Mode Active'
                              : 'Edit Mode Active',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.8,
                            color: isDark
                                ? const Color(0xFFD7E0EB)
                                : const Color(0xFF223447),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Zoom ${_zoomLevel.toStringAsFixed(1)}x',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFF1D7A0)
                                : const Color(0xFF243447),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: InteractiveViewer(
                        transformationController: _zoomController,
                        minScale: 0.4,
                        maxScale: 6.0,
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(800),
                        clipBehavior: Clip.none,
                        panEnabled: _panMode,
                        scaleEnabled: true,
                        child: SizedBox(
                          width: workspaceSize.width,
                          height: workspaceSize.height,
                          child: Stack(
                            children: [
                              IgnorePointer(
                                ignoring: _panMode,
                                child: EditableFloorView(
                                  key: _editorKey,
                                  rooms: roomsOfCurrentFloor,
                                  structures: structuresOfCurrentFloor,
                                  walls: wallsOfCurrentFloor,
                                  canvasSize: _canvasSize,
                                  darkMode: isDark,
                                  onDeleteRoom: (room) {
                                    setState(() {
                                      rooms.remove(room);
                                      _rebuildWalls();
                                    });
                                  },
                                  onDeleteStructure: (structure) {
                                    setState(() {
                                      structures.remove(structure);
                                      _rebuildWalls();
                                    });
                                  },
                                  onLayoutChanged: () {
                                    setState(() {
                                      _rebuildWalls();
                                    });
                                  },
                                  useMeters: useMeters,
                                  wallThickness: wallThickness,
                                ),
                              ),
                              if (_panMode)
                                Positioned(
                                  left: 10,
                                  top: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Drag To Move Workspace',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddMenu,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ),
    );
  }
}
