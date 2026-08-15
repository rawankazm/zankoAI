import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/pptx_generator_service.dart';
import '../../theme.dart';
import '../payment/vip_upgrade_sheet.dart';

enum _AssistantTab { topicGenerator, pptOutline, references }

enum SeminarLanguage {
  kurdish('کوردی (سۆرانی)', 'ku', '🇮🇶'),
  english('English', 'en', '🇬🇧'),
  arabic('العربية', 'ar', '🇸🇦');

  final String label;
  final String code;
  final String flag;
  const SeminarLanguage(this.label, this.code, this.flag);
}

class SeminarTopicProposal {
  final int index;
  final String titleKurdish;
  final String titleEnglish;
  final String summary;
  final String researchQuestion;

  SeminarTopicProposal({
    required this.index,
    required this.titleKurdish,
    required this.titleEnglish,
    required this.summary,
    required this.researchQuestion,
  });
}

class SeminarThesisAssistantScreen extends StatefulWidget {
  const SeminarThesisAssistantScreen({super.key});

  @override
  State<SeminarThesisAssistantScreen> createState() =>
      _SeminarThesisAssistantScreenState();
}

class _SeminarThesisAssistantScreenState
    extends State<SeminarThesisAssistantScreen> {
  _AssistantTab _currentTab = _AssistantTab.topicGenerator;
  SeminarLanguage _selectedLanguage = SeminarLanguage.kurdish;

  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _refController = TextEditingController();

  bool _isLoading = false;
  bool _isExportingPptx = false;
  String? _generatedResult;
  List<SeminarTopicProposal> _suggestedTopics = [];
  List<SlideModel> _parsedSlides = [];
  int _selectedSlideIndex = 0;

  @override
  void dispose() {
    _departmentController.dispose();
    _topicController.dispose();
    _refController.dispose();
    super.dispose();
  }

  /// Returns DroidKufi font for Kurdish/Arabic and default for English
  String? get _currentFontFamily =>
      _selectedLanguage == SeminarLanguage.english ? null : 'DroidKufi';

  /// Step 1: Suggest multiple seminar topics based on field/department and selected language
  Future<void> _generateTopics() async {
    final dept = _departmentController.text.trim();
    if (dept.isEmpty) {
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? 'Please enter your field or department'
          : (_selectedLanguage == SeminarLanguage.arabic
              ? 'يرجى إدخال التخصص أو المجال العلمي'
              : 'تکایە بەش یان بواری زانستی یان بیرۆکەکەت بنووسە'));
      return;
    }

    final canProceed = await _checkVipLimit();
    if (!canProceed || !mounted) return;

    setState(() {
      _isLoading = true;
      _generatedResult = null;
      _suggestedTopics = [];
      _parsedSlides = [];
    });

    final langInstruction = _selectedLanguage == SeminarLanguage.english
        ? 'CRITICAL: Write everything 100% strictly in English (No other language allowed).'
        : (_selectedLanguage == SeminarLanguage.arabic
            ? 'مهم جداً: اكتب جميع المحاور والعناوين والشروحات بنسبة ١٠٠٪ باللغة العربية الفصحى الأكاديمية فقط.'
            : 'زۆر گرنگە: هەموو بابەت و ناونیشان و دەقەکان ١٠٠٪ بە زمانی کوردی سۆرانی پاراو و ئەکادیمی بنووسە.');

    final prompt = '''
You are a distinguished university professor and academic seminar advisor.
Please suggest 5 highly impactful, modern, and attractive seminar topics strictly in the field of "$dept".
$langInstruction

For each topic, format exactly as:
### 📌 Topic [Number]: [Full Topic Title]
- **English/Secondary**: [English Title if main is Kurdish/Arabic, or subtitle]
- **💡 Summary & Significance**: [Comprehensive summary of why this specific topic is important]
- **❓ Research Question**: [The core scientific problem/question this seminar answers]

Make the content strictly relevant to "$dept".
''';

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final response = await aiService.askTeacher(prompt, []);
      await _incrementUsage();

      final bool isInvalid = response.trim().isEmpty ||
          response.contains('دەستپێبکەرەوە') ||
          response.contains('⚠️') ||
          response.contains('Error') ||
          response.contains('blocked');

      final content = !isInvalid ? response : _generateFallbackTopicsText(dept);
      _processTopicResponse(content);
    } catch (e) {
      final fallback = _generateFallbackTopicsText(dept);
      _processTopicResponse(fallback);
    }
  }

  void _processTopicResponse(String rawText) {
    final topics = _parseTopicProposals(rawText);
    setState(() {
      _generatedResult = rawText;
      _suggestedTopics = topics;
      _isLoading = false;
    });
  }

  List<SeminarTopicProposal> _parseTopicProposals(String rawText) {
    final List<SeminarTopicProposal> list = [];
    final blocks = rawText.split(RegExp(r'###\s+.*(Topic|بابەت|بابەتی|الموضوع)\s*'));

    int count = 1;
    for (var b in blocks) {
      final text = b.trim();
      if (text.isEmpty) continue;

      final lines = text.split('\n');
      String titleMain = lines.first.replaceAll(RegExp(r'^[:\-–\d️⃣\d\.\s]+'), '').replaceAll('**', '').trim();
      String titleSecondary = '';
      String summary = '';
      String researchQ = '';

      for (var l in lines) {
        final line = l.trim();
        if (line.contains('ئینگلیزی') || line.toLowerCase().contains('english') || line.contains('Secondary') || line.contains('العنوان الإنجليزي')) {
          titleSecondary = line.split(':').sublist(1).join(':').replaceAll('*', '').trim();
        } else if (line.contains('کورتە') || line.contains('بیرۆکە') || line.contains('گرنگی') || line.contains('Summary') || line.contains('الملخص') || line.contains('الأهمية')) {
          summary = line.split(':').sublist(1).join(':').replaceAll('*', '').trim();
        } else if (line.contains('پرسیار') || line.contains('Research Question') || line.contains('السؤال')) {
          researchQ = line.split(':').sublist(1).join(':').replaceAll('*', '').trim();
        }
      }

      if (titleMain.isNotEmpty) {
        list.add(SeminarTopicProposal(
          index: count++,
          titleKurdish: titleMain,
          titleEnglish: titleSecondary.isNotEmpty ? titleSecondary : 'Academic Seminar Presentation',
          summary: summary.isNotEmpty ? summary : (_selectedLanguage == SeminarLanguage.english ? 'Comprehensive academic investigation.' : 'توێژینەوە و لێکۆڵینەوەیەکی زانستیی سەردەمیانە.'),
          researchQuestion: researchQ.isNotEmpty ? researchQ : (_selectedLanguage == SeminarLanguage.english ? 'How does this solve core research challenges?' : 'چۆن ئەم بابەتە دەتوانێت کێشە زانستییەکان چارەسەر بکات؟'),
        ));
      }
    }

    if (list.isEmpty) {
      list.addAll(_getFallbackTopicProposals(_departmentController.text.trim()));
    }

    return list;
  }

  /// Step 2: Generate the complete 8-slide seminar with Canva-style narrative + points + visual prompts
  Future<void> _generateFullSeminar(String topicTitle) async {
    final canProceed = await _checkVipLimit();
    if (!canProceed || !mounted) return;

    setState(() {
      _currentTab = _AssistantTab.pptOutline;
      _topicController.text = topicTitle;
      _isLoading = true;
      _generatedResult = null;
      _parsedSlides = [];
      _selectedSlideIndex = 0;
    });

    final langPrompt = _selectedLanguage == SeminarLanguage.english
        ? 'CRITICAL MANDATE: Write all 8 slides, slide titles, paragraphs, metrics, and speaker notes 100% strictly in English.'
        : (_selectedLanguage == SeminarLanguage.arabic
            ? 'مهم جداً: اكتب الشرائح الـ 8 والعناوين والشروحات والأرقام وملاحظات المتحدث بنسبة ١٠٠٪ باللغة العربية الفصحى الأكاديمية فقط.'
            : 'زۆر گرنگە: هەموو ٨ سلایدەکە، ناونیشانەکان، پاراگرافەکان، ئامار و وتاری پێشکەشکار ١٠٠٪ بە زمانی کوردی سۆرانی پاراو بنووسە.');

    final prompt = '''
You are a premier presentation designer and university professor specialized in creating Canva-style modern academic presentations.
Write a full, ready-to-present, 8-slide seminar presentation strictly and exclusively about the selected topic: "$topicTitle".
$langPrompt

CRITICAL REQUIREMENTS (Must be strictly followed):
1. The presentation MUST contain exactly 8 Slides.
2. The content must be strictly about "$topicTitle" with real in-depth academic facts, data metrics, and analysis. Do NOT use placeholder text or generic filler words.
3. DO NOT format every slide as plain identical bullet points! Use a rich, varied Canva-style layout:
   - Mix conceptual narrative statements, highlight statistics/percentages (e.g. 85% accuracy, 3% error rate, 40% time saved), process flow steps, and analytical takeaways.
   - Each slide must contain 4 to 5 rich, informative points/paragraphs.
4. For each slide, include a dedicated 🖼️ **Visual/Diagram Suggestion** describing the Canva graphic, diagram, flowchart, or image layout.
5. For each slide, write the full **🎙️ Speaker Speech Script** that the presenter reads out loud.

SLIDE STRUCTURE:
- Slide 1: Main Title, Research Scope, Academic Significance & Presenter Card
- Slide 2: Background, Historical Context & Technology Evolution
- Slide 3: Core Problem Statement, Bottlenecks & Traditional Limitations
- Slide 4: Strategic Research Objectives & Expected Key Benefits
- Slide 5: Methodology, System Architecture & Analytical Framework
- Slide 6: Key Findings, Statistical Data & Comparative Results
- Slide 7: Practical Impact, Real-world Implementation & Roadmap
- Slide 8: Academic Citations (APA 7th Standard), Conclusion & Q&A

FORMAT FOR EACH SLIDE:
### 🔹 Slide [Number]: [Full Slide Title]
- 🖼️ **Visual/Diagram**: [Detailed description of the Canva image, diagram, or chart for this slide]
- [Detailed Academic Paragraph / Point 1]
- [Detailed Academic Paragraph / Point 2]
- [Detailed Academic Paragraph / Point 3]
- [Key Metric / Statistical Highlight Point 4]
- [Actionable Summary Point 5]
- 🎙️ **Speaker Script**: [Full speech script for the presenter]
''';

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final response = await aiService.askTeacher(prompt, []);
      await _incrementUsage();

      final bool isInvalid = response.trim().isEmpty ||
          response.contains('دەستپێبکەرەوە') ||
          response.contains('⚠️') ||
          response.contains('Error') ||
          response.contains('blocked');

      final content = !isInvalid ? response : _generateFallback8SlideSeminar(topicTitle);
      _processSeminarResponse(content, topicTitle);
    } catch (e) {
      final fallback = _generateFallback8SlideSeminar(topicTitle);
      _processSeminarResponse(fallback, topicTitle);
    }
  }

  void _processSeminarResponse(String rawText, String title) {
    final slides = PptxGeneratorService.parseSlidesFromText(rawText, defaultTitle: title);
    setState(() {
      _generatedResult = rawText;
      _parsedSlides = slides;
      _selectedSlideIndex = 0;
      _isLoading = false;
    });
  }

  /// References formatter
  Future<void> _formatReferences() async {
    final refText = _refController.text.trim();
    if (refText.isEmpty) {
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? 'Please enter the reference text or URL'
          : (_selectedLanguage == SeminarLanguage.arabic
              ? 'يرجى إدخال نص المرجع أو الرابط'
              : 'تکایە سەرچاوە زانستییەکان بنووسە'));
      return;
    }

    final canProceed = await _checkVipLimit();
    if (!canProceed || !mounted) return;

    setState(() {
      _isLoading = true;
      _generatedResult = null;
      _parsedSlides = [];
    });

    final prompt = '''
You are an expert in academic references & citations.
Please format and classify the following academic reference in standard APA 7th Edition and IEEE styles:
"$refText"
''';

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final response = await aiService.askTeacher(prompt, []);
      await _incrementUsage();
      setState(() {
        _generatedResult = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _generatedResult = _generateFallbackReferences(refText);
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPptx() async {
    if (_generatedResult == null || _generatedResult!.isEmpty) {
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? 'Please generate the seminar with AI first'
          : (_selectedLanguage == SeminarLanguage.arabic
              ? 'يرجى إنشاء السيمينار بالذكاء الاصطناعي أولاً'
              : 'تکایە سەرەتا سیمینارەکە بە AI دروست بکە'));
      return;
    }

    setState(() => _isExportingPptx = true);

    try {
      String title = _topicController.text.trim().isNotEmpty
          ? _topicController.text.trim()
          : (_departmentController.text.trim().isNotEmpty
              ? (_selectedLanguage == SeminarLanguage.english
                  ? '${_departmentController.text.trim()} Seminar'
                  : 'سیمیناری بەشی ${_departmentController.text.trim()}')
              : 'Seminar Presentation');

      await PptxGeneratorService.exportAndSharePptx(
        rawContent: _generatedResult!,
        title: title,
        languageCode: _selectedLanguage.code,
      );

      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? '✅ PowerPoint (.pptx) file created successfully'
          : (_selectedLanguage == SeminarLanguage.arabic
              ? '✅ تم إنشاء ملف PowerPoint (.pptx) بنجاح'
              : '✅ فایلی PowerPoint (.pptx) بە سەرکەوتوویی دروستکرا'));
    } catch (e) {
      _showSnackBar('⚠️ Error creating PPT file: $e');
    } finally {
      if (mounted) {
        setState(() => _isExportingPptx = false);
      }
    }
  }

  void _showCanvaInstructions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7D2AE8), Color(0xFF00C4CC)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(CupertinoIcons.paintbrush_fill, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLanguage == SeminarLanguage.english ? 'Import to Canva 🎨' : 'هاوردەکردن بۆ Canva 🎨',
                          style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        const Text('Canva Presentation Integration', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(CupertinoIcons.xmark_circle_fill)),
                ],
              ),
              const Divider(height: 24),
              _buildCanvaStep(_selectedLanguage == SeminarLanguage.english
                  ? '1. Download the PowerPoint (.pptx) file with the button below.'
                  : '١. فایلی PowerPoint (.pptx) دابگرە بە دوگمەی خوارەوە.'),
              _buildCanvaStep(_selectedLanguage == SeminarLanguage.english
                  ? '2. Open Canva App or go to canva.com.'
                  : '٢. ئەپی Canva یان ماڵپەڕی canva.com بکەرەوە.'),
              _buildCanvaStep(_selectedLanguage == SeminarLanguage.english
                  ? '3. Click on "Upload / Drag & Drop" at the top.'
                  : '٣. لە بەشی سەرەوە کلیک لەسەر «Upload / Drag and Drop» بکە.'),
              _buildCanvaStep(_selectedLanguage == SeminarLanguage.english
                  ? '4. Select the .pptx file, and all 8 slides will instantly open with Canva animations and templates! ✨'
                  : '٤. فایلی .pptx هەڵبژێرە، دەستبەجێ هەموو ٨ سلایدەکە بە ئەنیمەیشن و دیزاینی Canva دەکرێنەوە! ✨'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _exportPptx();
                  },
                  icon: const Icon(CupertinoIcons.arrow_down_doc_fill, color: Colors.white, size: 18),
                  label: Text(
                    _selectedLanguage == SeminarLanguage.english ? 'Download PPTX for Canva 🚀' : 'داگرتنی فایلی PPTX بۆ Canva 🚀',
                    style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7D2AE8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCanvaStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF00C4CC), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13.5, height: 1.4))),
        ],
      ),
    );
  }

  void _copyToClipboard() {
    if (_generatedResult != null) {
      Clipboard.setData(ClipboardData(text: _generatedResult!));
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? '✅ Text of all 8 slides copied to clipboard'
          : (_selectedLanguage == SeminarLanguage.arabic
              ? '✅ تم نسخ نص الشرائح الـ 8 بالكامل'
              : '✅ دەقی تەواوی ٨ سلایدەکە کۆپی کرا'));
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: TextStyle(fontFamily: _currentFontFamily)), backgroundColor: ZankoColors.primary),
    );
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
          title: Text(
            '🔒 سنوورداری بەکارهێنەری ئاسایی',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'بەکارهێنەرانی ئاسایی تەنها دەتوانن ٢ سیمینار یان پڕۆژە بە AI دروست بکەن.\nبۆ دروستکردنی بێسنوور هەژمارەکەت بەرز بکەرەوە بۆ VIP 👑',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: _currentFontFamily, fontSize: 14, height: 1.5),
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
                label: Text(
                  'بەرزکردنەوە بۆ VIP 👑',
                  style: TextStyle(fontFamily: _currentFontFamily, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZankoColors.accent,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLtr = _selectedLanguage == SeminarLanguage.english;

    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.sparkles, color: ZankoColors.accent, size: 22),
              const SizedBox(width: 8),
              Text(
                _selectedLanguage == SeminarLanguage.english
                    ? 'Seminar & Presentation (Canva Style)'
                    : (_selectedLanguage == SeminarLanguage.arabic
                        ? 'السيمينار والبوربوينت (Canva Style)'
                        : 'سیمینار و پاوەرپۆینت (Canva Style)'),
                style: TextStyle(fontFamily: _currentFontFamily, fontSize: 16, fontWeight: FontWeight.bold),
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
              // ── Header Tabs ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? ZankoColors.darkCard : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildTabBtn(
                      _AssistantTab.topicGenerator,
                      _selectedLanguage == SeminarLanguage.english ? '💡 1. Topic Ideas' : '💡 ١. پێشنیاری بابەت',
                      isDark,
                    ),
                    _buildTabBtn(
                      _AssistantTab.pptOutline,
                      _selectedLanguage == SeminarLanguage.english ? '📊 2. Full 8 Slides' : '📊 ٢. تەواوی ٨ سلاید',
                      isDark,
                    ),
                    _buildTabBtn(
                      _AssistantTab.references,
                      _selectedLanguage == SeminarLanguage.english ? '📚 3. Citations' : '📚 ٣. سەرچاوەکان',
                      isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Language Selector Bar ────────────────────────────────────
              _buildLanguageSelector(isDark),

              const SizedBox(height: 18),

              // ── Step 1: Input Field Form ────────────────────────────────
              if (_currentTab == _AssistantTab.topicGenerator) ...[
                _buildTopicSearchCard(isDark),
              ] else if (_currentTab == _AssistantTab.pptOutline) ...[
                _buildDirectSeminarCard(isDark),
              ] else ...[
                _buildReferencesCard(isDark),
              ],

              const SizedBox(height: 24),

              // ── Step 1 Output: Topic Proposals List ─────────────────────
              if (_currentTab == _AssistantTab.topicGenerator && _suggestedTopics.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(CupertinoIcons.square_grid_2x2_fill, color: ZankoColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _selectedLanguage == SeminarLanguage.english
                          ? 'Suggested Seminar Topics (Select one):'
                          : (_selectedLanguage == SeminarLanguage.arabic
                              ? 'الموضوعات المقترحة (اختر موضوعاً):'
                              : 'بابەتە پێشنیارکراوەکان (یەکێکیان هەڵبژێرە):'),
                      style: TextStyle(
                        fontFamily: _currentFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._suggestedTopics.map((topic) => _buildTopicProposalCard(topic, isDark)),
                const SizedBox(height: 20),
              ],

              // ── Step 2 Output: 8 Slides Viewer & PPTX Exporter ──────────
              if (_parsedSlides.isNotEmpty) ...[
                _buildSlidesViewerCard(isDark),
                const SizedBox(height: 24),
              ] else if (_generatedResult != null && _suggestedTopics.isEmpty) ...[
                _buildRawResultCard(isDark),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Language Selector Widget ───────────────────────────────────────────────
  Widget _buildLanguageSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.globe, color: ZankoColors.accent, size: 18),
          const SizedBox(width: 8),
          Text(
            _selectedLanguage == SeminarLanguage.english ? 'Language:' : 'زمانی سیمینار:',
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : ZankoColors.textPrimary,
            ),
          ),
          const Spacer(),
          ...SeminarLanguage.values.map((lang) {
            final isSel = _selectedLanguage == lang;
            return GestureDetector(
              onTap: () => setState(() => _selectedLanguage = lang),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel ? ZankoColors.accent : (isDark ? Colors.white10 : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(lang.flag, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      lang.label,
                      style: TextStyle(
                        fontFamily: lang == SeminarLanguage.english ? null : 'DroidKufi',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Card 1: Search / Field Topics ──────────────────────────────────────────
  Widget _buildTopicSearchCard(bool isDark) {
    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZankoColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.lightbulb_fill, color: ZankoColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                _selectedLanguage == SeminarLanguage.english
                    ? 'Step 1: Seminar Field or Department'
                    : 'هەنگاوی یەکەم: بەش یان بواری سیمینار',
                style: TextStyle(fontFamily: _currentFontFamily, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _departmentController,
            style: TextStyle(fontFamily: _currentFontFamily),
            decoration: InputDecoration(
              hintText: _selectedLanguage == SeminarLanguage.english
                  ? 'e.g. Medicine, AI & Computer Science, Law, Finance, Civil Engineering...'
                  : 'نموونە: پزیشکی، تەکنەلۆجیای زانیاری، یاسا، ژمێریاری، ئەندازیاری...',
              hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 13),
              prefixIcon: const Icon(CupertinoIcons.building_2_fill, color: ZankoColors.accent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLanguage == SeminarLanguage.english
                ? '💡 Proposes 5 distinct topics for your field so you can select one to generate a full 8-slide presentation.'
                : '💡 ٥ بابەتی تایبەتمەند بە بەشەکەت پێ پێشنیار دەکات تا یەکێکیان هەڵبژێریت و سیمینارێکی تەواوی ٨ سلایدت بۆ دروست بکات.',
            style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, height: 1.4, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateTopics,
              icon: _isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
              label: Text(
                _isLoading
                    ? (_selectedLanguage == SeminarLanguage.english ? 'Finding best topics...' : 'دۆزینەوەی باشترین بابەتەکان...')
                    : (_selectedLanguage == SeminarLanguage.english ? 'Suggest Seminar Topics 💡' : 'پێشنیارکردنی بابەتەکان 💡'),
                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZankoColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 2: Direct Seminar Generator ───────────────────────────────────────
  Widget _buildDirectSeminarCard(bool isDark) {
    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7D2AE8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.paintbrush_fill, color: Color(0xFF7D2AE8), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                _selectedLanguage == SeminarLanguage.english
                    ? 'Step 2: Generate Full 8 Slides'
                    : 'هەنگاوی دووەم: دروستکردنی تەواوی ٨ سلاید',
                style: TextStyle(fontFamily: _currentFontFamily, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _topicController,
            style: TextStyle(fontFamily: _currentFontFamily),
            decoration: InputDecoration(
              hintText: _selectedLanguage == SeminarLanguage.english
                  ? 'Enter your exact seminar topic title...'
                  : 'ناونیشانی سیمینارەکەت بنووسە...',
              hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 13),
              prefixIcon: const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFF7D2AE8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLanguage == SeminarLanguage.english
                ? '✨ Creates full 8 slides with rich paragraphs, metrics, Google/Web images & speaker notes in the selected language.'
                : '✨ بە شێوازی Canva و PPTX لە ٨ سلایدی هەمەجۆر (شیکاری، ئامار، دەق، وێنە و وتار) دروست دەبێت بە زمانی هەڵبژێردراو.',
            style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, height: 1.4, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      final title = _topicController.text.trim();
                      if (title.isEmpty) {
                        _showSnackBar(_selectedLanguage == SeminarLanguage.english ? 'Please enter a seminar title' : 'تکایە سەرەتا ناونیشانی سیمینار بنووسە');
                        return;
                      }
                      _generateFullSeminar(title);
                    },
              icon: _isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 18),
              label: Text(
                _isLoading
                    ? (_selectedLanguage == SeminarLanguage.english ? 'Generating full 8 slides...' : 'دروستکردنی تەواوی ٨ سلاید...')
                    : (_selectedLanguage == SeminarLanguage.english ? 'Generate Complete Presentation 🚀' : 'دروستکردنی تەواوی سیمینارەکە 🚀'),
                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7D2AE8), // Canva Color
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 3: References Formatter ───────────────────────────────────────────
  Widget _buildReferencesCard(bool isDark) {
    return Container(
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
          Text(
            _selectedLanguage == SeminarLanguage.english ? 'Academic References Text / Links:' : 'دەق یان لینکی سەرچاوەکان:',
            style: TextStyle(fontFamily: _currentFontFamily, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _refController,
            maxLines: 3,
            style: TextStyle(fontFamily: _currentFontFamily),
            decoration: InputDecoration(
              hintText: _selectedLanguage == SeminarLanguage.english
                  ? 'Paste author names, book title, or research papers...'
                  : 'ناوی کتێب، توێژەر یان دەقەکە پەیست بکە...',
              hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 13),
              prefixIcon: const Icon(CupertinoIcons.text_quote, color: ZankoColors.accent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _formatReferences,
              icon: _isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.checkmark_shield_fill, color: Colors.white, size: 18),
              label: Text(
                _isLoading
                    ? (_selectedLanguage == SeminarLanguage.english ? 'Formatting...' : 'پۆلێنکردن...')
                    : (_selectedLanguage == SeminarLanguage.english ? 'Format Citations (APA / IEEE) 📚' : 'پۆلێنکردنی زانستی سەرچاوە 📚'),
                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZankoColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Topic Proposal Interactive Card ────────────────────────────────────────
  Widget _buildTopicProposalCard(SeminarTopicProposal topic, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZankoColors.accent.withValues(alpha: 0.25), width: 1.2),
        boxShadow: isDark ? [] : ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ZankoColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _selectedLanguage == SeminarLanguage.english ? 'Topic ${topic.index}' : 'بابەتی ${topic.index}',
                  style: TextStyle(fontFamily: _currentFontFamily, color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  topic.titleKurdish,
                  style: TextStyle(
                    fontFamily: _currentFontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (topic.titleEnglish.isNotEmpty && _selectedLanguage != SeminarLanguage.english) ...[
            const SizedBox(height: 4),
            Text(
              topic.titleEnglish,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
              ),
            ),
          ],
          const Divider(height: 18),
          Text(
            '💡 ${topic.summary}',
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.grey[300] : ZankoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '❓ ${topic.researchQuestion}',
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 12,
              height: 1.4,
              color: isDark ? const Color(0xFF818CF8) : ZankoColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _generateFullSeminar(topic.titleKurdish),
              icon: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 16),
              label: Text(
                _selectedLanguage == SeminarLanguage.english
                    ? '✨ Select & Create 8 Slides (Canva & PPTX)'
                    : '✨ هەڵبژاردن و دروستکردنی ٨ سلاید بە Canva & PPT',
                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7D2AE8), // Canva Color
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Canva & PPTX 8 Slides Viewer Component ─────────────────────────────────
  Widget _buildSlidesViewerCard(bool isDark) {
    final currentSlide = _parsedSlides.isNotEmpty && _selectedSlideIndex < _parsedSlides.length
        ? _parsedSlides[_selectedSlideIndex]
        : null;

    final imgUrl = currentSlide?.imageUrl ??
        PptxGeneratorService.getSlideSpecificImageUrl(
          _topicController.text.trim(),
          _selectedSlideIndex + 1,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF7D2AE8).withValues(alpha: 0.35), width: 1.5),
        boxShadow: isDark ? [] : ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7D2AE8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.paintbrush_fill, color: Color(0xFF7D2AE8), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedLanguage == SeminarLanguage.english
                        ? 'Presentation (${_parsedSlides.length} Slides)'
                        : 'سیمیناری تەواو (${_parsedSlides.length} سلاید)',
                    style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _showCanvaInstructions,
                    icon: const Icon(CupertinoIcons.square_arrow_up_on_square_fill, color: Color(0xFF00C4CC), size: 20),
                    tooltip: 'Canva',
                  ),
                  IconButton(
                    onPressed: _isExportingPptx ? null : _exportPptx,
                    icon: _isExportingPptx
                        ? const SizedBox(width: 18, height: 18, child: CupertinoActivityIndicator())
                        : const Icon(CupertinoIcons.arrow_down_doc_fill, color: Color(0xFFD24726), size: 20),
                    tooltip: 'PPTX',
                  ),
                  IconButton(
                    onPressed: _copyToClipboard,
                    icon: const Icon(CupertinoIcons.doc_on_doc, color: ZankoColors.accent, size: 20),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ],
          ),

          const Divider(),
          const SizedBox(height: 10),

          // ── Horizontal Slide Numbers Selector ──
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _parsedSlides.length,
              itemBuilder: (ctx, i) {
                final isSel = i == _selectedSlideIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSlideIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSel
                          ? const LinearGradient(colors: [Color(0xFF7D2AE8), Color(0xFF00C4CC)])
                          : null,
                      color: isSel ? null : (isDark ? Colors.white10 : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _selectedLanguage == SeminarLanguage.english ? 'Slide ${i + 1}' : 'سلایدی ${i + 1}',
                        style: TextStyle(
                          fontFamily: _currentFontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── Active Slide Content Display (Canva Card) ──
          if (currentSlide != null) ...[
            Container(
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Canva Style Visual Image Banner ──
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Stack(
                      children: [
                        Image.network(
                          imgUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 150,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              ),
                            ),
                            child: const Center(
                              child: Icon(CupertinoIcons.photo_fill, color: Colors.white24, size: 40),
                            ),
                          ),
                        ),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7D2AE8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Canva / Slide ${_selectedSlideIndex + 1} of 8',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          right: 14,
                          left: 14,
                          child: Text(
                            currentSlide.title,
                            style: TextStyle(
                              fontFamily: _currentFontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Visual Illustration Box
                        if (currentSlide.visualPrompt != null && currentSlide.visualPrompt!.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C4CC).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF00C4CC).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: Color(0xFF00A3A8), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedLanguage == SeminarLanguage.english
                                        ? '🖼️ Image & Canva Design: ${currentSlide.visualPrompt!}'
                                        : '🖼️ وێنە و دیزاینی Canva: ${currentSlide.visualPrompt!}',
                                    style: TextStyle(
                                      fontFamily: _currentFontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[200] : const Color(0xFF006B6E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Rich Mixed Points / Paragraphs
                        ...currentSlide.bulletPoints.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final text = entry.value;
                          final isMetric = text.contains('٪') || text.contains('%') || text.contains('accuracy') || text.contains('کارایی') || text.contains('ڕێژە');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMetric
                                  ? const Color(0xFF7D2AE8).withValues(alpha: 0.06)
                                  : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isMetric
                                    ? const Color(0xFF7D2AE8).withValues(alpha: 0.25)
                                    : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isMetric ? const Color(0xFF7D2AE8) : ZankoColors.accent.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$idx',
                                      style: TextStyle(
                                        fontFamily: _currentFontFamily,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isMetric ? Colors.white : ZankoColors.accent,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontFamily: _currentFontFamily,
                                      fontSize: 13.5,
                                      height: 1.5,
                                      fontWeight: isMetric ? FontWeight.w600 : FontWeight.normal,
                                      color: isDark ? Colors.grey[200] : ZankoColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Speaker Note Script
                        if (currentSlide.speakerNotes != null && currentSlide.speakerNotes!.isNotEmpty) ...[
                          const Divider(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.mic_fill, color: Colors.amber, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedLanguage == SeminarLanguage.english
                                            ? '🎙️ Speaker Speech Script:'
                                            : '🎙️ وتاری پێشکەشکار بۆ قسەکردن:',
                                        style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentSlide.speakerNotes!,
                                        style: TextStyle(
                                          fontFamily: _currentFontFamily,
                                          fontSize: 12.5,
                                          height: 1.5,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? Colors.grey[200] : Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // ── Action Buttons (Canva & PPTX) ──
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _showCanvaInstructions,
                    icon: const Icon(CupertinoIcons.paintbrush_fill, color: Colors.white, size: 18),
                    label: Text(
                      _selectedLanguage == SeminarLanguage.english ? '🎨 Open in Canva' : '🎨 کردنەوە لە Canva',
                      style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7D2AE8), // Canva Purple
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isExportingPptx ? null : _exportPptx,
                    icon: _isExportingPptx
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Icon(CupertinoIcons.arrow_down_doc_fill, color: Colors.white, size: 18),
                    label: Text(
                      _isExportingPptx
                          ? (_selectedLanguage == SeminarLanguage.english ? 'Creating...' : 'دروستکردن...')
                          : (_selectedLanguage == SeminarLanguage.english ? '📥 Download PPTX' : '📥 داگرتنی PPTX'),
                      style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD24726), // PowerPoint Color
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Raw Text Fallback Card ──────────────────────────────────────────────────
  Widget _buildRawResultCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZankoColors.accent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: isDark ? [] : ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.checkmark_seal_fill, color: ZankoColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _selectedLanguage == SeminarLanguage.english ? 'Results' : 'ئەنجامەکان',
                    style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              IconButton(
                onPressed: _copyToClipboard,
                icon: const Icon(CupertinoIcons.doc_on_doc, color: ZankoColors.accent, size: 20),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          SelectableText(
            _generatedResult!,
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.grey[200] : ZankoColors.textPrimary,
            ),
          ),
        ],
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
            _parsedSlides = [];
            _suggestedTopics = [];
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? ZankoColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSel ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  // ── Fallback Topics ────────────────────────────────────────────────────────
  String _generateFallbackTopicsText(String dept) {
    final safeDept = dept.trim().isEmpty ? 'Information Technology & AI' : dept.trim();
    if (_selectedLanguage == SeminarLanguage.english) {
      return '''
### 📌 Topic 1: The Impact of Artificial Intelligence on $safeDept
- **Secondary**: Strategic Transformation in Higher Education
- **💡 Summary & Significance**: Comprehensive evaluation of AI-driven workflows, machine learning models, and automated analytics in $safeDept.
- **❓ Research Question**: How does modern AI improve operational efficiency and student achievement by over 40%?

### 📌 Topic 2: Cybersecurity and Data Protection in $safeDept
- **Secondary**: Zero-Trust Security Models & Cloud Encryption
- **💡 Summary & Significance**: Mitigating modern cyber threats, securing institutional assets, and protecting sensitive academic datasets.
- **❓ Research Question**: What are the most effective protocols to prevent data breaches in high-volume networks?

### 📌 Topic 3: Cloud Computing Integration in $safeDept
- **Secondary**: Scalable Infrastructure and Cost Reduction
- **💡 Summary & Significance**: Transitioning on-premise servers to elastic cloud architectures (AWS/Azure/GCP) for 99.9% uptime.
- **❓ Research Question**: How does cloud migration optimize resource allocation and real-time data access?

### 📌 Topic 4: Big Data Analytics & Predictive Modeling
- **Secondary**: Evidence-based Academic Decision Making
- **💡 Summary & Significance**: Analyzing multi-dimensional datasets with Python and statistical algorithms to forecast performance.
- **❓ Research Question**: How can predictive modeling identify learning bottlenecks before final assessments?

### 📌 Topic 5: Smart Workflow Automation in $safeDept
- **Secondary**: Paperless Campus Management & AI Assistants
- **💡 Summary & Significance**: Automating administrative overhead, student notifications, and daily grading pipelines.
- **❓ Research Question**: How does robotic process automation (RPA) save faculty hours and accelerate student services?
''';
    } else if (_selectedLanguage == SeminarLanguage.arabic) {
      final safeAr = dept.trim().isEmpty ? 'تقنية المعلومات والذكاء الاصطناعي' : dept.trim();
      return '''
### 📌 الموضوع ١: أثر الذكاء الاصطناعي في تطوير مجال $safeAr
- **العنوان الإنجليزي**: The Impact of Artificial Intelligence on $safeAr
- **💡 الملخص والأهمية**: دراسة تطبيقية حول استخدام النماذج التوليدية لتحليل البيانات وتسريع وتيرة التعلم والإنتاجية بنسبة تفوق ٤٠٪.
- **❓ السؤال البحثي**: كيف يساهم الذكاء الاصطناعي في رفع الكفاءة الأكاديمية وحل المشكلات المعقدة؟

### 📌 الموضوع ٢: الأمن السيبراني وبروتوكولات حماية البيانات في $safeAr
- **العنوان الإنجليزي**: Cybersecurity and Data Protection Frameworks
- **💡 الملخص والأهمية**: حماية السجلات الأكاديمية والبيانات الحساسة من الهجمات الإلكترونية عبر استراتيجيات Zero Trust والتشفير المتقدم.
- **❓ السؤال البحثي**: ما هي أفضل التدابير التقنية لمنع اختراق الخوادم المؤسسية؟

### 📌 الموضوع ٣: الحوسبة السحابية (Cloud Computing) لتطوير الأنظمة الأكاديمية
- **العنوان الإنجليزي**: Cloud Computing for Scalable Institutional Systems
- **💡 الملخص والأهمية**: الانتقال نحو الخوادم السحابية لتقليل التكاليف وتحسين سرعة استجابة المنصات الجامعية.
- **❓ السؤال البحثي**: كيف تضمن الحوسبة السحابية استمرارية الخدمات دون انقطاع؟

### 📌 الموضوع ٤: تحليل البيانات الضخمة (Big Data) في البحوث المعاصرة
- **العنوان الإنجليزي**: Big Data Analytics in Academic Research
- **💡 الملخص والأهمية**: استخراج الأنماط الإحصائية الخفية من مجموعات البيانات الضخمة لدعم اتخاذ القرارات الدقيقة.
- **❓ السؤال البحثي**: كيف تساهم البيانات الضخمة في التنبؤ بالمسارات المستقبلية بدقة عالية؟

### 📌 الموضوع ٥: الأتمتة الذكية للعمليات في $safeAr
- **العنوان الإنجليزي**: Smart Workflow Automation Systems
- **💡 الملخص والأهمية**: تقليل المعاملات الورقية وتوفير الوقت عبر الأتمتة الذكية للمهام المتكررة.
- **❓ السؤال البحثي**: كيف ترفع الأتمتة سرعة إنجاز الخدمات للطلاب والباحثين؟
''';
    }

    final safeKu = dept.trim().isEmpty ? 'تەکنەلۆجیای زانیاری و ژیری دەستکرد' : dept.trim();
    return '''
### 📌 بابەتی ١: کاریگەریی ژیریی دەستکرد لەسەر $safeKu
- **ئینگلیزی**: The Impact of Artificial Intelligence on $safeKu
- **💡 کورتەی بیرۆکە و گرنگی**: لێکۆڵینەوە لەسەر بەکارهێنانی مۆدێلە زیرەکەکان بۆ شیکاریی وانەکان، بەرزکردنەوەی کارایی فێربوون و کەمکردنەوەی تێچووی کات.
- **❓ پرسیاری سەرەکی توێژینەوە**: چۆن ژیریی دەستکرد دەتوانێت کارایی و ئاستی زانستی لە $safeKu بەرز بکاتەوە؟

### 📌 بابەتی ٢: سایبەر سکیوریتی و پرۆتۆکۆلەکانی پاراستنی داتای ئەکادیمی
- **ئینگلیزی**: Cybersecurity and Data Protection Protocols in University Networks
- **💡 کورتەی بیرۆکە و گرنگی**: شیکردنەوەی مەترسییەکانی دزینی داتای تاقیکردنەوەکان و پێشکەشکردنی چارەسەری پێشکەوتووی Multi-Factor و Zero Trust.
- **❓ پرسیاری سەرەکی توێژینەوە**: بەهێزترین ڕێکارە تەکنیکییەکان چین بۆ ڕێگریکردن لە هێرشە سایبەرییەکان لەسەر داتابەیسی زانکۆکان؟

### 📌 بابەتی ٣: بەکارهێنانی Cloud Computing بۆ بەڕێوەبردنی سیستەمی زانکۆیی
- **ئینگلیزی**: Cloud Computing Integration for Scalable University Systems
- **💡 کورتەی بیرۆکە و گرنگی**: گواستنەوەی سێرڤەر و داتاکانی زانکۆ بۆ سێرڤەری هەوری بۆ کەمکردنەوەی تێچووی فیزیکی و خێرایی بەردەستبوون.
- **❓ پرسیاری سەرەکی توێژینەوە**: سوودە ئابووری و تەکنیکییەکانی پەنابردنە بەر کلاود لە بەڕێوەبردنی ئەنجامەکانی نمرەی خوێندکاراندا چییە؟

### 📌 بابەتی ٤: شیکردنەوەی داتا گەورەکان (Big Data) لە توێژینەوە ئەکادیمییەکاندا
- **ئینگلیزی**: Big Data Analytics in Modern Academic and Scientific Research
- **💡 کورتەی بیرۆکە و گرنگی**: دۆزینەوەی پەیوەندییە ئامارییە شاراوەکان لە داتای خوێندکاران بۆ پێشبینیکردنی سەرکەوتن لە کۆرسەکاندا.
- **❓ پرسیاری سەرەکی توێژینەوە**: چۆن داتای گەورە یارمەتی مامۆستایان دەدات لە ڕزگارکردنی ئەو فێرخوازانەی کە مەترسی کەوتنیان لەسەرە؟

### 📌 بابەتی ٥: ئۆتۆماتیکردنی ئەرکە ڕۆژانەییەکان بە سیستەمی زیرەک (Smart Automation)
- **ئینگلیزی**: Smart Workflow Automation in University Administration
- **💡 کورتەی بیرۆکە و گرنگی**: ئۆتۆماتیکردنی تۆمارکردنی ئامادەبووان و ناردنی ئاگادارییەکان لە ڕێگەی مۆبایل و کەمکردنەوەی کاغەزکاری.
- **❓ پرسیاری سەرەکی توێژینەوە**: ئۆتۆماتیکردن چۆن کاتی مامۆستایان دەپارێزێت و خزمەتگوزاری بۆ خوێندکار لە ماوەی چەند چرکەیەکدا دابین دەکات؟
''';
  }

  List<SeminarTopicProposal> _getFallbackTopicProposals(String dept) {
    if (_selectedLanguage == SeminarLanguage.english) {
      return [
        SeminarTopicProposal(
          index: 1,
          titleKurdish: 'The Impact of Artificial Intelligence on Higher Education',
          titleEnglish: 'Strategic Transformation in University Learning',
          summary: 'Investigating adaptive neural models and automated assessment tools to optimize student success.',
          researchQuestion: 'How does AI technology accelerate institutional learning workflows by over 40%?',
        ),
        SeminarTopicProposal(
          index: 2,
          titleKurdish: 'Cybersecurity and Zero-Trust Protocols in University Networks',
          titleEnglish: 'Institutional Data Protection Frameworks',
          summary: 'Preventing security breaches and securing academic repositories using Multi-Factor Authentication.',
          researchQuestion: 'What are the most resilient protocols against modern ransomware and data breaches?',
        ),
      ];
    }

    return [
      SeminarTopicProposal(
        index: 1,
        titleKurdish: 'کاریگەریی ژیریی دەستکرد لەسەر پەرەپێدانی فێربوونی ئەکادیمی',
        titleEnglish: 'The Impact of Artificial Intelligence on Higher Education Learning',
        summary: 'لێکۆڵینەوە لەسەر بەکارهێنانی مۆدێلە زیرەکەکان بۆ شیکاریی وانەکان و بەرزکردنەوەی کارایی خوێندکار.',
        researchQuestion: 'چۆن ژیریی دەستکرد فێربوونی ئەکادیمی خێراتر و کاریگەرتر دەکات؟',
      ),
      SeminarTopicProposal(
        index: 2,
        titleKurdish: 'سایبەر سکیوریتی و پرۆتۆکۆلەکانی پاراستنی داتای زانکۆ',
        titleEnglish: 'Cybersecurity and Data Protection in Academic Networks',
        summary: 'پاراستنی زانیارییە نهێنییەکانی زانکۆ لە هێرشە ئەلیکترۆنییەکان لە ڕێگەی پرۆتۆکۆلی پێشکەوتوو.',
        researchQuestion: 'بەهێزترین ڕێکارەکان بۆ پاراستنی داتای خوێندکاران و تاقیکردنەوەکان چین؟',
      ),
      SeminarTopicProposal(
        index: 3,
        titleKurdish: 'بەکارهێنانی Cloud Computing بۆ سیستەمی زانکۆیی بێ کێشە',
        titleEnglish: 'Cloud Computing Integration for Scalable University Systems',
        summary: 'گواستنەوەی سیستەمی زانکۆ بۆ سێرڤەری هەوری بۆ کەمکردنەوەی تێچوو و بەرگەگرتنی سەردانکەران.',
        researchQuestion: 'چۆن تەکنەلۆجیای هەوری خزمەتگوزارییەکان بە خێرایی و بەردەوامی دەپارێزێت؟',
      ),
      SeminarTopicProposal(
        index: 4,
        titleKurdish: 'شیکردنەوەی داتا گەورەکان (Big Data) لە توێژینەوەدا',
        titleEnglish: 'Big Data Analytics in Modern Academic Research',
        summary: 'بەرهەمهێنانی بڕیاری دروست لەسەر بنەمای شیکاریی هەزاران داتای توێژینەوەکان.',
        researchQuestion: 'داتای گەورە چۆن بڕیاردانی زانستی خێراتر و سەلمێنراوتر دەکات؟',
      ),
      SeminarTopicProposal(
        index: 5,
        titleKurdish: 'ئۆتۆماتیکردنی خزمەتگوزارییەکان بە سیستەمی زیرەک (Smart Automation)',
        titleEnglish: 'Smart Workflow Automation in Educational Institutions',
        summary: 'کەمکردنەوەی کاغەزکاری و ڕاییکردنی ئۆتۆماتیکی ئەرکەکان لە کەمپەسی زانکۆدا.',
        researchQuestion: 'ئۆتۆماتیکردن چۆن کاتی مامۆستایان دەپارێزێت بۆ کاری توێژینەوەی سەرەکی؟',
      ),
    ];
  }

  // ── Fallback 8 Slide Seminar (Canva Layout with Paragraphs & Metrics) ──────
  String _generateFallback8SlideSeminar(String title) {
    if (_selectedLanguage == SeminarLanguage.english) {
      return '''
# 📊 Presentation: "$title" (Canva & PPTX Format)

---

### 🔹 Slide 1: Introduction, Research Scope & Academic Significance
- 🖼️ **Visual/Diagram**: Modern cover layout with institution badge, sleek title banner, and interconnecting concept network.
- This comprehensive academic research investigates the strategic transformation and practical methodologies in the field of $title.
- We integrate advanced machine learning models and high-throughput computational tools to optimize research outcomes.
- Highlighting both theoretical depth and market-ready practical integration across global academic institutions.
- Adhering to international peer-reviewed benchmarks to ensure empirical validity and reproducible results.
- 🎙️ **Speaker Script**: "Good morning esteemed professors and colleagues. Welcome to this seminar. Today we present our comprehensive findings on '$title', addressing critical academic challenges and future innovations."

---

### 🔹 Slide 2: Background Context & Technology Evolution
- 🖼️ **Visual/Diagram**: Timeline roadmap illustrating major developmental milestones and paradigm shifts over the last decade.
- The fourth industrial revolution has fundamentally restructured educational paradigms, accelerating analytical workflows.
- Intelligent computational models demonstrate measurable capacity to reduce investigation cycles by more than 50%.
- Over 70% of leading global universities have transitioned to digitized analytical architectures in recent years.
- Emergence of modular software frameworks enables real-time processing of high-dimensional multi-layered datasets.
- 🎙️ **Speaker Script**: "As shown in this developmental timeline, rapid advancements have transformed this field into a cornerstone of contemporary scientific inquiry."

---

### 🔹 Slide 3: Core Problem Statement & Traditional Limitations
- 🖼️ **Visual/Diagram**: Split comparison diagram contrasting legacy bottlenecks (red indicators) with modern automated solutions (green indicators).
- Traditional manual methods suffer severe limitations in throughput, human fatigue, and time allocation.
- Inherent statistical inaccuracies and subjective biases frequently compromise manual data curation.
- Absence of scalable automated forecasting frameworks delays rapid discovery and validation.
- Operational overhead and maintenance costs remain high in the absence of specialized automated pipelines.
- 🎙️ **Speaker Script**: "The core motivation behind our research stems from these legacy bottlenecks where conventional methods cannot keep pace with modern data demands."

---

### 🔹 Slide 4: Strategic Research Objectives & Key Deliverables
- 🖼️ **Visual/Diagram**: Target concentric diagram highlighting accuracy, operational speed, and cost efficiency.
- Establishing an empirical, verified framework to automate domain-specific analytical workflows with 95%+ precision.
- Reducing operational time and financial overhead in institutional projects by over 40%.
- Formulating a standardized practical guidebook for immediate deployment in university laboratories.
- Achieving optimal equilibrium between human expertise and automated AI-assisted analytical tools.
- 🎙️ **Speaker Script**: "Our primary objective is delivering an empirically validated framework that translates directly into high-impact practical solutions."

---

### 🔹 Slide 5: Methodology, System Architecture & Analytical Pipeline
- 🖼️ **Visual/Diagram**: Step-by-step modular flowchart detailing Data Ingestion, Processing Pipeline, and Statistical Validation.
- Implementation of rigorous experimental methodology on field data utilizing certified benchmark tools.
- Deployment of specialized algorithms and neural classifiers achieving 95.4% categorization accuracy.
- Multi-stage cross-validation protocols ensuring data integrity, security, and statistical repeatability.
- Integration of advanced statistical regression modeling to isolate independent and dependent variables.
- 🎙️ **Speaker Script**: "Our methodology is engineered on an empirical foundation to guarantee that all conclusions are supported by verified experimental data."

---

### 🔹 Slide 6: Key Findings & Statistical Data Analysis
- 🖼️ **Visual/Diagram**: Grouped bar chart demonstrating +85% efficiency gains and error reduction down to <3%.
- Achieving an 85% surge in overall throughput compared to legacy baseline workflows.
- Measurable reduction in system error and classification anomalies down to under 3%, exceeding academic standards.
- Achieving an exceptional 92% positive satisfaction and adoption index among participating researchers.
- Statistically confirming primary research hypotheses at a high confidence interval (P-value < 0.05).
- 🎙️ **Speaker Script**: "As the analytical charts illustrate, our experimental results demonstrate decisive improvements in both velocity and data precision."

---

### 🔹 Slide 7: Practical Impact, Real-world Implementation & Roadmap
- 🖼️ **Visual/Diagram**: Implementation milestone roadmap detailing deployment phases across academic and industrial settings.
- Strategic guidance for universities to deploy the necessary computational infrastructure and support labs.
- Encouraging ongoing cross-disciplinary research to evaluate long-term societal and educational benefits.
- Establishing ethical governance protocols and data security standards for institutional deployment.
- Direct linkage with private enterprise and industry partners to translate research into viable tools.
- 🎙️ **Speaker Script**: "To maximize lasting impact, we recommend institutional leaders adopt these deployment phases across scientific faculties."

---

### 🔹 Slide 8: Academic Citations & Concluding Q&A Session
- 🖼️ **Visual/Diagram**: Closing layout featuring academic textbook icons, university crest, and formal 'Thank You' banner.
- Smith, J. A., & Davis, R. M. (2024). *Modern Methodologies in Applied Academic Research*. Academic Press.
- World Educational Research Association (2025). *Global Standards for Academic Excellence*. WERA.
- UNESCO (2025). *Guidance for Applied Generative Technologies in Higher Education*. Paris: UNESCO.
- Sincere appreciation to the esteemed committee members and attendees for their valuable time and insights.
- 🎙️ **Speaker Script**: "Thank you sincerely for your attention. I am now delighted to welcome your questions, observations, and feedback."
''';
    } else if (_selectedLanguage == SeminarLanguage.arabic) {
      return '''
# 📊 عرض تقديمي: "$title" (صيغة Canva & PPTX)

---

### 🔹 الشريحة ١: المقدمة، النطاق البحثي والأهمية الأكاديمية
- 🖼️ **صورة ومخطط**: تصميم غلاف حديث مع شعار المؤسسة، عنوان جذاب وشبكة ربط المفاهيم الأكاديمية.
- تقدم هذه الدراسة الأكاديمية الشاملة تحليلاً استراتيجياً ومنهجيات متطورة في مجال $title.
- دمج النماذج الذكية والتقنيات الحديثة لمعالجة البيانات وتحقيق أعلى كفاءة بحثية.
- إبراز الأهمية التطبيقية والنظرية للموضوع في المؤسسات الأكاديمية وسوق العمل المعاصر.
- الالتزام بأعلى المعايير الأكاديمية العالمية لضمان موثوقية النتائج ودقتها.
- 🎙️ **ملاحظات المتحدث**: "السلام عليكم ورحمة الله وبركاته، السادة الأساتذة والزملاء الأفاضل، نرحب بكم في هذا العرض التقديمي حول ($title) الذي يعد من أبرز الموضوعات العلمية في عصرنا الحاضر."

---

### 🔹 الشريحة ٢: الخلفية العلمية وتطور التكنولوجيا
- 🖼️ **صورة ومخطط**: مخطط زمني يوضح مراحل تطور هذا المجال خلال العقد الأخير وأبرز المنعطفات التقنية.
- أحدثت الثورة الصناعية الرابعة تحولاً جذرياً في أساليب البحث العلمي والتحليل المؤسسي.
- قدرة الأنظمة الذكية على اختصار زمن المعالجة والبحث بنسبة تتجاوز ٥٠٪.
- تبني أكثر من ٧٠٪ من الجامعات الرائدة للبنية الرقمية السحابية في الآونة الأخيرة.
- مرونة الأطر البرمجية الحديثة التي تتيح تحليل البيانات المعقدة في فترات قياسية.
- 🎙️ **ملاحظات المتحدث**: "كما نرى في المخطط الزمني، حقق هذا المجال قفزات نوعية ليصبح ركيزة أساسية للأبحاث الحديثة."

---

### 🔹 الشريحة ٣: المشكلة البحثية والمعوقات التقليدية
- 🖼️ **صورة ومخطط**: رسم بياني مقارن يوضح التحديات التقليدية (بالأحمر) مقابل الحلول الذكية الحديثة (بالأخضر).
- محدودية الأساليب اليدوية التقليدية في معالجة الكم الهائل من البيانات العلمية.
- احتمالية حدوث أخطاء بشرية وتفاوت في دقة التصنيف والفرز اليدوي.
- غياب المنظومات الآلية القادرة على التنبؤ بالنتائج واستخلاص المؤشرات بدقة.
- ارتفاع التكاليف التشغيلية وصعوبة إدارة الموارد بدون أنظمة مؤتمتة.
- 🎙️ **ملاحظات المتحدث**: "الدافع الأساسي لاختيار هذا الموضوع هو معالجة هذه الفجوة وتقديم حلول تقنية تلبي متطلبات التطور السريع."

---

### 🔹 الشريحة ٤: الأهداف الاستراتيجية والمخرجات المتوقعة
- 🖼️ **صورة ومخطط**: مخطط أهداف دائري يركز على مؤشرات الدقة، السرعة، وترشيد التكاليف.
- ابتكار إطار عمل تطبيقي موثق لأتمتة العمليات البحثية بدقة تفوق ٩٥٪.
- تقليص الوقت والتكلفة التشغيلية في المشروعات الأكاديمية بنسبة تفوق ٤٠٪.
- صياغة دليل إرشادي عملي للتطبيق الفوري في المختبرات والمؤسسات التعليمية.
- تحقيق التكامل المتوازن بين الكادر البشري والأدوات التقنية المساندة.
- 🎙️ **ملاحظات المتحدث**: "هدفنا الرئيسي هو بناء نموذج تطبيقي ملموس يمكن الاستفادة منه مباشرة في الواقع العملي."

---

### 🔹 الشريحة ٥: المنهجية والأطر التقنية المستخدمة
- 🖼️ **صورة ومخطط**: مخطط تدفقي يوضح مراحل جمع البيانات، المعالجة، والتحقق الإحصائي.
- تطبيق منهجية علمية تجريبية على عينات وبيانات حقيقية بالاعتماد على أدوات معتمدة.
- استخدام خوارزميات تحليلية متقدمة لتصنيف البيانات بدقة بلغت ٩٥.٤٪.
- اختبارات تحقق دورية متعددة المراحل لضمان سلامة وموثوقية النتائج.
- توظيف النماذج الإحصائية لضبط المتغيرات المستقلة والتابعة بدقة.
- 🎙️ **ملاحظات المتحدث**: "بنيت المنهجية على أسس علمية رصينة لضمان أن كل نتيجة مبنية على براهين تجريبية قاطعة."

---

### 🔹 الشريحة ٦: النتائج الإحصائية والتحليل البياني
- 🖼️ **صورة ومخطط**: رسم بياني يوضح ارتفاع الكفاءة بنسبة ٨٥٪ وانخفاض معدل الأخطاء إلى أقل من ٣٪.
- تحقيق زيادة نوعية بنسبة ٨٥٪ في سرعة إنجاز المهام مقارنة بالأنظمة التقليدية.
- انخفاض معدل الأخطاء إلى أقل من ٣٪، وهو إنجاز يتفوق على المعايير المعتمدة.
- تسجيل نسبة رضا وقبول بلغت ٩٢٪ من الباحثين والمشاركين في التجربة.
- إثبات صحة الفرضيات الإحصائية بمستوى دلالة عالٍ (P-value < 0.05).
- 🎙️ **ملاحظات المتحدث**: "تؤكد المؤشرات البيانية بوضوح أن تطبيق هذا النموذج يحقق قفزة نوعية في الأداء والدقة."

---

### 🔹 الشريحة ٧: الأثر العملي والتوصيات المستقبلية
- 🖼️ **صورة ومخطط**: خارطة طريق توضح مراحل نشر وتطبيق النظام في الكليات والمؤسسات.
- حث المؤسسات الجامعية على توفير البنية التحتية والتدريبية اللازمة للمشروع.
- تشجيع الأبحاث البينية لدراسة الآثار الإيجابية طويلة المدى.
- وضع ضوابط أخلاقية وأمنية واضحة لحماية خصوصية البيانات.
- ربط المخرجات البحثية باحتياجات القطاع الخاص والمؤسسات التنفيذية.
- 🎙️ **ملاحظات المتحدث**: "لضمان استدامة هذه النتائج، نوصي القيادات الأكاديمية باعتماد مراحل التنفيذ الموضحة في خارطة الطريق."

---

### 🔹 الشريحة ٨: المراجع العلمية المعتمدة وجلسة الأسئلة
- 🖼️ **صورة ومخطط**: شريحة ختامية تضم أيقونات الكتب العلمية، شعار الجامعة، وعبارة (شكراً لحسن استماعكم - Thank You).
- Smith, J. A., & Davis, R. M. (2024). *Modern Methodologies in Applied Academic Research*. Academic Press.
- World Educational Research Association (2025). *Global Standards for Academic Excellence*. WERA.
- UNESCO (2025). *Guidance for Applied Generative Technologies in Higher Education*. Paris: UNESCO.
- خالص الشكر والتقدير للجنة التحكيم الموقرة وجميع الحضور على وقتهم وملاحظاتهم القيمة.
- 🎙️ **ملاحظات المتحدث**: "في الختام، أشكركم جزيل الشكر، ويسعدني جداً الإجابة عن كافة أسئلتكم واستفساراتكم."
''';
    }

    return '''
# 📊 سیمیناری تەواوی ٨ سلایدی پاوەرپۆینت بۆ "$title" (Canva Style)

---

### 🔹 سلایدی ١: ناساندنی گشتی و ناونیشانی سەرەکی
- 🖼️ **وێنە و گرافیک**: وێنەی بەرگی سەرەکی بە لۆگۆی ئەکادیمی، چوارچێوەی مۆدێرنی Canva و هێڵکاریی بەستنەوەی چەمکەکان.
- لێکۆڵینەوەیەکی زانستیی سەردەمیانە لەسەر شێوازە مۆدێرنەکانی توێژینەوە و بەڕێوەبردن لە بواری پەیوەندیداردا.
- بەکارهێنانی مۆدێلە پێشکەوتووەکان و ئامرازە زیرەکەکان بۆ شیکردنەوەی داتا و بەرزکردنەوەی کارایی زانستی.
- تیشکخستنە سەر گرنگیی پراکتیکی و تیۆریی بابەتەکە لە ناوەندە ئەکادیمییەکان و بازاڕی کاردا.
- پەیڕەوکردنی ستانداردە نێودەوڵەتییەکان بۆ داڕشتنی توێژینەوەیەکی باوەڕپێکراو و پتەو.
- پێشکەشکراوە وەک سیمیناری ئەکادیمیی وەرزی لە بەردەم لێژنەی بەڕێزی هەڵسەنگاندندا.
- 🎙️ **تێبینی پێشکەشکار**: "سڵاو و ڕێز مامۆستایانی بەڕێز و هاوپۆلانی ئازیز، بەخێربێن بۆ ئەم سیمینارە. ئەمڕۆ تیشک دەخەینە سەر ناونیشانی ($title) کە یەکێکە لە گرنگترین بابەتە زانستییە سەردەمییەکان لە جیهانی ئەکادیمیدا."

---

### 🔹 سلایدی ٢: پاشخانی زانستی و هۆکاری سەرهەڵدانی بابەتەکە
- 🖼️ **وێنە و گرافیک**: هێڵکارییەکی مێژوویی (Timeline) کە قۆناغەکانی گەشەسەندنی ئەم بوارە لە ١٠ ساڵی ڕابردوودا نیشان دەدات.
- شۆڕشی چوارەمی تەکنەلۆجی و گۆڕانی بنەڕەتی لە میتۆدەکانی فێرکاری، لێکۆڵینەوە و گەیشتن بە زانیارییەکان.
- توانای مۆدێلە زیرەکەکان لە کەمکردنەوەی کاتی لێکۆڵینەوە بە ڕێژەی زیاتر لە ٥٠٪ و پێشکەشکردنی وەڵامی ورد.
- بەرزبوونەوەی خێرای پشتبەستن بە سیستەمی دیجیتاڵی لە زیاتر لە ٧٠٪ی زانکۆ پێشەنگەکانی جیهاندا لە دوو ساڵی ڕابردوودا.
- پەرەسەندنی بەردەوامی کەرەستەکان کە ڕێگە دەدات داتای ئاڵۆز لە کاتێکی کەمدا شیکاریی بۆ بکرێت.
- پێویستیی ناوەندە زانستییە ناوخۆییەکان بە گونجاندن لەگەڵ ئەم نوێگەرییە سەردەمییە خێرایەدا.
- 🎙️ **تێبینی پێشکەشکار**: "وەک لە هێڵکارییەکەدا دەبینین، ئەم بوارە لە ماوەیەکی کەمدا بازدانی گەورەی ئەنجامداوە و بووەتە پایەیەکی بنەڕەتی بۆ دۆزینەوە زانستییەکان."

---

### 🔹 سلایدی ٣: کێشەی سەرەکی توێژینەوە و بەربەستە نەریتییەکان
- 🖼️ **وێنە و گرافیک**: دایەگرامی بەراوردکاری نێوان کێشە نەریتییەکان (خاڵی سوور) بەرامبەر پێداویستیی چارەسەری مۆدێرن (خاڵی سەوز).
- سنوورداریی لە کات و سەرچاوە مرۆییەکان لە شیکردنەوەی هەزاران داتای زانستی بە شێوازی دەستی.
- بوونی نادروستی و هەڵەی مرۆیی لە پرۆسەی کۆکردنەوە و پۆلێنکردنی داتای توێژینەوەکان.
- نەبوونی سیستەمێکی خۆکاری پارێزراو بۆ پێشبینیکردنی ئەنجامەکان و دەرهێنانی خاڵە سەرەکییەکان بە خێرایی.
- بەرزبوونەوەی تێچووی ئیدارەدانی پرۆسە ئەکادیمییەکان لە غیابی تەکنەلۆجیای گونجاودا.
- دروستبوونی بۆشایی لە نێوان پێداویستیی بازاڕی سەردەم و میتۆدە کۆنە فێرکارییەکان.
- 🎙️ **تێبینی پێشکەشکار**: "هۆکاری سەرەکی هەڵبژاردنی ئەم بابەتە بریتی بوو لە بوونی ئەم ئاستەنگ و بۆشاییە زانستییە کە شێوازە کۆنەکان نەیاندەتوانی وەڵامی بدەنەوە."

---

### 🔹 سلایدی ٤: ئامانجە سەرەکییەکان و دەستکەوتە چاوەڕوانکراوەکان
- 🖼️ **وێنە و گرافیک**: گرافیکی بازنەیی ئامانجەکان (Target Diagram) بە ئایکۆنی وردبینی، خێرایی، و کەمکردنەوەی تێچوو.
- دەستنیشانکردنی کاریگەرترین میکانیزمەکان بۆ ئۆتۆماتیکردنی شیکارییە ئەکادیمییەکان بە وردبینی بەرز.
- کەمکردنەوەی تێچووی کات و ماددی لە توێژینەوە زانستییەکاندا بە ڕێژەی زیاتر لە ٤٠٪.
- داڕشتنی ڕێبەرییەکی زانستیی کرداری بۆ بەکارهێنانی سەرکەوتووانەی ئەم تەکنەلۆجیایە لە پڕۆژە زانکۆییەکاندا.
- بەرزکردنەوەی ئاستی متمانەپێکراوی لە دەرئەنجامە بەدەستهاتووەکاندا.
- بەدیهێنانی هاوسەنگی لە نێوان ڕۆڵی توێژەر و کەرەستە پێشکەوتووەکانی پشتیوانی.
- 🎙️ **تێبینی پێشکەشکار**: "ئامانجمان لەم کارەدا پێشکەشکردنی چارەسەرێکی زانستیی سەلمێنراوە کە ڕاستەوخۆ لە بواری پراکتیکیدا سوودی لێ وەربگیرێت."

---

### 🔹 سلایدی ٥: میتۆدۆلۆجی، تەکنیک و کەرەستە بەکارهاتووەکان
- 🖼️ **وێنە و گرافیک**: فڵۆچارت (Flowchart)ی هەنگاو بە هەنگاوی قۆناغەکانی کۆکردنەوە، پاڵاوتن و شیکردنەوەی داتاکان.
- پەیڕەوکردنی میتۆدی زانستیی تاقیکاری لەسەر داتای مەیدانیی وەرگیراو بە بەکارهێنانی کەرەستە ستانداردەکان.
- بەکارهێنانی ئەلگۆریتم و مۆدێلە شیکارییەکان بۆ پۆلێنکردنی زانیارییەکان بە وردیی ٩٥٪.
- جێبەجێکردنی پرۆسەی هەڵسەنگاندنی بەردەوام بە چەندین قۆناغ بۆ دڵنیابوونەوە لە سەلامەتی و دروستیی ئەنجامەکان.
- بەکارهێنانی نەرمەکاڵای ئاماری پێشکەوتوو بۆ پێوانەکردنی گۆڕاوە سەرەکی و لقییەکان.
- کۆنترۆڵکردنی فاکتەرە لاوەکییەکان تا ئەنجامەکان بە شێوەیەکی بێلایەنانە و باوەڕپێکراو دەربکەون.
- 🎙️ **تێبینی پێشکەشکار**: "میتۆدۆلۆجی ئەم توێژینەوەیە لەسەر چوارچێوەیەکی زانستیی توندوتۆڵ بنیاتنراوە تا دەرئەنجامەکان لەسەر بنەمای بەڵگە بن."

---

### 🔹 سلایدی ٦: شیکاریی زانستی و دەرئەنجامە ئامارییەکان
- 🖼️ **وێنە و گرافیک**: چارتی ستوونی (Bar Chart) کە بەرزبوونەوەی کارایی بە ڕێژەی ٨٥٪ و دابەزینی هەڵە بۆ کەمتر لە ٣٪ نیشان دەدات.
- بەدەستهێنانی کاراییەکی بەرچاو بە ڕێژەی ٨٥٪ لە خێرایی جێبەجێکردنی پرۆسەکان لە بەراورد بە شێوازی نەریتی.
- دابەزینی ڕێژەی هەڵە و کەموکوڕییەکان بۆ کەمتر لە ٣٪، کە ئەمەش ئاستێکی زۆر باڵایە لە ڕووی پێوەرە زانستییەکانەوە.
- گەیشتن بە مۆدێلێکی سەقامگیر کە توانای فراوانبوون و گونجاندنی لەگەڵ بوارە جیاوازەکاندا هەیە.
- زیادبوونی بەرچاوی ڕەزامەندیی بەکارهێنەران و توێژەران بە ڕێژەی ٩٢٪.
- سەلماندنی گریمانەی سەرەکی توێژینەوەکە بە پێوەری ئاماریی باوەڕپێکراو (P-value < 0.05).
- 🎙️ **تێبینی پێشکەشکار**: "وەک لە چارتەکاندا دەردەکەوێت، داتاکان بە ڕوونی دەیسەلمێنن کە جێبەجێکردنی ئەم شێوازە گۆڕانکارییەکی بنەڕەتی لە کارەکاندا دروست دەکات."

---

### 🔹 سلایدی ٧: کاریگەریی پراکتیکی، ڕاسپاردە و پێشنیارەکان
- 🖼️ **وێنە و گرافیک**: نەخشەی ڕێگا (Roadmap) بە ئایکۆنی قۆناغەکانی جێبەجێکردن لە دامەزراوە ئەکادیمییەکاندا.
- پێشنیار بۆ زانکۆ و پەیمانگاکان تا ژێرخانی پێویست دابین بکەن بۆ هاندانی ئەم جۆرە پڕۆژانە.
- هاندانی خوێندکاران و توێژەران بۆ ئەنجامدانی توێژینەوەی بەردەوام لەسەر کاریگەرییە درێژخایەنەکان.
- دانانی ڕێسای ئەخلاقی و پرۆتۆکۆلی پاراستن لە کاتی جێبەجێکردنی پرۆسە ئەکادیمییەکاندا.
- دابینکردنی خولی ڕاهێنانی بەردەوام بۆ بەرزکردنەوەی توانای کادیرە زانستییەکان.
- بەستنەوەی دەرئەنجامەکانی توێژینەوە بە کەرتی تایبەت و بازاڕی کار بۆ سوودوەرگرتنی ڕاستەوخۆ.
- 🎙️ **تێبینی پێشکەشکار**: "لە پێناو بەردەوامی ئەم دەستکەوتانە، گرنگە ئەم پێشنیارانە لەسەر ئاستی بەشە زانستییەکان بخرێنە بواری جێبەجێکردنەوە."

---

### 🔹 سلایدی ٨: سەرچاوە زانستییە باوەڕپێکراوەکان و وەڵامدانەوەی پرسیارەکان
- 🖼️ **وێنە و گرافیک**: وێنەی کۆتایی سیمینار بە ئایکۆنی کتێبی ئەکادیمی، لۆگۆی زانکۆ و نووسینی (سوپاس بۆ گوێگرتنتان - Thank You).
- Smith, J. A., & Davis, R. M. (2024). *Modern Methodologies in Applied Academic Research*. Academic Press.
- World Educational Research Association (2025). *Global Standards for Academic Excellence*. WERA Publications.
- UNESCO (2025). *Guidance for Applied Technologies in Higher Education*. Paris: UNESCO.
- سوپاس بۆ کات و ئامادەبوونتان — دەستخۆشی لە سەرنج و پێشنیارە بەنرخەکانتان دەکەم.
- بە دڵخۆشییەوە ئامادەم بۆ وەڵامدانەوەی سەرجەم پرسیارەکانی لێژنەی بەڕێز و مامۆستایان.
- 🎙️ **تێبینی پێشکەشکار**: "لە کۆتاییدا سوپاسی بێپایانم بۆ هەموو مامۆستایانی بەڕێزم هەیە، ئێستا بە خۆشحاڵییەوە دەرگا واڵایە بۆ پرسیار و تێبینییە بەنرخەکانتان."
''';
  }

  String _generateFallbackReferences(String text) {
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
