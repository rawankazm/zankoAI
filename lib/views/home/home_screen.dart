import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../services/score_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../ai_teacher/ai_teacher_chat_screen.dart';
import '../ai_teacher/kurdish_voice_tutor_screen.dart';
import '../academic/seminar_thesis_assistant_screen.dart';
import '../academic/academic_dictionary_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../focus/pomodoro_timer_screen.dart';
import '../notifications/notifications_screen.dart';
import '../pdf/pdf_chat_screen.dart';
import '../profile/profile_screen.dart';
import '../gpa/gpa_tracker_screen.dart';
import '../quiz/ai_exam_generator_screen.dart';
import '../schedule/schedule_screen.dart';
import '../courses/course_detail_screen.dart';
import '../stats/stats_screen.dart';
import 'courses_screen.dart';
import '../../data/kurdistan_universities_data.dart';

// ─── Home Screen ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
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


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? 40.0 : 20.0;

    final langProvider = Provider.of<LanguageProvider>(context);
    final user = authService.currentUser;
    final isGuest = user == null ||
        user.isGuest ||
        user.name == 'مێوان' ||
        user.name == 'مێڤان' ||
        user.name == 'زائر' ||
        user.name.trim().toLowerCase() == 'guest';

    final userName = isGuest
        ? langProvider.translate('guest')
        : (user.name.trim().isNotEmpty && user.name.trim().toLowerCase() != 'student'
            ? user.name
            : langProvider.translate('student_role'));

    final userSubtitle = isGuest
        ? langProvider.translate('guest_account')
        : (user.universityName != null &&
                user.universityName!.trim().isNotEmpty &&
                user.universityName!.trim().toLowerCase() != 'zankoai student'
            ? KurdistanUniversitiesData.getLocalizedUniversityName(
                user.universityName!,
                langProvider.languageCode,
              )
            : langProvider.translate('zankoai_student_role'));

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
      child: Scaffold(
        backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header: Avatar, Greeting, Notifications & Search ───────────
              SliverToBoxAdapter(
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
                            // 3D Student Avatar
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => const ProfileScreen()),
                              ),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: (user?.photoUrl != null &&
                                          user!.photoUrl!.isNotEmpty &&
                                          !user.photoUrl!.contains('student_avatar_3d.png'))
                                      ? (user.photoUrl!.startsWith('http')
                                          ? Image.network(
                                              user.photoUrl!,
                                              width: 46,
                                              height: 46,
                                              fit: BoxFit.cover,
                                              errorBuilder: (ctx, err, stack) => Image.asset(
                                                'assets/images/student_avatar_3d.png',
                                                width: 46,
                                                height: 46,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Image.asset(user.photoUrl!, width: 46, height: 46, fit: BoxFit.cover))
                                      : Image.asset(
                                          'assets/images/student_avatar_3d.png',
                                          width: 46,
                                          height: 46,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                              const SizedBox(width: 12),
                              // User Name & Academic Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF17191F),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                      Text(
                                        userSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Notification bell
                              _NotificationBellButton(isDark: isDark),
                              const SizedBox(width: 8),
                              // Search button
                              _SearchButton(isDark: isDark),
                            ],
                          ),
                        ),
                      ],
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
                        const SizedBox(height: 8),
                        // ── 1. AI Hero Assistant Card ──────────────────────────
                        _staggered(
                          1,
                          AIHeroCard(
                            onStartLearning: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const AiTeacherChatScreen()),
                            ),
                            onQuickAction: (action) {
                              if (action == 'Voice Tutor') {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const KurdishVoiceTutorScreen()),
                                );
                              } else if (action == 'PDF Chat') {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const PdfChatScreen()),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const AiTeacherChatScreen()),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── 2. Continue Learning Section ───────────────────────
                        _staggered(
                          2,
                          _ContinueLearningSection(isDark: isDark),
                        ),
                        const SizedBox(height: 24),

                        // ── 3. Today's Progress Section ────────────────────────
                        _staggered(
                          3,
                          _TodayProgressSection(isDark: isDark),
                        ),
                        const SizedBox(height: 24),

                        // ── 4. Quick Tools Grid ────────────────────────────────
                        _staggered(
                          4,
                          _HomeQuickToolsSection(isDark: isDark),
                        ),
                        const SizedBox(height: 24),

                        // ── 5. Upcoming Tasks Section ──────────────────────────
                        _staggered(
                          5,
                          _UpcomingTasksSection(isDark: isDark),
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

// ─── Notification Bell Button ──────────────────────────────────────────────
class _NotificationBellButton extends StatelessWidget {
  final bool isDark;

  const _NotificationBellButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7),
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
            Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedNotification01,
                color: isDark ? Colors.white70 : ZankoColors.textSecondary,
                size: 20,
              ),
            ),
            if (user != null && !user.isGuest)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('direct_messages')
                    .where('userId', isEqualTo: user.id)
                    .snapshots(),
                builder: (context, dmSnap) {
                  bool hasUnread = false;
                  if (dmSnap.hasData) {
                    final normalizedEmail = user.email.trim().toLowerCase();
                    hasUnread = dmSnap.data!.docs.any((doc) {
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) return false;
                      final docUserId = (data['userId'] ?? data['user_id'] ?? data['recipientId'] ?? data['studentId'] ?? '').toString().trim();
                      final docEmail = (data['email'] ?? data['userEmail'] ?? '').toString().trim().toLowerCase();
                      final isMatch = (docUserId.isNotEmpty && docUserId == user.id) ||
                          (normalizedEmail.isNotEmpty && docEmail == normalizedEmail);
                      return isMatch && data['isRead'] != true;
                    });
                  }

                  if (!hasUnread) return const SizedBox.shrink();

                  return Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Timetable Button ───────────────────────────────────────────────────────
