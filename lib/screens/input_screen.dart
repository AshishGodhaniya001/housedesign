import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/room_model.dart';
import '../services/api_service.dart';
import '../services/session_storage.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  String? _authToken;
  Map<String, dynamic>? _authUser;
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await SessionStorage.getToken();
    final user = await SessionStorage.getUser();
    if (!mounted) return;
    setState(() {
      _authToken = token;
      _authUser = user;
      _sessionReady = true;
    });
  }

  void _openEditor(Object args) {
    Navigator.pushNamed(context, '/result', arguments: args);
  }

  Future<void> _openCustomPlanner() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AutoPlanDialog(),
    );

    if (result != null) {
      _openEditor(result);
    }
  }

  Future<void> _openAuthDialog({required bool registerMode}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AuthDialog(registerMode: registerMode),
    );

    if (result == null) return;

    final token = (result['token'] ?? '').toString();
    final userRaw = result['user'];
    final user = userRaw is Map
        ? userRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    if (token.isEmpty) return;

    await SessionStorage.saveSession(token: token, user: user);
    if (!mounted) return;

    setState(() {
      _authToken = token;
      _authUser = user;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Logged in as ${(user['email'] ?? user['name'] ?? 'User').toString()}',
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final token = _authToken;
    if (token != null && token.isNotEmpty) {
      try {
        await ApiService.logout(token: token);
      } catch (_) {
        // Session may already be invalid on backend.
      }
    }

    await SessionStorage.clearSession();
    if (!mounted) return;
    setState(() {
      _authToken = null;
      _authUser = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logged out')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userLabel = (_authUser?['email'] ?? _authUser?['name'] ?? 'Guest')
        .toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Royal Planner Suite'),
        actions: [
          if (!_sessionReady)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_authToken == null)
            PopupMenuButton<String>(
              tooltip: 'Account',
              onSelected: (value) {
                if (value == 'login') {
                  _openAuthDialog(registerMode: false);
                } else if (value == 'register') {
                  _openAuthDialog(registerMode: true);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'login', child: Text('Login')),
                PopupMenuItem(value: 'register', child: Text('Register')),
              ],
              icon: const Icon(Icons.account_circle_outlined),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Account',
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  value: 'user',
                  child: Text(userLabel),
                ),
                const PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
              icon: const Icon(Icons.verified_user),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF0A1018),
                    Color(0xFF121A25),
                    Color(0xFF0D141D),
                  ]
                : const [
                    Color(0xFFF6F1E5),
                    Color(0xFFECE2CE),
                    Color(0xFFF6EFE0),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF17202B).withValues(alpha: 0.88)
                        : Colors.white.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF5E4B2F)
                          : const Color(0xFFD5C19B),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Luxury 2D Floor Planner',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Custom Designer now generates an auto floor-wise layout using step-by-step inputs.',
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          color: isDark
                              ? const Color(0xFFC8D2E1)
                              : const Color(0xFF3F4A56),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF17202B).withValues(alpha: 0.82)
                        : Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF5E4B2F)
                          : const Color(0xFFD5C19B),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _authToken == null
                            ? Icons.lock_outline
                            : Icons.cloud_done_outlined,
                        size: 18,
                        color: isDark
                            ? const Color(0xFFE9D6AE)
                            : const Color(0xFF23354A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _authToken == null
                              ? 'Login to enable cloud database save/load.'
                              : 'Cloud connected as $userLabel',
                          style: TextStyle(
                            fontSize: 12.6,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFD6E0EE)
                                : const Color(0xFF2F3F52),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.grid_goldenratio,
                  title: 'Blank Royal Canvas',
                  subtitle: 'Start from scratch with full control',
                  darkMode: isDark,
                  onTap: () => _openEditor({
                    'floors': 1,
                    'rooms': <Map<String, dynamic>>[],
                  }),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.tune,
                  title: 'Custom Plan Designer',
                  subtitle: '1) Floors  2) Room Counts  3) Auto Create',
                  darkMode: isDark,
                  onTap: _openCustomPlanner,
                  highlighted: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthDialog extends StatefulWidget {
  const _AuthDialog({required this.registerMode});

  final bool registerMode;

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }
    if (widget.registerMode && password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = widget.registerMode
          ? await ApiService.register(
              name: name.isEmpty ? 'Planner User' : name,
              email: email,
              password: password,
            )
          : await ApiService.login(email: email, password: password);

      if (!mounted) return;
      Navigator.pop(context, response);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.registerMode ? 'Create Account' : 'Login';

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.registerMode) ...[
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB42318), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Please wait...' : title),
        ),
      ],
    );
  }
}

class _AutoPlanDialog extends StatefulWidget {
  const _AutoPlanDialog();

  @override
  State<_AutoPlanDialog> createState() => _AutoPlanDialogState();
}

class _AutoPlanDialogState extends State<_AutoPlanDialog> {
  final TextEditingController _floorsCtrl = TextEditingController(text: '2');
  final TextEditingController _attachedBathCtrl = TextEditingController(
    text: '1',
  );
  final TextEditingController _balconyPerFloorCtrl = TextEditingController(
    text: '1,1',
  );

  late final Map<RoomType, TextEditingController> _countCtrls = {
    RoomType.bedroom: TextEditingController(text: '3'),
    RoomType.bathroom: TextEditingController(text: '2'),
    RoomType.kitchen: TextEditingController(text: '1'),
    RoomType.living: TextEditingController(text: '1'),
    RoomType.dining: TextEditingController(text: '1'),
    RoomType.guestRoom: TextEditingController(text: '1'),
    RoomType.studyRoom: TextEditingController(text: '1'),
    RoomType.poojaRoom: TextEditingController(text: '0'),
    RoomType.balcony: TextEditingController(text: '1'),
    RoomType.utility: TextEditingController(text: '1'),
    RoomType.storeRoom: TextEditingController(text: '1'),
    RoomType.office: TextEditingController(text: '0'),
    RoomType.kidsRoom: TextEditingController(text: '1'),
    RoomType.stairs: TextEditingController(text: '1'),
    RoomType.garage: TextEditingController(text: '0'),
  };

