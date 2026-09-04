import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../theme.dart';

/// Renders either a HugeIcon or traditional IconData seamlessly
Widget appIcon(dynamic icon, {Color? color, double size = 20}) {
  if (icon is List<List<dynamic>>) {
    return HugeIcon(icon: icon, color: color, size: size);
  }
  if (icon is IconData) {
    return Icon(icon, color: color, size: size);
  }
  if (icon is Widget) {
    return icon;
  }
  return const SizedBox.shrink();
}

// ─── AppCard Widget ─────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = ZankoRadius.card,
    this.color,
    this.onTap,
    this.boxShadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? ZankoColors.darkCard : ZankoColors.card;

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? defaultBg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ??
            (isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : ZankoShadows.card),
        border: border ??
            Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF0F0F6),
              width: 1,
            ),
      ),
      child: child,
    );

    if (onTap != null) {
      return AnimatedScaleButton(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

// ─── AnimatedScaleButton (Micro-interaction wrapper) ────────────────────────
class AnimatedScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AnimatedScaleButton({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<AnimatedScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ─── Gradient Button Component ──────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String text;
  final dynamic icon;
  final VoidCallback onTap;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.text,
    this.icon,
    required this.onTap,
    this.height = 52,
    this.borderRadius = ZankoRadius.button,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScaleButton(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ZankoColors.primary, ZankoColors.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: ZankoShadows.glow,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: TextStyle(
          fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                appIcon(icon, color: Colors.white, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Glassmorphism Container ────────────────────────────────────────────────
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.7,
    this.color = Colors.white,
    this.borderRadius = ZankoRadius.card,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = isDark ? Colors.black : color;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Apple-style Search Bar ─────────────────────────────────────────────────
class AppleSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final VoidCallback? onTap;

  const AppleSearchBar({
    super.key,
    this.hintText = 'Ask AI anything...',
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(ZankoRadius.input),
        boxShadow: isDark ? [] : ZankoShadows.card,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7),
          width: 1,
        ),
      ),
      child: Center(
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAiMagic,
              color: ZankoColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                onTap: onTap,
                style: TextStyle(
          fontSize: 15,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
          fontSize: 15,
                    color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                if (controller != null && controller!.text.isNotEmpty) {
                  onSubmitted?.call(controller!.text);
                } else {
                  onTap?.call();
                }
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ZankoColors.primary, ZankoColors.accent],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: ZankoShadows.glow,
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowUp01,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progress Ring Painter ──────────────────────────────────────────────────
class ProgressRing extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final String title;
  final String subtitle;
  final double size;

  const ProgressRing({
    super.key,
    required this.value,
    required this.title,
    required this.subtitle,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(value: value, isDark: isDark),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
          fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
          fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400]! : ZankoColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final bool isDark;
  _RingPainter({required this.value, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFEFEFF7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * 3.141592653589793 * value;
    final activePaint = Paint()
      ..shader = LinearGradient(
        colors: [ZankoColors.primary, ZankoColors.accent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.141592653589793 / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.isDark != isDark;
}

// ─── AI Hero Card with Interactive 3D Floating Robot ─────────────────────────
class AIHeroCard extends StatefulWidget {
  final VoidCallback onStartLearning;
  final Function(String action)? onQuickAction;

  const AIHeroCard({
    super.key,
    required this.onStartLearning,
    this.onQuickAction,
  });

  @override
  State<AIHeroCard> createState() => _AIHeroCardState();
}

class _AIHeroCardState extends State<AIHeroCard>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _punchController;
  late Animation<double> _punchScale;

  int _quoteIndex = 0;
  bool _showBubble = false;

  List<String> _getAiQuotes(bool isEnglish) {
    if (isEnglish) {
      return const [
        'Hi! I am ready to assist with any university topic 🚀',
        'Ask me a question or paste your lecture to summarize! 💡',
        'Ready to start a new course and boost your grades? ✨',
        'You can speak with me using Voice Tutor! 🎙️',
      ];
    }
    return const [
      'سڵاو! من ئامادەم بۆ شیکارکردنی هەر بابەتێکی زانکۆ 🚀',
      'پرسیارێکم لێبکە یاخود دەقی بابەتەکەت دابنێ بۆ کورتکردنەوە! 💡',
      'ئامادەیت بۆ دەستپێکردنی کۆرسی نوێ و بەرزکردنەوەی نمرەکانت؟ ✨',
      'دەتوانیت لەگەڵم بە دەنگ قسە بکەیت لە بەشی Voice Tutor! 🎙️',
    ];
  }

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _punchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _punchScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_punchController);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _punchController.dispose();
    super.dispose();
  }

  void _onRobotTap() {
    HapticFeedback.mediumImpact();
    _punchController.forward(from: 0.0);
    setState(() {
      _showBubble = true;
      _quoteIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF131B2A), const Color(0xFF171B23)]
              : [const Color(0xFFF0F6FD), const Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF262C36) : const Color(0xFFE2EDFB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF035EC2).withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speech Bubble when robot is tapped
          if (_showBubble) ...[
            GestureDetector(
              onTap: () => setState(() => _showBubble = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF035EC2).withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedAiMagic,
                      color: Color(0xFFE4D27D),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getAiQuotes(langProvider.currentLanguage == AppLanguage.english)[
                            _quoteIndex % _getAiQuotes(langProvider.currentLanguage == AppLanguage.english).length],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                    ),
                    const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 12, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langProvider.translate('ai_tutor_hero_title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF17191F),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      langProvider.translate('ai_tutor_subtitle'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: widget.onStartLearning,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF035EC2),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF035EC2).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${langProvider.translate('nav_ai_teacher')} ✨',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowRight01,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Interactive 3D Floating Robot
              GestureDetector(
                onTap: _onRobotTap,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_floatAnimation, _punchController]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: Transform.scale(
                        scale: _punchScale.value,
                        child: SizedBox(
                          width: 175,
                          height: 175,
                          child: Image.asset(
                            'assets/images/robot.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                                return const HugeIcon(
                                  icon: HugeIcons.strokeRoundedAiMagic,
                                  size: 72,
                                  color: Color(0xFF035EC2),
                                );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Grid Item Card ───────────────────────────────────────────
class QuickActionCard extends StatelessWidget {
  final dynamic icon;
  final String title;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? bgColor.withValues(alpha: 0.2) : bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: appIcon(icon, color: iconColor, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
          fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Statistic Pill Card ────────────────────────────────────────────────────
class StatisticCard extends StatelessWidget {
  final dynamic icon;
  final String value;
  final String label;
  final Color color;

  const StatisticCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? color.withValues(alpha: 0.25) : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            appIcon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
          fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
          fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400]! : ZankoColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Course Card ────────────────────────────────────────────────────────────
class CourseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress; // 0.0 to 1.0
  final dynamic icon;
  final Color gradientStart;
  final Color gradientEnd;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final DateTime? midtermDate;
  final DateTime? finalDate;

  const CourseCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.midtermDate,
    this.finalDate,
  });

  Widget _buildExamBadge({
    required BuildContext context,
    required String label,
    required DateTime? examDate,
    required dynamic icon,
    required Color defaultColor,
    required bool isDark,
  }) {
    if (examDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final examDayStart = DateTime(examDate.year, examDate.month, examDate.day);
    final diffDays = examDayStart.difference(todayStart).inDays;

    String text;
    Color badgeColor;
    Color textColor;

    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final daysLeftText = langProvider.translate('days_left');

    if (diffDays < 0) {
      text = langProvider.translate('exam_completed');
      badgeColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
      textColor = Colors.grey;
    } else if (diffDays == 0) {
      text = '${langProvider.translate('today_exam')} ⚠️';
      badgeColor = const Color(0xFFFF3B30).withValues(alpha: 0.15);
      textColor = const Color(0xFFFF3B30);
    } else if (diffDays <= 3) {
      text = '$diffDays $daysLeftText 🔥';
      badgeColor = const Color(0xFFFF9500).withValues(alpha: 0.15);
      textColor = const Color(0xFFFF9500);
    } else {
      text = '$diffDays $daysLeftText';
      badgeColor = defaultColor.withValues(alpha: 0.12);
      textColor = defaultColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          appIcon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasExams = midtermDate != null || finalDate != null;

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF035EC2).withValues(alpha: 0.2) : const Color(0xFFE2EDFB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: appIcon(icon, color: const Color(0xFF035EC2), size: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400]! : ZankoColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreVertical,
                    color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                    size: 18,
                  ),
                  onSelected: (val) {
                    if (val == 'edit') onEdit?.call();
                    if (val == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit02, size: 16, color: ZankoColors.primary),
                            const SizedBox(width: 8),
                            Text(Provider.of<LanguageProvider>(context, listen: false).translate('edit_course'), style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Text(Provider.of<LanguageProvider>(context, listen: false).translate('delete_course'), style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF035EC2)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF035EC2).withValues(alpha: 0.2) : const Color(0xFFE2EDFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF035EC2),
                  ),
                ),
              ),
            ],
          ),

          if (hasExams) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (midtermDate != null)
                  _buildExamBadge(
                    context: context,
                    label: Provider.of<LanguageProvider>(context, listen: false).translate('midterm_exam'),
                    examDate: midtermDate,
                    icon: HugeIcons.strokeRoundedClock01,
                    defaultColor: const Color(0xFF007AFF),
                    isDark: isDark,
                  ),
                if (finalDate != null)
                  _buildExamBadge(
                    context: context,
                    label: Provider.of<LanguageProvider>(context, listen: false).translate('final_exam'),
                    examDate: finalDate,
                    icon: HugeIcons.strokeRoundedFlag01,
                    defaultColor: const Color(0xFFAF52DE),
                    isDark: isDark,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Floating Glass Bottom Navigation Bar with Micro-Interactions ────────────
class GlassBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    return Container(
      margin: const EdgeInsets.only(left: 18, right: 18, bottom: 20),
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171B23) : Colors.white,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AnimatedNavTile(
            index: 0,
            isSelected: currentIndex == 0,
            label: langProvider.translate('nav_home'),
            onTap: () => onTap(0),
            iconBuilder: (isSelected) => _AnimatedHomeIcon(isSelected: isSelected),
          ),
          _AnimatedNavTile(
            index: 1,
            isSelected: currentIndex == 1,
            label: langProvider.translate('nav_courses'),
            onTap: () => onTap(1),
            iconBuilder: (isSelected) => _AnimatedCoursesIcon(isSelected: isSelected),
          ),
          _AnimatedCenterAiButton(
            isSelected: currentIndex == 2,
            onTap: () {
              HapticFeedback.mediumImpact();
              onTap(2);
            },
          ),
          _AnimatedNavTile(
            index: 3,
            isSelected: currentIndex == 3,
            label: langProvider.translate('zankoline'),
            onTap: () => onTap(3),
            iconBuilder: (isSelected) => _AnimatedZankolineIcon(isSelected: isSelected),
          ),
          _AnimatedNavTile(
            index: 4,
            isSelected: currentIndex == 4,
            label: langProvider.translate('nav_profile'),
            onTap: () => onTap(4),
            iconBuilder: (isSelected) => _AnimatedProfileIcon(isSelected: isSelected),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Nav Tile Wrapper ───────────────────────────────────────────────
class _AnimatedNavTile extends StatelessWidget {
  final int index;
  final bool isSelected;
  final String label;
  final VoidCallback onTap;
  final Widget Function(bool isSelected) iconBuilder;

  const _AnimatedNavTile({
    required this.index,
    required this.isSelected,
    required this.label,
    required this.onTap,
    required this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? ZankoColors.primary.withValues(alpha: 0.18)
                    : ZankoColors.primary.withValues(alpha: 0.10))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconBuilder(isSelected),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'DroidKufi',
                  fontSize: isSelected ? 10.5 : 10.0,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? ZankoColors.primary
                      : (isDark ? Colors.grey[400]! : ZankoColors.textSecondary),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                height: 3,
                width: isSelected ? 12 : 0,
                decoration: BoxDecoration(
                  color: isSelected ? ZankoColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: ZankoColors.primary.withValues(alpha: 0.6),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : const [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 1. Home Animated Icon (Wiggle & Bounce) ─────────────────────────────────
class _AnimatedHomeIcon extends StatefulWidget {
  final bool isSelected;
  const _AnimatedHomeIcon({required this.isSelected});

  @override
  State<_AnimatedHomeIcon> createState() => _AnimatedHomeIconState();
}

class _AnimatedHomeIconState extends State<_AnimatedHomeIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_controller);

    _wiggleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.13)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.13, end: -0.06)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.06, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedHomeIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.isSelected
        ? ZankoColors.primary
        : (isDark ? Colors.grey[400]! : ZankoColors.textSecondary);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _wiggleAnimation.value,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedHome01,
              color: color,
              size: 23,
            ),
          ),
        );
      },
    );
  }
}

// ─── 2. Courses Animated Icon (3D Page Flip & Bounce) ───────────────────────
class _AnimatedCoursesIcon extends StatefulWidget {
  final bool isSelected;
  const _AnimatedCoursesIcon({required this.isSelected});

  @override
  State<_AnimatedCoursesIcon> createState() => _AnimatedCoursesIconState();
}

class _AnimatedCoursesIconState extends State<_AnimatedCoursesIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi * 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.28)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.28, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_controller);

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedCoursesIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.isSelected
        ? ZankoColors.primary
        : (isDark ? Colors.grey[400]! : ZankoColors.textSecondary);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateY(_flipAnimation.value);

        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform(
            alignment: Alignment.center,
            transform: transform,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedBook02,
              color: color,
              size: 23,
            ),
          ),
        );
      },
    );
  }
}