class _SearchButton extends StatelessWidget {
  final bool isDark;
  const _SearchButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const ScheduleScreen()),
      ),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF035EC2), Color(0xFF1A7FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF035EC2).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar03,
            color: Colors.white,
            size: 19,
          ),
        ),
      ),
    );
  }
}

class _HomeQuickToolsSection extends StatelessWidget {
  final bool isDark;
  const _HomeQuickToolsSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    final tools = [
      {
        'title': lang.translate('voice_tutor'),
        'subtitle': lang.translate('voice_tutor_sub'),
        'icon': HugeIcons.strokeRoundedMic01,
        'gradient': [const Color(0xFF035EC2), const Color(0xFF1E88E5)],
        'onTap': () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const KurdishVoiceTutorScreen())),
      },
      {
        'title': lang.translate('pdf_chat'),
        'subtitle': lang.translate('pdf_chat_sub'),
        'icon': HugeIcons.strokeRoundedFile02,
        'gradient': [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
        'onTap': () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const PdfChatScreen())),
      },
      {
        'title': lang.translate('nav_gpa'),
        'subtitle': lang.translate('gpa_sub'),
        'icon': HugeIcons.strokeRoundedAnalytics01,
        'gradient': [const Color(0xFFD97706), const Color(0xFFF59E0B)],
        'onTap': () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const GpaTrackerScreen())),
      },
      {
        'title': lang.translate('nav_quiz'),
        'subtitle': lang.translate('quiz_sub'),
        'icon': HugeIcons.strokeRoundedFlash,
        'gradient': [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
        'onTap': () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const AiExamGeneratorScreen())),
      },
      {
        'title': lang.translate('flashcards'),
        'subtitle': lang.translate('flashcards_sub'),
        'icon': HugeIcons.strokeRoundedLayers01,
        'gradient': [const Color(0xFF059669), const Color(0xFF10B981)],
        'onTap': () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const FlashcardsScreen())),
      },
      {
        'title': lang.translate('pomodoro_focus'),
        'subtitle': lang.translate('pomodoro_sub'),
        'icon': HugeIcons.strokeRoundedClock01,
        'gradient': [const Color(0xFFEA580C), const Color(0xFFFB923C)],
        'onTap': () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const PomodoroTimerScreen())),
      },
      {
        'title': lang.translate('academic_dictionary'),
        'subtitle': lang.translate('academic_dictionary_sub'),
        'icon': HugeIcons.strokeRoundedBook02,
        'gradient': [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
        'onTap': () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const AcademicDictionaryScreen())),
      },
      {
        'title': lang.translate('seminar_thesis_assistant'),
        'subtitle': lang.translate('seminar_thesis_sub'),
        'icon': HugeIcons.strokeRoundedNoteEdit,
        'gradient': [const Color(0xFF2563EB), const Color(0xFF60A5FA)],
        'onTap': () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const SeminarThesisAssistantScreen())),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.translate('quick_ai_tools'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF17191F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lang.translate('all_ai_tools_subtitle'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? ZankoColors.darkTextSecondary : ZankoColors.textSecondary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ZankoColors.primary.withValues(alpha: isDark ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ZankoColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedFlash,
                    color: ZankoColors.primary,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${tools.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ZankoColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2 Tools per Row (Large Modern Cards)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: tools.length,
          itemBuilder: (context, i) {
            final t = tools[i];
            final grad = t['gradient'] as List<Color>;
            final title = t['title'] as String;
            final subtitle = t['subtitle'] as String;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  (t['onTap'] as VoidCallback)();
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? ZankoColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? ZankoColors.darkBorder : const Color(0xFFE5EBF4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top row: Gradient icon & subtle indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? grad.map((c) => c.withValues(alpha: 0.90)).toList()
                                    : grad,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: grad.first.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: appIcon(t['icon'], color: Colors.white, size: 22),
                            ),
                          ),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F4F9),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Text Info (Title & Subtitle)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF151821),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              color: isDark ? ZankoColors.darkTextSecondary : ZankoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Continue Learning Section ─────────────────────────────────────────────
class _ContinueLearningSection extends StatelessWidget {
  final bool isDark;
  const _ContinueLearningSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    final courses = [
      {
        'title': 'Programming Fundamentals',
        'progress': 0.68,
        'completed': 12,
        'total': 18,
        'icon': HugeIcons.strokeRoundedCode,
      },
      {
        'title': 'Database Systems',
        'progress': 0.42,
        'completed': 8,
        'total': 19,
        'icon': HugeIcons.strokeRoundedDatabase,
      },
      {
        'title': 'Computer Networks',
        'progress': 0.81,
        'completed': 16,
        'total': 20,
        'icon': HugeIcons.strokeRoundedWifi01,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              langProvider.translate('continue_learning'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF17191F),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CoursesScreen()),
                );
              },
              child: Row(
                children: [
                  Text(
                    langProvider.translate('see_all'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF035EC2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 13,
                    color: Color(0xFF035EC2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: courses.length,
            separatorBuilder: (c, i) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = courses[index];
              final progress = (item['progress'] as double);
              final completed = item['completed'] as int;
              final total = item['total'] as int;
              final title = item['title'] as String;
              final icon = item['icon'];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => CourseDetailScreen(
                        courseTitle: title,
                        courseSubtitle: '$completed / $total lessons',
                        progress: progress,
                        icon: icon,
                        themeColor: const Color(0xFF035EC2),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF171B23) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF035EC2).withValues(alpha: 0.2)
                                  : const Color(0xFFE2EDFB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: appIcon(icon, color: const Color(0xFF035EC2), size: 18),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF035EC2).withValues(alpha: 0.2)
                                  : const Color(0xFFE2EDFB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF035EC2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF17191F),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? const Color(0xFF262C36)
                                  : const Color(0xFFECEEF2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF035EC2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$completed / $total lessons',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFA6ACB8)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF262C36)
                                      : const Color(0xFFF4F6F9),
                                  shape: BoxShape.circle,
                                ),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedArrowRight01,
                                  size: 12,
                                  color: isDark ? Colors.white : const Color(0xFF17191F),
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
            },
          ),
        ),
      ],
    );
  }
}

