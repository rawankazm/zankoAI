import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../theme.dart';

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
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : ZankoShadows.card),
        border: border ??
            Border.all(
              color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFF0F0F6),
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
  final IconData? icon;
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
          gradient: const LinearGradient(
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
                Icon(icon, color: Colors.white, size: 20),
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
            color: effectiveColor.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.8),
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
          color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFEFEFF7),
          width: 1,
        ),
      ),
      child: Center(
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.sparkles,
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
                  gradient: const LinearGradient(
                    colors: [ZankoColors.primary, ZankoColors.accent],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: ZankoShadows.glow,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_up,
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
      ..color = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFEFEFF7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * 3.141592653589793 * value;
    final activePaint = Paint()
      ..shader = const LinearGradient(
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

// ─── AI Hero Card ───────────────────────────────────────────────────────────
class AIHeroCard extends StatelessWidget {
  final VoidCallback onStartLearning;
  final Function(String action)? onQuickAction;

  const AIHeroCard({
    super.key,
    required this.onStartLearning,
    this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    return AppCard(
      padding: const EdgeInsets.all(20),
      color: isDark ? ZankoColors.darkCard : Colors.white,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Image.asset(
                  'assets/images/ai_robot_3d.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      CupertinoIcons.sparkles,
                      size: 48,
                      color: ZankoColors.primary,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.sparkles,
                          color: ZankoColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          langProvider.translate('ai_tutor'),
                          style: TextStyle(
          fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      langProvider.translate('ai_tutor_subtitle'),
                      style: TextStyle(
          fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.grey[300] : ZankoColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GradientButton(
                      text: langProvider.translate('start_learning'),
                      icon: CupertinoIcons.arrow_right,
                      height: 42,
                      onTap: onStartLearning,
                    ),
                  ],
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
  final IconData icon;
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
              color: isDark ? bgColor.withOpacity(0.2) : bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
  final IconData icon;
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
          color: color.withOpacity(isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? color.withOpacity(0.25) : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
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
  final IconData icon;
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
    required IconData icon,
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

    if (diffDays < 0) {
      text = 'تەواوبوو';
      badgeColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
      textColor = Colors.grey;
    } else if (diffDays == 0) {
      text = 'ئەمڕۆیە! ⚠️';
      badgeColor = const Color(0xFFFF3B30).withOpacity(0.15);
      textColor = const Color(0xFFFF3B30);
    } else if (diffDays <= 3) {
      text = '$diffDays ڕۆژی ماوە 🔥';
      badgeColor = const Color(0xFFFF9500).withOpacity(0.15);
      textColor = const Color(0xFFFF9500);
    } else {
      text = '$diffDays ڕۆژی ماوە';
      badgeColor = defaultColor.withOpacity(0.12);
      textColor = defaultColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withOpacity(0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradientStart, gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
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
                  icon: Icon(
                    CupertinoIcons.ellipsis_vertical,
                    color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                    size: 18,
                  ),
                  onSelected: (val) {
                    if (val == 'edit') onEdit?.call();
                    if (val == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.pencil, size: 16, color: ZankoColors.primary),
                            SizedBox(width: 8),
                            Text('دەستکاریکردنی وانە', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.trash, size: 16, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('سڕینەوەی وانە', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
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
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFEFEFF7),
                    valueColor: AlwaysStoppedAnimation<Color>(gradientStart),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
          fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey[300]! : ZankoColors.textSecondary,
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
                    label: 'میدترم',
                    examDate: midtermDate,
                    icon: CupertinoIcons.timer,
                    defaultColor: const Color(0xFF007AFF),
                    isDark: isDark,
                  ),
                if (finalDate != null)
                  _buildExamBadge(
                    context: context,
                    label: 'فایناڵ',
                    examDate: finalDate,
                    icon: CupertinoIcons.flag_fill,
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

// ─── Floating Glass Bottom Navigation Bar ────────────────────────────────────
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
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF161524).withOpacity(0.92)
                  : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.9),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context, 0, CupertinoIcons.house_fill, CupertinoIcons.house, langProvider.translate('nav_home')),
                _buildNavItem(context, 1, CupertinoIcons.book_fill, CupertinoIcons.book, langProvider.translate('nav_courses')),
                _buildCenterAiItem(2),
                _buildNavItem(context, 3, Icons.school_rounded, Icons.school_outlined, langProvider.translate('zankoline')),
                _buildNavItem(context, 4, CupertinoIcons.person_fill, CupertinoIcons.person, langProvider.translate('nav_profile')),
              ],
            ),


          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected
                    ? ZankoColors.primary
                    : (isDark ? Colors.grey[400]! : ZankoColors.textSecondary),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? ZankoColors.primary
                      : (isDark ? Colors.grey[400]! : ZankoColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAiItem(int index) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [ZankoColors.primary, ZankoColors.accent],
          ),
          shape: BoxShape.circle,
          boxShadow: ZankoShadows.floating,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: const Icon(
          CupertinoIcons.sparkles,
          color: Colors.white,
          size: 26,
        ),
      ),
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
            color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFF0F0F6),
          ),
          boxShadow: isDark ? [] : ZankoShadows.card,
        ),
        child: Center(child: child),
      ),
    );
  }
}

