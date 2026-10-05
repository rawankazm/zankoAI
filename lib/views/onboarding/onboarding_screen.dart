import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  static const int _totalPages = 3;
  static const Color _bgLight = Color(0xFFF8FAFD);
  static const Color _electricBlue = Color(0xFF0A63D8);

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, _) => const NavigationShell(),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _finish();
    }
  }

  List<_OnboardData> _buildPages(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.kurdish:
        return [
          const _OnboardData(
            imageAsset: 'assets/images/on1.png',
            headlineLine1: 'هاوڕێیەکی زیرەک',
            headlineLine2: 'بۆ خوێندکارانی زانکۆ',
            description:
                'بەکارهێنانی AI بۆ فێربوون، ئامادەکاری تاقیکردنەوە و پێشکەوتن لەسەر ڕێگاکەت.',
          ),
          const _OnboardData(
            imageAsset: 'assets/images/on2.png',
            headlineLine1: 'هەموو ئامرازەکانی خوێندن',
            headlineLine2: 'لە یەک کاتدا',
            description:
                'کۆرس، وتار، تاقیکردنەوە، پلاندانەری خوێندن و زۆرترین شت بە یەک شوێن.',
          ),
          const _OnboardData(
            imageAsset: 'assets/images/on3.png',
            headlineLine1: 'بەهێزترین AI',
            headlineLine2: 'بۆ فێربوون و تێگەیشتن',
            description:
                'وەڵامەکان بە شێوەی کوردی، ڕێکخستن، و پێداچوونەوەی ئاسانە بۆ تۆ.',
          ),
        ];

      case AppLanguage.kurdishBadini:
        return [
          const _OnboardData(
            imageAsset: 'assets/images/on1.png',
            headlineLine1: 'هاریکارەکێ زیرەک',
            headlineLine2: 'بۆ قوتابیێن زانکۆیێ',
            description:
                'بکارهینانا AI بۆ فێربوونێ، ئامادەکرنا تاقیکرنان و پێشڤەچوون د ڕێکا تەدا.',
          ),
          const _OnboardData(
            imageAsset: 'assets/images/on2.png',
            headlineLine1: 'هەمی ئامرازێن خواندنێ',
            headlineLine2: 'د ئێک دەمدا',
            description:
                'کۆرس، گوتار، تاقیکرن، ڕاپۆرت و ئامرازێن خواندنێ ل ئێک جهـ.',
          ),
          const _OnboardData(
            imageAsset: 'assets/images/on3.png',
            headlineLine1: 'ب هێزترین AI',
            headlineLine2: 'بۆ فێربوون و تێگەهشتنێ',
            description:
                'بەرسڤدان ب شێوازێ کوردی، ڕێکخستن و پێداچوونا ب ساناهی بۆ تە.',
          ),
        ];

      case AppLanguage.arabic:
        return [
          const _OnboardData(
            imageAsset: 'assets/images/on1.png',
            headlineLine1: 'مساعد ذكي',
            headlineLine2: 'لطلاب الجامعات',
            description:
                'استخدام الذكاء الاصطناعي للتعلم والتحضير للاختبارات والتقدم في مسيرتك الدراسية.',
          ),
          const _OnboardData(
            imageAsset: 'assets/images/on2.png',
            headlineLine1: 'جميع أدوات الدراسة',
            headlineLine2: 'في مكان واحد',
            description:
                'كورسات، ملخصات، اختبارات، تقارير وأدوات دراسية متكاملة في منصة واحدة.',
          ),
          const _OnboardData(
            imageAsset: 'assets/images/on3.png',
            headlineLine1: 'أقوى ذكاء اصطناعي',
            headlineLine2: 'للتعلم والاستيعاب',
            description:
                'إجابات وشروحات فورية، تلخيص ذكي ومساعدة أكاديمية متقدمة على مدار الساعة.',
          ),
        ];

      case AppLanguage.english:
        return [
          const _OnboardData(
            imageAsset: 'assets/images/on1.png',
            headlineLine1: 'Smart AI Companion',
            headlineLine2: 'For University Students',
            description:
                'AI-powered learning, exam preparation, and academic success for your university journey.',
          ),
          const _OnboardData(
            imageAsset: 'assets/images/on2.png',
            headlineLine1: 'All Your Study Tools',
            headlineLine2: 'Unified In One Place',
            description:
                'Courses, summaries, quizzes, reports, and AI study tools unified in one workspace.',
          ),
          const _OnboardData(
            imageAsset: 'assets/images/on3.png',
            headlineLine1: 'Most Powerful AI',
            headlineLine2: 'For Learning & Mastery',
            description:
                'Instant explanations, smart summaries, exam prediction, and 24/7 academic assistance.',
          ),
        ];
    }
  }

  String _getSkipLabel(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.kurdish:
        return 'تێپەڕاندن';
      case AppLanguage.kurdishBadini:
        return 'دەربازکرن';
      case AppLanguage.arabic:
        return 'تخطي';
      case AppLanguage.english:
        return 'Skip';
    }
  }

  String _getNextLabel(AppLanguage lang, bool isLast) {
    if (isLast) {
      switch (lang) {
        case AppLanguage.kurdish:
          return 'دەست پێبکە';
        case AppLanguage.kurdishBadini:
          return 'دەستپێبکە';
        case AppLanguage.arabic:
          return 'ابدأ الآن';
        case AppLanguage.english:
          return 'Get Started';
      }
    } else {
      switch (lang) {
        case AppLanguage.kurdish:
          return 'دواتر';
        case AppLanguage.kurdishBadini:
          return 'پاشتر';
        case AppLanguage.arabic:
          return 'التالي';
        case AppLanguage.english:
          return 'Next';
      }
    }
  }

  void _showLanguageBottomSheet(
    BuildContext context,
    LanguageProvider langProvider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'زمان هەڵبژێرە / Select Language',
                  style: TextStyle(
                    fontFamily: 'K24KurdishBold',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLanguageOption(
                  ctx,
                  langProvider,
                  AppLanguage.kurdish,
                  'کوردی (سۆرانی)',
                  'Kurdish Sorani (Default)',
                ),
                _buildLanguageOption(
                  ctx,
                  langProvider,
                  AppLanguage.kurdishBadini,
                  'کوردی (بادینی)',
                  'Kurdish Badini',
                ),
                _buildLanguageOption(
                  ctx,
                  langProvider,
                  AppLanguage.arabic,
                  'العربية',
                  'Arabic',
                ),
                _buildLanguageOption(
                  ctx,
                  langProvider,
                  AppLanguage.english,
                  'English',
                  'English',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext ctx,
    LanguageProvider langProvider,
    AppLanguage lang,
    String nativeName,
    String subName,
  ) {
    final isSelected = langProvider.currentLanguage == lang;

    return InkWell(
      onTap: () {
        langProvider.setLanguage(lang);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0A63D8).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF0A63D8).withValues(alpha: 0.35),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nativeName,
                  style: TextStyle(
                    fontFamily: lang == AppLanguage.english
                        ? null
                        : 'K24KurdishBold',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? const Color(0xFF0A63D8)
                        : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? const Color(0xFF0A63D8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0A63D8),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  String _getLanguageShortName(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.kurdish:
        return 'سۆرانی';
      case AppLanguage.kurdishBadini:
        return 'بادینی';
      case AppLanguage.arabic:
        return 'عربي';
      case AppLanguage.english:
        return 'EN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final currentLang = lang.currentLanguage;
    final isRTL = lang.isRtl;
    final pages = _buildPages(currentLang);
    final isLast = _currentPage == _totalPages - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Theme(
        data: ThemeData.light(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: _bgLight,
          colorScheme: const ColorScheme.light(
            primary: _electricBlue,
            surface: _bgLight,
          ),
        ),
        child: Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: _bgLight,
            body: Stack(
              children: [
                // Academic Pattern Background (Dot Matrix + Orbital Rings + Sparkles)
                Positioned.fill(
                  child: CustomPaint(
                    painter: const _AcademicBackgroundPatternPainter(),
                  ),
                ),

                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenH = constraints.maxHeight;

                      return Column(
                        children: [
                          // Top Compact Language Switcher Pill
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () => _showLanguageBottomSheet(
                                    context,
                                    lang,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFCBD5E1),
                                        width: 0.8,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.language_rounded,
                                          size: 14,
                                          color: Color(0xFF0A63D8),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _getLanguageShortName(currentLang),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // PageView with Visuals and Headlines
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (i) =>
                                  setState(() => _currentPage = i),
                              itemCount: _totalPages,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (context, i) {
                                return AnimatedBuilder(
                                  animation: _pageController,
                                  builder: (context, child) {
                                    double page = _currentPage.toDouble();
                                    if (_pageController.hasClients &&
                                        _pageController
                                            .position
                                            .hasContentDimensions) {
                                      page = _pageController.page ??
                                          _currentPage.toDouble();
                                    }
                                    final diff = (i - page);
                                    final scale =
                                        (1.0 - (diff.abs() * 0.12))
                                            .clamp(0.86, 1.0);
                                    final opacity =
                                        (1.0 - (diff.abs() * 0.55))
                                            .clamp(0.0, 1.0);

                                    return Transform.scale(
                                      scale: scale,
                                      child: Opacity(
                                        opacity: opacity,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _OnboardPageView(
                                    data: pages[i],
                                    floatAnim: _floatAnim,
                                    screenHeight: screenH,
                                    screenWidth: constraints.maxWidth,
                                    language: currentLang,
                                  ),
                                );
                              },
                            ),
                          ),

                          // Bottom Navigation Section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
                            child: _BottomNavigationRow(
                              currentPage: _currentPage,
                              totalPages: _totalPages,
                              isLast: isLast,
                              isRTL: isRTL,
                              skipLabel: _getSkipLabel(currentLang),
                              nextLabel:
                                  _getNextLabel(currentLang, isLast),
                              onSkip: _finish,
                              onNext: _nextPage,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page View Layout (Kurdish / Arabic / English Typography Handling)
// ---------------------------------------------------------------------------
class _OnboardPageView extends StatelessWidget {
  final _OnboardData data;
  final Animation<double> floatAnim;
  final double screenHeight;
  final double screenWidth;
  final AppLanguage language;

  const _OnboardPageView({
    required this.data,
    required this.floatAnim,
    required this.screenHeight,
    required this.screenWidth,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final maxIllustrationH = (screenHeight * 0.32).clamp(170.0, 240.0);
    final maxIllustrationW = (screenWidth * 0.65).clamp(170.0, 240.0);

    final isKurdish = language == AppLanguage.kurdish ||
        language == AppLanguage.kurdishBadini;
    final headlineFont = isKurdish ? 'K24KurdishBold' : 'NotoSansArabic';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Illustration with Smooth Floating Animation
          AnimatedBuilder(
            animation: floatAnim,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, floatAnim.value),
                child: child,
              );
            },
            child: SizedBox(
              width: maxIllustrationW,
              height: maxIllustrationH,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft Aura Disc behind illustration
                  Container(
                    width: maxIllustrationW * 0.95,
                    height: maxIllustrationH * 0.95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF168DFF).withValues(alpha: 0.12),
                          const Color(0xFF0A63D8).withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        radius: 0.7,
                      ),
                    ),
                  ),

                  // 3D Visual Asset
                  Image.asset(
                    data.imageAsset,
                    width: maxIllustrationW,
                    height: maxIllustrationH,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.school_rounded,
                      size: 90,
                      color: Color(0xFF0A63D8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(flex: 1),

          // Typography Area
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Headline Line 1 (Deep Navy/Black)
              Text(
                data.headlineLine1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: headlineFont,
                  fontFamilyFallback: const ['NotoSansArabic', 'DroidKufi'],
                  color: const Color(0xFF0F172A),
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),

              // Headline Line 2 (Vibrant Zanko Academic Blue)
              Text(
                data.headlineLine2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: headlineFont,
                  fontFamilyFallback: const ['NotoSansArabic', 'DroidKufi'],
                  color: const Color(0xFF0A63D8),
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  shadows: [
                    Shadow(
                      color: const Color(0xFF0A63D8).withValues(alpha: 0.20),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Supporting Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  data.description,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: const TextStyle(
                    fontFamily: 'NotoSansArabic',
                    fontFamilyFallback: ['DroidKufi', 'K24KurdishBold'],
                    color: Color(0xFF475569),
                    fontSize: 14.5,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Navigation Row: Skip | Indicators | Next Button (RTL Aware)
// ---------------------------------------------------------------------------
class _BottomNavigationRow extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLast;
  final bool isRTL;
  final String skipLabel;
  final String nextLabel;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _BottomNavigationRow({
    required this.currentPage,
    required this.totalPages,
    required this.isLast,
    required this.isRTL,
    required this.skipLabel,
    required this.nextLabel,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Skip Button
        SizedBox(
          width: 80,
          child: TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
            ),
            child: Text(
              skipLabel,
              style: const TextStyle(
                fontFamily: 'NotoSansArabic',
                color: Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // 3 Animated Dot Indicators
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(totalPages, (i) {
            final active = i == currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF0A63D8)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0A63D8).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),

        // Next / Get Started Action Button with Micro-Motion & RTL Arrow Direction
        _AnimatedNextButton(
          isRTL: isRTL,
          isLast: isLast,
          label: nextLabel,
          onTap: onNext,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Animated Next Action Button (Bounce on Press, Directional Arrow Nudge, RTL Arrow)
// ---------------------------------------------------------------------------
class _AnimatedNextButton extends StatefulWidget {
  final bool isRTL;
  final bool isLast;
  final String label;
  final VoidCallback onTap;

  const _AnimatedNextButton({
    required this.isRTL,
    required this.isLast,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AnimatedNextButton> createState() => _AnimatedNextButtonState();
}

class _AnimatedNextButtonState extends State<_AnimatedNextButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrowCtrl;
  late final Animation<double> _arrowAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Impulse nudge forward and spring back
    _arrowAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_arrowCtrl);
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _arrowCtrl.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // In RTL, progress is to the left (-7px). In LTR, progress is to the right (+7px).
    final nudgeDistance = widget.isRTL ? -7.0 : 7.0;

    return AnimatedScale(
      scale: _isPressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF168DFF), Color(0xFF0A63D8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A63D8).withValues(
                alpha: _isPressed ? 0.18 : 0.36,
              ),
              blurRadius: _isPressed ? 8 : 16,
              offset: Offset(0, _isPressed ? 2 : 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isLast ? 24 : 20,
                vertical: 13,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontFamily: 'NotoSansArabic',
                      fontFamilyFallback: ['K24KurdishBold', 'DroidKufi'],
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _arrowAnim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_arrowAnim.value * nudgeDistance, 0),
                        child: child,
                      );
                    },
                    child: Transform.flip(
                      flipX: widget.isRTL,
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        textDirection: TextDirection.ltr,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Academic Background Pattern Painter (Dot Matrix + Orbital Rings + Sparkles)
// ---------------------------------------------------------------------------
class _AcademicBackgroundPatternPainter extends CustomPainter {
  const _AcademicBackgroundPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft atmospheric gradient background
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.0, -0.3),
        radius: 0.95,
        colors: [
          Color(0xFFE8F2FF),
          Color(0xFFF1F6FD),
          Color(0xFFF8FAFD),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Micro Dot Grid Matrix (Academic/Tech graph pattern)
    final dotPaint = Paint()
      ..color = const Color(0xFF0A63D8).withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;

    const double step = 26.0;
    final int cols = (size.width / step).ceil();
    final int rows = (size.height / step).ceil();

    for (int i = 0; i <= cols; i++) {
      for (int j = 0; j <= rows; j++) {
        final x = i * step;
        final y = j * step;
        final double opacityFactor =
            (1.0 - (y / size.height) * 0.45).clamp(0.0, 1.0);
        if (opacityFactor > 0.1) {
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    }

    // 3. Concentric Orbital Rings centered behind the illustration area
    final center = Offset(size.width * 0.5, size.height * 0.28);

    final ringPaint = Paint()
      ..color = const Color(0xFF168DFF).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 125, ringPaint);
    _drawDashedCircle(canvas, center, 175, 44, ringPaint);
    canvas.drawCircle(
      center,
      230,
      ringPaint..color = const Color(0xFF168DFF).withValues(alpha: 0.045),
    );

    // 4. Subtle Decorative AI Sparkles (✦)
    _drawSparkle(
      canvas,
      Offset(size.width * 0.14, size.height * 0.14),
      7,
      const Color(0xFF168DFF).withValues(alpha: 0.35),
    );
    _drawSparkle(
      canvas,
      Offset(size.width * 0.86, size.height * 0.18),
      8,
      const Color(0xFF168DFF).withValues(alpha: 0.35),
    );
    _drawSparkle(
      canvas,
      Offset(size.width * 0.10, size.height * 0.44),
      6,
      const Color(0xFF0A63D8).withValues(alpha: 0.25),
    );
    _drawSparkle(
      canvas,
      Offset(size.width * 0.90, size.height * 0.48),
      6,
      const Color(0xFF0A63D8).withValues(alpha: 0.25),
    );
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    int segments,
    Paint paint,
  ) {
    final double sweep = (2 * 3.1415926535) / segments;
    for (int i = 0; i < segments; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * 0.6,
        false,
        paint,
      );
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Model Data Class
// ---------------------------------------------------------------------------
class _OnboardData {
  final String imageAsset;
  final String headlineLine1;
  final String headlineLine2;
  final String description;

  const _OnboardData({
    required this.imageAsset,
    required this.headlineLine1,
    required this.headlineLine2,
    required this.description,
  });
}
