import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dbService = Provider.of<DatabaseService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    // Get current stats
    final pomodoros = dbService.completedPomodoros;
    final quizzes = dbService.quizzesTaken;
    final flashcards = dbService.flashcardsFlipped;
    final notes = dbService.notes.length;

    // Translations
    final String title = langProvider.currentLanguage == AppLanguage.english
        ? 'Study Statistics & Achievements'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'إحصائيات الدراسة والإنجازات'
            : 'ئاماری خوێندن و دەستکەوتەکانم';

    final String statsHeader = langProvider.currentLanguage == AppLanguage.english
        ? 'Weekly Activity'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'النشاط الأسبوعي'
            : 'چالاکییەکانی خوێندنم';

    final String badgesHeader = langProvider.currentLanguage == AppLanguage.english
        ? 'Earned Badges'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'الشارات والميداليات المستحقة'
            : 'میدالیا و دەستکەوتەکانم';

    final String statPomodoros = langProvider.currentLanguage == AppLanguage.english
        ? 'Pomodoros'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'جلسات بومودورو'
            : 'خولەکانی تەرکیز';

    final String statQuizzes = langProvider.currentLanguage == AppLanguage.english
        ? 'Quizzes Done'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'الاختبارات المنجزة'
            : 'کویزە تەواوکراوەکان';

    final String statCards = langProvider.currentLanguage == AppLanguage.english
        ? 'Cards Flipped'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'البطاقات المراجعة'
            : 'فلاشکاردەکان';

    final String statNotes = langProvider.currentLanguage == AppLanguage.english
        ? 'Notes Kept'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'الملاحظات المحفوظة'
            : 'تێبینییە ڕێکخراوەکان';

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
                  fontFamily: 'Noto Sans Arabic',
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
                  fontFamily: 'Noto Sans Arabic',
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
                    title: 'AI Scholar / زانای AI',
                    desc: 'Organized 2+ AI Notes',
                    color: Colors.amber,
                    isUnlocked: hasScholar,
                  ),
                  _buildBadgeCard(
                    context,
                    icon: Icons.workspace_premium_rounded,
                    title: 'Quiz Master / پاڵەوانی کویز',
                    desc: 'Completed 1+ Quiz tests',
                    color: Colors.cyan,
                    isUnlocked: hasQuizMaster,
                  ),
                  _buildBadgeCard(
                    context,
                    icon: Icons.flash_on_rounded,
                    title: 'Focus Guru / پسپۆڕی تەرکیز',
                    desc: 'Completed 1+ Pomodoros',
                    color: Colors.redAccent,
                    isUnlocked: hasPomodoroGuru,
                  ),
                  _buildBadgeCard(
                    context,
                    icon: Icons.auto_stories_rounded,
                    title: 'Deep Reader / خوێنەری زیرەک',
                    desc: 'Extracted 1+ PDF notes',
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
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Noto Sans Arabic'),
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
                fontFamily: 'Noto Sans Arabic',
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
                fontFamily: 'Noto Sans Arabic',
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
