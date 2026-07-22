import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../ai_teacher/ai_teacher_screen.dart';
import 'teacher_quiz_create_screen.dart';
import 'teacher_courses_screen.dart';
import 'teacher_students_screen.dart';
import 'teacher_enrollments_screen.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Provider.of<LanguageProvider>(context);
    final auth = Provider.of<AuthService>(context);
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
                                Icons.cast_for_education_rounded,
                                color: Colors.white,
                                size: 28,
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
                                    user?.name ?? 'مامۆستا',
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
                    // ─── Stats Row ─────────────────────────────────
                    _StatsRow(t: t, theme: theme),
                    const SizedBox(height: 28),

                    // ─── Quick Actions ──────────────────────────────
                    Text(
                      t('teacher_quick_actions'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _QuickActionsGrid(t: t, theme: theme),
                    const SizedBox(height: 28),

                    // ─── Recent Activity ────────────────────────────
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
  const _StatsRow({required this.t, required this.theme});

  @override
  Widget build(BuildContext context) {
    final stats = [
      {'value': '124', 'label': t('teacher_stats_students'), 'icon': Icons.people_rounded, 'color': const Color(0xFF2196F3)},
      {'value': '6', 'label': t('teacher_stats_courses'), 'icon': Icons.book_rounded, 'color': const Color(0xFF4CAF50)},
      {'value': '18', 'label': t('teacher_stats_quizzes'), 'icon': Icons.quiz_rounded, 'color': const Color(0xFFFF9800)},
    ];
    return Row(
      children: stats.map((s) {
        final color = s['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(s['icon'] as IconData, color: color, size: 26),
                const SizedBox(height: 8),
                Text(
                  s['value'] as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
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
        'label': t('teacher_create_quiz'),
        'icon': Icons.add_circle_outline_rounded,
        'color': const Color(0xFF7C3AED),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherQuizCreateScreen())),
      },
      {
        'label': t('teacher_add_course'),
        'icon': Icons.library_add_rounded,
        'color': const Color(0xFF059669),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCoursesScreen())),
      },
      {
        'label': t('teacher_view_students'),
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF0284C7),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherStudentsScreen())),
      },
      {
        'label': t('teacher_ai_content'),
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFFD97706),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiTeacherScreen())),
      },
      {
        'label': t('enrollment_requests'),
        'icon': Icons.supervised_user_circle_rounded,
        'color': const Color(0xFFE11D48),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherEnrollmentsScreen())),
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: actions.map((a) {
        final color = a['color'] as Color;
        return GestureDetector(
          onTap: a['onTap'] as VoidCallback,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(a['icon'] as IconData, color: Colors.white, size: 32),
                const SizedBox(height: 10),
                Text(
                  a['label'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
      {'icon': Icons.quiz_rounded, 'color': const Color(0xFF7C3AED), 'text': 'کویزی "تۆڕەکان" دروست کرا', 'time': '٢ کاتژمێر پێش'},
      {'icon': Icons.person_add_rounded, 'color': const Color(0xFF059669), 'text': '٣ قوتابیی نوێ خۆیان تۆمار کرد', 'time': 'دوێنێ'},
      {'icon': Icons.picture_as_pdf_rounded, 'color': const Color(0xFF0284C7), 'text': 'PDF وانەی "داتابەیس" بارکرا', 'time': '٣ ڕۆژ پێش'},
    ];

    return Column(
      children: activities.map((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
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
