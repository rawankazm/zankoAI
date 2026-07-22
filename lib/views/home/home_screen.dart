import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../ai_teacher/ai_teacher_chat_screen.dart';
import '../courses/course_detail_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../focus/focus_screen.dart';
import '../gpa/gpa_tracker_screen.dart';
import '../notifications/notifications_screen.dart';
import '../pdf/pdf_chat_screen.dart';
import '../profile/profile_screen.dart';
import '../quiz/quiz_screen.dart';
import '../schedule/schedule_screen.dart';

// ─── Home Screen ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _gpaController;
  late Animation<double> _gpaAnimation;
  final TextEditingController _searchController = TextEditingController();

  // Demo data
  final double _gpaValue = 3.65;
  final double _maxGpa = 4.0;

  @override
  void initState() {
    super.initState();

    _gpaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _gpaAnimation = Tween<double>(begin: 0.0, end: _gpaValue / _maxGpa).animate(
      CurvedAnimation(parent: _gpaController, curve: Curves.easeOutCubic),
    );

    _gpaController.forward();
  }

  @override
  void dispose() {
    _gpaController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? 40.0 : 20.0;

    String t(String key) => langProvider.translate(key);
    final user = authService.currentUser;
    final userName = user?.name ?? 'Student';
    final gpa = user?.gpa ?? 3.65;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.dark,
              statusBarIconBrightness: Brightness.light,
              statusBarColor: Colors.transparent,
            )
          : const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
              statusBarColor: Colors.transparent,
            ),
      child: Directionality(
        textDirection: langProvider.textDirection,
        child: Scaffold(
          backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Floating Header ─────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                systemOverlayStyle: isDark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                primary: true,
                flexibleSpace: SafeArea(
                  top: true,
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const ProfileScreen()),
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [ZankoColors.primary, ZankoColors.accent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: ZankoColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (userName.isNotEmpty ? userName[0] : 'S').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Greeting + Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_greeting()} 👋',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : ZankoColors.textSecondary,
                                ),
                              ),
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Notification bell
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const NotificationsScreen()),
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? ZankoColors.darkCard
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFEFEFF7),
                                width: 1,
                              ),
                              boxShadow: isDark
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Stack(
                              children: [
                                const Center(
                                  child: Icon(
                                    CupertinoIcons.bell,
                                    color: ZankoColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: ZankoColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Main Scrollable Content ────────────────────────────────────
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── AI Search Bar ──────────────────────────────────────
                        _AiSearchBar(
                          controller: _searchController,
                          isDark: isDark,
                          onSubmitted: (query) {
                            if (query.trim().isNotEmpty) {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => const AiTeacherChatScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── AI Hero Card ───────────────────────────────────────
                        AIHeroCard(
                          onStartLearning: () => Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const AiTeacherChatScreen()),
                          ),
                          onQuickAction: (action) {
                            if (action == 'Explain' || action == 'Summarize') {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => const AiTeacherChatScreen()),
                              );
                            } else if (action == 'Voice Tutor') {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => const FocusScreen()),
                              );
                            } else if (action == 'PDF Chat') {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => const PdfChatScreen()),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 32),

                        // ── Continue Learning ──────────────────────────────────
                        _SectionHeader(
                          title: t('continue_learning'),
                          actionText: t('see_all'),
                          isDark: isDark,
                          onAction: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const ScheduleScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ContinueLearningCard(
                          isDark: isDark,
                          progress: 0.76,
                          courseTitle: 'Calculus & Linear Algebra',
                          lessonInfo: '18 Lessons • Chapter 4',
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => CourseDetailScreen(
                                courseTitle: 'Calculus & Linear Algebra',
                                courseSubtitle: '18 Lessons • Chapter 4',
                                progress: 0.76,
                                icon: CupertinoIcons.function,
                                themeColor: ZankoColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Current GPA ────────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _GpaSection(
                                gpa: gpa,
                                maxGpa: _maxGpa,
                                isDark: isDark,
                                gpaAnimation: _gpaAnimation,
                                onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const GpaTrackerScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // ── Quick AI Tools ─────────────────────────────────────
                        _SectionHeader(
                          title: t('quick_ai_tools'),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        _QuickAiToolsGrid(isDark: isDark),
                        const SizedBox(height: 32),

                        // ── Today's Progress ───────────────────────────────────
                        _SectionHeader(
                          title: t('todays_progress'),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        _TodayProgress(
                          isDark: isDark,
                          studyMinutes: 47,
                          questionsAnswered: 12,
                          accuracy: 0.83,
                        ),
                        const SizedBox(height: 32),

                        // ── Recommended Courses ────────────────────────────────
                        _SectionHeader(
                          title: t('recommended_courses'),
                          actionText: t('see_all'),
                          isDark: isDark,
                          onAction: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SizedBox(
                          height: 230,
                          child: _RecommendedCoursesScroll(),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── AI Search Bar ─────────────────────────────────────────────────────────
class _AiSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onSubmitted;

  const _AiSearchBar({
    required this.controller,
    required this.isDark,
    required this.onSubmitted,
  });

  @override
  State<_AiSearchBar> createState() => _AiSearchBarState();
}

class _AiSearchBarState extends State<_AiSearchBar> with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          height: 58,
          decoration: BoxDecoration(
            color: widget.isDark
                ? ZankoColors.darkCard
                : Colors.white,
            borderRadius: BorderRadius.circular(ZankoRadius.input),
            border: Border.all(
              color: _isFocused
                  ? ZankoColors.primary.withValues(alpha: _glowAnimation.value * 0.5)
                  : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFEFEFF7)),
              width: 1.5,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: ZankoColors.primary.withValues(alpha: 0.15 * _glowAnimation.value),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: widget.isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 18),
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Icon(
                    CupertinoIcons.sparkles,
                    color: ZankoColors.primary.withValues(alpha: _glowAnimation.value),
                    size: 20,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onSubmitted: widget.onSubmitted,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white : ZankoColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask AI anything...',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark
                          ? Colors.grey[500]
                          : ZankoColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (widget.controller.text.trim().isNotEmpty) {
                    widget.onSubmitted(widget.controller.text.trim());
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ZankoColors.primary, ZankoColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
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
        );
      },
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final bool isDark;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionText,
    required this.isDark,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        if (actionText != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: ZankoColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                actionText!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ZankoColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Continue Learning Card ────────────────────────────────────────────────
class _ContinueLearningCard extends StatefulWidget {
  final bool isDark;
  final double progress;
  final String courseTitle;
  final String lessonInfo;
  final VoidCallback onTap;

  const _ContinueLearningCard({
    required this.isDark,
    required this.progress,
    required this.courseTitle,
    required this.lessonInfo,
    required this.onTap,
  });

  @override
  State<_ContinueLearningCard> createState() => _ContinueLearningCardState();
}

class _ContinueLearningCardState extends State<_ContinueLearningCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: widget.progress).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScaleButton(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(ZankoRadius.card),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF0F0F6),
            width: 1,
          ),
          boxShadow: widget.isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : ZankoShadows.card,
        ),
        child: Row(
          children: [
            // Course icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ZankoColors.primary, ZankoColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(CupertinoIcons.function, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 18),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.courseTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : ZankoColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.lessonInfo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.grey[400]! : ZankoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progressAnimation.value,
                                minHeight: 6,
                                backgroundColor: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFEFEFF7),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  ZankoColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(_progressAnimation.value * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark ? Colors.grey[300] : ZankoColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ZankoColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                CupertinoIcons.chevron_forward,
                color: ZankoColors.primary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── GPA Section ────────────────────────────────────────────────────────────
class _GpaSection extends StatelessWidget {
  final double gpa;
  final double maxGpa;
  final bool isDark;
  final Animation<double> gpaAnimation;
  final VoidCallback onTap;

  const _GpaSection({
    required this.gpa,
    required this.maxGpa,
    required this.isDark,
    required this.gpaAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScaleButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E1C30), const Color(0xFF161524)]
                : [Colors.white, const Color(0xFFF8F8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(ZankoRadius.card),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF0F0F6),
            width: 1,
          ),
          boxShadow: isDark ? [] : ZankoShadows.card,
        ),
        child: Row(
          children: [
            // Progress Ring
            AnimatedBuilder(
              animation: gpaAnimation,
              builder: (context, child) {
                return ProgressRing(
                  value: gpaAnimation.value,
                  title: gpa.toStringAsFixed(2),
                  subtitle: 'GPA',
                  size: 110,
                );
              },
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current GPA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400]! : ZankoColors.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.star_fill,
                        color: Color(0xFFFF9F0A),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Excellent',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${gpa.toStringAsFixed(2)} / ${maxGpa.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[500]! : ZankoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: ZankoColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.arrow_up_right,
                            color: ZankoColors.primary, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Top 5% of class',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ZankoColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick AI Tools ───────────────────────────────────────────────────────
class _QuickAiToolsGrid extends StatelessWidget {
  final bool isDark;

  const _QuickAiToolsGrid({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ToolData(
        icon: CupertinoIcons.doc_richtext,
        title: 'PDF Chat',
        color: const Color(0xFF4ADE80),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const PdfChatScreen()),
        ),
      ),
      _ToolData(
        icon: CupertinoIcons.mic,
        title: 'Voice Tutor',
        color: const Color(0xFFC084FC),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const FocusScreen()),
        ),
      ),
      _ToolData(
        icon: CupertinoIcons.square_list_fill,
        title: 'Quiz Generator',
        color: const Color(0xFFFF9F0A),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const QuizScreen()),
        ),
      ),
      _ToolData(
        icon: CupertinoIcons.tray_full,
        title: 'Flashcards',
        color: const Color(0xFF60A5FA),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const FlashcardsScreen()),
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: tools.length,
      itemBuilder: (_, i) => _ToolCard(data: tools[i], isDark: isDark),
    );
  }
}

class _ToolData {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ToolData({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}

class _ToolCard extends StatelessWidget {
  final _ToolData data;
  final bool isDark;

  const _ToolCard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedScaleButton(
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(ZankoRadius.card),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF0F0F6),
            width: 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? data.color.withValues(alpha: 0.2)
                    : data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(data.icon, color: data.color, size: 22),
            ),
            Text(
              data.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Today's Progress ──────────────────────────────────────────────────────
class _TodayProgress extends StatefulWidget {
  final bool isDark;
  final int studyMinutes;
  final int questionsAnswered;
  final double accuracy;

  const _TodayProgress({
    required this.isDark,
    required this.studyMinutes,
    required this.questionsAnswered,
    required this.accuracy,
  });

  @override
  State<_TodayProgress> createState() => _TodayProgressState();
}

class _TodayProgressState extends State<_TodayProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(
        icon: CupertinoIcons.clock,
        value: '${widget.studyMinutes}m',
        label: 'Study Time',
        color: const Color(0xFF6C5CE7),
      ),
      _StatItem(
        icon: CupertinoIcons.question_diamond,
        value: '${widget.questionsAnswered}',
        label: 'Questions',
        color: const Color(0xFF38BDF8),
      ),
      _StatItem(
        icon: CupertinoIcons.check_mark_circled,
        value: '${(widget.accuracy * 100).toInt()}%',
        label: 'Accuracy',
        color: const Color(0xFF4ADE80),
      ),
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(ZankoRadius.card),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF0F0F6),
            width: 1,
          ),
          boxShadow: widget.isDark ? [] : ZankoShadows.card,
        ),
        child: Row(
          children: stats
              .map(
                (s) => Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? s.color.withValues(alpha: 0.2)
                              : s.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(s.icon, color: s.color, size: 18),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.value,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark ? Colors.white : ZankoColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : ZankoColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

// ─── Recommended Courses Horizontal Scroll ────────────────────────────────
class _RecommendedCoursesScroll extends StatelessWidget {
  const _RecommendedCoursesScroll();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final courses = [
      _CourseData(
        title: 'Machine Learning',
        subtitle: '12 Lessons',
        progress: 0.80,
        icon: CupertinoIcons.sparkles,
        color: const Color(0xFFAF52DE),
      ),
      _CourseData(
        title: 'Data Structures',
        subtitle: '24 Lessons',
        progress: 0.45,
        icon: CupertinoIcons.square_grid_2x2,
        color: const Color(0xFF007AFF),
      ),
      _CourseData(
        title: 'Python & Data Science',
        subtitle: '20 Lessons',
        progress: 0.60,
        icon: CupertinoIcons.chevron_left_slash_chevron_right,
        color: const Color(0xFFFF9F0A),
      ),
      _CourseData(
        title: 'Operating Systems',
        subtitle: '15 Lessons',
        progress: 0.90,
        icon: CupertinoIcons.device_desktop,
        color: const Color(0xFF34C759),
      ),
    ];

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: courses.length,
      separatorBuilder: (context2, index) => const SizedBox(width: 14),
      itemBuilder: (_, i) {
        final c = courses[i];
        return _RecommendedCourseCard(
          data: c,
          isDark: isDark,
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => CourseDetailScreen(
                courseTitle: c.title,
                courseSubtitle: c.subtitle,
                progress: c.progress,
                icon: c.icon,
                themeColor: c.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CourseData {
  final String title;
  final String subtitle;
  final double progress;
  final IconData icon;
  final Color color;

  const _CourseData({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.icon,
    required this.color,
  });
}

class _RecommendedCourseCard extends StatelessWidget {
  final _CourseData data;
  final bool isDark;
  final VoidCallback onTap;

  const _RecommendedCourseCard({
    required this.data,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScaleButton(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(ZankoRadius.card),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF0F0F6),
            width: 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [data.color, data.color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(data.icon, color: Colors.white, size: 24),
            ),
            const Spacer(),
            Text(
              data.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              data.subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400]! : ZankoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: data.progress,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFFEFEFF7),
                      valueColor: AlwaysStoppedAnimation<Color>(data.color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(data.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[300]! : ZankoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
