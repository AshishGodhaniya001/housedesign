import 'package:flutter/material.dart';

class PlannerHeroCard extends StatelessWidget {
  const PlannerHeroCard({
    super.key,
    required this.darkMode,
    required this.connected,
  });

  final bool darkMode;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final titleColor = darkMode
        ? const Color(0xFFF5E6C8)
        : const Color(0xFF1A2B40);
    final bodyColor = darkMode
        ? const Color(0xFFC7D3E4)
        : const Color(0xFF4B5B70);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: darkMode
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF172434), Color(0xFF0F1926), Color(0xFF20344A)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFCF5), Color(0xFFF1E6D1), Color(0xFFE7D7BB)],
              ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: darkMode ? const Color(0xFF71562F) : const Color(0xFFD6BE93),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: darkMode ? 0.28 : 0.1),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -24,
            child: _GlowBlob(
              size: 140,
              color: darkMode
                  ? const Color(0xFFD9B567).withValues(alpha: 0.17)
                  : const Color(0xFF314A68).withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: -48,
            left: -26,
            child: _GlowBlob(
              size: 150,
              color: darkMode
                  ? const Color(0xFF5A89BF).withValues(alpha: 0.14)
                  : const Color(0xFFE0B65F).withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: darkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: darkMode
                        ? const Color(0xFF6A5635)
                        : const Color(0xFFD7C29A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      connected ? Icons.cloud_done_rounded : Icons.bolt_rounded,
                      size: 16,
                      color: const Color(0xFFE0BD72),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connected ? 'Cloud On' : 'Local Mode',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Plan fast.\nBuild well.',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.06,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pick a mode. Build the layout. Save when ready.',
                style: TextStyle(
                  fontSize: 13.7,
                  height: 1.42,
                  color: bodyColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroMetricChip(
                    icon: Icons.draw_rounded,
                    title: 'Manual',
                    subtitle: 'Free edit',
                    darkMode: darkMode,
                  ),
                  _HeroMetricChip(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Smart',
                    subtitle: 'Quick start',
                    darkMode: darkMode,
                  ),
                  _HeroMetricChip(
                    icon: Icons.view_in_ar_rounded,
                    title: 'Preview',
                    subtitle: '2D + 3D',
                    darkMode: darkMode,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AuthAccessCard extends StatelessWidget {
  const AuthAccessCard({
    super.key,
    required this.darkMode,
    required this.loading,
    required this.onSignIn,
    required this.onSignUp,
  });

  final bool darkMode;
  final bool loading;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final cardGradient = darkMode
        ? const [Color(0xFF172536), Color(0xFF21344C)]
        : const [Color(0xFFFFFFFF), Color(0xFFF5EDDD)];
    final titleColor = darkMode
        ? const Color(0xFFF0E2C5)
        : const Color(0xFF1B2D45);
    final subtitleColor = darkMode
        ? const Color(0xFFC5D2E4)
        : const Color(0xFF4D5D71);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: darkMode ? const Color(0xFF5E4B2F) : const Color(0xFFD7C29D),
        ),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withValues(alpha: 0.24)
                : const Color(0xFF6D5835).withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: darkMode
                      ? const Color(0xFF2A3F5A)
                      : const Color(0xFF1F324A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 19,
                  color: Color(0xFFE4C885),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Sign in for cloud save',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : onSignIn,
                  icon: loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login, size: 18),
                  label: const Text('Sign In'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onSignUp,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Sign Up'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlannerStatusCard extends StatelessWidget {
  const PlannerStatusCard({
    super.key,
    required this.darkMode,
    required this.connected,
    required this.userLabel,
  });

  final bool darkMode;
  final bool connected;
  final String userLabel;

  @override
  Widget build(BuildContext context) {
    final borderColor = darkMode
        ? const Color(0xFF5E4B2F)
        : const Color(0xFFD5C19B);
    final surfaceColor = darkMode
        ? const Color(0xFF17202B).withValues(alpha: 0.84)
        : Colors.white.withValues(alpha: 0.76);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFF6EC6A8).withValues(alpha: 0.14)
                      : const Color(0xFFE4C885).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  connected ? Icons.cloud_done_rounded : Icons.storage_rounded,
                  color: connected
                      ? const Color(0xFF6EC6A8)
                      : const Color(0xFFE4C885),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'Cloud ready' : 'Local ready',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: darkMode
                            ? const Color(0xFFF0E3C9)
                            : const Color(0xFF1C2A3B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? 'Connected as $userLabel'
                          : 'You can still save here',
                      style: TextStyle(
                        fontSize: 12.4,
                        height: 1.25,
                        color: darkMode
                            ? const Color(0xFFC7D3E4)
                            : const Color(0xFF556273),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusStat(
                  icon: Icons.layers_outlined,
                  label: '2 Modes',
                  darkMode: darkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusStat(
                  icon: Icons.save_outlined,
                  label: connected ? 'Cloud Save' : 'Local Save',
                  darkMode: darkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusStat(
                  icon: Icons.bolt_rounded,
                  label: 'Quick Start',
                  darkMode: darkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlannerActionCard extends StatelessWidget {
  const PlannerActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.onTap,
    required this.darkMode,
    required this.points,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final VoidCallback onTap;
  final bool darkMode;
  final List<String> points;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final background = highlighted
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

    final innerGlow = highlighted
        ? const [Color(0xFFD7B56D), Color(0x00D7B56D)]
        : darkMode
        ? const [Color(0xFF2C4058), Color(0x002C4058)]
        : const [Color(0xFFE7D8BA), Color(0x00E7D8BA)];

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: background,
          borderRadius: BorderRadius.circular(22),
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
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -34,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: innerGlow),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? const Color(0xFFD7B56D)
                        : (darkMode
                              ? const Color(0xFF243347)
                              : const Color(0xFF1D2A3C)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: highlighted
                        ? const Color(0xFF1B150A)
                        : Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        highlighted ? 'SMART MODE' : 'MANUAL MODE',
                        style: TextStyle(
                          fontSize: 10.8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: highlighted
                              ? const Color(0xFFF2D89E)
                              : (darkMode
                                    ? const Color(0xFF9DB2CB)
                                    : const Color(0xFF61728A)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12.4,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: points
                            .map(
                              (point) => _PointChip(
                                label: point,
                                darkMode: darkMode,
                                highlighted: highlighted,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: highlighted
                            ? const Color(0xFFDAB96C).withValues(alpha: 0.16)
                            : (darkMode
                                  ? const Color(0xFF202F42)
                                  : const Color(0xFFF0E6D4)),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: highlighted
                              ? const Color(0xFFE6C980)
                              : (darkMode
                                    ? const Color(0xFF4D6482)
                                    : const Color(0xFFD6C3A1)),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: highlighted
                              ? const Color(0xFFF3D9A2)
                              : (darkMode
                                    ? const Color(0xFFD6E1F0)
                                    : const Color(0xFF384B61)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: highlighted
                            ? const LinearGradient(
                                colors: [Color(0xFFE2C170), Color(0xFFC89E52)],
                              )
                            : (darkMode
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF273B52),
                                        Color(0xFF1C2A3D),
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFF26374E),
                                        Color(0xFF1A2B3F),
                                      ],
                                    )),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            highlighted ? 'Start' : 'Open',
                            style: TextStyle(
                              fontSize: 11.6,
                              fontWeight: FontWeight.w800,
                              color: highlighted
                                  ? const Color(0xFF1B150A)
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: highlighted
                                ? const Color(0xFF1B150A)
                                : Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlannerFeatureDeck extends StatelessWidget {
  const PlannerFeatureDeck({super.key, required this.darkMode});

  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkMode
            ? const Color(0xFF131C28).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: darkMode ? const Color(0xFF4E402B) : const Color(0xFFD9C7A4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick perks',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: darkMode
                  ? const Color(0xFFF0E3C8)
                  : const Color(0xFF1D2B3D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Simple flow. Fast start. Easy save.',
            style: TextStyle(
              fontSize: 12.8,
              height: 1.35,
              color: darkMode
                  ? const Color(0xFFC3D1E3)
                  : const Color(0xFF566476),
            ),
          ),
          const SizedBox(height: 14),
          const _FeatureRow(
            icon: Icons.draw_rounded,
            title: 'Edit',
            subtitle: 'Full control',
          ),
          const SizedBox(height: 10),
          const _FeatureRow(
            icon: Icons.auto_fix_high_rounded,
            title: 'Generate',
            subtitle: 'Quick first draft',
          ),
          const SizedBox(height: 10),
          const _FeatureRow(
            icon: Icons.cloud_sync_rounded,
            title: 'Save',
            subtitle: 'Local or cloud',
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.05), Colors.transparent],
        ),
      ),
    );
  }
}

class _HeroMetricChip extends StatelessWidget {
  const _HeroMetricChip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.darkMode,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: darkMode
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE1BD71)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w800,
                    color: darkMode
                        ? const Color(0xFFF5E8CF)
                        : const Color(0xFF1E2A38),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.3,
                    height: 1.1,
                    color: darkMode
                        ? const Color(0xFFB8C7DB)
                        : const Color(0xFF697686),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStat extends StatelessWidget {
  const _StatusStat({
    required this.icon,
    required this.label,
    required this.darkMode,
  });

  final IconData icon;
  final String label;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: darkMode
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: const Color(0xFFE4C885)),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
              color: darkMode
                  ? const Color(0xFFDCE5F0)
                  : const Color(0xFF304154),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointChip extends StatelessWidget {
  const _PointChip({
    required this.label,
    required this.darkMode,
    required this.highlighted,
  });

  final String label;
  final bool darkMode;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFFD7B56D).withValues(alpha: 0.14)
            : (darkMode
                  ? const Color(0xFF223247)
                  : const Color(0xFFF3E8D2)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFE5C980)
              : (darkMode
                    ? const Color(0xFF4D6482)
                    : const Color(0xFFDDC8A8)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.1,
          fontWeight: FontWeight.w700,
          color: highlighted
              ? const Color(0xFFF3DBA5)
              : (darkMode
                    ? const Color(0xFFD5E1F1)
                    : const Color(0xFF405166)),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFD7B56D).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Color(0xFFE4C885),
            size: 18,
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
                  fontSize: 13.4,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFFF0E3C8)
                      : const Color(0xFF1D2B3D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: isDark
                      ? const Color(0xFFC2D0E1)
                      : const Color(0xFF5C6978),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
