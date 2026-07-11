import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/language_provider.dart';
import '../navigation_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const NavigationShell(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  List<_OnboardPage> get _pages {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String l(String en, String ar, String ku) =>
        lang.currentLanguage == AppLanguage.english ? en : lang.currentLanguage == AppLanguage.arabic ? ar : ku;

    return [
      _OnboardPage(
        gradient: const [Color(0xFF007AFF), Color(0xFF5856D6)],
        icon: Icons.auto_awesome_rounded,
        title: l('Welcome to ZankoAI', 'مرحباً بك في ZankoAI', 'بەخێرهاتیت بۆ ZankoAI'),
        body: l(
          'Your all-in-one AI-powered study companion designed for university students.',
          'مرافقك الدراسي الشامل المدعوم بالذكاء الاصطناعي لطلاب الجامعات.',
          'هاوڕێی خوێندنی گشتگیرت کە بە هێزی AI بۆ خوێندکارانی زانکۆ دروستکراوە.',
        ),
        badge: '🎓',
      ),
      _OnboardPage(
        gradient: const [Color(0xFFFF3B30), Color(0xFFFF6B35)],
        icon: Icons.picture_as_pdf_rounded,
        title: l('Summarize Your Courses', 'لخّص موادك الدراسية', 'وانەکانت کورت بکەرەوە'),
        body: l(
          'Upload PDFs or paste text — get instant AI summaries and translations.',
          'ارفع ملفات PDF أو الصق النص للحصول على ملخصات فورية.',
          'PDF باربکە یان دەق بنووسە — دەستبەجێ کورتکراوە و وەرگێڕان وەربگرە.',
        ),
        badge: '📄',
      ),
      _OnboardPage(
        gradient: const [Color(0xFF34C759), Color(0xFF00C896)],
        icon: Icons.event_note_rounded,
        title: l('Plan Your Study Week', 'خطط لأسبوعك الدراسي', 'هەفتەی خوێندنت پلان بکە'),
        body: l(
          'AI builds a personalized day-by-day study plan for your exams.',
          'الذكاء يبني خطة دراسة يومية شخصية لامتحاناتك.',
          'AI پلانی خوێندنی ڕۆژانەی تایبەتت بۆ تاقیکردنەوەکانت دروست دەکات.',
        ),
        badge: '📅',
      ),
      _OnboardPage(
        gradient: const [Color(0xFFFF9500), Color(0xFFFFCC00)],
        icon: Icons.quiz_rounded,
        title: l('Test Yourself', 'اختبر نفسك', 'خۆت بتاقیبکەرەوە'),
        body: l(
          'Generate quizzes, flashcards, and predicted exam questions with AI.',
          'أنشئ اختبارات وبطاقات مراجعة وأسئلة متوقعة بالذكاء الاصطناعي.',
          'تاقیکردنەوە، فلاشکارد، و پرسیاری پێشبینیکراو بە AI دروست بکە.',
        ),
        badge: '🧠',
      ),
      _OnboardPage(
        gradient: const [Color(0xFFAF52DE), Color(0xFF5856D6)],
        icon: Icons.rocket_launch_rounded,
        title: l('Ready to Start?', 'مستعد للبدء؟', 'ئامادەیت دەست پێبکەیت؟'),
        body: l(
          'Set your Gemini API key from the home screen to unlock all AI features.',
          'أضف مفتاح Gemini API من الشاشة الرئيسية لتفعيل كل ميزات الذكاء.',
          'کلیلی Gemini API لە پەڕەی سەرەکییەکەوە زیاد بکە بۆ کردنەوەی هەموو ئامرازەکانی AI.',
        ),
        badge: '🚀',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isRTL = lang.currentLanguage != AppLanguage.english;
    String l(String en, String ar, String ku) =>
        lang.currentLanguage == AppLanguage.english ? en : lang.currentLanguage == AppLanguage.arabic ? ar : ku;

    final pages = _pages;
    final page = pages[_currentPage];
    final isLast = _currentPage == pages.length - 1;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            children: [
              // Gradient background
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: page.gradient,
                  ),
                ),
              ),

              // Decorative circles
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),

              // Skip button
              SafeArea(
                child: Align(
                  alignment: isRTL ? Alignment.topLeft : Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        l('Skip', 'تخطي', 'تێپەڕکردن'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ),

              // Page content
              PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: pages.length,
                itemBuilder: (_, i) => _PageContent(page: pages[i]),
              ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dots indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pages.length, (i) {
                            final active = i == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active ? Colors.white : Colors.white38,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 28),
                        // Next / Get Started button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: page.gradient[0],
                              minimumSize: const Size(0, 58),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isLast
                                      ? l("Let's Go! 🚀", 'هيا نبدأ! 🚀', 'با بچینە ناو! 🚀')
                                      : l('Next →', 'التالي →', 'دواتر →'),
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: page.gradient[0],
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
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String body;
  final String badge;
  const _OnboardPage({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.body,
    required this.badge,
  });
}

class _PageContent extends StatelessWidget {
  final _OnboardPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 100, 32, 160),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white30, width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(page.icon, color: Colors.white, size: 56),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Text(page.badge, style: const TextStyle(fontSize: 22)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          // Body
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
