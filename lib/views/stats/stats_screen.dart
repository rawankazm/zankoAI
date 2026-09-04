import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
import '../../services/score_service.dart';
import '../../theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);
    final dbService = Provider.of<DatabaseService>(context);
    final scoreService = Provider.of<ScoreService>(context);

    // Stats data from DatabaseService
    final pomodoros = dbService.completedPomodoros;
    final quizzes = dbService.quizzesTaken;
    final flashcards = dbService.flashcardsFlipped;
    final notes = dbService.notes.length;
    final streak = scoreService.streakCount > 0 ? scoreService.streakCount : 7;

    // Badge lock evaluations
    final hasScholar = notes >= 2;
    final hasQuizMaster = quizzes >= 1;
    final hasPomodoroGuru = pomodoros >= 1;
    final hasDeepReader = notes >= 1;

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          lang.translate('nav_progress'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Performance Overview Hero ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171B23) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE2EDFB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.graph_circle_fill,
                            color: Color(0xFF035EC2),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Academic Overview',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: isDark ? Colors.white : const Color(0xFF17191F),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '🔥 $streak days streak • Top 10% student',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE4D27D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Image.asset(
                            'assets/images/trophy.png',
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFFE4D27D),
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 1,
                      color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickStat(
                          label: lang.translate('stats_pomodoros'),
                          value: '$pomodoros',
                          icon: CupertinoIcons.timer,
                          isDark: isDark,
                        ),
                        _buildQuickStat(
                          label: lang.translate('stats_quizzes_done'),
                          value: '$quizzes',
                          icon: CupertinoIcons.checkmark_seal_fill,
                          isDark: isDark,
                        ),
                        _buildQuickStat(
                          label: lang.translate('stats_cards_flipped'),
                          value: '$flashcards',
                          icon: CupertinoIcons.rectangle_on_rectangle_angled,
                          isDark: isDark,
                        ),
                        _buildQuickStat(
                          label: lang.translate('stats_notes_kept'),
                          value: '$notes',
                          icon: CupertinoIcons.doc_text_fill,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 2. Weekly Study Time Bar Chart ───────────────────────────
              Text(
                'Weekly Study Hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF17191F),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171B23) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '18.5 hrs',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : const Color(0xFF17191F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Total focused study this week',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2EDFB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.arrow_up_right, color: Color(0xFF035EC2), size: 13),
                              SizedBox(width: 3),
                              Text(
                                '+14% vs last week',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF035EC2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Weekly Bar Chart
                    SizedBox(
                      height: 140,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar('Mon', 0.55, '2.2h', false, isDark),
                          _buildBar('Tue', 0.80, '3.2h', false, isDark),
                          _buildBar('Wed', 0.45, '1.8h', false, isDark),
                          _buildBar('Thu', 0.90, '3.6h', true, isDark), // Today
                          _buildBar('Fri', 0.70, '2.8h', false, isDark),
                          _buildBar('Sat', 0.60, '2.4h', false, isDark),
                          _buildBar('Sun', 0.65, '2.5h', false, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 3. Course Progress Breakdown ─────────────────────────────
              Text(
                'Course Progress Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF17191F),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171B23) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                child: Column(
                  children: [
                    _buildCourseProgressItem(
                      title: 'Programming Fundamentals',
                      lessons: '12 / 18 lessons',
                      progress: 0.68,
                      icon: CupertinoIcons.chevron_left_slash_chevron_right,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildCourseProgressItem(
                      title: 'Database Systems',
                      lessons: '8 / 19 lessons',
                      progress: 0.42,
                      icon: CupertinoIcons.layers_alt_fill,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildCourseProgressItem(
                      title: 'Computer Networks',
                      lessons: '16 / 20 lessons',
                      progress: 0.81,
                      icon: CupertinoIcons.wifi,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildCourseProgressItem(
                      title: 'Operating Systems',
                      lessons: '5 / 15 lessons',
                      progress: 0.33,
                      icon: CupertinoIcons.device_desktop,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 4. Academic Achievements & Badges ────────────────────────
              Text(
                lang.translate('stats_badges'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF17191F),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  _buildAppleBadgeCard(
                    icon: CupertinoIcons.doc_text_fill,
                    title: lang.translate('ai_scholar'),
                    desc: lang.translate('stat_organized_notes'),
                    isUnlocked: hasScholar,
                    isDark: isDark,
                  ),
                  _buildAppleBadgeCard(
                    icon: CupertinoIcons.bolt_badge_a_fill,
                    title: lang.translate('quiz_master'),
                    desc: lang.translate('stat_completed_quiz'),
                    isUnlocked: hasQuizMaster,
                    isDark: isDark,
                  ),
                  _buildAppleBadgeCard(
                    icon: CupertinoIcons.timer,
                    title: lang.translate('focus_guru'),
                    desc: lang.translate('stat_completed_pomodoro'),
                    isUnlocked: hasPomodoroGuru,
                    isDark: isDark,
                  ),
                  _buildAppleBadgeCard(
                    icon: CupertinoIcons.book_fill,
                    title: lang.translate('deep_reader'),
                    desc: lang.translate('stat_extracted_pdf'),
                    isUnlocked: hasDeepReader,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF035EC2), size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF17191F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String day, double fraction, String time, bool isToday, bool isDark) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday
                  ? const Color(0xFF035EC2)
                  : (isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 22,
            height: 80 * fraction,
            decoration: BoxDecoration(
              color: isToday
                  ? const Color(0xFF035EC2)
                  : (isDark ? const Color(0xFF262C36) : const Color(0xFFE2EDFB)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: isToday
                  ? const Color(0xFF035EC2)
                  : (isDark ? Colors.white70 : const Color(0xFF17191F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseProgressItem({
    required String title,
    required String lessons,
    required double progress,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF035EC2).withValues(alpha: 0.2) : const Color(0xFFE2EDFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF035EC2), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF17191F),
                    ),
                  ),
                  Text(
                    lessons,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF035EC2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF035EC2)),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleBadgeCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool isUnlocked,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171B23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFF035EC2).withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? const Color(0xFFE2EDFB)
                  : (isDark ? const Color(0xFF262C36) : const Color(0xFFF4F6F9)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isUnlocked
                  ? const Color(0xFF035EC2)
                  : (isDark ? Colors.white30 : const Color(0xFFA6ACB8)),
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isUnlocked
                  ? (isDark ? Colors.white : const Color(0xFF17191F))
                  : (isDark ? Colors.white38 : const Color(0xFFA6ACB8)),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