// ─── Today's Progress Section ──────────────────────────────────────────────
class _TodayProgressSection extends StatelessWidget {
  final bool isDark;
  const _TodayProgressSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final scoreService = Provider.of<ScoreService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              langProvider.translate('today_progress'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF17191F),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const StatsScreen()),
                );
              },
              child: Row(
                children: [
                  Text(
                    langProvider.translate('view_details'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF035EC2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 13,
                    color: Color(0xFF035EC2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF171B23) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Stat 1: Lessons completed
                    _buildStatCol(
                      value: '3',
                      label: langProvider.translate('lessons_completed'),
                      isDark: isDark,
                    ),
                    _buildVerticalDivider(isDark),
                    // Stat 2: Study time Today
                    _buildStatCol(
                      value: '2h 30m',
                      label: langProvider.translate('study_time_today'),
                      isDark: isDark,
                    ),
                    _buildVerticalDivider(isDark),
                    // Stat 3: Day streak
                    _buildStatCol(
                      value: '🔥 ${scoreService.streakCount > 0 ? scoreService.streakCount : 7}',
                      label: langProvider.translate('day_streak'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 3D Gold Trophy
              SizedBox(
                width: 52,
                height: 52,
                child: Image.asset(
                  'assets/images/trophy.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF9E7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFE4D27D),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCol({
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF17191F),
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10,
                height: 1.15,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
    );
  }
}

// ─── Upcoming Tasks Section ────────────────────────────────────────────────
class _UpcomingTasksSection extends StatelessWidget {
  final bool isDark;
  const _UpcomingTasksSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    final tasks = [
      {
        'title': 'Data Structures Assignment',
        'due': 'Due tomorrow, 11:59 PM',
        'priority': langProvider.translate('high_priority'),
        'isHigh': true,
        'icon': HugeIcons.strokeRoundedFile02,
      },
      {
        'title': 'Database Quiz',
        'due': 'Due in 2 days',
        'priority': langProvider.translate('medium_priority'),
        'isHigh': false,
        'icon': HugeIcons.strokeRoundedHelpCircle,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              langProvider.translate('upcoming_tasks'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF17191F),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const ScheduleScreen()),
                );
              },
              child: Row(
                children: [
                  Text(
                    langProvider.translate('see_all'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF035EC2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 13,
                    color: Color(0xFF035EC2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final isHigh = task['isHigh'] as bool;
            final icon = task['icon'];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF171B23) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isHigh
                          ? (isDark
                              ? const Color(0xFF035EC2).withValues(alpha: 0.2)
                              : const Color(0xFFE2EDFB))
                          : (isDark
                              ? const Color(0xFFE4D27D).withValues(alpha: 0.2)
                              : const Color(0xFFFEF9E7)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: appIcon(
                        icon,
                        color: isHigh ? const Color(0xFF035EC2) : const Color(0xFFB8860B),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title'] as String,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF17191F),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          task['due'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHigh
                          ? const Color(0xFFE2EDFB)
                          : const Color(0xFFFEF9E7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task['priority'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isHigh ? const Color(0xFF035EC2) : const Color(0xFFB8860B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 14,
                    color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