  @override
  void dispose() {
    _floorsCtrl.dispose();
    _attachedBathCtrl.dispose();
    _balconyPerFloorCtrl.dispose();
    for (final c in _countCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _countOf(RoomType type) {
    return (int.tryParse(_countCtrls[type]!.text.trim()) ?? 0).clamp(0, 99);
  }

  int _attachedBathroomCount(int totalBathrooms) {
    final privateRooms =
        _countOf(RoomType.bedroom) +
        _countOf(RoomType.kidsRoom) +
        _countOf(RoomType.guestRoom);
    final requested = int.tryParse(_attachedBathCtrl.text.trim()) ?? 0;
    return requested.clamp(0, math.min(totalBathrooms, privateRooms));
  }

  List<int> _balconyFloorCounts(int totalFloors, int fallbackTotal) {
    final raw = _balconyPerFloorCtrl.text.trim();
    if (raw.isNotEmpty) {
      final parsed = raw
          .split(RegExp(r'[, ]+'))
          .where((e) => e.trim().isNotEmpty)
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .map((e) => e.clamp(0, 99))
          .toList();
      if (parsed.isNotEmpty) {
        final counts = List<int>.filled(totalFloors, 0);
        for (int i = 0; i < totalFloors && i < parsed.length; i++) {
          counts[i] = parsed[i];
        }
        return counts;
      }
    }

    final counts = List<int>.filled(totalFloors, 0);
    var remaining = fallbackTotal;
    var floor = totalFloors - 1;
    while (remaining > 0 && totalFloors > 0) {
      counts[floor] += 1;
      remaining--;
      floor--;
      if (floor < 0) floor = totalFloors - 1;
    }
    return counts;
  }

  void _applyRecommendedCounts() {
    final floors = (int.tryParse(_floorsCtrl.text.trim()) ?? 1).clamp(1, 15);
    final upper = floors > 1;

    _countCtrls[RoomType.living]!.text = '1';
    _countCtrls[RoomType.kitchen]!.text = '1';
    _countCtrls[RoomType.dining]!.text = upper ? '1' : '0';
    _countCtrls[RoomType.bedroom]!.text = upper ? '${floors + 1}' : '2';
    _countCtrls[RoomType.bathroom]!.text = upper ? '$floors' : '1';
    _attachedBathCtrl.text = upper ? '2' : '1';
    _countCtrls[RoomType.guestRoom]!.text = upper ? '1' : '0';
    _countCtrls[RoomType.kidsRoom]!.text = upper ? '1' : '0';
    _countCtrls[RoomType.studyRoom]!.text = upper ? '1' : '0';
    _countCtrls[RoomType.office]!.text = floors >= 3 ? '1' : '0';
    _countCtrls[RoomType.poojaRoom]!.text = floors >= 2 ? '1' : '0';
    _countCtrls[RoomType.utility]!.text = '1';
    _countCtrls[RoomType.storeRoom]!.text = '1';
    _countCtrls[RoomType.stairs]!.text = upper ? '1' : '0';
    _countCtrls[RoomType.balcony]!.text = upper ? '$floors' : '0';
    _balconyPerFloorCtrl.text = upper ? '1,1' : '1';
    _countCtrls[RoomType.garage]!.text = '0';
  }

  int _pickFloorForType(RoomType type, int totalFloors, List<int> load) {
    int minLoadIndex(List<int> indices) {
      var best = indices.first;
      for (final i in indices) {
        if (load[i] < load[best]) best = i;
      }
      return best;
    }

    if (type == RoomType.living ||
        type == RoomType.kitchen ||
        type == RoomType.dining ||
        type == RoomType.garage ||
        type == RoomType.poojaRoom) {
      return 0;
    }

    if (type == RoomType.balcony) {
      return totalFloors - 1;
    }

    if (totalFloors > 1 &&
        (type == RoomType.bedroom ||
            type == RoomType.kidsRoom ||
            type == RoomType.studyRoom ||
            type == RoomType.office ||
            type == RoomType.guestRoom)) {
      return minLoadIndex(List.generate(totalFloors - 1, (i) => i + 1));
    }

    return minLoadIndex(List.generate(totalFloors, (i) => i));
  }

  Size _defaultFt(RoomType type) {
    switch (type) {
      case RoomType.living:
        return const Size(16, 12);
      case RoomType.kitchen:
        return const Size(10, 8);
      case RoomType.bathroom:
        return const Size(8, 7);
      case RoomType.bedroom:
        return const Size(12, 10);
      case RoomType.dining:
        return const Size(11, 10);
      case RoomType.guestRoom:
      case RoomType.kidsRoom:
        return const Size(11, 10);
      case RoomType.studyRoom:
      case RoomType.office:
        return const Size(10, 9);
      case RoomType.poojaRoom:
        return const Size(7, 7);
      case RoomType.balcony:
        return const Size(10, 6);
      case RoomType.utility:
      case RoomType.storeRoom:
        return const Size(8, 6);
      case RoomType.garage:
        return const Size(18, 11);
      case RoomType.stairs:
        return const Size(9, 6);
      case RoomType.other:
        return const Size(12, 10);
    }
  }

  List<Map<String, dynamic>> _buildRooms(int totalFloors) {
    final load = List<int>.filled(totalFloors, 0);
    final rooms = <Map<String, dynamic>>[];
    final stairCount = _countOf(RoomType.stairs);
    final hasLinkedStairs = totalFloors > 1 && stairCount > 0;
    final stairFt = _defaultFt(RoomType.stairs);
    final stairW = stairFt.width * 8;
    final stairH = stairFt.height * 8;
    final reservedStairX = hasLinkedStairs ? (340.0 - stairW - 6) : 340.0;

    final orderedTypes = [
      RoomType.living,
      RoomType.kitchen,
      RoomType.dining,
      RoomType.bedroom,
      RoomType.bathroom,
      RoomType.guestRoom,
      RoomType.kidsRoom,
      RoomType.studyRoom,
      RoomType.office,
      RoomType.poojaRoom,
      RoomType.utility,
      RoomType.storeRoom,
      RoomType.garage,
    ];

    final roomsByFloor = <int, List<Map<String, dynamic>>>{};

    for (final type in orderedTypes) {
      final count = _countOf(type);
      for (int i = 0; i < count; i++) {
        final floor = _pickFloorForType(type, totalFloors, load);
        final size = _defaultFt(type);
        load[floor] += 1;

        roomsByFloor.putIfAbsent(floor, () => []);
        roomsByFloor[floor]!.add({
          'name': type.label,
          'type': type.name,
          'width': size.width,
          'height': size.height,
          'floor': floor,
        });
      }
    }

    final balconyCounts = _balconyFloorCounts(
      totalFloors,
      _countOf(RoomType.balcony),
    );
    final balconySize = _defaultFt(RoomType.balcony);
    for (int floor = 0; floor < totalFloors; floor++) {
      final count = balconyCounts[floor];
      for (int i = 0; i < count; i++) {
        roomsByFloor.putIfAbsent(floor, () => []);
        roomsByFloor[floor]!.add({
          'name': RoomType.balcony.label,
          'type': RoomType.balcony.name,
          'width': balconySize.width,
          'height': balconySize.height,
          'floor': floor,
        });
      }
    }

    if (hasLinkedStairs) {
      for (int shaft = 0; shaft < stairCount; shaft++) {
        final sx = 340.0 - stairW - 6;
        final sy = 20.0 + shaft * (stairH + 8);

        for (int floor = 0; floor < totalFloors; floor++) {
          String stairName;
          if (floor == 0) {
            stairName = 'Stair C${shaft + 1} UP ${floor + 1}';
          } else if (floor == totalFloors - 1) {
            stairName = 'Stair C${shaft + 1} DOWN ${floor - 1}';
          } else {
            stairName = 'Stair C${shaft + 1} UP ${floor + 1}';
          }

          roomsByFloor.putIfAbsent(floor, () => []);
          roomsByFloor[floor]!.add({
            'name': stairName,
            'type': RoomType.stairs.name,
            'width': stairFt.width,
            'height': stairFt.height,
            'floor': floor,
            'x': sx,
            'y': sy,
            'fixedPosition': true,
            'stairCore': shaft + 1,
          });
          load[floor] += 1;
        }
      }
    }

    const startX = 20.0;
    const startY = 20.0;
    final maxWidthPx = hasLinkedStairs ? reservedStairX - 2 : 340.0;
    const maxHeightPx = 620.0;
    const cell = 20.0;
    const touchGap = 0.0;
    const smallGap = 4.0;
    const walkwayGap = 4.0;
    int attachedBathroomsRemaining = _attachedBathroomCount(
      _countOf(RoomType.bathroom),
    );

    for (int floor = 0; floor < totalFloors; floor++) {
      final floorItems = roomsByFloor[floor] ?? [];
      final fixedItems = floorItems
          .where((i) => i['fixedPosition'] == true)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final dynamicItems = floorItems
          .where((i) => i['fixedPosition'] != true)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final needsCorridor = dynamicItems.length >= 6;
      if (needsCorridor) {
        final corridorWidthFt = 5.0;
        final corridorHeightFt = 22.0;
        final corridorW = corridorWidthFt * 8;
        final corridorX = startX + ((maxWidthPx - startX - corridorW) / 2);
        final corridorY = startY + 120;
        fixedItems.add({
          'name': 'Corridor',
          'customName': 'Corridor',
          'type': RoomType.other.name,
          'width': corridorWidthFt,
          'height': corridorHeightFt,
          'floor': floor,
          'x': corridorX,
          'y': corridorY,
          'fixedPosition': true,
          'isCorridor': true,
        });
      }

      final occupied = <Rect>[];
      final floorPlaced = <Map<String, dynamic>>[];
      for (final item in fixedItems) {
        final x = (item['x'] as num).toDouble();
        final y = (item['y'] as num).toDouble();
        final w = ((item['width'] as num).toDouble() * 8);
        final h = ((item['height'] as num).toDouble() * 8);
        occupied.add(Rect.fromLTWH(x, y, w, h));
        final placed = {
          'name': item['name'],
          'customName': item['customName'],
          'type': item['type'],
          'width': item['width'],
          'height': item['height'],
          'floor': item['floor'],
          'x': x,
          'y': y,
          'fixedPosition': true,
        };
        rooms.add(placed);
        floorPlaced.add(placed);
      }

      bool canPlace(
        double x,
        double y,
        double w,
        double h, {
        double clearance = walkwayGap,
      }) {
        if (x < startX || y < startY) return false;
        if (x + w > maxWidthPx || y + h > maxHeightPx) return false;
        final r = Rect.fromLTWH(x, y, w, h);
        final check = clearance > 0 ? r.inflate(clearance) : r;
        for (final o in occupied) {
          if (check.overlaps(o)) return false;
        }
        return true;
      }

      Map<String, dynamic>? placeExact(
        Map<String, dynamic> item,
        Offset point, {
        double snap = cell,
        double clearance = 0,
      }) {
        final w = ((item['width'] as num).toDouble() * 8);
        final h = ((item['height'] as num).toDouble() * 8);
        final sx = ((point.dx / snap).round() * snap).toDouble();
        final sy = ((point.dy / snap).round() * snap).toDouble();
        if (!canPlace(sx, sy, w, h, clearance: clearance)) return null;
        occupied.add(Rect.fromLTWH(sx, sy, w, h));
        final placed = {...item, 'x': sx, 'y': sy};
        rooms.add(placed);
        floorPlaced.add(placed);
        return placed;
      }

      Map<String, dynamic> place(
        Map<String, dynamic> item,
        List<Offset> preferred, {
        double snap = cell,
        double clearance = walkwayGap,
      }) {
        final w = ((item['width'] as num).toDouble() * 8);
        final h = ((item['height'] as num).toDouble() * 8);

        Offset snapPoint(Offset p) {
          final sx = ((p.dx / snap).round() * snap).toDouble();
          final sy = ((p.dy / snap).round() * snap).toDouble();
          return Offset(sx, sy);
        }

        for (final p in preferred) {
          final q = snapPoint(p);
          if (canPlace(q.dx, q.dy, w, h, clearance: clearance)) {
            occupied.add(Rect.fromLTWH(q.dx, q.dy, w, h));
            final placed = {...item, 'x': q.dx, 'y': q.dy};
            rooms.add(placed);
            floorPlaced.add(placed);
            return placed;
          }
        }

        Offset anchor() {
          if (occupied.isEmpty) return const Offset(startX, startY);
          double sx = 0;
          double sy = 0;
          for (final r in occupied) {
            sx += r.center.dx;
            sy += r.center.dy;
          }
          return Offset(sx / occupied.length, sy / occupied.length);
        }

        final a = anchor();
        double bestScore = double.infinity;
        Offset? bestPos;
        for (double y = startY; y <= maxHeightPx - h; y += cell) {
          for (double x = startX; x <= maxWidthPx - w; x += cell) {
            if (canPlace(x, y, w, h, clearance: clearance)) {
              final c = Offset(x + w / 2, y + h / 2);
              final score =
                  (c - a).distance +
                  ((y - startY).abs() * 0.35) +
                  ((x - startX).abs() * 0.08);
              if (score < bestScore) {
                bestScore = score;
                bestPos = Offset(x, y);
              }
            }
          }
        }

        if (bestPos != null) {
          occupied.add(Rect.fromLTWH(bestPos.dx, bestPos.dy, w, h));
          final placed = {...item, 'x': bestPos.dx, 'y': bestPos.dy};
          rooms.add(placed);
          floorPlaced.add(placed);
          return placed;
        }

        final fx = startX;
        final fy = startY;
        occupied.add(Rect.fromLTWH(fx, fy, w, h));
        final fallback = {...item, 'x': fx, 'y': fy};
        rooms.add(fallback);
        floorPlaced.add(fallback);
        return fallback;
      }

      ({Map<String, dynamic> primary, Map<String, dynamic> secondary})?
      placeAdjacentPair(
        Map<String, dynamic> primaryItem,
        Map<String, dynamic> secondaryItem, {
        required List<Offset> primaryPreferred,
        List<String> secondarySides = const ['right', 'left', 'bottom', 'top'],
        double gap = touchGap,
      }) {
        final pw = ((primaryItem['width'] as num).toDouble() * 8);
        final ph = ((primaryItem['height'] as num).toDouble() * 8);
        final sw = ((secondaryItem['width'] as num).toDouble() * 8);
        final sh = ((secondaryItem['height'] as num).toDouble() * 8);

        Offset snapPoint(Offset p) {
          final sx = ((p.dx / cell).round() * cell).toDouble();
          final sy = ((p.dy / cell).round() * cell).toDouble();
          return Offset(sx, sy);
        }

        ({double x, double y}) secondaryPos(String side, double px, double py) {
          switch (side) {
            case 'left':
              return (x: px - sw - gap, y: py + (ph - sh) / 2);
            case 'top':
              return (x: px + (pw - sw) / 2, y: py - sh - gap);
            case 'bottom':
              return (x: px + (pw - sw) / 2, y: py + ph + gap);
            case 'right':
            default:
              return (x: px + pw + gap, y: py + (ph - sh) / 2);
          }
        }

        bool tryPlace(double px, double py) {
          if (!canPlace(px, py, pw, ph, clearance: 0)) return false;
          final tempPrimary = Rect.fromLTWH(px, py, pw, ph);
          occupied.add(tempPrimary);

          for (final side in secondarySides) {
            final p = secondaryPos(side, px, py);
            if (canPlace(p.x, p.y, sw, sh, clearance: 0)) {
              occupied.removeLast();
              final primaryPlaced = {...primaryItem, 'x': px, 'y': py};
              final secondaryPlaced = {...secondaryItem, 'x': p.x, 'y': p.y};
              occupied.add(Rect.fromLTWH(px, py, pw, ph));
              occupied.add(Rect.fromLTWH(p.x, p.y, sw, sh));
              rooms.add(primaryPlaced);
              rooms.add(secondaryPlaced);
              floorPlaced.add(primaryPlaced);
              floorPlaced.add(secondaryPlaced);
              return true;
            }
          }

          occupied.removeLast();
          return false;
        }

        for (final p in primaryPreferred) {
          final q = snapPoint(p);
          if (tryPlace(q.dx, q.dy)) {
            final primaryPlaced = rooms[rooms.length - 2];
            final secondaryPlaced = rooms.last;
            return (primary: primaryPlaced, secondary: secondaryPlaced);
          }
        }

        for (double y = startY; y <= maxHeightPx - ph; y += cell) {
          for (double x = startX; x <= maxWidthPx - pw; x += cell) {
            if (tryPlace(x, y)) {
              final primaryPlaced = rooms[rooms.length - 2];
              final secondaryPlaced = rooms.last;
              return (primary: primaryPlaced, secondary: secondaryPlaced);
            }
          }
        }

        return null;
      }

      Map<String, dynamic>? popOne(String type) {
        final i = dynamicItems.indexWhere((e) => e['type'] == type);
        if (i < 0) return null;
        return dynamicItems.removeAt(i);
      }

      List<Map<String, dynamic>> popAll(String type) {
        final result = <Map<String, dynamic>>[];
        for (int i = dynamicItems.length - 1; i >= 0; i--) {
          if (dynamicItems[i]['type'] == type) {
            result.add(dynamicItems.removeAt(i));
          }
        }
        return result.reversed.toList();
      }

      double w(Map<String, dynamic> item) =>
          ((item['width'] as num).toDouble() * 8);
      double h(Map<String, dynamic> item) =>
          ((item['height'] as num).toDouble() * 8);
      Map<String, dynamic>? placeBalconyOutside(
        Map<String, dynamic> balcony,
        Map<String, dynamic> anchor, {
        List<String> sides = const ['top', 'right', 'left', 'bottom'],
      }) {
        final ax = (anchor['x'] as num).toDouble();
        final ay = (anchor['y'] as num).toDouble();
        final aw = w(anchor);
        final ah = h(anchor);

        for (final side in sides) {
          final b = Map<String, dynamic>.from(balcony);
          var bw = w(b);
          var bh = h(b);
          double bx;
          double by;

          if (side == 'top' || side == 'bottom') {
            // Keep attached part square/clean and clip extra unattached width.
            final attachedW = math.max(40.0, math.min(bw, aw - 4));
            b['width'] = attachedW / 8;
            bw = attachedW;
            bx = ax + (aw - bw) / 2;
            by = side == 'top' ? ay - bh - touchGap : ay + ah + touchGap;
          } else {
            // Clip extra unattached height on side-attached balconies.
            final attachedH = math.max(32.0, math.min(bh, ah - 4));
            b['height'] = attachedH / 8;
            bh = attachedH;
            bx = side == 'left' ? ax - bw - touchGap : ax + aw + touchGap;
            by = ay + (ah - bh) / 2;
          }

          final placed = placeExact(b, Offset(bx, by));
          if (placed != null) return placed;
        }

        return null;
      }

      final livingRaw = popOne(RoomType.living.name);
      Map<String, dynamic>? living;
      if (livingRaw != null) {
        final lw = w(livingRaw);
        living = place(livingRaw, [
          Offset(startX + ((maxWidthPx - startX - lw) / 2), startY + 90),
          Offset(startX + ((maxWidthPx - startX - lw) / 2), startY + 70),
        ]);
      }

      final diningRaw = popOne(RoomType.dining.name);
      final kitchenRaw = popOne(RoomType.kitchen.name);
      Map<String, dynamic>? dining;
      Map<String, dynamic>? kitchen;

      if (diningRaw != null && kitchenRaw != null) {
        final preferred = living != null
            ? [
                Offset(
                  (living['x'] as num).toDouble() - w(diningRaw) - touchGap,
                  (living['y'] as num).toDouble(),
                ),
                Offset(
                  (living['x'] as num).toDouble(),
                  (living['y'] as num).toDouble() - h(diningRaw) - touchGap,
                ),
                Offset(
                  (living['x'] as num).toDouble() + w(living) + touchGap,
                  (living['y'] as num).toDouble(),
                ),
              ]
            : [const Offset(startX + 40, startY + 60)];

        final pair = placeAdjacentPair(
          diningRaw,
          kitchenRaw,
          primaryPreferred: preferred,
          secondarySides: const ['right', 'left', 'bottom', 'top'],
        );
        if (pair != null) {
          dining = pair.primary;
          kitchen = pair.secondary;
        } else {
          dining = place(diningRaw, preferred);
          kitchen = place(kitchenRaw, [
            Offset(
              (dining['x'] as num).toDouble() + w(dining) + touchGap,
              (dining['y'] as num).toDouble(),
            ),
          ]);
        }
      } else if (diningRaw != null) {
        dining = place(diningRaw, [const Offset(startX, startY + 60)]);
      } else if (kitchenRaw != null) {
        kitchen = place(kitchenRaw, [const Offset(startX + 120, startY + 60)]);
      }

      final poojaRooms = popAll(RoomType.poojaRoom.name);
      for (int i = 0; i < poojaRooms.length; i++) {
        final p = poojaRooms[i];
        if (living != null) {
          place(p, [
            Offset(
              (living['x'] as num).toDouble() - w(p) - smallGap,
              (living['y'] as num).toDouble() - h(p) - smallGap - (i * 10),
            ),
            Offset(
              (living['x'] as num).toDouble() + w(living) + smallGap,
              (living['y'] as num).toDouble() - h(p) - smallGap - (i * 10),
            ),
          ]);
        } else {
          place(p, [Offset(startX + (i * 20), startY)]);
        }
      }

      final guestRooms = popAll(RoomType.guestRoom.name);
      for (int i = 0; i < guestRooms.length; i++) {
        final g = guestRooms[i];
        if (living != null) {
          place(g, [
            Offset(
              (living['x'] as num).toDouble() - w(g) - touchGap,
              (living['y'] as num).toDouble() + h(living) * 0.35 + (i * 10),
            ),
            Offset(
              (living['x'] as num).toDouble() + w(living) + touchGap,
              (living['y'] as num).toDouble() + h(living) * 0.35 + (i * 10),
            ),
          ]);
        } else {
          place(g, [Offset(startX, startY + 180 + (i * 20))]);
        }
      }

      final bedrooms = [
        ...popAll(RoomType.bedroom.name),
        ...popAll(RoomType.kidsRoom.name),
      ];
      final placedBedrooms = <Map<String, dynamic>>[];
      final bathrooms = popAll(RoomType.bathroom.name);
      final attachedTargetForFloor = math.min(
        attachedBathroomsRemaining,
        math.min(bedrooms.length, bathrooms.length),
      );
      int attachedUsedForFloor = 0;
      double privateX = startX;
      double privateY = living != null
          ? (living['y'] as num).toDouble() + h(living) + 10
          : startY + 160;
      double privateRowH = 0;

      for (final bed in bedrooms) {
        final bw = w(bed);
        final bh = h(bed);
        if (privateX + bw > maxWidthPx) {
          privateX = startX;
          privateY += privateRowH + 10;
          privateRowH = 0;
        }
        if (bathrooms.isNotEmpty &&
            attachedUsedForFloor < attachedTargetForFloor) {
          final bath = bathrooms.removeAt(0);
          final pair = placeAdjacentPair(
            bed,
            bath,
            primaryPreferred: [Offset(privateX, privateY)],
            secondarySides: const ['right', 'left', 'bottom', 'top'],
          );
          if (pair != null) {
            final placedBed = pair.primary;
            final placedBath = pair.secondary;
            placedBedrooms.add(placedBed);
            final pairRight = math.max(
              (placedBed['x'] as num).toDouble() + w(placedBed),
              (placedBath['x'] as num).toDouble() + w(placedBath),
            );
            privateX = pairRight + 8;
            privateRowH = math.max(
              privateRowH,
              math.max(h(placedBed), h(placedBath)),
            );
            attachedUsedForFloor += 1;
            continue;
          }
          bathrooms.insert(0, bath);
        }

        final placedBed = place(bed, [Offset(privateX, privateY)]);
        placedBedrooms.add(placedBed);
        privateX = (placedBed['x'] as num).toDouble() + bw + 8;
        privateRowH = math.max(privateRowH, bh);
      }

      attachedBathroomsRemaining -= attachedUsedForFloor;

      final studyOffice = [
        ...popAll(RoomType.studyRoom.name),
        ...popAll(RoomType.office.name),
      ];
      for (final s in studyOffice) {
        if (living != null) {
          place(s, [
            Offset(
              (living['x'] as num).toDouble() + w(living) + 8,
              (living['y'] as num).toDouble() + h(living) + 8,
            ),
            Offset(
              (living['x'] as num).toDouble() - w(s) - 8,
              (living['y'] as num).toDouble() + h(living) + 8,
            ),
          ]);
        } else {
          place(s, [Offset(startX + 60, privateY + privateRowH + 20)]);
        }
      }

      final serviceRooms = [
        ...popAll(RoomType.utility.name),
        ...popAll(RoomType.storeRoom.name),
      ];
      for (final s in serviceRooms) {
        if (kitchen != null) {
          place(s, [
            Offset(
              (kitchen['x'] as num).toDouble() + w(kitchen) + touchGap,
              (kitchen['y'] as num).toDouble(),
            ),
            Offset(
              (kitchen['x'] as num).toDouble(),
              (kitchen['y'] as num).toDouble() + h(kitchen) + touchGap,
            ),
          ]);
        } else {
          place(s, [Offset(startX + 180, startY + 210)]);
        }
      }

      for (final bath in bathrooms) {
        place(bath, [
          Offset(startX + 10, privateY + privateRowH + 8),
          Offset(startX + 130, privateY + privateRowH + 8),
        ]);
      }

      final balconies = popAll(RoomType.balcony.name);
      for (int i = 0; i < balconies.length; i++) {
        final b = balconies[i];
        Map<String, dynamic>? anchor = living;
        if (anchor == null && placedBedrooms.isNotEmpty) {
          anchor = placedBedrooms[i % placedBedrooms.length];
        }
        anchor ??= kitchen;
        anchor ??= dining;

        Map<String, dynamic>? placed;
        if (anchor != null) {
          placed = placeBalconyOutside(
            b,
            anchor,
            sides: living != null
                ? const ['top', 'right', 'left', 'bottom']
                : const ['right', 'top', 'left', 'bottom'],
          );
        }

        placed ??= place(b, [
          Offset(startX + 10 + (i * 20), startY + 8),
          Offset(maxWidthPx - w(b) - 10, startY + 8),
        ]);
      }

      for (final g in popAll(RoomType.garage.name)) {
        place(g, [Offset(startX, maxHeightPx - h(g) - 20)]);
      }

      while (dynamicItems.isNotEmpty) {
        place(dynamicItems.removeAt(0), [const Offset(startX, startY)]);
      }

      // Compact movable rooms to reduce random large empty gaps.
      Rect roomRect(Map<String, dynamic> r) {
        return Rect.fromLTWH(
          (r['x'] as num).toDouble(),
          (r['y'] as num).toDouble(),
          ((r['width'] as num).toDouble() * 8),
          ((r['height'] as num).toDouble() * 8),
        );
      }

      bool isLocked(Map<String, dynamic> r) {
        final name = (r['name'] ?? '').toString().toLowerCase();
        final custom = (r['customName'] ?? '').toString().toLowerCase();
        final type = (r['type'] ?? '').toString();
        return r['fixedPosition'] == true ||
            name.contains('corridor') ||
            custom.contains('corridor') ||
            type == RoomType.stairs.name ||
            type == RoomType.balcony.name;
      }

      bool hasCollision(Map<String, dynamic> room, Rect next) {
        if (next.left < startX || next.top < startY) return true;
        if (next.right > maxWidthPx || next.bottom > maxHeightPx) return true;
        for (final other in floorPlaced) {
          if (identical(room, other)) continue;
          if (next.overlaps(roomRect(other))) return true;
        }
        return false;
      }

      final movable = floorPlaced.where((r) => !isLocked(r)).toList()
        ..sort((a, b) {
          final ay = (a['y'] as num).toDouble();
          final by = (b['y'] as num).toDouble();
          if ((ay - by).abs() > 0.1) return ay.compareTo(by);
          final ax = (a['x'] as num).toDouble();
          final bx = (b['x'] as num).toDouble();
          return ax.compareTo(bx);
        });

      for (final r in movable) {
        var moved = true;
        while (moved) {
          moved = false;
          final current = roomRect(r);
          final up = current.shift(const Offset(0, -cell));
          if (!hasCollision(r, up)) {
            r['y'] = (r['y'] as num).toDouble() - cell;
            moved = true;
            continue;
          }
          final left = current.shift(const Offset(-cell, 0));
          if (!hasCollision(r, left)) {
            r['x'] = (r['x'] as num).toDouble() - cell;
            moved = true;
          }
        }
      }
    }

    return rooms;
  }

  List<Map<String, dynamic>> _buildAutoStructures(
    List<Map<String, dynamic>> rooms,
  ) {
    final structures = <Map<String, dynamic>>[];
    final roomsByFloor = <int, List<Map<String, dynamic>>>{};
    final sharedDoorPairs = <String>{};
    for (final r in rooms) {
      final f = (r['floor'] as num?)?.toInt() ?? 0;
      roomsByFloor.putIfAbsent(f, () => []);
      roomsByFloor[f]!.add(r);
    }

    Rect openingFootprint(Map<String, dynamic> s) {
      final x = (s['x'] as num).toDouble();
      final y = (s['y'] as num).toDouble();
      final w = (s['width'] as num).toDouble();
      final h = (s['height'] as num).toDouble();
      final r = ((s['rotation'] as num?)?.toDouble() ?? 0).abs();
      final center = Offset(x + w / 2, y + h / 2);
      final vertical = (r % math.pi - math.pi / 2).abs() < 0.2;
      final fw = vertical ? h : w;
      final fh = vertical ? w : h;
      return Rect.fromCenter(center: center, width: fw, height: fh);
    }

    bool openingOverlaps(Map<String, dynamic> a, Map<String, dynamic> b) {
      return openingFootprint(
        a,
      ).inflate(1.5).overlaps(openingFootprint(b).inflate(1.5));
    }

    bool canAddOpening(Map<String, dynamic> candidate) {
      final floor = (candidate['floor'] as num?)?.toInt() ?? 0;
      final type = (candidate['type'] ?? '').toString();
      for (final s in structures) {
        if ((s['floor'] as num?)?.toInt() != floor) continue;
        final st = (s['type'] ?? '').toString();
        if (st != 'door' && st != 'window') continue;
        if (!openingOverlaps(s, candidate)) continue;
        if (type == 'window') return false;
        if (type == 'door' && st == 'door') return false;
      }
      return true;
    }

    void removeOverlappingWindowsForDoor(Map<String, dynamic> door) {
      final floor = (door['floor'] as num?)?.toInt() ?? 0;
      structures.removeWhere((s) {
        if ((s['floor'] as num?)?.toInt() != floor) return false;
        if ((s['type'] ?? '').toString() != 'window') return false;
        return openingOverlaps(s, door);
      });
    }

    Map<String, dynamic>? addOnWall({
      required String type,
      required String side,
      required double roomX,
      required double roomY,
      required double roomW,
      required double roomH,
      required int floor,
      required double length,
      double thickness = 6.0,
      double align = 0.5,
    }) {
      final clampedAlign = align.clamp(0.18, 0.82).toDouble();
      late final Map<String, dynamic> candidate;
      if (side == 'left' || side == 'right') {
        final minCy = roomY + 10;
        final maxCy = roomY + roomH - 10;
        final cy = (roomY + roomH * clampedAlign).clamp(minCy, maxCy);
        final wallX = side == 'left' ? roomX : roomX + roomW;
        candidate = {
          'type': type,
          'x': wallX - length / 2,
          'y': cy - thickness / 2,
          'width': length,
          'height': thickness,
          'rotation': math.pi / 2,
          'floor': floor,
        };
      } else {
        final minCx = roomX + 10;
        final maxCx = roomX + roomW - 10;
        final cx = (roomX + roomW * clampedAlign).clamp(minCx, maxCx);
        final wallY = side == 'top' ? roomY : roomY + roomH;
        candidate = {
          'type': type,
          'x': cx - length / 2,
          'y': wallY - thickness / 2,
          'width': length,
          'height': thickness,
          'rotation': 0.0,
          'floor': floor,
        };
      }

      if (!canAddOpening(candidate)) {
        return null;
      }

      if (type == 'door') {
        removeOverlappingWindowsForDoor(candidate);
      }

      structures.add(candidate);
      return candidate;
    }

    bool isDuplicateDoor(Map<String, dynamic> door) {
      final floor = (door['floor'] as num?)?.toInt() ?? 0;
      final x = (door['x'] as num).toDouble();
      final y = (door['y'] as num).toDouble();
      final w = (door['width'] as num).toDouble();
      final h = (door['height'] as num).toDouble();
      final r = (door['rotation'] as num?)?.toDouble() ?? 0;
      final c = Offset(x + w / 2, y + h / 2);

      for (final s in structures) {
        if (s['type'] != 'door') continue;
        if (identical(s, door)) continue;
        if ((s['floor'] as num?)?.toInt() != floor) continue;
        final sx = (s['x'] as num).toDouble();
        final sy = (s['y'] as num).toDouble();
        final sw = (s['width'] as num).toDouble();
        final sh = (s['height'] as num).toDouble();
        final sr = (s['rotation'] as num?)?.toDouble() ?? 0;
        final sc = Offset(sx + sw / 2, sy + sh / 2);
        final sameRotation = (sr - r).abs() < 0.15;
        if (sameRotation && (sc - c).distance < 10) {
          return true;
        }
      }
      return false;
    }

    Offset centerOf(Map<String, dynamic> room) {
      final x = (room['x'] as num).toDouble();
      final y = (room['y'] as num).toDouble();
      final w = ((room['width'] as num).toDouble() * 8);
      final h = ((room['height'] as num).toDouble() * 8);
      return Offset(x + w / 2, y + h / 2);
    }

    Map<String, dynamic>? nearestOfTypes(
      Map<String, dynamic> room,
      List<String> types,
    ) {
      final floor = (room['floor'] as num).toInt();
      final sourceCenter = centerOf(room);
      Map<String, dynamic>? best;
      double bestDist = double.infinity;

      for (final candidate in roomsByFloor[floor] ?? const []) {
        if (identical(candidate, room)) continue;
        final t = (candidate['type'] ?? '').toString();
        if (!types.contains(t)) continue;
        final dist = (sourceCenter - centerOf(candidate)).distance;
        if (dist < bestDist) {
          bestDist = dist;
          best = candidate;
        }
      }
      return best;
    }

    ({String side, double align}) sideToward(
      Map<String, dynamic> room,
      Map<String, dynamic>? target,
    ) {
      final x = (room['x'] as num).toDouble();
      final y = (room['y'] as num).toDouble();
      final roomW = ((room['width'] as num).toDouble() * 8);
      final roomH = ((room['height'] as num).toDouble() * 8);

      if (target == null) {
        return (side: 'bottom', align: 0.5);
      }

      final c1 = centerOf(room);
      final c2 = centerOf(target);
      final dx = c2.dx - c1.dx;
      final dy = c2.dy - c1.dy;

      if (dx.abs() >= dy.abs()) {
        final side = dx >= 0 ? 'right' : 'left';
        final align = ((c2.dy - y) / roomH).clamp(0.2, 0.8).toDouble();
        return (side: side, align: align);
      } else {
        final side = dy >= 0 ? 'bottom' : 'top';
        final align = ((c2.dx - x) / roomW).clamp(0.2, 0.8).toDouble();
        return (side: side, align: align);
      }
    }

    ({String side, double align})? sharedWallPlacement(
      Map<String, dynamic> room,
      Map<String, dynamic> target,
    ) {
      final rx = (room['x'] as num).toDouble();
      final ry = (room['y'] as num).toDouble();
      final rw = ((room['width'] as num).toDouble() * 8);
      final rh = ((room['height'] as num).toDouble() * 8);
      final tx = (target['x'] as num).toDouble();
      final ty = (target['y'] as num).toDouble();
      final tw = ((target['width'] as num).toDouble() * 8);
      final th = ((target['height'] as num).toDouble() * 8);

      const tol = 0.1;

      final rightTouch = (rx + rw - tx).abs() <= tol;
      final leftTouch = (rx - (tx + tw)).abs() <= tol;
      final bottomTouch = (ry + rh - ty).abs() <= tol;
      final topTouch = (ry - (ty + th)).abs() <= tol;

      if (rightTouch || leftTouch) {
        final overlapTop = math.max(ry, ty);
        final overlapBottom = math.min(ry + rh, ty + th);
        if (overlapBottom - overlapTop > 10) {
          final mid = (overlapTop + overlapBottom) / 2;
          final align = ((mid - ry) / rh).clamp(0.2, 0.8).toDouble();
          return (side: rightTouch ? 'right' : 'left', align: align);
        }
      }

      if (bottomTouch || topTouch) {
        final overlapLeft = math.max(rx, tx);
        final overlapRight = math.min(rx + rw, tx + tw);
        if (overlapRight - overlapLeft > 10) {
          final mid = (overlapLeft + overlapRight) / 2;
          final align = ((mid - rx) / rw).clamp(0.2, 0.8).toDouble();
          return (side: bottomTouch ? 'bottom' : 'top', align: align);
        }
      }

      return null;
    }

    for (final room in rooms) {
      final floor = (room['floor'] as num).toInt();
      final x = (room['x'] as num).toDouble();
      final y = (room['y'] as num).toDouble();
      final roomType = (room['type'] ?? '').toString().toLowerCase();
      final roomName = (room['name'] ?? '').toString().toLowerCase();
      final customName = (room['customName'] ?? '').toString().toLowerCase();
      final roomW = ((room['width'] as num).toDouble() * 8);
      final roomH = ((room['height'] as num).toDouble() * 8);
      if (roomW < 24 || roomH < 24) {
        continue;
      }

      final isStairs = roomType.contains('stairs');
      final isCorridor =
          roomName.contains('corridor') || customName.contains('corridor');
      final isBathroom = roomType.contains('bathroom');
      final isUtility = roomType.contains('utility');
      final isStore = roomType.contains('store');
      final isBalcony = roomType.contains('balcony');
      final isKitchen = roomType.contains('kitchen');
      final isLiving = roomType.contains('living');
      final isBedroom =
          roomType.contains('bedroom') ||
          roomType.contains('guest') ||
          roomType.contains('kids');
      final isStudy = roomType.contains('study') || roomType.contains('office');

      if (!isStairs && !isCorridor) {
        Map<String, dynamic>? target;
        if (isBedroom) {
          target = nearestOfTypes(room, [
            RoomType.bathroom.name,
            RoomType.living.name,
          ]);
        } else if (isBathroom) {
          target = nearestOfTypes(room, [
            RoomType.bedroom.name,
            RoomType.kidsRoom.name,
            RoomType.guestRoom.name,
            RoomType.living.name,
          ]);
        } else if (isKitchen) {
          target = nearestOfTypes(room, [
            RoomType.dining.name,
            RoomType.living.name,
          ]);
        } else if (roomType.contains('dining')) {
          target = nearestOfTypes(room, [
            RoomType.kitchen.name,
            RoomType.living.name,
          ]);
        } else if (roomType.contains('pooja')) {
          target = nearestOfTypes(room, [RoomType.living.name]);
        } else if (isStudy) {
          target = nearestOfTypes(room, [
            RoomType.living.name,
            RoomType.bedroom.name,
          ]);
        } else if (isUtility || isStore) {
          target = nearestOfTypes(room, [
            RoomType.kitchen.name,
            RoomType.dining.name,
          ]);
        } else if (isBalcony) {
          target = nearestOfTypes(room, [
            RoomType.living.name,
            RoomType.bedroom.name,
          ]);
        } else if (roomType.contains('living')) {
          target = nearestOfTypes(room, [
            RoomType.dining.name,
            RoomType.kitchen.name,
            RoomType.guestRoom.name,
            RoomType.bedroom.name,
          ]);
        }

        final placement = target != null
            ? (sharedWallPlacement(room, target) ?? sideToward(room, target))
            : sideToward(room, target);
        final doorSide = placement.side;
        final doorAlign = placement.align;
        final doorWallLength = (doorSide == 'left' || doorSide == 'right')
            ? roomH
            : roomW;
        final doorLength = (doorWallLength * 0.30).clamp(14.0, 42.0).toDouble();
        final roomIndex = rooms.indexOf(room);
        final targetIndex = target == null ? -1 : rooms.indexOf(target);
        final onSharedWall =
            target != null &&
            sharedWallPlacement(room, target) != null &&
            roomIndex >= 0 &&
            targetIndex >= 0;

        if (onSharedWall) {
          final a = math.min(roomIndex, targetIndex);
          final b = math.max(roomIndex, targetIndex);
          final pairKey = '$floor-$a-$b';
          if (!sharedDoorPairs.contains(pairKey)) {
            final created = addOnWall(
              type: 'door',
              side: doorSide,
              roomX: x,
              roomY: y,
              roomW: roomW,
              roomH: roomH,
              floor: floor,
              length: doorLength,
              align: doorAlign,
            );
            if (created != null && !isDuplicateDoor(created)) {
              sharedDoorPairs.add(pairKey);
            } else if (created != null) {
              structures.removeLast();
            }
          }
        } else {
          final created = addOnWall(
            type: 'door',
            side: doorSide,
            roomX: x,
            roomY: y,
            roomW: roomW,
            roomH: roomH,
            floor: floor,
            length: doorLength,
            align: doorAlign,
          );
          if (created != null && isDuplicateDoor(created)) {
            structures.removeLast();
          }
        }
      }

      final allowWindow = !isBathroom && !isStairs && !isStore && !isCorridor;
      if (allowWindow) {
        final biggestSide = math.max(roomW, roomH);
        int windowCount = 1;
        if ((isLiving || isBedroom) && biggestSide >= 96) {
          windowCount = 2;
        }
        if (isUtility || roomW < 48 || roomH < 48) {
          windowCount = 1;
        }

        final preferredSides = <String>[
          if (isLiving) 'top',
          if (isBedroom) 'right',
          if (isKitchen) 'top',
          if (isStudy) 'right',
          if (isBalcony) 'top',
          'right',
          'top',
          'left',
        ];

        final usedSides = <String>{};
        for (int i = 0; i < windowCount; i++) {
          String side = preferredSides.firstWhere(
            (s) => !usedSides.contains(s),
            orElse: () => preferredSides[i % preferredSides.length],
          );
          usedSides.add(side);

          final wallLength = (side == 'left' || side == 'right')
              ? roomH
              : roomW;
          final windowLength = (wallLength * 0.28).clamp(14.0, 38.0).toDouble();
          final align = windowCount == 1 ? 0.5 : (i == 0 ? 0.3 : 0.7);

          addOnWall(
            type: 'window',
            side: side,
            roomX: x,
            roomY: y,
            roomW: roomW,
            roomH: roomH,
            floor: floor,
            length: windowLength,
            align: align,
          );
        }
      }

      final allowPillar =
          !isBathroom &&
          !isUtility &&
          !isStore &&
          !isBalcony &&
          !isStairs &&
          !isCorridor;
      if (allowPillar && roomW * roomH >= 9000) {
        const pillarSize = 16.0;
        structures.add({
          'type': 'pillar',
          'x': x + (roomW - pillarSize) / 2,
          'y': y + (roomH - pillarSize) / 2,
          'width': pillarSize,
          'height': pillarSize,
          'rotation': 0.0,
          'floor': floor,
        });
      }
    }

    return structures;
  }

  Widget _countField(RoomType type) {
    return TextField(
      controller: _countCtrls[type],
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: '${type.label} Count'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Plan Designer'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Step 1: How many floors do you want?'),
              const SizedBox(height: 6),
              TextField(
                controller: _floorsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Floors',
                  hintText: 'Example: 3',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _balconyPerFloorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Balcony Count Per Floor (G,1st,2nd...)',
                  hintText: 'Example: 1,0,2',
                ),
              ),
              const SizedBox(height: 14),
              const Text('Step 2: Enter quantity for each room type'),
              const SizedBox(height: 8),
              _countField(RoomType.bedroom),
              const SizedBox(height: 8),
              _countField(RoomType.bathroom),
              const SizedBox(height: 8),
              TextField(
                controller: _attachedBathCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Attached Bathrooms (with bedrooms)',
                ),
              ),
              const SizedBox(height: 8),
              _countField(RoomType.kitchen),
              const SizedBox(height: 8),
              _countField(RoomType.living),
              const SizedBox(height: 8),
              _countField(RoomType.dining),
              const SizedBox(height: 8),
              _countField(RoomType.guestRoom),
              const SizedBox(height: 8),
              _countField(RoomType.kidsRoom),
              const SizedBox(height: 8),
              _countField(RoomType.studyRoom),
              const SizedBox(height: 8),
              _countField(RoomType.office),
              const SizedBox(height: 8),
              _countField(RoomType.poojaRoom),
              const SizedBox(height: 8),
              _countField(RoomType.utility),
              const SizedBox(height: 8),
              _countField(RoomType.storeRoom),
              const SizedBox(height: 8),
              _countField(RoomType.stairs),
              const SizedBox(height: 8),
              _countField(RoomType.balcony),
              const SizedBox(height: 8),
              _countField(RoomType.garage),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => setState(_applyRecommendedCounts),
          child: const Text('Recommended Plan'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final totalFloors = (int.tryParse(_floorsCtrl.text.trim()) ?? 1)
                .clamp(1, 15);
            final rooms = _buildRooms(totalFloors);
            final structures = _buildAutoStructures(rooms);
            Navigator.pop(context, {
              'floors': totalFloors,
              'rooms': rooms,
              'structures': structures,
            });
          },
          child: const Text('Create Auto Plan'),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.darkMode,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool darkMode;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bg = highlighted
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C2A3B), Color(0xFF2A3C53)],
          )
        : LinearGradient(
            colors: darkMode
                ? const [Color(0xFF15202D), Color(0xFF1D2A3A)]
                : const [Color(0xFFFFFFFF), Color(0xFFF9F4E9)],
          );

    final titleColor = highlighted
        ? Colors.white
        : (darkMode ? const Color(0xFFE7EEF9) : const Color(0xFF172334));
    final subtitleColor = highlighted
        ? Colors.white.withValues(alpha: 0.82)
        : (darkMode ? const Color(0xFFBFCADA) : const Color(0xFF47515F));

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? const Color(0xFFD7B56D)
                : (darkMode
                      ? const Color(0xFF4B3C28)
                      : const Color(0xFFDCC8A6)),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: darkMode
                  ? Colors.black.withValues(alpha: 0.34)
                  : const Color(0xFF6D5835).withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: highlighted
                    ? const Color(0xFFD7B56D)
                    : (darkMode
                          ? const Color(0xFF243347)
                          : const Color(0xFF1D2A3C)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: highlighted ? const Color(0xFF1B150A) : Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: subtitleColor, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: highlighted
                  ? const Color(0xFFE7C887)
                  : (darkMode
                        ? const Color(0xFF9BB2CD)
                        : const Color(0xFF2A3A4D)),
            ),
          ],
        ),
      ),
    );
  }
}
