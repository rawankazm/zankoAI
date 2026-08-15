import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../services/database_service.dart';
import '../ai_teacher/ai_teacher_screen.dart';
import '../auth/login_screen.dart';
import 'teacher_quiz_create_screen.dart';
import 'teacher_courses_screen.dart';
import 'teacher_students_screen.dart';
import 'teacher_enrollments_screen.dart';
import 'teacher_analytics_screen.dart';
import 'teacher_lectures_screen.dart';
import 'teacher_announcements_screen.dart';
import '../../theme.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Provider.of<LanguageProvider>(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DatabaseService>(context);
    String t(String key) => lang.translate(key);
    final user = auth.currentUser;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'چوونەدەرەوە / Logout',
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF9C27B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t('teacher_welcome'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    user?.name ?? 'مامۆستا د. سارا محمد',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Directionality(
              textDirection: lang.textDirection,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Stats Overview Cards ─────────────────────
                    _StatsRow(t: t, theme: theme, db: db),
                    const SizedBox(height: 28),

                    // ─── Core Teacher Modules ──────────────────────
                    Text(
                      'داشبۆردی مامۆستا (Teacher Core Hub)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _QuickActionsGrid(t: t, theme: theme),
                    const SizedBox(height: 28),

                    // ─── Recent Activity Stream ───────────────────
                    Text(
                      t('teacher_recent_activity'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _RecentActivityList(theme: theme, lang: lang),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String Function(String) t;
  final ThemeData theme;
  final DatabaseService db;
  const _StatsRow({required this.t, required this.theme, required this.db});

  @override
  Widget build(BuildContext context) {
    final stats = [
      {
        'value': '124',
        'label': t('teacher_stats_students'),
        'icon': Icons.people_alt_rounded,
        'color': const Color(0xFF2196F3)
      },
      {
        'value': '${db.lectures.length + 3}',
        'label': t('teacher_stats_lectures'),
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF059669)
      },
      {
        'value': '${db.quizzes.length + 2}',
        'label': t('teacher_stats_quizzes'),
        'icon': Icons.quiz_rounded,
        'color': const Color(0xFFFF9800)
      },
      {
        'value': '${db.announcements.length + 2}',
        'label': t('teacher_stats_announcements'),
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFFE11D48)
      },
    ];

    return Row(
      children: stats.map((s) {
        final color = s['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Icon(s['icon'] as IconData, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  s['value'] as String,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Quick Actions Grid ────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  final String Function(String) t;
  final ThemeData theme;
  const _QuickActionsGrid({required this.t, required this.theme});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'label': t('teacher_analytics_title'),
        'sublabel': 'ئاماری گشتی و دابەشبوونی نمرەکان',
        'icon': Icons.insights_rounded,
        'color': ZankoColors.primary,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAnalyticsScreen())),
      },
      {
        'label': t('teacher_lectures_title'),
        'sublabel': 'بارکردنی PDF، PPT و Video',
        'icon': Icons.cloud_upload_rounded,
        'color': const Color(0xFF059669),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherLecturesScreen())),
      },
      {
        'label': t('teacher_quizzes_exams_title'),
        'sublabel': 'دروستکردنی کویز و تاقیکردنەوەی دیاریکراو',
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFFD97706),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherQuizCreateScreen())),
      },
      {
        'label': t('teacher_announcements_title'),
        'sublabel': 'ناردنی ئاگاداری بۆ قوتابیان',
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFFE11D48),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAnnouncementsScreen())),
      },
      {
        'label': t('teacher_view_students'),
        'sublabel': 'بەدواداچوون بۆ ئاستی قوتابیان',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF0284C7),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherStudentsScreen())),
      },
      {
        'label': t('enrollment_requests'),
        'sublabel': 'پەسەندکردنی تۆماربوونی قوتابییان',
        'icon': Icons.how_to_reg_rounded,
        'color': const Color(0xFF0891B2),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherEnrollmentsScreen())),
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      itemBuilder: (context, i) {
        final a = actions[i];
        final color = a['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: a['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(a['icon'] as IconData, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['label'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a['sublabel'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: color.withOpacity(0.7),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Recent Activity List ──────────────────────────────────────────────────────
class _RecentActivityList extends StatelessWidget {
  final ThemeData theme;
  final LanguageProvider lang;
  const _RecentActivityList({required this.theme, required this.lang});

  @override
  Widget build(BuildContext context) {
    final activities = [
      {'icon': Icons.campaign_rounded, 'color': const Color(0xFFE11D48), 'text': 'ئاگاداری میدترم نێردرا بۆ قوتابیان', 'time': '١٠ خولەک پێش'},
      {'icon': Icons.quiz_rounded, 'color': ZankoColors.primary, 'text': 'کویزی "تۆڕەکان" دروست کرا', 'time': '٢ کاتژمێر پێش'},
      {'icon': Icons.picture_as_pdf_rounded, 'color': const Color(0xFF059669), 'text': 'PDF وانەی "سیستەمی کارپێکردن" بارکرا', 'time': 'دوێنێ'},
    ];

    return Column(
      children: activities.map((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (a['color'] as Color).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a['text'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a['time'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