// ─── 3. Center AI Button (Elevated Primary Blue Circle with Sparkles) ───────
class _AnimatedCenterAiButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedCenterAiButton({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF035EC2),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF035EC2).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAiMagic,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(height: 2),
              Text(
                'AI Tutor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 4. Zankoline Animated Icon (Cap Toss & School Icon) ─────────────────────
class _AnimatedZankolineIcon extends StatefulWidget {
  final bool isSelected;
  const _AnimatedZankolineIcon({required this.isSelected});

  @override
  State<_AnimatedZankolineIcon> createState() => _AnimatedZankolineIconState();
}

class _AnimatedZankolineIconState extends State<_AnimatedZankolineIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedZankolineIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.isSelected
        ? const Color(0xFF035EC2)
        : (isDark ? Colors.grey[400]! : ZankoColors.textSecondary);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMortarboard02,
        color: color,
        size: 24,
      ),
    );
  }
}

// ─── 5. Profile Animated Icon (Spring Pop & Float) ──────────────────────────
class _AnimatedProfileIcon extends StatefulWidget {
  final bool isSelected;
  const _AnimatedProfileIcon({required this.isSelected});

  @override
  State<_AnimatedProfileIcon> createState() => _AnimatedProfileIconState();
}

class _AnimatedProfileIconState extends State<_AnimatedProfileIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.30)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.30, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_controller);

    _floatAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -4.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -4.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_controller);

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedProfileIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.isSelected
        ? ZankoColors.primary
        : (isDark ? Colors.grey[400]! : ZankoColors.textSecondary);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              color: color,
              size: 23,
            ),
          ),
        );
      },
    );
  }
}

// ─── Glass Button Widget ───────────────────────────────────────────────────
class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double size;

  const GlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF0F0F6),
          ),
          boxShadow: isDark ? [] : ZankoShadows.card,
        ),
        child: Center(child: child),
      ),
    );
  }
}

