import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/room_model.dart';
import '../services/api_service.dart';
import '../services/session_storage.dart';
import '../widgets/input_landing_cards.dart';

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
    final persistSession = (result['persistSession'] as bool?) ?? true;

    if (token.isEmpty) return;

    if (persistSession) {
      await SessionStorage.saveSession(token: token, user: user);
    } else {
      await SessionStorage.clearSession();
    }
    if (!mounted) return;

    setState(() {
      _authToken = token;
      _authUser = user;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          persistSession
              ? 'Logged in as ${(user['email'] ?? user['name'] ?? 'User').toString()}'
              : 'Logged in for this session only',
        ),
      ),
    );

    await _showPlansAfterLogin(token);
  }

  Future<Map<String, dynamic>?> _pickCloudPlan(
    List<Map<String, dynamic>> layouts,
  ) {
    final media = MediaQuery.of(context);
    final dialogWidth = math.min(520.0, media.size.width - 48);
    final listHeight = math.min(420.0, media.size.height * 0.56);
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('My Plans'),
        content: SizedBox(
          width: dialogWidth,
          child: layouts.isEmpty
              ? const Text('No cloud plans found.')
              : SizedBox(
                  height: listHeight,
                  child: ListView.separated(
                    itemCount: layouts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = layouts[index];
                      final id = (item['id'] as num?)?.toInt() ?? 0;
                      final name = (item['name'] ?? 'Untitled Plan').toString();
                      final updatedAt = (item['updatedAt'] ?? '')
                          .toString()
                          .replaceFirst('T', ' ')
                          .replaceFirst('Z', '');

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            if (updatedAt.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Updated: $updatedAt',
                                style: const TextStyle(fontSize: 12.2),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(context, {
                                    'id': id,
                                    'name': name,
                                    'open3d': false,
                                  }),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Open 2D'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: () => Navigator.pop(context, {
                                    'id': id,
                                    'name': name,
                                    'open3d': true,
                                  }),
                                  icon: const Icon(
                                    Icons.threed_rotation,
                                    size: 16,
                                  ),
                                  label: const Text('Open 3D'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlansAfterLogin(String token) async {
    try {
      final layouts = await ApiService.fetchLayouts(token: token);
      if (!mounted || layouts.isEmpty) {
        return;
      }

      final picked = await _pickCloudPlan(layouts);
      if (!mounted || picked == null) return;

      final selectedId = (picked['id'] as num?)?.toInt();
      if (selectedId == null || selectedId <= 0) return;

      final open3d = picked['open3d'] == true;
      final payload = await ApiService.fetchLayoutById(
        selectedId,
        token: token,
      );
      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/result',
        arguments: {
          'floors': (payload['floors'] as num?)?.toInt() ?? 1,
          'rooms': payload['rooms'] as List<dynamic>? ?? const [],
          'structures': payload['structures'] as List<dynamic>? ?? const [],
          'open3d': open3d,
          'layoutId': selectedId,
          'layoutName': (payload['name'] ?? picked['name'] ?? 'Untitled')
              .toString(),
        },
      );
    } catch (_) {
      // Silent fallback: login should still succeed even if cloud is unreachable.
    }
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
        title: const Text('RoyalNest Planner'),
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
                PopupMenuItem(value: 'login', child: Text('Sign In')),
                PopupMenuItem(value: 'register', child: Text('Sign Up')),
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
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                PlannerHeroCard(
                  darkMode: isDark,
                  connected: _authToken != null,
                ),
                const SizedBox(height: 16),
                if (_authToken == null)
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0.96, end: 1),
                    builder: (_, value, child) => Opacity(
                      opacity: value.clamp(0, 1),
                      child: Transform.scale(scale: value, child: child),
                    ),
                    child: AuthAccessCard(
                      darkMode: isDark,
                      loading: !_sessionReady,
                      onSignIn: () => _openAuthDialog(registerMode: false),
                      onSignUp: () => _openAuthDialog(registerMode: true),
                    ),
                  )
                else
                  PlannerStatusCard(
                    darkMode: isDark,
                    connected: true,
                    userLabel: userLabel,
                  ),
                const SizedBox(height: 18),
                Text(
                  'Start here',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFF0E3C8)
                        : const Color(0xFF1E2A38),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a mode and begin.',
                  style: TextStyle(
                    fontSize: 12.8,
                    height: 1.35,
                    color: isDark
                        ? const Color(0xFFB7C5D8)
                        : const Color(0xFF5B6878),
                  ),
                ),
                const SizedBox(height: 14),
                PlannerActionCard(
                  icon: Icons.edit_square,
                  title: 'Blank Canvas',
                  subtitle: 'Draw it your way.',
                  tag: 'MANUAL',
                  darkMode: isDark,
                  points: const ['Free edit', '1 floor', 'Custom'],
                  onTap: () => _openEditor({
                    'floors': 1,
                    'rooms': <Map<String, dynamic>>[],
                  }),
                ),
                const SizedBox(height: 12),
                PlannerActionCard(
                  icon: Icons.auto_awesome,
                  title: 'Auto Planner',
                  subtitle: 'Get a quick draft.',
                  tag: 'SMART',
                  darkMode: isDark,
                  points: const ['3 steps', 'Fast draft', 'Easy start'],
                  onTap: _openCustomPlanner,
                  highlighted: true,
                ),
                const SizedBox(height: 14),
                PlannerFeatureDeck(darkMode: isDark),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyApiError(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(raw);
  if (match != null) {
    return match.group(1)!;
  }

  final lower = raw.toLowerCase();
  if (lower.contains('request timed out at http://10.0.2.2:8000/api') ||
      lower.contains('cannot connect to server at http://10.0.2.2:8000/api')) {
    return 'Backend not reachable. If this is a real Android phone, run the app with API_LAN_BASE_URL pointing to your PC backend.';
  }
  if (lower.contains('request timed out') || lower.contains('cannot connect')) {
    return 'Backend not reachable. Start the backend server and check the API URL.';
  }

  return raw;
}

bool _isValidEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

class _AuthDialog extends StatefulWidget {
  const _AuthDialog({required this.registerMode});

  final bool registerMode;

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  late bool _registerMode;
  bool _rememberMe = true;
  bool _acceptTerms = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _registerMode = widget.registerMode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _switchMode(bool registerMode) {
    if (_registerMode == registerMode) return;
    setState(() {
      _registerMode = registerMode;
      _error = null;
      _info = null;
    });
  }

  Future<void> _openForgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(initialEmail: _emailCtrl.text),
    );

    if (!mounted || email == null) return;

    setState(() {
      _registerMode = false;
      _emailCtrl.text = email;
      _passwordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _error = null;
      _info = 'Password reset complete. Please sign in.';
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_registerMode && !_acceptTerms) {
      setState(() => _error = 'Please accept terms to create your account.');
      return;
    }

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      final response = _registerMode
          ? await ApiService.register(
              name: name,
              email: email,
              password: password,
            )
          : await ApiService.login(email: email, password: password);

      if (!mounted) return;
      Navigator.pop(context, {
        'token': response['token'],
        'user': response['user'],
        'persistSession': _registerMode ? true : _rememberMe,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyApiError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _registerMode ? 'Create Account' : 'Sign In';
    final media = MediaQuery.of(context);
    final dialogWidth = math.min(430.0, media.size.width - 48);
    final maxContentHeight = math.max(
      260.0,
      math.min(620.0, media.size.height - media.viewInsets.bottom - 170),
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Access'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _switchMode(false),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !_registerMode
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.14)
                        : null,
                  ),
                  child: const Text('Sign In'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _switchMode(true),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _registerMode
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.14)
                        : null,
                  ),
                  child: const Text('Sign Up'),
                ),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: Form(
            key: _formKey,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_registerMode) ...[
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                        ),
                        validator: (value) {
                          final name = (value ?? '').trim();
                          if (name.isEmpty) return 'Name is required';
                          if (name.length < 2) return 'Name is too short';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                      ),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) return 'Email is required';
                        if (!_isValidEmail(email)) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: _registerMode
                          ? TextInputAction.next
                          : TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: _registerMode
                            ? 'Create Password'
                            : 'Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Password is required';
                        }
                        if ((value ?? '').length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (_registerMode) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Please confirm password';
                          }
                          if (value != _passwordCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_registerMode)
                      CheckboxListTile(
                        value: _acceptTerms,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: _loading
                            ? null
                            : (value) =>
                                  setState(() => _acceptTerms = value ?? false),
                        title: const Text(
                          'I agree to create an account with these details',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      )
                    else ...[
                      CheckboxListTile(
                        value: _rememberMe,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: _loading
                            ? null
                            : (value) =>
                                  setState(() => _rememberMe = value ?? true),
                        title: const Text(
                          'Remember me on this device',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _openForgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _info!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
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

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl = TextEditingController(
    text: widget.initialEmail.trim(),
  );
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _loading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;
  String? _info;
  String? _resetToken;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      final result = await ApiService.sendForgotPasswordOtp(
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otpVerified = false;
        _resetToken = null;
        _otpCtrl.clear();
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
        _info = (result['message'] ?? 'OTP sent. Check your email.').toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyApiError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      final result = await ApiService.verifyForgotPasswordOtp(
        email: _emailCtrl.text.trim(),
        otp: _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _otpVerified = true;
        _resetToken = (result['resetToken'] ?? '').toString();
        _info = (result['message'] ?? 'OTP verified. Set a new password.')
            .toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyApiError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (_resetToken == null) {
      setState(() => _error = 'Verify OTP first');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      await ApiService.resetForgotPassword(
        email: _emailCtrl.text.trim(),
        resetToken: _resetToken!,
        newPassword: _newPasswordCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, _emailCtrl.text.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyApiError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _resetFlow() {
    setState(() {
      _otpSent = false;
      _otpVerified = false;
      _resetToken = null;
      _error = null;
      _info = null;
      _otpCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogWidth = math.min(430.0, media.size.width - 48);
    final maxContentHeight = math.max(
      240.0,
      math.min(560.0, media.size.height - media.viewInsets.bottom - 170),
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      title: const Text('Forgot Password'),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: Form(
            key: _formKey,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'First verify your email, then set a new password',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailCtrl,
                      readOnly: _otpSent,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: _otpSent
                          ? TextInputAction.next
                          : TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                      ),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) return 'Email is required';
                        if (!_isValidEmail(email)) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _otpCtrl,
                        readOnly: _otpVerified,
                        keyboardType: TextInputType.number,
                        textInputAction: _otpVerified
                            ? TextInputAction.next
                            : TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Email OTP',
                          hintText: 'Enter 6-digit code',
                        ),
                        validator: (value) {
                          if (!_otpSent) return null;
                          final otp = (value ?? '').trim();
                          if (otp.isEmpty) return 'OTP is required';
                          if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                            return 'Enter a valid 6-digit OTP';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_otpVerified) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _newPasswordCtrl,
                        obscureText: _obscureNewPassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () =>
                                  _obscureNewPassword = !_obscureNewPassword,
                            ),
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (!_otpVerified) return null;
                          if ((value ?? '').isEmpty) {
                            return 'New password is required';
                          }
                          if ((value ?? '').length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (!_otpVerified) return null;
                          if ((value ?? '').isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _newPasswordCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _info!,
                        style: const TextStyle(
                          color: Color(0xFF0A7A3E),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_otpSent)
          TextButton(
            onPressed: _loading ? null : _resetFlow,
            child: const Text('Start Over'),
          ),
        ElevatedButton(
          onPressed: _loading
              ? null
              : (_otpVerified
                    ? _resetPassword
                    : (_otpSent ? _verifyOtp : _sendOtp)),
          child: Text(
            _loading
                ? 'Please wait...'
                : (_otpVerified
                      ? 'Update Password'
                      : (_otpSent ? 'Verify OTP' : 'Send OTP')),
          ),
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

  int get _primaryBedroomCount =>
      _countOf(RoomType.bedroom) +
      _countOf(RoomType.guestRoom) +
      _countOf(RoomType.kidsRoom);

  String? _templateKindFor(int totalFloors) {
    if (totalFloors != 1) return null;

    if (_countOf(RoomType.living) == 1 &&
        _countOf(RoomType.kitchen) == 1 &&
        _countOf(RoomType.bathroom) == 1 &&
        _primaryBedroomCount == 1 &&
        _countOf(RoomType.dining) == 0 &&
        _countOf(RoomType.studyRoom) == 0 &&
        _countOf(RoomType.office) == 0 &&
        _countOf(RoomType.poojaRoom) == 0 &&
        _countOf(RoomType.utility) == 0 &&
        _countOf(RoomType.storeRoom) == 0 &&
        _countOf(RoomType.garage) == 0 &&
        _countOf(RoomType.stairs) == 0 &&
        _countOf(RoomType.balcony) == 0) {
      return '1bhk';
    }

    if (_countOf(RoomType.living) == 1 &&
        _countOf(RoomType.kitchen) == 1 &&
        _countOf(RoomType.bathroom) == 1 &&
        _primaryBedroomCount == 2 &&
        _countOf(RoomType.dining) == 0 &&
        _countOf(RoomType.studyRoom) == 0 &&
        _countOf(RoomType.office) == 0 &&
        _countOf(RoomType.poojaRoom) == 0 &&
        _countOf(RoomType.utility) == 0 &&
        _countOf(RoomType.storeRoom) == 0 &&
        _countOf(RoomType.garage) == 0 &&
        _countOf(RoomType.stairs) == 0 &&
        _countOf(RoomType.balcony) == 0) {
      return '2bhk';
    }

    if (_countOf(RoomType.living) == 1 &&
        _countOf(RoomType.kitchen) == 1 &&
        _countOf(RoomType.bathroom) == 2 &&
        _primaryBedroomCount == 3 &&
        _countOf(RoomType.dining) == 0 &&
        _countOf(RoomType.studyRoom) == 0 &&
        _countOf(RoomType.office) == 0 &&
        _countOf(RoomType.poojaRoom) == 0 &&
        _countOf(RoomType.utility) == 0 &&
        _countOf(RoomType.storeRoom) == 0 &&
        _countOf(RoomType.garage) == 0 &&
        _countOf(RoomType.stairs) == 0 &&
        _countOf(RoomType.balcony) == 0) {
      return '3bhk';
    }

    if (_countOf(RoomType.living) == 1 &&
        _countOf(RoomType.kitchen) == 1 &&
        _countOf(RoomType.bathroom) == 2 &&
        _primaryBedroomCount == 4 &&
        _countOf(RoomType.utility) == 1 &&
        _countOf(RoomType.dining) == 0 &&
        _countOf(RoomType.studyRoom) == 0 &&
        _countOf(RoomType.office) == 0 &&
        _countOf(RoomType.poojaRoom) == 0 &&
        _countOf(RoomType.storeRoom) == 0 &&
        _countOf(RoomType.garage) == 0 &&
        _countOf(RoomType.stairs) == 0 &&
        _countOf(RoomType.balcony) == 0) {
      return '4bhk';
    }

    return null;
  }

  Map<String, dynamic>? _buildPercentTemplatePlan(int totalFloors) {
    final kind = _templateKindFor(totalFloors);
    if (kind == null) return null;

    const canvasX = 20.0;
    const canvasY = 20.0;
    const canvasWidth = 320.0;
    const canvasHeight = 600.0;

    Rect rectPct(double x, double y, double w, double h) {
      return Rect.fromLTWH(
        canvasX + (x / 100) * canvasWidth,
        canvasY + (y / 100) * canvasHeight,
        (w / 100) * canvasWidth,
        (h / 100) * canvasHeight,
      );
    }

    Map<String, dynamic> roomFromPct({
      required String name,
      required RoomType type,
      required double x,
      required double y,
      required double w,
      required double h,
    }) {
      final rect = rectPct(x, y, w, h);
      return {
        'name': name,
        'type': type.name,
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
        'floor': 0,
      };
    }

    Map<String, dynamic> structureFromPct({
      required String type,
      required double x,
      required double y,
      required double w,
      required double h,
      double rotation = 0,
    }) {
      final rect = rectPct(x, y, w, h);
      return {
        'type': type,
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
        'rotation': rotation,
        'floor': 0,
      };
    }

    late final List<Map<String, dynamic>> rooms;
    late final List<Map<String, dynamic>> structures;

    switch (kind) {
      case '1bhk':
        rooms = [
          roomFromPct(
            name: 'Living Room',
            type: RoomType.living,
            x: 0,
            y: 0,
            w: 55,
            h: 45,
          ),
          roomFromPct(
            name: 'Kitchen',
            type: RoomType.kitchen,
            x: 55,
            y: 0,
            w: 45,
            h: 45,
          ),
          roomFromPct(
            name: 'Bedroom',
            type: RoomType.bedroom,
            x: 0,
            y: 45,
            w: 55,
            h: 40,
          ),
          roomFromPct(
            name: 'Bathroom',
            type: RoomType.bathroom,
            x: 55,
            y: 45,
            w: 45,
            h: 40,
          ),
        ];
        structures = [
          structureFromPct(type: 'door', x: 44, y: 88, w: 12, h: 6),
          structureFromPct(type: 'window', x: 10, y: 0, w: 10, h: 2),
          structureFromPct(type: 'window', x: 65, y: 0, w: 10, h: 2),
          structureFromPct(
            type: 'window',
            x: 0,
            y: 55,
            w: 2,
            h: 10,
            rotation: math.pi / 2,
          ),
        ];
        break;
      case '2bhk':
        rooms = [
          roomFromPct(
            name: 'Living Room',
            type: RoomType.living,
            x: 0,
            y: 0,
            w: 100,
            h: 30,
          ),
          roomFromPct(
            name: 'Bedroom 1',
            type: RoomType.bedroom,
            x: 0,
            y: 30,
            w: 50,
            h: 35,
          ),
          roomFromPct(
            name: 'Bedroom 2',
            type: RoomType.bedroom,
            x: 50,
            y: 30,
            w: 50,
            h: 35,
          ),
          roomFromPct(
            name: 'Kitchen',
            type: RoomType.kitchen,
            x: 0,
            y: 65,
            w: 50,
            h: 25,
          ),
          roomFromPct(
            name: 'Bathroom',
            type: RoomType.bathroom,
            x: 50,
            y: 65,
            w: 50,
            h: 25,
          ),
        ];
        structures = [
          structureFromPct(type: 'door', x: 44, y: 92, w: 12, h: 5),
          structureFromPct(type: 'window', x: 15, y: 0, w: 12, h: 2),
          structureFromPct(type: 'window', x: 65, y: 0, w: 12, h: 2),
          structureFromPct(
            type: 'window',
            x: 0,
            y: 40,
            w: 2,
            h: 10,
            rotation: math.pi / 2,
          ),
          structureFromPct(
            type: 'window',
            x: 98,
            y: 40,
            w: 2,
            h: 10,
            rotation: math.pi / 2,
          ),
        ];
        break;
      case '3bhk':
        rooms = [
          roomFromPct(
            name: 'Living Room',
            type: RoomType.living,
            x: 0,
            y: 0,
            w: 60,
            h: 35,
          ),
          roomFromPct(
            name: 'Kitchen',
            type: RoomType.kitchen,
            x: 60,
            y: 0,
            w: 40,
            h: 35,
          ),
          roomFromPct(
            name: 'Bedroom 1',
            type: RoomType.bedroom,
            x: 0,
            y: 35,
            w: 33,
            h: 35,
          ),
          roomFromPct(
            name: 'Bedroom 2',
            type: RoomType.bedroom,
            x: 33,
            y: 35,
            w: 34,
            h: 35,
          ),
          roomFromPct(
            name: 'Bedroom 3',
            type: RoomType.bedroom,
            x: 67,
            y: 35,
            w: 33,
            h: 35,
          ),
          roomFromPct(
            name: 'Bathroom 1',
            type: RoomType.bathroom,
            x: 0,
            y: 70,
            w: 50,
            h: 20,
          ),
          roomFromPct(
            name: 'Bathroom 2',
            type: RoomType.bathroom,
            x: 50,
            y: 70,
            w: 50,
            h: 20,
          ),
        ];
        structures = [
          structureFromPct(type: 'door', x: 44, y: 92, w: 12, h: 5),
          structureFromPct(type: 'window', x: 10, y: 0, w: 12, h: 2),
          structureFromPct(type: 'window', x: 68, y: 0, w: 10, h: 2),
          structureFromPct(
            type: 'window',
            x: 0,
            y: 45,
            w: 2,
            h: 10,
            rotation: math.pi / 2,
          ),
          structureFromPct(
            type: 'window',
            x: 98,
            y: 45,
            w: 2,
            h: 10,
            rotation: math.pi / 2,
          ),
          structureFromPct(
            type: 'window',
            x: 0,
            y: 75,
            w: 2,
            h: 8,
            rotation: math.pi / 2,
          ),
        ];
        break;
      case '4bhk':
        rooms = [
          roomFromPct(
            name: 'Living Room',
            type: RoomType.living,
            x: 0,
            y: 0,
            w: 60,
            h: 30,
          ),
          roomFromPct(
            name: 'Kitchen',
            type: RoomType.kitchen,
            x: 60,
            y: 0,
            w: 40,
            h: 30,
          ),
          roomFromPct(
            name: 'Master Bedroom',
            type: RoomType.bedroom,
            x: 0,
            y: 30,
            w: 50,
            h: 28,
          ),
          roomFromPct(
            name: 'Bedroom 2',
            type: RoomType.bedroom,
            x: 50,
            y: 30,
            w: 50,
            h: 28,
          ),
          roomFromPct(
            name: 'Bedroom 3',
            type: RoomType.bedroom,
            x: 0,
            y: 58,
            w: 50,
            h: 24,
          ),
          roomFromPct(
            name: 'Bedroom 4',
            type: RoomType.bedroom,
            x: 50,
            y: 58,
            w: 50,
            h: 24,
          ),
          roomFromPct(
            name: 'Bathroom 1',
            type: RoomType.bathroom,
            x: 0,
            y: 82,
            w: 34,
            h: 11,
          ),
          roomFromPct(
            name: 'Bathroom 2',
            type: RoomType.bathroom,
            x: 34,
            y: 82,
            w: 33,
            h: 11,
          ),
          roomFromPct(
            name: 'Utility',
            type: RoomType.utility,
            x: 67,
            y: 82,
            w: 33,
            h: 11,
          ),
        ];
        structures = [
          structureFromPct(type: 'door', x: 44, y: 94, w: 12, h: 5),
          structureFromPct(type: 'window', x: 10, y: 0, w: 12, h: 2),
          structureFromPct(type: 'window', x: 68, y: 0, w: 10, h: 2),
          structureFromPct(
            type: 'window',
            x: 0,
            y: 35,
            w: 2,
            h: 10,
            rotation: math.pi / 2,
          ),
          structureFromPct(
            type: 'window',
            x: 98,
            y: 35,
            w: 2,
            h: 10,
            rotation: math.pi / 2,
          ),
          structureFromPct(
            type: 'window',
            x: 0,
            y: 65,
            w: 2,
            h: 10,
            rotation: math.pi / 2,
          ),
          structureFromPct(
            type: 'window',
            x: 98,
            y: 65,
            w: 2,
            h: 10,
            rotation: math.pi / 2,
          ),
        ];
        break;
      default:
        return null;
    }

    return {
      'floors': 1,
      'rooms': rooms,
      'structures': structures,
      'templateKind': kind,
    };
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
    const smallGap = touchGap;
    const walkwayGap = touchGap;
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
          ? (living['y'] as num).toDouble() + h(living) + touchGap
          : startY + 160;
      double privateRowH = 0;

      for (final bed in bedrooms) {
        final bw = w(bed);
        final bh = h(bed);
        if (privateX + bw > maxWidthPx) {
          privateX = startX;
          privateY += privateRowH + touchGap;
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
            privateX = pairRight + touchGap;
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
        privateX = (placedBed['x'] as num).toDouble() + bw + touchGap;
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
              (living['x'] as num).toDouble() + w(living) + touchGap,
              (living['y'] as num).toDouble() + h(living) + touchGap,
            ),
            Offset(
              (living['x'] as num).toDouble() - w(s) - touchGap,
              (living['y'] as num).toDouble() + h(living) + touchGap,
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
          Offset(startX + 10, privateY + privateRowH + touchGap),
          Offset(startX + 130, privateY + privateRowH + touchGap),
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
            type == RoomType.stairs.name;
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

      double overlapLength(
        double aStart,
        double aEnd,
        double bStart,
        double bEnd,
      ) {
        return math.max(0.0, math.min(aEnd, bEnd) - math.max(aStart, bStart));
      }

      Rect? bestSnapRect(Map<String, dynamic> room) {
        final current = roomRect(room);
        const minSupport = 18.0;
        const maxSnapGap = 96.0;

        Rect? bestRect;
        double bestGap = double.infinity;
        double bestShift = double.infinity;
        double bestSupport = -1;

        void consider(Rect candidate, double gap, double support) {
          if (support < minSupport || gap <= 0 || gap > maxSnapGap) return;
          if (hasCollision(room, candidate)) return;
          final shift =
              (candidate.left - current.left).abs() +
              (candidate.top - current.top).abs();
          final isBetter =
              gap < bestGap - 0.1 ||
              ((gap - bestGap).abs() <= 0.1 && support > bestSupport + 0.1) ||
              ((gap - bestGap).abs() <= 0.1 &&
                  (support - bestSupport).abs() <= 0.1 &&
                  shift < bestShift);
          if (isBetter) {
            bestRect = candidate;
            bestGap = gap;
            bestShift = shift;
            bestSupport = support;
          }
        }

        for (final other in floorPlaced) {
          if (identical(room, other)) continue;
          final target = roomRect(other);
          final verticalSupport = overlapLength(
            current.top,
            current.bottom,
            target.top,
            target.bottom,
          );
          if (verticalSupport >= minSupport) {
            final gapToLeft = target.left - current.right;
            consider(
              Rect.fromLTWH(
                target.left - current.width,
                current.top,
                current.width,
                current.height,
              ),
              gapToLeft,
              verticalSupport,
            );

            final gapToRight = current.left - target.right;
            consider(
              Rect.fromLTWH(
                target.right,
                current.top,
                current.width,
                current.height,
              ),
              gapToRight,
              verticalSupport,
            );
          }

          final horizontalSupport = overlapLength(
            current.left,
            current.right,
            target.left,
            target.right,
          );
          if (horizontalSupport >= minSupport) {
            final gapAbove = target.top - current.bottom;
            consider(
              Rect.fromLTWH(
                current.left,
                target.top - current.height,
                current.width,
                current.height,
              ),
              gapAbove,
              horizontalSupport,
            );

            final gapBelow = current.top - target.bottom;
            consider(
              Rect.fromLTWH(
                current.left,
                target.bottom,
                current.width,
                current.height,
              ),
              gapBelow,
              horizontalSupport,
            );
          }
        }

        return bestRect;
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

      for (int pass = 0; pass < 6; pass++) {
        var changed = false;
        for (final r in movable) {
          final snapped = bestSnapRect(r);
          if (snapped == null) continue;
          final current = roomRect(r);
          if ((snapped.left - current.left).abs() < 0.1 &&
              (snapped.top - current.top).abs() < 0.1) {
            continue;
          }
          r['x'] = snapped.left;
          r['y'] = snapped.top;
          changed = true;
        }
        if (!changed) {
          break;
        }
      }

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

    double sharedWallOverlap(
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

      final verticalOverlap = math.max(
        0.0,
        math.min(ry + rh, ty + th) - math.max(ry, ty),
      );
      final horizontalOverlap = math.max(
        0.0,
        math.min(rx + rw, tx + tw) - math.max(rx, tx),
      );

      final placement = sharedWallPlacement(room, target);
      if (placement == null) return 0.0;
      return placement.side == 'left' || placement.side == 'right'
          ? verticalOverlap
          : horizontalOverlap;
    }

    Map<String, dynamic>? bestSharedWallNeighbor(Map<String, dynamic> room) {
      final floor = (room['floor'] as num?)?.toInt() ?? 0;
      Map<String, dynamic>? best;
      double bestOverlap = 0.0;

      for (final candidate in roomsByFloor[floor] ?? const []) {
        if (identical(candidate, room)) continue;
        final overlap = sharedWallOverlap(room, candidate);
        if (overlap > bestOverlap + 0.1) {
          best = candidate;
          bestOverlap = overlap;
        }
      }

      return best;
    }

    Set<String> sharedWallSides(Map<String, dynamic> room) {
      final floor = (room['floor'] as num?)?.toInt() ?? 0;
      final sides = <String>{};
      for (final candidate in roomsByFloor[floor] ?? const []) {
        if (identical(candidate, room)) continue;
        final placement = sharedWallPlacement(room, candidate);
        if (placement == null) continue;
        sides.add(placement.side);
      }
      return sides;
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
      final sharedNeighbor = bestSharedWallNeighbor(room);

      if (!isStairs && !isCorridor) {
        Map<String, dynamic>? target = sharedNeighbor;
        if (target == null) {
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

        final blockedSides = sharedWallSides(room);
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
        final availableSides = preferredSides
            .where((side) => !blockedSides.contains(side))
            .toList();
        final windowSides = availableSides.isEmpty
            ? preferredSides
            : availableSides;

        final usedSides = <String>{};
        for (int i = 0; i < windowCount; i++) {
          String side = windowSides.firstWhere(
            (s) => !usedSides.contains(s),
            orElse: () => windowSides[i % windowSides.length],
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

  List<RoomType> get _plannerRoomTypes => const [
    RoomType.bedroom,
    RoomType.bathroom,
    RoomType.kitchen,
    RoomType.living,
    RoomType.dining,
    RoomType.guestRoom,
    RoomType.kidsRoom,
    RoomType.studyRoom,
    RoomType.office,
    RoomType.poojaRoom,
    RoomType.utility,
    RoomType.storeRoom,
    RoomType.stairs,
    RoomType.balcony,
    RoomType.garage,
  ];

  int _ctrlInt(
    TextEditingController ctrl, {
    int fallback = 0,
    int min = 0,
    int max = 99,
  }) {
    final parsed = int.tryParse(ctrl.text.trim()) ?? fallback;
    return parsed.clamp(min, max);
  }

  void _setCtrlInt(
    TextEditingController ctrl,
    int value, {
    int min = 0,
    int max = 99,
  }) {
    ctrl.text = value.clamp(min, max).toString();
  }

  IconData _iconForRoomType(RoomType type) {
    switch (type) {
      case RoomType.bedroom:
        return Icons.bed_outlined;
      case RoomType.bathroom:
        return Icons.bathtub_outlined;
      case RoomType.kitchen:
        return Icons.kitchen_outlined;
      case RoomType.living:
        return Icons.weekend_outlined;
      case RoomType.dining:
        return Icons.table_restaurant_outlined;
      case RoomType.guestRoom:
        return Icons.king_bed_outlined;
      case RoomType.kidsRoom:
        return Icons.child_friendly_outlined;
      case RoomType.studyRoom:
        return Icons.menu_book_outlined;
      case RoomType.office:
        return Icons.work_outline;
      case RoomType.poojaRoom:
        return Icons.temple_hindu_outlined;
      case RoomType.utility:
        return Icons.local_laundry_service_outlined;
      case RoomType.storeRoom:
        return Icons.inventory_2_outlined;
      case RoomType.stairs:
        return Icons.stairs_outlined;
      case RoomType.balcony:
        return Icons.deck_outlined;
      case RoomType.garage:
        return Icons.garage_outlined;
      case RoomType.other:
        return Icons.meeting_room_outlined;
    }
  }

  void _changeRoomCount(RoomType type, int delta) {
    final ctrl = _countCtrls[type]!;
    _setCtrlInt(ctrl, _ctrlInt(ctrl) + delta);
    setState(() {});
  }

  void _changeFloors(int delta) {
    _setCtrlInt(
      _floorsCtrl,
      _ctrlInt(_floorsCtrl, fallback: 1, min: 1, max: 15) + delta,
      min: 1,
      max: 15,
    );
    setState(() {});
  }

  void _changeAttachedBath(int delta) {
    final maxAttached = math.min(
      _countOf(RoomType.bathroom),
      _countOf(RoomType.bedroom) +
          _countOf(RoomType.kidsRoom) +
          _countOf(RoomType.guestRoom),
    );
    _setCtrlInt(
      _attachedBathCtrl,
      _ctrlInt(_attachedBathCtrl, max: maxAttached) + delta,
      max: maxAttached,
    );
    setState(() {});
  }

  int _totalRoomInputCount() {
    return _plannerRoomTypes.fold(0, (sum, type) => sum + _countOf(type));
  }

  Widget _metricChip({
    required String label,
    required String value,
    required bool darkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: darkMode
            ? const Color(0xFF101924).withValues(alpha: 0.85)
            : const Color(0xFFFAF4E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: darkMode ? const Color(0xFF5A4A33) : const Color(0xFFD8C49E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.2,
              color: darkMode
                  ? const Color(0xFFAFC0D8)
                  : const Color(0xFF6A7788),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: darkMode
                  ? const Color(0xFFF3E3BE)
                  : const Color(0xFF20354F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
    required bool darkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: darkMode
            ? const Color(0xFF17202B).withValues(alpha: 0.86)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: darkMode ? const Color(0xFF5E4B2F) : const Color(0xFFD8C39B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: darkMode
                  ? const Color(0xFFF0DFC0)
                  : const Color(0xFF1B2F47),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.4,
                color: darkMode
                    ? const Color(0xFFB8C7D9)
                    : const Color(0xFF5B6B80),
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _numberStepper({
    required String label,
    required String helper,
    required int value,
    required int min,
    required int max,
    required IconData icon,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6C19B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(helper, style: const TextStyle(fontSize: 11.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: value > min ? onMinus : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: value < max ? onPlus : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roomCountTile(RoomType type, bool darkMode) {
    final count = _countOf(type);
    final name = type.label.replaceAll(' Room', '');

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: darkMode
            ? const Color(0xFF111A25).withValues(alpha: 0.88)
            : const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: darkMode ? const Color(0xFF5C6F88) : const Color(0xFFDCC8A4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForRoomType(type),
                size: 16,
                color: darkMode
                    ? const Color(0xFFE5D2AA)
                    : const Color(0xFF223A55),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.8,
                    color: darkMode
                        ? const Color(0xFFE8EDF6)
                        : const Color(0xFF20364F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              InkResponse(
                onTap: () => _changeRoomCount(type, -1),
                radius: 18,
                child: const Icon(Icons.remove_circle_outline, size: 20),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              InkResponse(
                onTap: () => _changeRoomCount(type, 1),
                radius: 18,
                child: const Icon(Icons.add_circle_outline, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _createAutoPlan() {
    final totalFloors = _ctrlInt(_floorsCtrl, fallback: 1, min: 1, max: 15);
    final templatePlan = _buildPercentTemplatePlan(totalFloors);
    if (templatePlan != null) {
      Navigator.pop(context, templatePlan);
      return;
    }

    final rooms = _buildRooms(totalFloors);
    final structures = _buildAutoStructures(rooms);
    Navigator.pop(context, {
      'floors': totalFloors,
      'rooms': rooms,
      'structures': structures,
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = media.size.width;
    final keyboardInset = media.viewInsets.bottom;
    final dialogWidth = math.min(760.0, screenWidth - 40);
    final maxContentHeight = math.max(
      260.0,
      math.min(620.0, media.size.height - keyboardInset - 150),
    );
    final floors = _ctrlInt(_floorsCtrl, fallback: 1, min: 1, max: 15);
    final attachedMax = math.min(
      _countOf(RoomType.bathroom),
      _countOf(RoomType.bedroom) +
          _countOf(RoomType.kidsRoom) +
          _countOf(RoomType.guestRoom),
    );
    final attachedBath = _ctrlInt(_attachedBathCtrl, max: attachedMax);
    final totalRooms = _totalRoomInputCount();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Smart Planner'),
          SizedBox(height: 4),
          Text(
            'Modern auto-layout wizard',
            style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionCard(
                    title: 'Recommended Setup',
                    subtitle: 'Use balanced defaults for quick planning',
                    darkMode: isDark,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => setState(_applyRecommendedCounts),
                        icon: const Icon(Icons.lightbulb_outline, size: 17),
                        label: const Text('Recommended'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionCard(
                    title: 'Project Setup',
                    subtitle: 'Define floors and vertical distribution',
                    darkMode: isDark,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 470;
                        final floorStepper = _numberStepper(
                          label: 'Floors',
                          helper: 'Total levels (1-15)',
                          value: floors,
                          min: 1,
                          max: 15,
                          icon: Icons.layers_outlined,
                          onMinus: () => _changeFloors(-1),
                          onPlus: () => _changeFloors(1),
                        );
                        final attachedStepper = _numberStepper(
                          label: 'Attached Baths',
                          helper: 'Max $attachedMax based on rooms',
                          value: attachedBath,
                          min: 0,
                          max: attachedMax,
                          icon: Icons.shower_outlined,
                          onMinus: () => _changeAttachedBath(-1),
                          onPlus: () => _changeAttachedBath(1),
                        );

                        return Column(
                          children: [
                            if (compact) ...[
                              floorStepper,
                              const SizedBox(height: 10),
                              attachedStepper,
                            ] else
                              Row(
                                children: [
                                  Expanded(child: floorStepper),
                                  const SizedBox(width: 10),
                                  Expanded(child: attachedStepper),
                                ],
                              ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _balconyPerFloorCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Balcony split by floor',
                                hintText: 'Example: 1,0,2 (Ground,1st,2nd)',
                                prefixIcon: Icon(Icons.deck_outlined),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionCard(
                    title: 'Room Mix',
                    subtitle: 'Adjust room counts with +/- controls',
                    darkMode: isDark,
                    child: LayoutBuilder(
                      builder: (_, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 700
                            ? 4
                            : (width >= 520 ? 3 : 2);
                        final tileWidth = (width - (columns - 1) * 8) / columns;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _plannerRoomTypes
                              .map(
                                (type) => SizedBox(
                                  width: tileWidth,
                                  child: _roomCountTile(type, isDark),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionCard(
                    title: 'Live Summary',
                    subtitle: 'Quick overview before generating the plan',
                    darkMode: isDark,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metricChip(
                          label: 'Floors',
                          value: '$floors',
                          darkMode: isDark,
                        ),
                        _metricChip(
                          label: 'Input Rooms',
                          value: '$totalRooms',
                          darkMode: isDark,
                        ),
                        _metricChip(
                          label: 'Bathrooms',
                          value: '${_countOf(RoomType.bathroom)}',
                          darkMode: isDark,
                        ),
                        _metricChip(
                          label: 'Attached',
                          value: '$attachedBath',
                          darkMode: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _createAutoPlan,
          icon: const Icon(Icons.auto_fix_high_outlined),
          label: const Text('Generate Plan'),
        ),
      ],
    );
  }
}
