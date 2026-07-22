import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final __lang = Provider.of<LanguageProvider>(context);
    String t(String key) => __lang.translate(key);
    final theme = Theme.of(context);
    final dbService = Provider.of<DatabaseService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    // Get current stats
    final pomodoros = dbService.completedPomodoros;
    final quizzes = dbService.quizzesTaken;
    final flashcards = dbService.flashcardsFlipped;
    final notes = dbService.notes.length;

    // Translations
    final String title = t('stats_title');
    final String statsHeader = t('stats_weekly_activity');
    final String badgesHeader = t('stats_badges');
    final String statPomodoros = t('stats_pomodoros');
    final String statQuizzes = t('stats_quizzes_done');
    final String statCards = t('stats_cards_flipped');
    final String statNotes = t('stats_notes_kept');

    // Badge lock evaluations
    final hasScholar = notes >= 2;
    final hasQuizMaster = quizzes >= 1;
    final hasPomodoroGuru = pomodoros >= 1;
    final hasDeepReader = notes >= 1; // proxy for reading files

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats Title
              Text(
                statsHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // 2x2 Grid of stats cards
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard(context, Icons.timer_outlined, pomodoros.toString(), statPomodoros, Colors.orange),
                  _buildStatCard(context, Icons.quiz_outlined, quizzes.toString(), statQuizzes, Colors.teal),
                  _buildStatCard(context, Icons.style_outlined, flashcards.toString(), statCards, Colors.indigo),
                  _buildStatCard(context, Icons.description_outlined, notes.toString(), statNotes, Colors.blue),
                ],
              ),
              const SizedBox(height: 32),

              // Badges Section Title
              Text(
                badgesHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Badges Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: [
                  _buildBadgeCard(
                    context,
                    icon: Icons.school_rounded,
                    title: t('ai_scholar'),
                    desc: t('stat_organized_notes'),
                    color: Colors.amber,
                    isUnlocked: hasScholar,
                  ),
                  _buildBadgeCard(
                    context,
                    icon: Icons.workspace_premium_rounded,
                    title: t('quiz_master'),
                    desc: t('stat_completed_quiz'),
                    color: Colors.cyan,
                    isUnlocked: hasQuizMaster,
                  ),
                  _buildBadgeCard(
                    context,
                    icon: Icons.flash_on_rounded,
                    title: t('focus_guru'),
                    desc: t('stat_completed_pomodoro'),
                    color: Colors.redAccent,
                    isUnlocked: hasPomodoroGuru,
                  ),
                  _buildBadgeCard(
                    context,
                    icon: Icons.auto_stories_rounded,
                    title: t('deep_reader'),
                    desc: t('stat_extracted_pdf'),
                    color: Colors.green,
                    isUnlocked: hasDeepReader,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, IconData icon, String val, String title, Color color) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              val,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required bool isUnlocked,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: isUnlocked 
          ? color.withOpacity(0.08) 
          : theme.cardColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUnlocked ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnlocked ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: isUnlocked ? color : Colors.grey.shade500,
                  ),
                ),
                if (!isUnlocked)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isUnlocked ? theme.colorScheme.onSurface : Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: isUnlocked ? theme.colorScheme.onSurface.withOpacity(0.7) : Colors.grey.shade500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
