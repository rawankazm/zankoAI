import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// A gorgeous animated VIP badge widget with shimmer, glow, and particle effects.
/// Place it anywhere on top of an avatar or next to a username.
class VipBadge extends StatefulWidget {
  /// Size variant of the badge.
  final VipBadgeSize size;

  /// If true shows the full pill label, if false shows only the crown icon.
  final bool showLabel;

  const VipBadge({
    super.key,
    this.size = VipBadgeSize.medium,
    this.showLabel = false,
  });

  @override
  State<VipBadge> createState() => _VipBadgeState();
}

enum VipBadgeSize { small, medium, large }

class _VipBadgeState extends State<VipBadge>
    with TickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _scaleCtrl;
  late AnimationController _sparkleCtrl;

  late Animation<double> _shimmerAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _sparkleAnim;

  @override
  void initState() {
    super.initState();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _shimmerAnim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );

    _sparkleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _sparkleCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _glowCtrl.dispose();
    _scaleCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  double get _badgeHeight {
    switch (widget.size) {
      case VipBadgeSize.small:
        return 20;
      case VipBadgeSize.medium:
        return 26;
      case VipBadgeSize.large:
        return 34;
    }
  }

  double get _crownSize {
    switch (widget.size) {
      case VipBadgeSize.small:
        return 11;
      case VipBadgeSize.medium:
        return 14;
      case VipBadgeSize.large:
        return 18;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case VipBadgeSize.small:
        return 9;
      case VipBadgeSize.medium:
        return 11;
      case VipBadgeSize.large:
        return 14;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case VipBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 6, vertical: 3);
      case VipBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 9, vertical: 4);
      case VipBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _shimmerAnim,
        _glowAnim,
        _scaleAnim,
        _sparkleAnim,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Outer glow halo ──
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700)
                            .withValues(alpha: 0.55 * _glowAnim.value),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFA500)
                            .withValues(alpha: 0.3 * _glowAnim.value),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Main pill badge ──
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  height: _badgeHeight,
                  padding: _padding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFB8860B), // dark golden rod
                        Color(0xFFFFD700), // gold
                        Color(0xFFFFF176), // pale gold highlight
                        Color(0xFFFFD700), // gold
                        Color(0xFFDAA520), // goldenrod
                      ],
                      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Crown icon
                      Text(
                        '👑',
                        style: TextStyle(
                          fontSize: _crownSize,
                          height: 1.0,
                        ),
                      ),
                      if (widget.showLabel) ...[
                        SizedBox(
                            width: widget.size == VipBadgeSize.small ? 3 : 5),
                        Text(
                          'VIP',
                          style: TextStyle(
                            fontSize: _fontSize,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF3D2000),
                            letterSpacing: 0.8,
                            shadows: const [
                              Shadow(
                                color: Colors.white38,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Shimmer sweep overlay ──
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: SizedBox(
                  height: _badgeHeight,
                  child: AnimatedBuilder(
                    animation: _shimmerAnim,
                    builder: (context, _) => CustomPaint(
                      painter: _ShimmerPainter(_shimmerAnim.value),
                    ),
                  ),
                ),
              ),

              // ── Sparkle particles (small) ──
              if (widget.size != VipBadgeSize.small)
                ..._buildSparkles(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSparkles() {
    final sparkles = <Widget>[];
    final radius = widget.size == VipBadgeSize.large ? 24.0 : 18.0;

    for (var i = 0; i < 4; i++) {
      final angle = (_sparkleAnim.value * 2 * math.pi) + (i * math.pi / 2);
      final opacity = (math.sin(_sparkleAnim.value * 2 * math.pi + i) + 1) / 2;
      final size = widget.size == VipBadgeSize.large ? 5.0 : 4.0;

      sparkles.add(
        Positioned(
          left: radius * math.cos(angle) + radius - size / 2,
          top: radius * math.sin(angle) + radius / 2 - size / 2,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF9C4),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFFD700),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return sparkles;
  }
}

/// Custom painter for the shimmer sweep effect
class _ShimmerPainter extends CustomPainter {
  final double progress;
  _ShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final sweepX = (progress + 2) / 4 * size.width * 2 - size.width / 2;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(
        Rect.fromLTWH(sweepX - 30, 0, 60, size.height),
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) =>
      old.progress != progress;
}

/// ─────────────────────────────────────────────────────────────
/// Full-width VIP membership card — replaces the existing banner
/// ─────────────────────────────────────────────────────────────
class VipMembershipCard extends StatefulWidget {
  final bool isVip;
  final VoidCallback onUpgradeTap;

  const VipMembershipCard({
    super.key,
    required this.isVip,
    required this.onUpgradeTap,
  });

  @override
  State<VipMembershipCard> createState() => _VipMembershipCardState();
}

class _VipMembershipCardState extends State<VipMembershipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return GestureDetector(
          onTap: widget.onUpgradeTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: widget.isVip
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: -2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFA500).withValues(alpha: 0.2),
                        blurRadius: 40,
                        spreadRadius: 0,
                        offset: const Offset(0, 16),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: ZankoColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: -2,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // ── Background gradient ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: widget.isVip
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF1A1200),
                                Color(0xFF2C1F00),
                                Color(0xFF3D2B00),
                                Color(0xFF1A1200),
                              ],
                              stops: [0.0, 0.35, 0.65, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [
                                Color(0xFF0F0C29),
                                Color(0xFF1A1050),
                                Color(0xFF2D1B7A),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                  ),

                  // ── Decorative glow orbs ──
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: widget.isVip
                              ? [
                                  const Color(0xFFFFD700)
                                      .withValues(alpha: 0.25),
                                  Colors.transparent,
                                ]
                              : [
                                  const Color(0xFF818CF8)
                                      .withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    left: 20,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: widget.isVip
                              ? [
                                  const Color(0xFFFFA500)
                                      .withValues(alpha: 0.2),
                                  Colors.transparent,
                                ]
                              : [
                                  ZankoColors.accent
                                      .withValues(alpha: 0.2),
                                  Colors.transparent,
                                ],
                        ),
                      ),
                    ),
                  ),

                  // ── Shimmer sweep ──
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CardShimmerPainter(_shimmer.value),
                    ),
                  ),

                  // ── Gold border ──
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: widget.isVip
                              ? const Color(0xFFFFD700).withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.12),
                          width: widget.isVip ? 1.5 : 1,
                        ),
                      ),
                    ),
                  ),

                  // ── Content ──
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: widget.isVip
                        ? _buildVipActiveContent()
                        : _buildUpgradeContent(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVipActiveContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Large crown + "VIP MEMBER" label
            const Text('👑', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'VIP MEMBER',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const VipBadge(
                          size: VipBadgeSize.small, showLabel: false),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'بەشداربووی فەرمی پریمۆم',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Active pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0xFF10B981),
                            blurRadius: 5,
                            spreadRadius: 1)
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'چالاک',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(color: Color(0x33FFD700), height: 1),
        const SizedBox(height: 14),

        // Feature pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _featurePill('💬 پەیامی بێسنوور'),
            _featurePill('📸 شیکاری وێنە'),
            _featurePill('📄 کورتکراوەی PDF'),
            _featurePill('🎯 تایبەتمەندی تر'),
          ],
        ),
      ],
    );
  }

  Widget _buildUpgradeContent() {
    return Row(
      children: [
        // Left: icon area
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text('👑', style: TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 14),

        // Middle: text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'VIP بەدەستبهێنە',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const VipBadge(size: VipBadgeSize.small),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'پەیامی بێسنوور + PDF + وێنەی پرسیار',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '٥,٠٠٠ دیناری عێراقی / مانگانە',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Right: CTA button
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onUpgradeTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  'چالاک\nبکە',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF3D2000),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _featurePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Custom painter for card-wide shimmer sweep
class _CardShimmerPainter extends CustomPainter {
  final double progress;
  _CardShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final sweepX = (progress + 1.5) / 4 * size.width * 2.5 - size.width * 0.5;
    final rect = Rect.fromLTWH(sweepX - 50, 0, 100, size.height);

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CardShimmerPainter old) =>
      old.progress != progress;
}
