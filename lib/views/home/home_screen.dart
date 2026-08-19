import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../services/score_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../../widgets/ad_banner_widget.dart';
import '../ai_teacher/ai_teacher_chat_screen.dart';
import '../academic/seminar_thesis_assistant_screen.dart';
import '../academic/academic_dictionary_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../focus/pomodoro_timer_screen.dart';
import '../notifications/notifications_screen.dart';
import '../pdf/pdf_chat_screen.dart';
import '../pdf/audio_summarizer_view.dart';
import '../profile/profile_screen.dart';

import '../gpa/gpa_tracker_screen.dart';
import '../quiz/ai_exam_generator_screen.dart';
import '../quiz/quiz_screen.dart';
import '../schedule/schedule_screen.dart';
import '../payment/vip_upgrade_sheet.dart';

// ─── Home Screen ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _gpaController;
  late Animation<double> _gpaAnimation;
  final TextEditingController _searchController = TextEditingController();

  // Demo data
  final double _gpaValue = 0.0;
  final double _maxGpa = 4.0;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _gpaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _gpaAnimation = Tween<double>(begin: 0.0, end: _gpaValue / _maxGpa).animate(
      CurvedAnimation(parent: _gpaController, curve: Curves.easeOutCubic),
    );

    _gpaController.forward();
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _gpaController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.06).clamp(0.0, 0.65);
    final end = (start + 0.35).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - animation.value) * 26),
            child: child,
          ),
        );
      },
    );
  }

  String _greeting(LanguageProvider langProvider) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return langProvider.translate('greeting_morning');
    } else if (hour >= 12 && hour < 17) {
      return langProvider.translate('greeting_afternoon');
    } else if (hour >= 17 && hour < 22) {
      return langProvider.translate('greeting_evening');
    } else {
      return langProvider.translate('greeting_night');
    }
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
    final gpa = user?.gpa ?? 0.0;

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
              // ── Header & Dynamic Island (Feature 4) ──────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _staggered(
                          0,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const ProfileScreen()),
                                ),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [ZankoColors.primary, ZankoColors.accent],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: ZankoColors.primary.withValues(alpha: 0.35),
                                        blurRadius: 10,
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
                                        fontSize: 17,
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
                                      '${_greeting(langProvider)} 👋',
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
                                        fontSize: 17,
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
                        // ── 1. AI Search Bar ──────────────────────────────────
                        _staggered(
                          1,
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
                        ),
                        const SizedBox(height: 12),

                        // ── 2. VIP Upgrade Promo Card ──────────────────────────
                        _staggered(
                          2,
                          _VipPromoCard(
                            isDark: isDark,
                            isVip: user?.isVip ?? false,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── 3. AI Hero Assistant Card ──────────────────────────
                        _staggered(
                          3,
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
                                  CupertinoPageRoute(builder: (_) => const AudioSummarizerView()),
                                );
                              } else if (action == 'PDF Chat') {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const PdfChatScreen()),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── 4. Daily Streak Flame Card ─────────────────────────
                        _staggered(
                          4,
                          _DailyStreakFlameCard(isDark: isDark),
                        ),
                        const SizedBox(height: 12),

                        // ── 5. GPA Tracker & Scores ────────────────────────────
                        _staggered(
                          5,
                          _GpaSection(
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
                        const SizedBox(height: 20),

                        // ── 6. Academic AI Tools Grid ──────────────────────────
                        _staggered(
                          6,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: t('quick_ai_tools'),
                                isDark: isDark,
                              ),
                              const SizedBox(height: 14),
                              _QuickAiToolsGrid(isDark: isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── 7. Sponsor Ad Banner ───────────────────────────────
                        _staggered(
                          7,
                          const AdBannerWidget(screenName: 'home'),
                        ),
                        const SizedBox(height: 100),
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
                  decoration: BoxDecoration(
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
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ZankoColors.textPrimary,
              letterSpacing: -0.4,
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
                gradient: LinearGradient(
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
                                valueColor: AlwaysStoppedAnimation<Color>(
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
              child: Icon(
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
    final scoreService = ScoreService.instance;

    return ListenableBuilder(
      listenable: scoreService,
      builder: (context, _) {
        final totalScore = scoreService.totalScore100;
        final quizScore = scoreService.quizScore40.toStringAsFixed(1);
        final examScore = scoreService.examScore60.toStringAsFixed(1);

        String statusText;
        if (totalScore == 0) {
          statusText = 'دەستپێنەکراوە 🎯';
        } else if (totalScore >= 85) {
          statusText = 'زۆر باشە ✨';
        } else if (totalScore >= 70) {
          statusText = 'باشە ⭐';
        } else {
          statusText = 'پێویستی بە ڕاهێنانە 📈';
        }

        return AnimatedScaleButton(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [ZankoColors.darkCardSecondary, const Color(0xFF171033), const Color(0xFF0F172A)]
                    : [Colors.white, const Color(0xFFF3F4F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: ZankoColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: ZankoColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: ZankoColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ئاستی تاقیکردنەوەکان',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ZankoColors.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: totalScore > 0 ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: totalScore > 0 ? const Color(0xFF10B981) : Colors.amber[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$totalScore',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '/ 100 نمرە',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            color: totalScore > 0 ? const Color(0xFFFFB800) : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              totalScore == 0
                                  ? 'کویز: (٤٠ نمرە) • تاقیکردنەوە: (٦٠ نمرە)'
                                  : 'کویز: $quizScore/40 • تاقیکردنەوە: $examScore/60',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                ProgressRing(
                  value: totalScore / 100.0,
                  title: '$totalScore%',
                  subtitle: 'نمرە',
                  size: 92,
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Quick AI Tools ───────────────────────────────────────────────────────
class _QuickAiToolsGrid extends StatelessWidget {
  final bool isDark;

  const _QuickAiToolsGrid({required this.isDark});

  void _showExamOrQuizSelection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Directionality(
          textDirection: langProvider.textDirection,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'تاقیکردنەوە و کویزی AI 🎯',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'جۆری ئەو تاقیکردنەوەیە دیاری بکە کە دەتەوێت دروستی بکەیت:',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Option 1: Exams (تاقیکردنەوەکان)
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const AiExamGeneratorScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9F0A).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F0A).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.doc_text_fill,
                            color: Color(0xFFFF9F0A),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تاقیکردنەوەکان (Exams)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'دروستکردنی تاقیکردنەوەی ئەزموونی و فۆرماتدار بە کات و ئاستی جیاواز',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(CupertinoIcons.chevron_forward, color: Color(0xFFFF9F0A)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Option 2: Quizzes (کویزەکان)
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const QuizScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ZankoColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ZankoColors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ZankoColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.question_square_fill,
                            color: ZankoColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'کویزەکان (Quizzes)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'دروستکردنی کویزی خێرا بەپێی بابەت یان بە فایلی PDF',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_forward, color: ZankoColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    final tools = [
      _ToolData(
        icon: CupertinoIcons.book_fill,
        title: 'سیمینار و ڕاپۆرت',
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const SeminarThesisAssistantScreen()),
        ),
      ),
      _ToolData(
        icon: CupertinoIcons.sparkles,
        title: 'تاقیکردنەوە و کویز',
        color: const Color(0xFFFF9F0A),
        onTap: () => _showExamOrQuizSelection(context),
      ),
      _ToolData(
        icon: CupertinoIcons.doc_richtext,
        title: langProvider.translate('pdf_chat'),
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const PdfChatScreen()),
        ),
      ),
      _ToolData(
        icon: CupertinoIcons.mic_fill,
        title: langProvider.translate('voice_tutor'),
        color: ZankoColors.accent,
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const AudioSummarizerView()),
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
      _ToolData(
        icon: CupertinoIcons.calendar_today,
        title: langProvider.translate('schedule_title'),
        color: ZankoColors.primary,
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const ScheduleScreen()),
        ),
      ),
      _ToolData(
        icon: CupertinoIcons.timer,
        title: 'کاتژمێری تەرکیز',
        color: const Color(0xFFF43F5E),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const PomodoroTimerScreen()),
        ),
      ),
      _ToolData(
        icon: CupertinoIcons.textbox,
        title: 'فەرهەنگی زاراوەکان',
        color: const Color(0xFF06B6D4),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const AcademicDictionaryScreen()),
        ),
      ),
    ];


    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B192C) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: data.color.withValues(alpha: isDark ? 0.35 : 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: data.color.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: data.color.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(data.icon, color: data.color, size: 26),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
                letterSpacing: -0.3,
                height: 1.2,
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

  const _TodayProgress({required this.isDark});

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
    final scoreService = ScoreService.instance;

    return ListenableBuilder(
      listenable: scoreService,
      builder: (context, _) {
        final studyMins = scoreService.todayStudyMinutes;
        final questionsCount = scoreService.totalQuestionsAnswered;
        final accuracyPercent = (scoreService.overallAccuracy * 100).toInt();

        final stats = [
          _StatItem(
            icon: CupertinoIcons.clock,
            value: '${studyMins}m',
            label: 'Study Time',
            color: const Color(0xFF6C5CE7),
          ),
          _StatItem(
            icon: CupertinoIcons.question_diamond,
            value: '$questionsCount',
            label: 'Questions',
            color: ZankoColors.accent,
          ),
          _StatItem(
            icon: CupertinoIcons.check_mark_circled,
            value: '$accuracyPercent%',
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
      },
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




// ─── Dynamic Island / Live Activity Pill (Feature 4) ─────────────────────────
class _DynamicIslandPill extends StatefulWidget {
  final bool isDark;
  final String userName;
  final String greeting;

  const _DynamicIslandPill({
    required this.isDark,
    required this.userName,
    required this.greeting,
  });

  @override
  State<_DynamicIslandPill> createState() => _DynamicIslandPillState();
}

class _DynamicIslandPillState extends State<_DynamicIslandPill> {
  int _stateIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (mounted) {
        setState(() => _stateIndex = (_stateIndex + 1) % 3);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (_stateIndex == 0) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const AiTeacherChatScreen()),
      );
    } else if (_stateIndex == 1) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const PomodoroTimerScreen()),
      );
    } else {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const AiExamGeneratorScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String text;
    IconData icon;
    Color accentColor;

    if (_stateIndex == 0) {
      text = '${widget.greeting} ${widget.userName} • کاتی سەرکەوتنە ✨';
      icon = CupertinoIcons.sparkles;
      accentColor = const Color(0xFFFFD700);
    } else if (_stateIndex == 1) {
      text = 'فۆکەسی خوێندن • دەستپێکردنی خولی ٢٥ خولەکی 🍅';
      icon = CupertinoIcons.timer;
      accentColor = const Color(0xFFFF453A);
    } else {
      text = 'تاقیکردنەوە نزیکە • بەرهەمهێنانی کویزی زیرەک ⚡';
      icon = CupertinoIcons.bolt_badge_a_fill;
      accentColor = const Color(0xFF6C5CE7);
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: widget.isDark
              ? ZankoColors.darkCardSecondary.withValues(alpha: 0.95)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 15, color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  text,
                  key: ValueKey<int>(_stateIndex),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_left,
              size: 13,
              color: widget.isDark ? Colors.grey[400] : ZankoColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Daily Study Streak & Fire Animation Card (Feature 3) ────────────────────
class _DailyStreakFlameCard extends StatefulWidget {
  final bool isDark;
  const _DailyStreakFlameCard({required this.isDark});

  @override
  State<_DailyStreakFlameCard> createState() => _DailyStreakFlameCardState();
}

class _DailyStreakFlameCardState extends State<_DailyStreakFlameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flameController;
  late Animation<double> _flameScale;
  int _streakDays = 3;
  int _streakXp = 150;
  bool _claimedToday = false;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _flameScale = Tween<double>(begin: 0.92, end: 1.15).animate(
      CurvedAnimation(parent: _flameController, curve: Curves.easeInOutSine),
    );

    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString('last_streak_date');
    final count = prefs.getInt('study_streak_count') ?? 3;
    final xp = prefs.getInt('study_streak_xp') ?? 150;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (mounted) {
      setState(() {
        _streakDays = count;
        _streakXp = xp;
        _claimedToday = (lastDateStr == todayStr);
      });
    }
  }

  Future<void> _claimDailyStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (!_claimedToday) {
      final newStreak = _streakDays + 1;
      final newXp = _streakXp + 50;
      await prefs.setString('last_streak_date', todayStr);
      await prefs.setInt('study_streak_count', newStreak);
      await prefs.setInt('study_streak_xp', newXp);
      if (mounted) {
        setState(() {
          _streakDays = newStreak;
          _streakXp = newXp;
          _claimedToday = true;
        });
      }
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _flameController.dispose();
    super.dispose();
  }

  void _showStreakModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StreakCelebrationSheet(
        streakDays: _streakDays,
        streakXp: _streakXp,
        claimedToday: _claimedToday,
        isDark: widget.isDark,
        onClaim: () {
          _claimDailyStreak();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showStreakModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isDark
                ? [const Color(0xFF1E102F), const Color(0xFF2D124D)]
                : [const Color(0xFFFFF4E5), const Color(0xFFFFECE0)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFFF6B00).withValues(alpha: widget.isDark ? 0.4 : 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Animated Flame Icon
            AnimatedBuilder(
              animation: _flameScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _flameScale.value,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Text('🔥', style: TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$_streakDays ڕۆژ بەردەوامی لە خوێندن!',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white : const Color(0xFF803000),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '+$_streakXp XP',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFB800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _claimedToday
                        ? 'پاداشتی ئەمڕۆت وەرگرتووە • سبەی بەردەوام بە! 🎯'
                        : 'کلیک بکە بۆ وەرگرتنی +50 XP ڕۆژانە! 🎁',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.grey[300] : const Color(0xFFA04500),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_left,
              color: Color(0xFFFF6B00),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Streak Celebration Bottom Sheet ─────────────────────────────────────────
class _StreakCelebrationSheet extends StatelessWidget {
  final int streakDays;
  final int streakXp;
  final bool claimedToday;
  final bool isDark;
  final VoidCallback onClaim;

  const _StreakCelebrationSheet({
    required this.streakDays,
    required this.streakXp,
    required this.claimedToday,
    required this.isDark,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final daysOfWeek = ['شەممە', '١شەممە', '٢شەممە', '٣شەممە', '٤شەممە', 'پێنجشەممە', 'هەینی'];
    final currentDayIndex = (DateTime.now().weekday + 1) % 7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text('🔥', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 10),
          Text(
            '$streakDays ڕۆژ بەردەوامی لەسەریەک!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ZankoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ڕۆژانە بەکارهێنانی ZankoAI نمرەکانت بەرز دەکاتەوە و XP کۆدەکاتەوە.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : ZankoColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // 7-day progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isPassedOrToday = index <= currentDayIndex;
              return Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isPassedOrToday
                          ? const Color(0xFFFF6B00)
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0F0F8)),
                      shape: BoxShape.circle,
                      boxShadow: isPassedOrToday
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Icon(
                        isPassedOrToday ? CupertinoIcons.checkmark : CupertinoIcons.flame,
                        color: isPassedOrToday
                            ? Colors.white
                            : (isDark ? Colors.grey[600] : Colors.grey[400]),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    daysOfWeek[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 28),
          GradientButton(
            text: claimedToday ? 'ئەمڕۆ پاداشت وەرگیراوە ✅' : 'وەرگرتنی +50 XP 🎁',
            onTap: claimedToday ? () => Navigator.pop(context) : onClaim,
          ),
        ],
      ),
    );
  }
}

// ── VIP Promotion Card Component ──────────────────────────────────────────────
class _VipPromoCard extends StatelessWidget {
  final bool isDark;
  final bool isVip;

  const _VipPromoCard({
    required this.isDark,
    required this.isVip,
  });

  @override
  Widget build(BuildContext context) {
    if (isVip) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1602), Color(0xFF2C2003)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Text('👑', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ئەندامی نایابی VIP 🌟',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD700),
                      fontSize: 13.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'هەموو تایبەتمەندییە ئەکادیمییەکان بە بێسنوور بۆت کراوەیە',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => VipUpgradeSheet.show(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C1300), Color(0xFF2E2002), Color(0xFF422E04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.18),
              blurRadius: 16,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('👑', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ئەندامێتی VIP بەدەستبهێنە 🔥',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ڕاپۆرت و سێمینار، پێشبینی تاقیکردنەوە، چاتی بێسنوور',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'نوێکردنەوە',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2C1F00),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFFFFD700), size: 13),
                      SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Word و PPTX',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFFFFD700), size: 13),
                      SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'پێشبینی فاینەڵ',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '٥,٠٠٠ د.ع',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
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

