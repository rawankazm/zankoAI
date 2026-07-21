import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';
import '../../services/theme_provider.dart';
import '../../models/user_model.dart';
import '../schedule/schedule_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../gpa/gpa_tracker_screen.dart';
import '../reminders/reminders_screen.dart';
import '../ai_teacher/ai_teacher_screen.dart';
import '../pdf/pdf_summary_screen.dart';
import '../study_planner/study_planner_screen.dart';
import '../profile/profile_screen.dart';
import '../focus/focus_screen.dart';
import '../stats/stats_screen.dart';
import '../notes/notes_screen.dart';
import '../quiz/quiz_screen.dart';
import 'exam_predictor_view.dart';
import 'mind_map_view.dart';
import 'student_courses_enroll_screen.dart';
import '../pdf/audio_summarizer_view.dart';
import '../flashcards/qr_share_sheet.dart';
import '../../widgets/feature_intro_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showApiKeyDialog(BuildContext context, AiService aiService, LanguageProvider lang) {
    final controller = TextEditingController(text: aiService.apiKey);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: lang.textDirection,
        child: AlertDialog(
          title: Text(
            lang.currentLanguage == AppLanguage.english
                ? 'Gemini API Key'
                : lang.currentLanguage == AppLanguage.arabic
                    ? 'مفتاح Gemini API'
                    : 'کلیلی Gemini API',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.currentLanguage == AppLanguage.english
                    ? 'Paste your Gemini API Key to enable all AI features.'
                    : lang.currentLanguage == AppLanguage.arabic
                        ? 'الصق مفتاح Gemini لتفعيل مزايا الذكاء الاصطناعي.'
                        : 'کلیلی Gemini دابنێ بۆ چالاکردنی هەموو ئامرازەکانی AI.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'AIzaSy...'),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.currentLanguage == AppLanguage.english ? 'Cancel' : lang.currentLanguage == AppLanguage.arabic ? 'إلغاء' : 'پاشگەزبوونەوە'),
            ),
            FilledButton(
              onPressed: () {
                aiService.apiKey = controller.text.trim();
                Navigator.pop(context);
              },
              child: Text(lang.currentLanguage == AppLanguage.english ? 'Save' : lang.currentLanguage == AppLanguage.arabic ? 'حفظ' : 'پاشەکەوت'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);
    final dbService = Provider.of<DatabaseService>(context);
    final aiService = Provider.of<AiService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primary = theme.colorScheme.primary;

    String t(String key) => langProvider.translate(key);

    final user = authService.currentUser;
    final userName = user?.name ?? 'Student';
    final todayLectures = dbService.schedule.where((item) => item.dayName == 'شەممە').take(3).toList();

    // Feature cards list
    final features = _buildFeatureList(context, langProvider, t);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Directionality(
        textDirection: langProvider.textDirection,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              // ── Large Title AppBar (Apple style) ──────────────────────────
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                backgroundColor: isDark
                    ? theme.colorScheme.surface.withOpacity(0.92)
                    : const Color(0xFFF2F2F7).withOpacity(0.92),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
                  title: Text(
                    'ZankoAI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  expandedTitleScale: 1.0,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [theme.colorScheme.surface, theme.scaffoldBackgroundColor]
                            : [const Color(0xFFF2F2F7), const Color(0xFFF2F2F7)],
                      ),
                    ),
                  ),
                ),
                actions: [
                  // Dark/Light Mode Toggle
                  _AppBarBtn(
                    icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isDark ? const Color(0xFFFFCC00) : const Color(0xFF5856D6),
                    onTap: () => themeProvider.toggleTheme(!isDark),
                  ),
                  // Language
                  _AppBarBtn(
                    icon: Icons.language_rounded,
                    color: primary,
                    onTap: () => _showLanguageSheet(context, langProvider),
                  ),
                  // API Key
                  _AppBarBtn(
                    icon: aiService.hasRealApiKey ? Icons.key_rounded : Icons.key_off_rounded,
                    color: aiService.hasRealApiKey ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                    onTap: () => _showApiKeyDialog(context, aiService, langProvider),
                  ),
                  // Profile
                  GestureDetector(
                    onTap: () => Navigator.push(context, _slide(() => const ProfileScreen())),
                    child: Container(
                      margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, theme.colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (userName.isNotEmpty ? userName[0] : 'S').toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Greeting ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t('hello')}، $userName 👋',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t('hello_companion'),
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                                ),
                              ],
                            ),
                          ),
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user?.role == UserRole.teacher ? t('teacher') : user?.role == UserRole.admin ? t('admin') : t('student'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── GPA Hero Card ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, _slide(() => const GpaTrackerScreen())),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary, theme.colorScheme.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t('gpa_title'),
                                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${user?.gpa ?? 3.65} / 4.00',
                                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: (user?.gpa ?? 3.65) / 4.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 32),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── AI Status Banner ──────────────────────────────────────
                    if (!aiService.hasRealApiKey)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GestureDetector(
                          onTap: () => _showApiKeyDialog(context, aiService, langProvider),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withOpacity(isDark ? 0.15 : 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Text('⚡', style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        langProvider.currentLanguage == AppLanguage.english
                                            ? 'Connect Gemini AI'
                                            : langProvider.currentLanguage == AppLanguage.arabic
                                                ? 'اربط Gemini AI'
                                                : 'Gemini AI پەیوەند بکە',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFFF9500)),
                                      ),
                                      Text(
                                        langProvider.currentLanguage == AppLanguage.english
                                            ? 'Tap to add your API key'
                                            : langProvider.currentLanguage == AppLanguage.arabic
                                                ? 'اضغط لإضافة مفتاح API'
                                                : 'بکلیک بکە بۆ زیادکردنی کلیل',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF9500)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!aiService.hasRealApiKey) const SizedBox(height: 24),

                    // ── Today's Lectures ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t('today_lectures'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                          GestureDetector(
                            onTap: () => Navigator.push(context, _slide(() => const ScheduleScreen())),
                            child: Text(t('view_all'), style: TextStyle(fontSize: 15, color: primary, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (todayLectures.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: _EmptyState(
                          icon: Icons.event_available_rounded,
                          label: t('no_lectures_today'),
                          color: primary,
                        ),
                      )
                    else
                      ...todayLectures.map((lec) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: _LectureTile(
                              title: lec.courseName,
                              subtitle: '${lec.time} • ${lec.location}',
                              color: primary,
                              onTap: () => Navigator.push(context, _slide(() => const ScheduleScreen())),
                            ),
                          )),

                    const SizedBox(height: 28),

                    // ── Features Grid ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(t('quick_access'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    ),
                    const SizedBox(height: 14),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.25,
                        ),
                        itemCount: features.length,
                        itemBuilder: (_, i) => _FeatureCard(data: features[i], isDark: isDark),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_FeatureData> _buildFeatureList(BuildContext context, LanguageProvider lang, String Function(String) t) {
    String l(String en, String ar, String ku) =>
        lang.currentLanguage == AppLanguage.english ? en : lang.currentLanguage == AppLanguage.arabic ? ar : ku;

    final langCode = lang.currentLanguage == AppLanguage.english ? 'en' : lang.currentLanguage == AppLanguage.arabic ? 'ar' : 'ku';

    // Helper: show intro then navigate
    void go(BuildContext ctx, FeatureIntroData intro, Widget Function() screen) async {
      await showFeatureIntro(ctx, intro, langCode);
      if (ctx.mounted) Navigator.push(ctx, _slide(screen));
    }

    return [
      _FeatureData(
        icon: Icons.auto_awesome_rounded,
        label: t('nav_ai_teacher'),
        sublabel: t('ask_and_learn'),
        gradient: const [Color(0xFF007AFF), Color(0xFF5856D6)],
        onTap: (ctx) => go(ctx, FeatureIntros.aiTeacher, () => const AiTeacherScreen()),
      ),
      _FeatureData(
        icon: Icons.picture_as_pdf_rounded,
        label: t('nav_courses'),
        sublabel: t('summarize_and_translate'),
        gradient: const [Color(0xFFFF3B30), Color(0xFFFF6B35)],
        onTap: (ctx) => go(ctx, FeatureIntros.pdfSummary, () => const PdfSummaryScreen()),
      ),
      _FeatureData(
        icon: Icons.style_rounded,
        label: l('Flashcards', 'بطاقات المراجعة', 'فلاشکارد'),
        sublabel: l('Study card deck', 'مراجعة وحفظ', 'کارتی یادکردنەوە'),
        gradient: const [Color(0xFF5856D6), Color(0xFFAF52DE)],
        onTap: (ctx) => go(ctx, FeatureIntros.flashcards, () => const FlashcardsScreen()),
      ),
      _FeatureData(
        icon: Icons.quiz_rounded,
        label: t('nav_quiz'),
        sublabel: l('Test your knowledge', 'اختبر نفسك', 'خۆت بتاقیبکەرەوە'),
        gradient: const [Color(0xFFFF9500), Color(0xFFFFCC00)],
        onTap: (ctx) => go(ctx, FeatureIntros.quiz, () => const QuizScreen()),
      ),
      _FeatureData(
        icon: Icons.alarm_on_rounded,
        label: l('Reminders', 'التذكيرات', 'یاددەهێنەر'),
        sublabel: l('Tasks countdown', 'المهام الدراسية', 'ماوە بۆ ئەرکەکان'),
        gradient: const [Color(0xFFFF2D55), Color(0xFFFF6B6B)],
        onTap: (ctx) => go(ctx, FeatureIntros.reminders, () => const RemindersScreen()),
      ),
      _FeatureData(
        icon: Icons.event_note_rounded,
        label: l('AI Planner', 'مخطط الدراسة', 'پلانی خوێندن'),
        sublabel: l('Weekly study guide', 'جدول أسبوعي', 'پلانی هەفتانە'),
        gradient: const [Color(0xFF34C759), Color(0xFF00C896)],
        onTap: (ctx) => go(ctx, FeatureIntros.planner, () => const StudyPlannerScreen()),
      ),
      _FeatureData(
        icon: Icons.timer_rounded,
        label: l('Focus Timer', 'مؤقت التركيز', 'کاتژمێری تەرکیز'),
        sublabel: l('Pomodoro clock', 'ساعة بومودورو', 'شێوازی پۆمۆدۆرۆ'),
        gradient: const [Color(0xFFFF9500), Color(0xFFFF3B30)],
        onTap: (ctx) => go(ctx, FeatureIntros.focus, () => const FocusScreen()),
      ),
      _FeatureData(
        icon: Icons.emoji_events_rounded,
        label: l('Stats', 'الإحصائيات', 'ئامار'),
        sublabel: l('Study statistics', 'إحصائيات نشاطك', 'کۆی چالاکییەکان'),
        gradient: const [Color(0xFFFFCC00), Color(0xFFFF9500)],
        onTap: (ctx) => go(ctx, FeatureIntros.stats, () => const StatsScreen()),
      ),
      _FeatureData(
        icon: Icons.psychology_rounded,
        label: l('Exam Predictor', 'توقع الامتحان', 'پێشبینیکەر'),
        sublabel: l('AI exam questions', 'توقع الأسئلة', 'پرسیاری وانەکان'),
        gradient: const [Color(0xFFAF52DE), Color(0xFF5856D6)],
        onTap: (ctx) => go(ctx, FeatureIntros.examPredictor, () => const ExamPredictorView()),
      ),
      _FeatureData(
        icon: Icons.hub_rounded,
        label: l('Mind Maps', 'خرائط المفاهيم', 'نەخشەی مێشک'),
        sublabel: l('Visual concepts', 'ربط المفاهيم', 'بەستنەوەی بابەت'),
        gradient: const [Color(0xFF00C896), Color(0xFF007AFF)],
        onTap: (ctx) => go(ctx, FeatureIntros.mindMap, () => const MindMapView()),
      ),
      _FeatureData(
        icon: Icons.mic_rounded,
        label: l('Audio Lecture', 'ملخص صوتي', 'کورتکەرەوەی دەنگ'),
        sublabel: l('Summarize recordings', 'لخص الملفات الصوتية', 'کورتکردنەوەی دەنگ'),
        gradient: const [Color(0xFFFF2D55), Color(0xFFAF52DE)],
        onTap: (ctx) => go(ctx, FeatureIntros.audioSummarizer, () => const AudioSummarizerView()),
      ),
      _FeatureData(
        icon: Icons.qr_code_scanner_rounded,
        label: l('Peer Share', 'مشاركة كروت', 'هاوبەشکردن'),
        sublabel: l('QR import/export', 'عبر QR كود', 'گۆڕینەوەی QR'),
        gradient: const [Color(0xFF007AFF), Color(0xFF34C759)],
        onTap: (ctx) => go(ctx, FeatureIntros.peerShare, () => const QrScannerView()),
      ),
      _FeatureData(
        icon: Icons.note_alt_rounded,
        label: l('My Notes', 'ملاحظاتي', 'تێبینییەکانم'),
        sublabel: l('Write & organize', 'اكتب ونظم', 'بنووسە و ڕێکبخە'),
        gradient: const [Color(0xFF34C759), Color(0xFF007AFF)],
        onTap: (ctx) => go(ctx, FeatureIntros.notes, () => const NotesScreen()),
      ),
      _FeatureData(
        icon: Icons.calendar_today_rounded,
        label: l('Schedule', 'جدول الوانات', 'خشتەی وانەکان'),
        sublabel: l('Weekly timetable', 'خشتەی هەفتانەی وانەکان', 'الجدول الأسبوعي'),
        gradient: const [Color(0xFF5856D6), Color(0xFF34C759)],
        onTap: (ctx) => go(ctx, FeatureIntros.schedule, () => const ScheduleScreen()),
      ),
      _FeatureData(
        icon: Icons.school_rounded,
        label: t('course_enrollment'),
        sublabel: l('Enroll in courses', 'التسجيل في المواد', 'تۆماربوون لە وانەکان'),
        gradient: const [Color(0xFF1565C0), Color(0xFF1E88E5)],
        onTap: (ctx) => Navigator.push(ctx, _slide(() => const StudentCoursesEnrollScreen())),
      ),
    ];
  }

  void _showLanguageSheet(BuildContext context, LanguageProvider lang) {
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Language / زبان / اللغة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primary)),
            const SizedBox(height: 16),
            for (final entry in [
              (AppLanguage.kurdish, 'کوردی', '🇮🇶'),
              (AppLanguage.arabic, 'العربية', '🌍'),
              (AppLanguage.english, 'English', '🇬🇧'),
            ])
              ListTile(
                leading: Text(entry.$3, style: const TextStyle(fontSize: 24)),
                title: Text(entry.$2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                trailing: lang.currentLanguage == entry.$1 ? Icon(Icons.check_circle_rounded, color: primary) : null,
                onTap: () { lang.setLanguage(entry.$1); Navigator.pop(ctx); },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
          ],
        ),
      ),
    );
  }

  static PageRoute _slide(Widget Function() builder) => PageRouteBuilder(
        pageBuilder: (_, a, __) => builder(),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      );
}

// ── Feature Card ──────────────────────────────────────────────────────────────
class _FeatureData {
  final IconData icon;
  final String label;
  final String sublabel;
  final List<Color> gradient;
  final void Function(BuildContext) onTap;
  const _FeatureData({required this.icon, required this.label, required this.sublabel, required this.gradient, required this.onTap});
}

class _FeatureCard extends StatefulWidget {
  final _FeatureData data;
  final bool isDark;
  const _FeatureCard({required this.data, required this.isDark});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1, end: 0.94).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); d.onTap(context); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isDark
                  ? [d.gradient[0].withOpacity(0.85), d.gradient[1].withOpacity(0.85)]
                  : d.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: d.gradient[0].withOpacity(widget.isDark ? 0.25 : 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(d.icon, color: Colors.white, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(d.sublabel, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Lecture Tile ──────────────────────────────────────────────────────────────
class _LectureTile extends StatelessWidget {
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _LectureTile({required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.book_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _EmptyState({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.5), size: 24),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }
}

// ── AppBar Icon Button ────────────────────────────────────────────────────────
class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
