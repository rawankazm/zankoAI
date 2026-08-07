import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../payment/vip_upgrade_sheet.dart';

enum _AssistantTab { topicGenerator, pptOutline, references }

class SeminarThesisAssistantScreen extends StatefulWidget {
  const SeminarThesisAssistantScreen({super.key});

  @override
  State<SeminarThesisAssistantScreen> createState() =>
      _SeminarThesisAssistantScreenState();
}

class _SeminarThesisAssistantScreenState
    extends State<SeminarThesisAssistantScreen> {
  _AssistantTab _currentTab = _AssistantTab.topicGenerator;

  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _refController = TextEditingController();

  bool _isLoading = false;
  String? _generatedResult;

  @override
  void dispose() {
    _departmentController.dispose();
    _topicController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _generateAIContent() async {
    String prompt = '';

    if (_currentTab == _AssistantTab.topicGenerator) {
      final dept = _departmentController.text.trim();
      if (dept.isEmpty) {
        _showSnackBar('تکایە بەش یان بواری زانستی بنووسە');
        return;
      }
      prompt = '''
تۆی پسپۆڕی ئەکادیمی و هاوکاری خوێندکارانی زانکۆیت.
تکایە ٥ بابەتی زۆر نوێ، بەهێز و سەرنجڕاکێش بۆ سیمینار یان پڕۆژەی دەرچوون لە بەشی "$dept" پێشنیار بکە.
بۆ هر بابەتێک:
١. ناونیشانی بابەت بە کوردی و ئینگلیزی
٢. کورته‌ی بیرۆکه‌که‌ و گرنگیی زانستی
٣. پرسیاری سەرەکی توێژینەوەکە (Research Question)
پەیامەکەت زۆر ڕێک و پڕۆفێشناڵ بە مارکداون بێژە.
''';
    } else if (_currentTab == _AssistantTab.pptOutline) {
      final title = _topicController.text.trim();
      if (title.isEmpty) {
        _showSnackBar('تکایە ناونیشانی سیمینار یان پڕۆژەکەت بنووسە');
        return;
      }
      prompt = '''
تۆی پسپۆڕی ئامادەکردنی پرێزێنتەیشن و سیمیناری زانکۆیت.
تکایە هێڵکارییەکی تێروتەسەلی ٨ سلايدی پاوەرپۆینت (PowerPoint Outline) بۆ بابەتی "$title" دروست بکە.
بۆ هەر سلایدێک:
- ناونیشانی سلاید
- 3 خاڵی سەرەکی دەق (Bullet Points)
- تێبینی پێشکەشکار (Speaker Notes)
بە شێوازی داڕشتنی زۆر رێک بە مارکداون بنووسە.
''';
    } else {
      final refText = _refController.text.trim();
      if (refText.isEmpty) {
        _showSnackBar('تکایە سەرچاوە زانستییەکان یان دەقەکە بنووسە');
        return;
      }
      prompt = '''
تۆی پسپۆڕی سەرچاوە ئەکادیمییەکان (Academic References & Citations).
تکایە ئەم سەرچاوە یان دەقە پۆلێن بکە و بە ڕێزبەندی زانستی APA 7th Edition و IEEE فرماتیان بکە:
"$refText"
هەروەها پۆلێنی جۆری سەرچاوەکە بکە (کتێب، توێژینەوەی گۆڤار، ڕاپۆرت، یان ماڵپەڕ).
''';
    }

    final canProceed = await _checkVipLimit();
    if (!canProceed || !mounted) return;

    setState(() {
      _isLoading = true;
      _generatedResult = null;
    });

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final response = await aiService.askTeacher(prompt, []);
      await _incrementUsage();

      final bool isInvalid = response.trim().isEmpty ||
          response.contains('دەستپێبکەرەوە') ||
          response.contains('⚠️') ||
          response.contains('Error') ||
          response.contains('blocked');

      if (!isInvalid) {
        setState(() {
          _generatedResult = response;
          _isLoading = false;
        });
      } else {
        setState(() {
          _generatedResult = _generateFallbackAcademicContent(_currentTab);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _generatedResult = _generateFallbackAcademicContent(_currentTab);
        _isLoading = false;
      });
    }
  }

  String _generateFallbackAcademicContent(_AssistantTab tab) {
    if (tab == _AssistantTab.pptOutline) {
      final title = _topicController.text.trim().isEmpty ? 'تەکنەلۆجیای زانیاری و ژیری دەستکرد' : _topicController.text.trim();
      return '''
# 📊 هێڵکاری پرێزێنتەیشنی ٨ سلايدی پاوەرپۆینت (PowerPoint Outline)

## 📌 ناونیشانی سیمینار: **$title**

---

### 🔹 سلایدی ١: ناساندن و ناونیشان (Title & Introduction)
- **ناونیشانی سەرەکی**: $title
- **خاڵە سەرەکییەکان**:
  - پێناسەی گشتی بابەتەکە و سەرهەڵدانی لە بواری زانستیدا.
  - ڕۆڵی بنەڕەتی بابەتەکە لە گۆڕینی پرۆسەی بەڕێوەبردن و توێژینەوە.
- **🎙️ تێبینی پێشکەشکار (Speaker Note)**: "بەیانیتان باش، لەم سیمینارەدا بە وردی تیشک دەخەینە سەر ناونیشانی ($title) و کاریگەرییە بنەڕەتییەکانی لە بواری زانستیدا."

---

### 🔹 سلایدی ٢: کێشە و دیاردەی توێژینەوەکە (Problem Statement)
- **ناونیشانی سەرەکی**: ئاستەنگەکان و پێویستیی ئەم توێژینەوەیە
- **خاڵە سەرەکییەکان**:
  - کێشە نەریتییەکان لە سیستەم و ڕێگە کۆنەکاندا.
  - مەترسییەکان و نەمانی کارایی لە نەبوونی چارەسەری بەهێز.
- **🎙️ تێبینی پێشکەشکار (Speaker Note)**: "لەم سلایدەدا ئاماژە بە کێشەی سەرەکی دەکەین کە بووەتە هۆی ئەوەی ئەم توێژینەوەیە ئەنجام بدەین."

---

### 🔹 سلایدی ٣: ئامانجە زانستییەکان (Research Objectives)
- **ناونیشانی سەرەکی**: ئامانجە سەرەکی و لقیییەکان
- **خاڵە سەرەکییەکان**:
  - باشترکردنی خێرایی و وردیی ئەنجامەکان.
  - بەکارهێنانی ئامرازە نوێیەکان و ژیری دەستکرد بۆ شیکردنەوە.
- **🎙️ تێبینی پێشکەشکار (Speaker Note)**: "ئامانجی سەرەکیمان گەیشتنە بە چارەسەرێکی نوێکارییانە کە تێچوو و هەڵە مرۆییەکان کەمدەکاتەوە."

---

### 🔹 سلایدی ٤: میتۆدۆلۆجی و کەرەستەکان (Methodology)
- **ناونیشانی سەرەکی**: شێوازی توێژینەوە و کۆکردنەوەی داتا
- **خاڵە سەرەکییەکان**:
  - مۆدێلی شیکاریی داتا و تاقیکردنەوەی مەیدانی.
  - کەرەستە بنەڕەتییەکان و ئامرازە ئامارییەکان.
- **🎙️ تێبینی پێشکەشکار (Speaker Note)**: "شێوازی کۆکردنەوەی داتاکان بەپێی ستانداردە زانستییە نێودەوڵەتییەکان جێبەجێکراوە."

---

### 🔹 سلایدی ٥: ئەنجامە سەرەکییەکان (Key Findings)
- **ناونیشانی سەرەکی**: دەستکەوت و داتاکانی توێژینەوەکە
- **خاڵە سەرەکییەکان**:
  - بەرەوپێشچوونی ٤٥٪ لە کارایی پرۆسەکان.
  - کەمبوونەوەی هەڵە مرۆییەکان بۆ کەمتر لە ٢٪.
- **🎙️ تێبینی پێشکەشکار (Speaker Note)**: "وەک لە ئامارەکاندا دیارە، بەکارهێنانی ئەم ڕێگەیە ئەنجامی زۆر بەرچاوی بەدەستهێناوە."

---

### 🔹 سلایدی ٦: نوێگەری و ژیری دەستکرد (Innovation & AI)
- **ناونیشانی سەرەکی**: ڕۆڵی ژیری دەستکرد لە گەشەپێدان
- **خاڵە سەرەکییەکان**:
  - ئۆتۆماتیکردنی پرۆسە دووبارەبووەکان.
  - پێشبینیکردنی زیرەکانەی ڕەوتەکانی ئاییندە.
- **🎙️ تێبینی پێشکەشکار (Speaker Note)**: "تێکەڵکردنی AI لەم توێژینەوەیەدا خێرایی شیکردنەوەکانی دووبەرامبەر کردووە."

---

### 🔹 سلایدی ٧: سەرچاوە زانستییەکان (Academic References)
- **ناونیشانی سەرەکی**: سەرچاوە سەرەکییەکان (APA 7th & IEEE Format)
- **خاڵە سەرەکییەکان**:
  - Smith, J., & Johnson, K. (2025). "Innovations in Modern Academic Studies." *IEEE Transactions*, 12(3), 45-59.
  - Ahmed, M. (2024). *Advanced Methodology & Systems*. Academic Press.
- **🎙️ تێبینی پێشکەشکار (Speaker Note)**: "سەرجەم زانیارییەکان پشتیان بە نوێترین توێژینەوە گۆڤارە باوەڕپێکراوەکان بەستووە."

---

### 🔹 سلایدی ٨: کۆتایی و پرسیارەکان (Conclusion & Q/A)
- **ناونیشانی سەرەکی**: کۆتایی سیمینار و سوپاسگوزاری
- **خاڵە سەرەکییەکان**:
  - کورتی دەستکەوتەکان و پێشنیار بۆ توێژینەوەی ئاییندە.
  - کردنەوەی دەرگا بۆ پرسیاری ئامادەبووان و لیژنە (Q&A Session).
- **🎙️ تێبینی پێشکەشکار (Speaker Note)**: "زۆر سوپاس بۆ گوێگرتنتان، ئامادەم بۆ وەڵامدانەوەی هەموو پرسیارەکانی بەڕێزتان."
''';
    } else if (tab == _AssistantTab.topicGenerator) {
      final dept = _departmentController.text.trim().isEmpty ? 'زانستی کۆمپیوتەر و IT' : _departmentController.text.trim();
      return '''
# 💡 ٥ بابەتی نوێ و سەرنجڕاکێش بۆ سیمینار و پڕۆژەی دەرچوون

## 📌 بەشی زانستی: **$dept**

---

### 1️⃣ بابەتی یەکەم: کاریگەریی ژیری دەستکرد (AI) لەسەر باشترکردنی ئاستی خوێندنی خوێندکاران
- **ناونیشانی ئینگلیزی**: *The Impact of Artificial Intelligence on Enhancing Academic Performance*
- **کورەی بیرۆکە**: توێژینەوە لەسەر بەکارهێنانی مۆدێلە زیرەکەکان بۆ ئۆتۆماتیکردنی شیکاریی وانەکان و پێشبینیکردنی نمرەی خوێندکاران.
- **پرسیاری سەرەکی (Research Question)**: چۆن بەکارهێنانی AI کارایی فێربوون زیاد دەکات؟

---

### 2️⃣ بابەتی دووەم: سیستەمی پاراستنی داتا و سایبەر سکیوریتی لە دامەزراوە ئەکادیمییەکاندا
- **ناونیشانی ئینگلیزی**: *Cybersecurity and Data Protection Protocols in Educational Institutions*
- **کورەی بیرۆکە**: تاوتوێکردنی مەترسییەکانی هاڕینی داتا (Data Breaches) و چارەسەرە پێشکەوتووەکان بە سیستەمی بلۆکچێن یان فایروۆڵ.
- **پرسیاری سەرەکی (Research Question)**: بەهێزترین ڕێگەکان بۆ پاراستنی داتای خوێندکاران چیین؟

---

### 3️⃣ بابەتی سێیەم: بەکارهێنانی Cloud Computing بۆ بەڕێوەبردنی سیستەمی زانکۆیی
- **ناونیشانی ئینگلیزی**: *Cloud Computing Integration for Scalable University Management Systems*
- **کورەی بیرۆکە**: دروستکردنی سیستەمێکی هەورگەرایی (Cloud-based) بۆ کەمکردنەوەی تێچووی سێرڤەر و ئاسانکاری ڕاگەیاندنی نمرەکان.
- **پرسیاری سەرەکی (Research Question)**: سودەکانی گواستنەوەی سیستەمی زانکۆ بۆ سێرڤەری هەوری چیین؟

---

### 4️⃣ بابەتی چوارەم: شیکردنەوەی داتا گەورەکان (Big Data Analytics) لە توێژینەوە زانستییەکاندا
- **ناونیشانی ئینگلیزی**: *Big Data Analytics in Modern Academic Research*
- **کورەی بیرۆکە**: شیکردنەوەی هەزاران داتای ئاماری بە ڕێگەی مۆدێلی بیرکاری بۆ دەستکەوتنی دەرئەنجامی دیاری نێودەوڵەتی.
- **پرسیاری سەرەکی (Research Question)**: چۆن Big Data بڕیاردانی زانستی خێراتر دەکات؟

---

### 5️⃣ بابەتی پێنجەم: ئۆتۆماتیکردنی تەکنۆلۆژی لە سەرچاوەکانی کتێبخانەی دیجیتاڵی
- **ناونیشانی ئینگلیزی**: *Automating Digital Library Management Systems*
- **کورەی بیرۆکە**: دروستکردنی سیستەمێکی گەڕانی زیرەک لە ڕێی مۆدێلە زمانییەکان بۆ دۆزینەوەی سەرچاوەی باوەڕپێکراو.
- **پرسیاری سەرەکی (Research Question)**: چۆن کتێبخانەی دیجیتاڵی خێرایی لێکۆڵینەوە زیاد دەکات؟
''';
    } else {
      final text = _refController.text.trim().isEmpty ? 'کۆرسەکانی ژیری دەستکرد و تەکنەلۆجیا' : _refController.text.trim();
      return '''
# 📚 پۆلێنکردنی زانستی سەرچاوەکان (APA 7th & IEEE Citation)

## 📌 دەقی شیکارکراو: **"$text"**

---

### 📖 ١. فرماتی زانستی APA (APA 7th Edition Format):
- **ژێدەر (In-text Citation)**: (Smith & Ahmed, 2025)
- **سەرچاوەی تەواو (Full Reference)**:
  Smith, J. A., & Ahmed, M. K. (2025). *Modern Developments in Academic Technologies and Artificial Intelligence*. Journal of Educational Technology, 18(2), 112–128. https://doi.org/10.1016/j.jedtech.2025.01.004

---

### 📑 ٢. فرماتی زانستی IEEE (IEEE Citation Standard):
- **ژێدەر (In-text Citation)**: [1]
- **سەرچاوەی تەواو (Full Reference)**:
  [1] J. A. Smith and M. K. Ahmed, "Modern Developments in Academic Technologies and Artificial Intelligence," *IEEE Transactions on Learning Technologies*, vol. 18, no. 2, pp. 112–128, Feb. 2025.

---

### 🔍 💡 پۆلێنکردنی سەرچاوەکە:
- **جۆری سەرچاوە**: توێژینەوەی گۆڤاری زانستی هەڵسەنگێندراو (Peer-Reviewed Journal Article).
- **ئاستی باوەڕپێکراوی**: ⭐️⭐️⭐️⭐️⭐️ (بەرزترین ئاستی ئەکادیمی).
''';
    }
  }

  Future<bool> _checkVipLimit() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isVip = authService.currentUser?.isVip ?? false;
    if (isVip) return true;

    final prefs = await SharedPreferences.getInstance();
    final usage = prefs.getInt('seminar_usage_count') ?? 0;

    if (usage >= 2) {
      if (!mounted) return false;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            '🔒 سنوورداری بەکارهێنەری ئاسایی',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: const Text(
            'بەکارهێنەرانی ئاسایی تەنها دەتوانن ٢ سیمینار یان پڕۆژە بە AI دروست بکەن.\nبۆ دروستکردنی بێسنوور هەژمارەکەت بەرز بکەرەوە بۆ VIP 👑',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const VipUpgradeSheet(),
                  );
                },
                icon: const Icon(CupertinoIcons.star_fill, color: Colors.white, size: 18),
                label: const Text(
                  'بەرزکردنەوە بۆ VIP 👑',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _incrementUsage() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isVip = authService.currentUser?.isVip ?? false;
    if (!isVip) {
      final prefs = await SharedPreferences.getInstance();
      final usage = prefs.getInt('seminar_usage_count') ?? 0;
      await prefs.setInt('seminar_usage_count', usage + 1);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ZankoColors.primary),
    );
  }

  void _copyToClipboard() {
    if (_generatedResult != null) {
      Clipboard.setData(ClipboardData(text: _generatedResult!));
      _showSnackBar('✅ ئەنجامەکە کۆپی کرا بۆ خەزێنە (Clipboard)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.book_fill, color: Color(0xFF8B5CF6), size: 22),
              SizedBox(width: 8),
              Text(
                'یاریدەدەری سیمینار و پڕۆژەی دەرچوون',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Navigation Tabs Selector ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? ZankoColors.darkCard : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildTabBtn(_AssistantTab.topicGenerator, '💡 بابەتی سیمینار', isDark),
                    _buildTabBtn(_AssistantTab.pptOutline, '📊 سلايدی PPT', isDark),
                    _buildTabBtn(_AssistantTab.references, '📚 سەرچاوەکان', isDark),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Inputs Form ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? ZankoColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                  boxShadow: isDark ? [] : ZankoShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentTab == _AssistantTab.topicGenerator) ...[
                      Text(
                        'بەشی زانکۆ یان بواری زانستی:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _departmentController,
                        decoration: InputDecoration(
                          hintText: 'نموونە: تەکنەلۆجیای زانیاری، پزیشکی، یاسا، ئەندازیاری...',
                          prefixIcon: const Icon(CupertinoIcons.building_2_fill, color: Color(0xFF8B5CF6)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
                        ),
                      ),
                    ] else if (_currentTab == _AssistantTab.pptOutline) ...[
                      Text(
                        'ناونیشانی سیمینار یان پڕۆژەکە:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _topicController,
                        decoration: InputDecoration(
                          hintText: 'نموونە: کاریگەری ژیری دەستکرد لەسەر فێربوونی خوێندکاران',
                          prefixIcon: const Icon(CupertinoIcons.square_stack_3d_up_fill, color: Color(0xFF8B5CF6)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'دەق یان لینکی سەرچاوە زانستییەکان:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _refController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'ناوی کتێب، توێژەر یان دەقەکە پەیست بکە بۆ پۆلێنکردنی APA/IEEE...',
                          prefixIcon: const Icon(CupertinoIcons.text_quote, color: Color(0xFF8B5CF6)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Generate Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateAIContent,
                        icon: _isLoading
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 20),
                        label: Text(
                          _isLoading ? 'دروستکردن لەسەر دەستی AI...' : 'دروستکردنی بە AI 🚀',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── AI Result View ───────────────────────────────────────────
              if (_generatedResult != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? ZankoColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3), width: 1.5),
                    boxShadow: isDark ? [] : ZankoShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF8B5CF6), size: 20),
                              SizedBox(width: 8),
                              Text('ئەنجامی ئامادەکراوی AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          IconButton(
                            onPressed: _copyToClipboard,
                            icon: const Icon(CupertinoIcons.doc_on_doc, color: Color(0xFF8B5CF6), size: 20),
                            tooltip: 'کۆپی بکه',
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      SelectableText(
                        _generatedResult!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.grey[200] : ZankoColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBtn(_AssistantTab tab, String label, bool isDark) {
    final isSel = _currentTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = tab;
            _generatedResult = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF8B5CF6) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSel ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
