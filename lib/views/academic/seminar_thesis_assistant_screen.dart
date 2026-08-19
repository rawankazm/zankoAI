import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/docx_generator_service.dart';
import '../../services/pptx_generator_service.dart';
import '../../services/report_pdf_generator_service.dart';
import '../../theme.dart';
import '../payment/vip_upgrade_sheet.dart';

enum _AssistantTab { topicGenerator, pptOutline, academicReport, references }

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

enum ReportWritingStyle {
  academicComprehensive, // پەڕەگرافی ئەکادیمیی درێژ و تێروتەسەل بەبێ خاڵبەندی
  balancedStandard,       // تێکەڵاو (پەڕەگرافی زانستی + خاڵە گرنگەکان)
  bulletStructured,       // پوخت و خاڵبەندیی ڕێکخراو
}

enum ReportLengthLevel {
  words4000, // ئێجگار درێژ و زۆرترین وردەکاری (٤٠٠٠+ وشە - زۆرترین لاپەڕە)
  words3000, // زۆر درێژ و تێروتەسەل (٣٠٠٠+ وشە - زانکۆیی باڵا)
  words2000, // فراوان و دەوڵەمەند (٢٠٠٠+ وشە)
  standard,  // مامناوەند و پوخت (١٠٠٠+ وشە)
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
  ReportWritingStyle _selectedReportStyle = ReportWritingStyle.academicComprehensive;
  ReportLengthLevel _selectedReportLength = ReportLengthLevel.words4000;

  // Controllers
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _refController = TextEditingController();

  // Report Controllers
  final TextEditingController _reportTitleController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _supervisorNameController = TextEditingController();
  final TextEditingController _universityController = TextEditingController(text: 'زانکۆی سەڵاحەدین - هەولێر');
  final TextEditingController _reportDeptController = TextEditingController(text: 'کۆلێژی زانست - بەشی تەکنەلۆجیای زانیاری');
  final TextEditingController _academicYearController = TextEditingController(text: '2025 - 2026');

  // University Logo Bytes
  Uint8List? _universityLogoBytes;
  String? _universityLogoName;

  bool _isLoading = false;
  bool _isExportingPptx = false;
  bool _isExportingDocx = false;
  bool _isExportingPdf = false;

  String? _generatedResult;
  List<SeminarTopicProposal> _suggestedTopics = [];
  List<SlideModel> _parsedSlides = [];
  int _selectedSlideIndex = 0;

  // 12-Page Report State
  AcademicReportModel? _parsedReport;
  int _selectedReportPageIndex = 0;

  @override
  void dispose() {
    _departmentController.dispose();
    _topicController.dispose();
    _refController.dispose();
    _reportTitleController.dispose();
    _studentNameController.dispose();
    _supervisorNameController.dispose();
    _universityController.dispose();
    _reportDeptController.dispose();
    _academicYearController.dispose();
    super.dispose();
  }

  /// Returns Calibri for Kurdish/Arabic and Times New Roman for English
  String? get _currentFontFamily =>
      _selectedLanguage == SeminarLanguage.english ? 'Times New Roman' : 'Calibri';

  // ─── University Logo Picker ────────────────────────────────────────────────
  Future<void> _pickUniversityLogo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _universityLogoBytes = bytes;
          _universityLogoName = picked.name;
        });
        _showSnackBar(_selectedLanguage == SeminarLanguage.english
            ? '✅ University logo loaded successfully'
            : '✅ لۆگۆی زانکۆ بە سەرکەوتوویی دیاریکرا');
      }
    } catch (e) {
      _showSnackBar('⚠️ Error picking logo: $e');
    }
  }

  void _removeUniversityLogo() {
    setState(() {
      _universityLogoBytes = null;
      _universityLogoName = null;
    });
  }

  // ─── Step 1: Suggest Topics ────────────────────────────────────────────────
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
      _parsedReport = null;
    });

    final langInstruction = _selectedLanguage == SeminarLanguage.english
        ? 'CRITICAL: Write all topic titles, summaries, and research questions 100% strictly in English.'
        : (_selectedLanguage == SeminarLanguage.arabic
            ? 'مهم جداً: اكتب جميع العناوين والمحاور والملخصات والأسئلة البحثية بنسبة ١٠٠٪ باللغة العربية الفصحى الأكاديمية الرصينة.'
            : 'زۆر گرنگە: هەموو ناونیشان، کورتە، و پرسیارە زانستییەکان ١٠٠٪ بە زمانی کوردی سۆرانی پاراو و ئەکادیمی بنووسە.');

    final randomSeed = DateTime.now().millisecondsSinceEpoch % 10000;
    final prompt = '''
You are a senior university professor, academic research director, and thesis committee chair.
Suggest 6 to 8 highly creative, diverse, innovative, and attractive research report / seminar topic proposals strictly within the academic field/department: "$dept".
$langInstruction

CRITICAL MANDATE FOR VARIETY & FRESHNESS (Seed: $randomSeed):
- Provide diverse, distinct angles (e.g. Theoretical Foundations, Cutting-edge Applied Innovations, Emerging 2025/2026 Breakthroughs, Practical Case Studies, Policy & Ethical Dimensions, and System Optimization).
- DO NOT provide generic, repetitive, or cliché topics. Make every single topic compelling, academic, and specific to "$dept".

Format each topic strictly as:
### 📌 Topic [Number]: [Specific Professional Topic Title]
- **Secondary**: [English Title if main is Kurdish/Arabic, or subtitle]
- **💡 Summary & Significance**: [Clear, comprehensive summary explaining the scientific value, real-world relevance, and depth of this topic]
- **❓ Research Question**: [The core scientific or practical question investigated by this topic]
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
          titleEnglish: titleSecondary.isNotEmpty ? titleSecondary : 'Academic Presentation & Report',
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

  // ─── Step 2: Generate 8 Slides Presentation ────────────────────────────────
  Future<void> _generateFullSeminar(String topicTitle) async {
    final canProceed = await _checkVipLimit();
    if (!canProceed || !mounted) return;

    setState(() {
      _currentTab = _AssistantTab.pptOutline;
      _topicController.text = topicTitle;
      _isLoading = true;
      _generatedResult = null;
      _parsedSlides = [];
      _parsedReport = null;
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

CRITICAL REQUIREMENTS:
1. The presentation MUST contain exactly 8 Slides.
2. The content must be strictly about "$topicTitle" with real in-depth academic facts, data metrics, and analysis.
3. Mix conceptual narrative statements, highlight statistics/percentages, process flow steps, and analytical takeaways (4-5 points per slide).
4. For each slide, include 🖼️ **Visual/Diagram Suggestion**.
5. For each slide, write the full **🎙️ Speaker Speech Script**.

SLIDE STRUCTURE:
- Slide 1: Main Title, Scope & Presenter Card
- Slide 2: Background Context & Technology Evolution
- Slide 3: Core Problem Statement & Limitations
- Slide 4: Strategic Research Objectives & Benefits
- Slide 5: Methodology, System Architecture & Analytical Framework
- Slide 6: Key Findings, Statistical Data & Comparative Results
- Slide 7: Practical Impact, Real-world Implementation & Roadmap
- Slide 8: Academic Citations (APA 7th Standard), Conclusion & Q&A
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

  // ─── Step 3: Generate 12-Page Academic Report ──────────────────────────────
  Future<void> _generate12PageReport(String reportTitle) async {
    final canProceed = await _checkVipLimit();
    if (!canProceed || !mounted) return;

    if (reportTitle.isEmpty) {
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? 'Please enter the report title'
          : 'تکایە ناونیشانی سەرەکی ڕاپۆرت بنووسە');
      return;
    }

    setState(() {
      _currentTab = _AssistantTab.academicReport;
      _reportTitleController.text = reportTitle;
      _isLoading = true;
      _generatedResult = null;
      _parsedReport = null;
      _parsedSlides = [];
      _selectedReportPageIndex = 0;
    });

    final langPrompt = _selectedLanguage == SeminarLanguage.english
        ? 'CRITICAL MANDATE: Write all 10 numbered sections, Table of Contents, and 6 references 100% strictly in English.'
        : (_selectedLanguage == SeminarLanguage.arabic
            ? 'مهم جداً: اكتب كامل المحاور العشرة المرقمة وفهرس المحتويات والمراجع الستة بنسبة ١٠٠٪ باللغة العربية الفصحى الأكاديمية الرصينة الخالية تماماً من الأخطاء النحوية والإملائية.'
            : 'زۆر گرنگە: هەموو ١٠ تەوەرە سەرەکییەکان، پێڕستی ناوەڕۆک و ٦ سەرچاوە زانستییەکان بە زمانی کوردیی سۆرانیی ئەکادیمیی پاراو و بە ڕێنووسێکی یەکگرتووی بێ خەوش و بێ هەڵەی ڕێزمانی بنووسە. پیتەکانی (ڕ، ڵ، ۆ، ێ، ە) بە دروستی بنووسە و ڕستەکان بە شێوازی دەوڵەمەندی زانستی دابڕێژە.');

    String stylePrompt = '';
    switch (_selectedReportStyle) {
      case ReportWritingStyle.academicComprehensive:
        stylePrompt = '''
CRITICAL STYLE & FORMATTING MANDATE (DEEP ACADEMIC PROSE):
- Write in continuous, highly detailed, scholarly academic paragraphs.
- DO NOT use short bullet points or brief summaries. Use rich, extensive academic prose (3-4 detailed paragraphs per section, at least 300-450 words for each section, reaching 2000+ total words).
- Elaborate deeply on the scientific theories, underlying molecular/computational/biochemical mechanisms, empirical findings, and rigorous academic analyses.
''';
        break;
      case ReportWritingStyle.balancedStandard:
        stylePrompt = '''
CRITICAL STYLE & FORMATTING MANDATE (BALANCED NARRATIVE & HIGHLIGHTS):
- For each section, write 2-3 rich, extensive academic paragraphs providing in-depth theoretical and empirical explanations.
- Follow the paragraphs with 3-4 structured, highly detailed analytical bullet points explaining key components or mechanisms.
''';
        break;
      case ReportWritingStyle.bulletStructured:
        stylePrompt = '''
CRITICAL STYLE & FORMATTING MANDATE (STRUCTURED BULLET POINTS):
- For each section, write a clear, rich introductory paragraph followed by comprehensive, detailed, well-explained analytical points.
''';
        break;
    }

    String depthPrompt = '';
    switch (_selectedReportLength) {
      case ReportLengthLevel.words4000:
        depthPrompt = '''
CRITICAL LENGTH MANDATE: EXPAND ALL 10 SECTIONS TO ULTRA-DETAILED MAXIMUM ACADEMIC LENGTH (4000+ TOTAL WORDS).
- Each section MUST contain at least 400-500 words across 4-6 rich, dense scholarly paragraphs.
- Provide comprehensive historical context, in-depth theoretical foundations, granular chemical/computational/biochemical/mathematical mechanisms, real-world case studies, empirical benchmarks, and exhaustive analytical discussions.
''';
        break;
      case ReportLengthLevel.words3000:
        depthPrompt = '''
CRITICAL LENGTH MANDATE: EXPAND ALL 10 SECTIONS TO SUPER LONG IN-DEPTH ACADEMIC LENGTH (3000+ TOTAL WORDS).
- Each section MUST contain at least 300-400 words across 3-5 rich, scholarly paragraphs.
- Elaborate deeply on literature background, practical applications, sub-system integrations, comparative paradigms, and thorough academic conclusions.
''';
        break;
      case ReportLengthLevel.words2000:
        depthPrompt = '''
CRITICAL LENGTH MANDATE: EXPAND ALL 10 SECTIONS TO COMPREHENSIVE ACADEMIC DEPTH (2000+ TOTAL WORDS).
- Each section MUST contain at least 200-250 words across 3-4 detailed academic paragraphs.
''';
        break;
      case ReportLengthLevel.standard:
        depthPrompt = 'Provide standard university-grade academic coverage for each of the 10 sections (1000-1500 total words).';
        break;
    }

    final formalToneMandate = '''
STRICT ACADEMIC REGISTER & UNIVERSITY-GRADE FORMALITY MANDATE (100% STRICTLY ENFORCED):
- Write at the highest level of scholarly academic rigor, equivalent to an article published in a world-class academic journal (e.g. Nature, Lancet, IEEE Transactions, Oxford Academic Press) or a prestigious university textbook.
- Tone: Formal, authoritative, objective, precise, scholarly, and analytically exhaustive.
- Strictly forbidden: Colloquialisms, casual remarks, simplified informal speech, slang, conversational greetings, placeholders, or superficial summaries.
- Vocabulary & Phrasing:
  * For Kurdish (سۆرانی): Use high-level academic and scholarly terminology. Employ formal scholarly syntactic connectors such as «لە ڕوانگەی لێکۆڵینەوە و توێژینەوە زانستییە هاوچەرخەکاندا...»، «شیکارییە ئەزموونی و تیۆرییەکان ئەوە دووپات دەکەنەوە کە...»، «بەپێی بنەما سەرەکی و چەسپاوەکانی...»، «ئەم پرۆسەیە لە ڕێگەی هاوسەنگییەکی دەقیقی زانستی و فیزیۆلۆجییەوە بەڕێوە دەچێت...»، «لە ڕەهەندە پراکتیکی و تیۆرییەکاندا بایەخێکی یەکلاکەرەوە دەدرێت بە...». Ensure perfect grammatical structure and unified Kurdish typography (ڕ, ڵ, ۆ, ێ, ە).
  * For Arabic: Use formal academic Arabic (الفصحى الأكاديمية الرصينة), incorporating advanced terminology, rigorous analytical phraseology («استناداً إلى الأبحاث والدراسات المرجعية المعاصرة»، «تُظهر التحليلات الفسيولوجية والتجريبية الدقيقة أن»، «في ضوء النماذج الهيكلية والقوانين العلمية الحاكمة»).
  * For English: Use peer-reviewed academic prose («Empirical evidence and systematic academic inquiries substantiate that...», «From an epistemological and mechanistic perspective...», «The underlying architectural framework operates under stringent homeostatic parameters...»).
- References: Must be formatted in standard APA 7th Edition or IEEE format including credible authors/institutions, publication year, comprehensive publication title, journal/publisher, and DOI/URL.
''';

    final prompt = '''
You are a distinguished university professor, research scientist, and academic author.
Write a comprehensive, publication-grade, exceptionally thorough 8-page academic research report specifically and exclusively about the topic: "$reportTitle".
$langPrompt

$formalToneMandate

$stylePrompt

$depthPrompt

CRITICAL REPORT STRUCTURE & DOMAIN-SPECIFIC SPECIFICATION:
You MUST structure the report into exactly 10 comprehensive, logically progressive academic sections strictly customized to "$reportTitle":

### Table of Contents
1. [Section 1 Title - Introduction & Scientific Scope of $reportTitle / پێشەکی و چوارچێوەی زانستی]
2. [Section 2 Title - Foundational Theories, Concepts & Background of $reportTitle / بنەما تیۆرییەکان و مێژووی پەرەسەندن]
3. [Section 3 Title - Core Architecture, Key Components & Structures of $reportTitle / پێکهاتە بنەڕەتییەکان و تەلارسازی]
4. [Section 4 Title - Operational Mechanisms, Methodologies & Workflows of $reportTitle / میکانیزمی کارکردن و میتۆدۆلۆجیا]
5. [Section 5 Title - In-Depth Scientific Analysis & Functional Dynamics of $reportTitle / شیکاریی زانستیی قووڵ و فەرمانە سەرەکییەکان]
6. [Section 6 Title - Practical Implementations, Contemporary Innovations & Case Studies / جێبەجێکردنی پراکتیکی و بەکارهێنانە هاوچەرخەکان]
7. [Section 7 Title - Comparative Matrix, Performance Metrics & System Integration / بەراوردکاری و پێوەرەکانی کارایی]
8. [Section 8 Title - Challenges, Technical/Ethical Limitations & Risk Management / ئاستەنگە سەرەکییەکان و ڕەهەندە ئەخلاقییەکان]
9. [Section 9 Title - Future Horizons, Emerging Trends & Next-Generation Paradigms / ئاسۆی داهاتوو و گۆڕانکارییە پێشکەوتووەکان]
10. [Section 10 Title - Academic Findings, Strategic Recommendations & Comprehensive Conclusion / دەرئەنجامە زانستییەکان و پێشنیارەکان]

### 1. [Section 1 Title]
[Write extensive academic text introducing $reportTitle, defining core terminologies, historical background, and fundamental academic and industrial relevance across multiple rich paragraphs...]

### 2. [Section 2 Title]
[Write extensive academic text detailing the underlying scientific/theoretical framework, foundational models, and scholarly literature governing $reportTitle across multiple rich paragraphs...]

### 3. [Section 3 Title]
[Detailed academic content breaking down the primary structural components, essential modules, and underlying architectural layers of $reportTitle across multiple rich paragraphs...]

### 4. [Section 4 Title]
[Detailed academic content analyzing the operational workflows, experimental/computational methodologies, and process flows of $reportTitle across multiple rich paragraphs...]

### 5. [Section 5 Title]
[Detailed academic content providing in-depth analysis, scientific mechanisms, data processing, and catalytic/functional dynamics of $reportTitle across multiple rich paragraphs...]

### 6. [Section 6 Title]
[Detailed academic content evaluating real-world implementations, clinical/industrial/technological applications, and modern innovations related to $reportTitle across multiple rich paragraphs...]

### 7. [Section 7 Title]
[Detailed academic content presenting rigorous comparative evaluations, benchmarks, efficiency metrics, and integration with adjacent systems across multiple rich paragraphs...]

### 8. [Section 8 Title]
[Detailed academic content examining prevalent vulnerabilities, logistical/theoretical challenges, ethical and security considerations, and mitigation strategies across multiple rich paragraphs...]

### 9. [Section 9 Title]
[Detailed academic content exploring emerging breakthroughs, transformative innovations, and next-generation research horizons in $reportTitle across multiple rich paragraphs...]

### 10. [Section 10 Title]
[Detailed academic content synthesizing key findings, critical research implications, strategic recommendations for universities and practitioners, and a powerful final conclusion across multiple rich paragraphs...]

### References
1. [Author/Organization (2024). Full Title. Academic Journal/Publisher. DOI/URL]
2. [Author/Organization (2025). Full Title. Academic Journal/Publisher. DOI/URL]
3. [Author/Organization (2023). Full Title. Academic Journal/Publisher. DOI/URL]
4. [Author/Organization (2024). Full Title. Academic Journal/Publisher. DOI/URL]
5. [Author/Organization (2025). Full Title. Academic Journal/Publisher. DOI/URL]
6. [Author/Organization (2024). Full Title. Academic Journal/Publisher. DOI/URL]
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

      final content = !isInvalid ? response : _generateFallback12PageReportText(reportTitle);
      _processReportResponse(content, reportTitle);
    } catch (e) {
      final fallback = _generateFallback12PageReportText(reportTitle);
      _processReportResponse(fallback, reportTitle);
    }
  }

  void _processReportResponse(String rawText, String title) {
    final report = DocxGeneratorService.parseReportFromText(
      rawText: rawText,
      title: title,
      studentName: _studentNameController.text.trim(),
      supervisorName: _supervisorNameController.text.trim(),
      universityName: _universityController.text.trim(),
      departmentName: _reportDeptController.text.trim(),
      academicYear: _academicYearController.text.trim(),
      logoBytes: _universityLogoBytes,
      languageCode: _selectedLanguage.code,
    );

    setState(() {
      _generatedResult = rawText;
      _parsedReport = report;
      _selectedReportPageIndex = 0;
      _isLoading = false;
    });
  }

  // ─── VIP Export Limit Check ───────────────────────────────────────────────
  Future<bool> _checkVipExportLimit(String fileType) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isVip = authService.currentUser?.isVip ?? false;
    if (isVip) return true;

    final prefs = await SharedPreferences.getInstance();
    final exportCount = prefs.getInt('academic_export_count') ?? 0;

    if (exportCount >= 1) {
      if (!mounted) return false;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('👑', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text(
                'داگرتنی بێسنووری فایلی ئەکادیمی',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'بەکارهێنەرانی ئاسایی تەنها دەتوانن ١ فایلی $fileType بەخۆڕایی دابگرن.\nلە مەکتەبەکان بۆ هەر فایلێک ١٥,٠٠٠+ د.ع وەردەگرن، بەڵام لە Zanko AI بە تەنها ٥,٠٠٠ د.ع مانگێک هەموو سێمینار و ڕاپۆرتەکانت بە فایلی وۆرد و پاوەرپۆینت دابگرە!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Text('💡', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'داگرتنی ڕاستەوخۆ بە فۆرماتی Word و PowerPoint ئامادەکراو بۆ پێشکەشکردن!',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB8860B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('دواتر', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const VipUpgradeSheet(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB8860B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('بەرزکردنەوە بۆ VIP 👑', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      return false;
    }

    await prefs.setInt('academic_export_count', exportCount + 1);
    return true;
  }

  // ─── Export Word (.docx) ───────────────────────────────────────────────────
  Future<void> _exportDocx() async {
    if (_parsedReport == null) {
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? 'Please generate the report first'
          : 'تکایە سەرەتا ڕاپۆرتەکە دروست بکە');
      return;
    }

    final allowed = await _checkVipExportLimit('Word (.docx)');
    if (!allowed || !mounted) return;

    setState(() => _isExportingDocx = true);
    try {
      await DocxGeneratorService.exportAndShareDocx(_parsedReport!);
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? '✅ Word (.docx) document created successfully'
          : '✅ فایلی وۆرد (.docx) بە سەرکەوتوویی دروستکرا');
    } catch (e) {
      _showSnackBar('⚠️ Error creating Word file: $e');
    } finally {
      if (mounted) setState(() => _isExportingDocx = false);
    }
  }

  // ─── Export PDF (.pdf) ─────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    if (_parsedReport == null) {
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? 'Please generate the report first'
          : 'تکایە سەرەتا ڕاپۆرتەکە دروست بکە');
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      await ReportPdfGeneratorService.exportAndSharePdf(_parsedReport!);
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? '✅ PDF (.pdf) document created successfully'
          : '✅ فایلی PDF (.pdf) بە سەرکەوتوویی دروستکرا');
    } catch (e) {
      _showSnackBar('⚠️ Error creating PDF file: $e');
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  // ─── Export PPTX (.pptx) ───────────────────────────────────────────────────
  Future<void> _exportPptx() async {
    if (_generatedResult == null || _generatedResult!.isEmpty) {
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? 'Please generate the seminar with AI first'
          : 'تکایە سەرەتا سیمینارەکە بە AI دروست بکە');
      return;
    }

    final allowed = await _checkVipExportLimit('PowerPoint (.pptx)');
    if (!allowed || !mounted) return;

    setState(() => _isExportingPptx = true);

    try {
      String title = _topicController.text.trim().isNotEmpty
          ? _topicController.text.trim()
          : (_departmentController.text.trim().isNotEmpty
              ? '${_departmentController.text.trim()} Presentation'
              : 'Seminar Presentation');

      await PptxGeneratorService.exportAndSharePptx(
        rawContent: _generatedResult!,
        title: title,
        languageCode: _selectedLanguage.code,
      );

      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? '✅ PowerPoint (.pptx) file created successfully'
          : '✅ فایلی PowerPoint (.pptx) بە سەرکەوتوویی دروستکرا');
    } catch (e) {
      _showSnackBar('⚠️ Error creating PPT file: $e');
    } finally {
      if (mounted) setState(() => _isExportingPptx = false);
    }
  }

  // ─── Step 4: Citations Formatter ───────────────────────────────────────────
  Future<void> _formatReferences() async {
    final refText = _refController.text.trim();
    if (refText.isEmpty) {
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? 'Please enter the reference text or URL'
          : 'تکایە سەرچاوە زانستییەکان بنووسە');
      return;
    }

    final canProceed = await _checkVipLimit();
    if (!canProceed || !mounted) return;

    setState(() {
      _isLoading = true;
      _generatedResult = null;
      _parsedSlides = [];
      _parsedReport = null;
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
          ? '✅ Text copied to clipboard'
          : '✅ دەقەکە کۆپی کرا');
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
            'بەکارهێنەرانی ئاسایی تەنها دەتوانن ٢ سیمینار یان ڕاپۆرت بە AI دروست بکەن.\nبۆ دروستکردنی بێسنوور هەژمارەکەت بەرز بکەرەوە بۆ VIP 👑',
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
              Icon(CupertinoIcons.sparkles, color: ZankoColors.accent, size: 22),
              const SizedBox(width: 8),
              Text(
                _selectedLanguage == SeminarLanguage.english
                    ? 'Academic Seminar & 12-Page Report'
                    : (_selectedLanguage == SeminarLanguage.arabic
                        ? 'السيمينار والتقرير الأكاديمي (١٢ صفحة)'
                        : 'سیمینار و ڕاپۆرتی ئەکادیمی (١٢ پەڕە)'),
                style: TextStyle(fontFamily: _currentFontFamily, fontSize: 15, fontWeight: FontWeight.bold),
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
              // ── Header 4 Tabs ───────────────────────────────────────────
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
                      _selectedLanguage == SeminarLanguage.english ? '💡 1. Topics' : '💡 ١. بابەت',
                      isDark,
                    ),
                    _buildTabBtn(
                      _AssistantTab.pptOutline,
                      _selectedLanguage == SeminarLanguage.english ? '📊 2. PPTX' : '📊 ٢. سیمینار',
                      isDark,
                    ),
                    _buildTabBtn(
                      _AssistantTab.academicReport,
                      _selectedLanguage == SeminarLanguage.english ? '📑 3. Report' : '📑 ٣. ڕاپۆرت',
                      isDark,
                    ),
                    _buildTabBtn(
                      _AssistantTab.references,
                      _selectedLanguage == SeminarLanguage.english ? '📚 4. Citations' : '📚 ٤. سەرچاوە',
                      isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Language Selector Bar ────────────────────────────────────
              _buildLanguageSelector(isDark),

              const SizedBox(height: 14),

              if (!(Provider.of<AuthService>(context, listen: false).currentUser?.isVip ?? false)) ...[
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const VipUpgradeSheet(),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1500), Color(0xFF2C2000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.45)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('👑', style: TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'داگرتنی بێسنووری Word و PowerPoint (VIP)',
                                style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'بە ٥,٠٠٠ د.ع هەموو سێمینار و ڕاپۆرتەکانت لەبری مەکتەبە لێرە دابگرە!',
                                style: TextStyle(color: Colors.white70, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'VIP ⚡',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2C2000)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Tab 1: Topic Generator Form ──────────────────────────────
              if (_currentTab == _AssistantTab.topicGenerator) ...[
                _buildTopicSearchCard(isDark),
              ] else if (_currentTab == _AssistantTab.pptOutline) ...[
                _buildDirectSeminarCard(isDark),
              ] else if (_currentTab == _AssistantTab.academicReport) ...[
                _buildAcademicReportCard(isDark),
              ] else ...[
                _buildReferencesCard(isDark),
              ],

              const SizedBox(height: 24),

              // ── Output: Topic Proposals List ────────────────────────────
              if (_currentTab == _AssistantTab.topicGenerator && _suggestedTopics.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(CupertinoIcons.square_grid_2x2_fill, color: ZankoColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _selectedLanguage == SeminarLanguage.english
                          ? 'Suggested Topics (Select one to create):'
                          : 'بابەتە پێشنیارکراوەکان (یەکێکیان هەڵبژێرە):',
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

              // ── Output: 12-Page Report Live Viewer & Exporter ───────────
              if (_currentTab == _AssistantTab.academicReport && _parsedReport != null) ...[
                _buildReportViewerCard(isDark),
                const SizedBox(height: 24),
              ],

              // ── Output: 8 Slides Viewer & PPTX Exporter ──────────────────
              if (_currentTab == _AssistantTab.pptOutline && _parsedSlides.isNotEmpty) ...[
                _buildSlidesViewerCard(isDark),
                const SizedBox(height: 24),
              ] else if (_generatedResult != null && _suggestedTopics.isEmpty && _parsedReport == null && _parsedSlides.isEmpty) ...[
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
          Icon(CupertinoIcons.globe, color: ZankoColors.accent, size: 18),
          const SizedBox(width: 6),
          Text(
            _selectedLanguage == SeminarLanguage.english ? 'Language:' : 'زمانی داڕشتن:',
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : ZankoColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: SeminarLanguage.values.map((lang) {
                  final isSel = _selectedLanguage == lang;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedLanguage = lang),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(left: 4, right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSel ? ZankoColors.accent : (isDark ? Colors.white10 : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(lang.flag, style: const TextStyle(fontSize: 11)),
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
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Topic Generator Card ────────────────────────────────────────────
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
                child: Icon(CupertinoIcons.lightbulb_fill, color: ZankoColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                _selectedLanguage == SeminarLanguage.english
                    ? 'Step 1: Seminar / Report Field'
                    : 'هەنگاوی یەکەم: بەش یان بواری ئەکادیمی',
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
              prefixIcon: Icon(CupertinoIcons.building_2_fill, color: ZankoColors.accent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLanguage == SeminarLanguage.english
                ? '💡 Proposes 5 distinct topics so you can choose one to generate an 8-slide presentation or 12-page research report.'
                : '💡 ٥ بابەتی تایبەتمەند بە بەشەکەت پێ پێشنیار دەکات تا یەکێکیان هەڵبژێریت بۆ سیمیناری ٨ سلاید یان ڕاپۆرتی ١٢ پەڕەیی.',
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
                    : (_selectedLanguage == SeminarLanguage.english ? 'Suggest Academic Topics 💡' : 'پێشنیارکردنی بابەتەکان 💡'),
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

  // ── Tab 2: PPTX Seminar Card ───────────────────────────────────────────────
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
                ? '✨ Creates full 8 slides with rich paragraphs, metrics, Google/Web images & speaker notes.'
                : '✨ بە شێوازی Canva و PPTX لە ٨ سلایدی هەمەجۆر (شیکاری، ئامار، دەق، وێنە و وتار) دروست دەبێت.',
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

  // ── Tab 3: 12-Page Academic Report Card ────────────────────────────────────
  Widget _buildAcademicReportCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.35), width: 1.5),
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
                  color: const Color(0xFFF97316).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFFF97316), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLanguage == SeminarLanguage.english
                          ? '12-Page Academic Report Generator'
                          : 'دروستکەری ڕاپۆرتی زانستیی ١٢ پەڕەیی',
                      style: TextStyle(fontFamily: _currentFontFamily, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _selectedLanguage == SeminarLanguage.english
                          ? 'Word (.docx) & PDF (.pdf) with Cover, TOC & Citations'
                          : 'بە فایلی Word و PDF لەگەڵ بەرگی فەرمی و ٥ سەرچاوە',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // 1. Report Title Input
          Text(
            _selectedLanguage == SeminarLanguage.english ? 'Report Title:' : 'ناونیشانی سەرەکی ڕاپۆرت:',
            style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reportTitleController,
            style: TextStyle(fontFamily: _currentFontFamily),
            decoration: InputDecoration(
              hintText: _selectedLanguage == SeminarLanguage.english
                  ? 'e.g. The Impact of AI on Higher Education Learning'
                  : 'ناونیشانی ڕاپۆرتەکە بنووسە...',
              hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 13),
              prefixIcon: const Icon(CupertinoIcons.doc_fill, color: Color(0xFFF97316)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Student(s) Name (Single or Multiple Group Members) & Supervisor Name
          Text(
            _selectedLanguage == SeminarLanguage.english
                ? 'Student Name(s) / Research Team:'
                : (_selectedLanguage == SeminarLanguage.arabic
                    ? 'أسماء الطلاب / فريق العمل (يمكنك كتابة عدة أسماء):'
                    : 'ناوی قوتابی یان گرووپ (دەتوانیت ناوی چەند قوتابییەک بنووسیت):'),
            style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _studentNameController,
            minLines: 1,
            maxLines: 3,
            style: TextStyle(fontFamily: _currentFontFamily),
            decoration: InputDecoration(
              hintText: _selectedLanguage == SeminarLanguage.english
                  ? 'e.g. John Doe, Sarah Smith (or write names on new lines)...'
                  : (_selectedLanguage == SeminarLanguage.arabic
                      ? 'مثال: أحمد علي، سارة محمد (أو كتابة كل اسم في سطر)...'
                      : 'بۆ نموونە: ئاراس علی، سارا محمد (یان هەر ناوێک لە دێڕێکدا بنووسە)...'),
              hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
              prefixIcon: const Icon(CupertinoIcons.person_2_fill, color: Color(0xFFF97316), size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            _selectedLanguage == SeminarLanguage.english
                ? 'Academic Supervisor / Instructor:'
                : (_selectedLanguage == SeminarLanguage.arabic
                    ? 'الأستاذ المشرف على البحث:'
                    : 'ناوی مامۆستای سەرپەرشتیاری ڕاپۆرت:'),
            style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _supervisorNameController,
            style: TextStyle(fontFamily: _currentFontFamily),
            decoration: InputDecoration(
              hintText: _selectedLanguage == SeminarLanguage.english
                  ? 'e.g. Dr. Alan Smith, Asst. Prof. Robert...'
                  : (_selectedLanguage == SeminarLanguage.arabic
                      ? 'مثال: د. أحمد خالد / أ.م.د. علي حسين...'
                      : 'بۆ نموونە: پ.ی.د. ئاراس علی / د. نەبەز عومەر...'),
              hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
              prefixIcon: const Icon(CupertinoIcons.person_badge_plus_fill, color: Color(0xFFF97316), size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),
          const SizedBox(height: 14),

          // 3. University & Department Inputs
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLanguage == SeminarLanguage.english ? 'University:' : 'ناوی زانکۆ:',
                      style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _universityController,
                      style: TextStyle(fontFamily: _currentFontFamily),
                      decoration: InputDecoration(
                        hintText: _selectedLanguage == SeminarLanguage.english ? 'e.g. Erbil Polytechnic University' : 'زانکۆی پۆلیتەکنیکی هەولێر...',
                        hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                        prefixIcon: const Icon(CupertinoIcons.building_2_fill, color: Color(0xFFF97316), size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLanguage == SeminarLanguage.english ? 'Department / College:' : 'کۆلێژ و بەشی زانستی:',
                      style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reportDeptController,
                      style: TextStyle(fontFamily: _currentFontFamily),
                      decoration: InputDecoration(
                        hintText: _selectedLanguage == SeminarLanguage.english ? 'e.g. Medical Laboratory Technology' : 'کۆلێژی تەکنیکی تەندروستی...',
                        hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                        prefixIcon: const Icon(CupertinoIcons.square_grid_2x2_fill, color: Color(0xFFF97316), size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. Academic Year & Stage Input
          Text(
            _selectedLanguage == SeminarLanguage.english ? 'Academic Year / Stage:' : 'ساڵی خوێندن و قۆناغ:',
            style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _academicYearController,
            style: TextStyle(fontFamily: _currentFontFamily),
            decoration: InputDecoration(
              hintText: _selectedLanguage == SeminarLanguage.english
                  ? 'e.g. 2024 - 2025  or  Stage : One'
                  : 'بۆ نموونە: 2024 - 2025 یان قۆناغی : یەکەم',
              hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
              prefixIcon: const Icon(CupertinoIcons.calendar, color: Color(0xFFF97316), size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Report Writing Style & Depth Selector (User Customization)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? ZankoColors.darkBackground : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.slider_horizontal_3, color: Color(0xFFF97316), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _selectedLanguage == SeminarLanguage.english ? 'Report Writing Style & Format:' : 'شێوازی داڕشتن و جۆری نووسینی ڕاپۆرت:',
                      style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Style Options
                _buildStyleOption(
                  title: _selectedLanguage == SeminarLanguage.english ? '📚 Academic Prose (Extensive Paragraphs)' : '📚 ئەکادیمی و تێروتەسەل (پەڕەگرافی درێژ)',
                  subtitle: _selectedLanguage == SeminarLanguage.english ? 'Rich scholarly paragraphs without short bullet lists' : 'پەڕەگرافی ئەکادیمیی زۆر درێژ بەبێ خاڵبەندی، بە شیکاریی قووڵ',
                  isSelected: _selectedReportStyle == ReportWritingStyle.academicComprehensive,
                  onTap: () => setState(() => _selectedReportStyle = ReportWritingStyle.academicComprehensive),
                ),
                const SizedBox(height: 8),
                _buildStyleOption(
                  title: _selectedLanguage == SeminarLanguage.english ? '⚖️ Balanced (Prose & Highlights)' : '⚖️ هاوسەنگ (پەڕەگراف + خاڵە گرنگەکان)',
                  subtitle: _selectedLanguage == SeminarLanguage.english ? 'Detailed academic paragraphs with structured analytical points' : 'پەڕەگرافی زانستی لەگەڵ خاڵبەندیی ورد',
                  isSelected: _selectedReportStyle == ReportWritingStyle.balancedStandard,
                  onTap: () => setState(() => _selectedReportStyle = ReportWritingStyle.balancedStandard),
                ),
                const SizedBox(height: 8),
                _buildStyleOption(
                  title: _selectedLanguage == SeminarLanguage.english ? '📑 Bullet Structured (Concise)' : '📑 پوخت و خاڵبەندی (خێرا و پوخت)',
                  subtitle: _selectedLanguage == SeminarLanguage.english ? 'Short paragraphs with comprehensive bullet lists' : 'پەڕەگرافی کورت لەگەڵ خاڵبەندیی ڕێکخراو',
                  isSelected: _selectedReportStyle == ReportWritingStyle.bulletStructured,
                  onTap: () => setState(() => _selectedReportStyle = ReportWritingStyle.bulletStructured),
                ),
                const SizedBox(height: 14),
                // Depth & Length Level
                Row(
                  children: [
                    const Icon(CupertinoIcons.text_quote, color: Color(0xFFF97316), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _selectedLanguage == SeminarLanguage.english ? 'Content Depth & Volume:' : 'ئاستی درێژی و قووڵیی بابەت:',
                      style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 1: 4000+ Words & 3000+ Words
                Row(
                  children: [
                    _buildLengthCard(
                      title: _selectedLanguage == SeminarLanguage.english ? '🔥 4000+ Words' : '🔥 ٤٠٠٠+ وشە',
                      subtitle: _selectedLanguage == SeminarLanguage.english ? 'Ultra-Detailed' : 'زۆرترین وردەکاری',
                      isSelected: _selectedReportLength == ReportLengthLevel.words4000,
                      onTap: () => setState(() => _selectedReportLength = ReportLengthLevel.words4000),
                    ),
                    const SizedBox(width: 8),
                    _buildLengthCard(
                      title: _selectedLanguage == SeminarLanguage.english ? '⭐ 3000+ Words' : '⭐ ٣٠٠٠+ وشە',
                      subtitle: _selectedLanguage == SeminarLanguage.english ? 'Super Long' : 'زۆر تێروتەسەل',
                      isSelected: _selectedReportLength == ReportLengthLevel.words3000,
                      onTap: () => setState(() => _selectedReportLength = ReportLengthLevel.words3000),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: 2000+ Words & 1000+ Standard
                Row(
                  children: [
                    _buildLengthCard(
                      title: _selectedLanguage == SeminarLanguage.english ? '🌟 2000+ Words' : '🌟 ٢٠٠٠+ وشە',
                      subtitle: _selectedLanguage == SeminarLanguage.english ? 'Deep Academic' : 'دەوڵەمەند و فراوان',
                      isSelected: _selectedReportLength == ReportLengthLevel.words2000,
                      onTap: () => setState(() => _selectedReportLength = ReportLengthLevel.words2000),
                    ),
                    const SizedBox(width: 8),
                    _buildLengthCard(
                      title: _selectedLanguage == SeminarLanguage.english ? '📖 1000+ Words' : '📖 ١٠٠٠+ وشە',
                      subtitle: _selectedLanguage == SeminarLanguage.english ? 'Standard' : 'مامناوەند و پوخت',
                      isSelected: _selectedReportLength == ReportLengthLevel.standard,
                      onTap: () => setState(() => _selectedReportLength = ReportLengthLevel.standard),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. University Logo Picker (Requirement 2)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? ZankoColors.darkBackground : const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                if (_universityLogoBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_universityLogoBytes!, width: 44, height: 44, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _universityLogoName ?? 'University Logo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _selectedLanguage == SeminarLanguage.english ? 'Logo will appear on Cover Page' : 'لۆگۆکە دەخرێتە سەر بەرگی فەرمی',
                          style: const TextStyle(fontSize: 11, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _removeUniversityLogo,
                    icon: const Icon(CupertinoIcons.trash_fill, color: Colors.red, size: 18),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: Color(0xFFF97316), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLanguage == SeminarLanguage.english ? 'University Logo (Optional):' : 'لۆگۆی فەرمی زانکۆ (داواکاری مەرجی ٢):',
                          style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _selectedLanguage == SeminarLanguage.english ? 'Tap to upload from device' : 'لێرە کلیک بکە بۆ دیاریکردنی لۆگۆ لە مۆبایل',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickUniversityLogo,
                    icon: const Icon(CupertinoIcons.cloud_upload_fill, size: 14),
                    label: Text(_selectedLanguage == SeminarLanguage.english ? 'Select' : 'دیاریکردن', style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      side: const BorderSide(color: Color(0xFFF97316)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Generate 12-Page Report Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      final title = _reportTitleController.text.trim();
                      _generate12PageReport(title);
                    },
              icon: _isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.doc_text_fill, color: Colors.white, size: 18),
              label: Text(
                _isLoading
                    ? (_selectedLanguage == SeminarLanguage.english ? 'Writing 12-Page Academic Report...' : 'دروستکردنی تەواوی ١٢ پەڕەی ڕاپۆرت...')
                    : (_selectedLanguage == SeminarLanguage.english ? 'Generate Complete 12-Page Report 📑' : 'دروستکردنی تەواوی ڕاپۆرتی ١٢ پەڕەیی 📑'),
                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316), // Academic Blue
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF97316).withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E1415) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFF97316) : (isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.25)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              color: isSelected ? const Color(0xFFF97316) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: _currentFontFamily,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? const Color(0xFFF97316) : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: _currentFontFamily,
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLengthCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF97316).withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1E1415) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF97316)
                  : (isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.25)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                    color: isSelected ? const Color(0xFFF97316) : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: _currentFontFamily,
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? const Color(0xFFF97316) : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 22, right: 22),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: _currentFontFamily,
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 4: References Formatter Card ───────────────────────────────────────
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
              prefixIcon: Icon(CupertinoIcons.text_quote, color: ZankoColors.accent),
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

          // Two Action Buttons: PPTX Seminar OR 12-Page Report
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => _generateFullSeminar(topic.titleKurdish),
                    icon: const Icon(CupertinoIcons.paintbrush_fill, color: Colors.white, size: 14),
                    label: Text(
                      _selectedLanguage == SeminarLanguage.english ? '8 Slides PPTX' : 'سیمیناری ٨ سلاید',
                      style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7D2AE8), // Canva Color
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _reportTitleController.text = topic.titleKurdish;
                      _generate12PageReport(topic.titleKurdish);
                    },
                    icon: const Icon(CupertinoIcons.doc_text_fill, color: Colors.white, size: 14),
                    label: Text(
                      _selectedLanguage == SeminarLanguage.english ? '12-Page Report' : 'ڕاپۆرتی ١٢ پەڕەیی',
                      style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316), // Academic Blue
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ── 12-Page Academic Report Viewer & Exporter ──────────────────────────────
  Widget _buildReportViewerCard(bool isDark) {
    if (_parsedReport == null || _parsedReport!.pages.isEmpty) return const SizedBox();

    final currentPage = _selectedReportPageIndex < _parsedReport!.pages.length
        ? _parsedReport!.pages[_selectedReportPageIndex]
        : _parsedReport!.pages.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.35), width: 1.5),
        boxShadow: isDark ? [] : ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title & Quick Export Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFFF97316), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedLanguage == SeminarLanguage.english
                        ? 'Academic Report (12 Pages)'
                        : 'ڕاپۆرتی ئەکادیمی (١٢ پەڕە)',
                    style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _isExportingDocx ? null : _exportDocx,
                    icon: _isExportingDocx
                        ? const SizedBox(width: 18, height: 18, child: CupertinoActivityIndicator())
                        : const Icon(CupertinoIcons.doc_fill, color: Color(0xFF2B579A), size: 20),
                    tooltip: 'Word (.docx)',
                  ),
                  IconButton(
                    onPressed: _isExportingPdf ? null : _exportPdf,
                    icon: _isExportingPdf
                        ? const SizedBox(width: 18, height: 18, child: CupertinoActivityIndicator())
                        : const Icon(CupertinoIcons.arrow_down_doc_fill, color: Color(0xFFD32F2F), size: 20),
                    tooltip: 'PDF (.pdf)',
                  ),
                  IconButton(
                    onPressed: _copyToClipboard,
                    icon: Icon(CupertinoIcons.doc_on_doc, color: ZankoColors.accent, size: 20),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ],
          ),

          const Divider(),
          const SizedBox(height: 10),

          // ── Horizontal Page Number Switcher (1 to 8) ──
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _parsedReport!.pages.length,
              itemBuilder: (ctx, i) {
                final isSel = i == _selectedReportPageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedReportPageIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSel
                          ? LinearGradient(colors: [ZankoColors.primary, ZankoColors.accent])
                          : null,
                      color: isSel ? null : (isDark ? Colors.white10 : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _selectedLanguage == SeminarLanguage.english ? 'Page ${i + 1}' : 'پەڕەی ${i + 1}',
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

          // ── Active Page Content Display ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header / Type Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC00000), // Red badge
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _selectedLanguage == SeminarLanguage.english
                            ? 'Page ${currentPage.pageNumber} of ${_parsedReport!.pages.length}'
                            : 'پەڕەی ${currentPage.pageNumber} لە ${_parsedReport!.pages.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    Text(
                      currentPage.pageType.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Page Title
                Text(
                  currentPage.pageTitle,
                  style: TextStyle(
                    fontFamily: _currentFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Divider(height: 18),

                // ── PAGE 1: EXACT MATCH TO USER'S SCREENSHOT COVER TEMPLATE ──
                if (currentPage.pageType == 'cover') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? ZankoColors.darkBackground : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Builder(
                      builder: (context) {
                        final isKurdishOrArabic = _selectedLanguage != SeminarLanguage.english;
                        final ministryLine1 = _selectedLanguage == SeminarLanguage.english
                            ? 'Ministry of higher education'
                            : (_selectedLanguage == SeminarLanguage.arabic
                                ? 'وزارة التعليم العالي والبحث العلمي'
                                : 'وەزارەتی خوێندنی باڵا و توێژینەوەی زانستی');

                        final ministryLine2 = _selectedLanguage == SeminarLanguage.english ? 'And science research' : '';

                        final reportAboutLabel = _selectedLanguage == SeminarLanguage.english
                            ? 'Report about :'
                            : (_selectedLanguage == SeminarLanguage.arabic ? 'تقرير حول :' : 'ڕاپۆرت لەبارەی :');

                        final preparedLabel = _selectedLanguage == SeminarLanguage.english
                            ? 'Prepared by :'
                            : (_selectedLanguage == SeminarLanguage.arabic ? 'إعداد :' : 'ئامادەکردنی :');

                        final supervisorLabel = _selectedLanguage == SeminarLanguage.english
                            ? 'supervisor :'
                            : (_selectedLanguage == SeminarLanguage.arabic ? 'بإشراف :' : 'بەسەرپەرشتیی :');

                        final stageText = _parsedReport!.academicYear.isNotEmpty
                            ? _parsedReport!.academicYear
                            : (_selectedLanguage == SeminarLanguage.english ? 'Stage : One' : 'قۆناغی : یەکەم');

                        final studentList = _parsedReport!.studentName
                            .split(RegExp(r'[\n\r,،]+'))
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();

                        // Header Info Widget
                        final headerInfoWidget = Column(
                          crossAxisAlignment: isKurdishOrArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              ministryLine1,
                              textAlign: isKurdishOrArabic ? TextAlign.right : TextAlign.left,
                              style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[200] : const Color(0xFF0F172A)),
                            ),
                            if (ministryLine2.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                ministryLine2,
                                textAlign: isKurdishOrArabic ? TextAlign.right : TextAlign.left,
                                style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, color: isDark ? Colors.grey[200] : const Color(0xFF0F172A)),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              _parsedReport!.universityName,
                              textAlign: isKurdishOrArabic ? TextAlign.right : TextAlign.left,
                              style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, color: isDark ? Colors.grey[200] : const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _parsedReport!.departmentName,
                              textAlign: isKurdishOrArabic ? TextAlign.right : TextAlign.left,
                              style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12.5, color: isDark ? Colors.grey[300] : const Color(0xFF334155)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stageText,
                              textAlign: isKurdishOrArabic ? TextAlign.right : TextAlign.left,
                              style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF475569)),
                            ),
                          ],
                        );

                        // Logo Widget
                        final logoWidget = _universityLogoBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(_universityLogoBytes!, width: 64, height: 64, fit: BoxFit.cover),
                              )
                            : Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC00000).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFC00000).withValues(alpha: 0.3)),
                                ),
                                child: const Center(child: Text('🎓', style: TextStyle(fontSize: 28))),
                              );

                        // Prepared By Widget
                        final preparedByWidget = Column(
                          crossAxisAlignment: isKurdishOrArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              preparedLabel,
                              textAlign: isKurdishOrArabic ? TextAlign.right : TextAlign.left,
                              style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black),
                            ),
                            const SizedBox(height: 4),
                            if (studentList.isEmpty)
                              Text(_parsedReport!.studentName, textAlign: isKurdishOrArabic ? TextAlign.right : TextAlign.left, style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? Colors.grey[200] : Colors.black87))
                            else
                              ...studentList.map((s) => Text(
                                    s,
                                    textAlign: isKurdishOrArabic ? TextAlign.right : TextAlign.left,
                                    style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? Colors.grey[200] : Colors.black87),
                                  )),
                          ],
                        );

                        // Supervisor Widget
                        final supervisorWidget = Column(
                          crossAxisAlignment: isKurdishOrArabic ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Text(
                              supervisorLabel,
                              textAlign: isKurdishOrArabic ? TextAlign.left : TextAlign.right,
                              style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _parsedReport!.supervisorName,
                              textAlign: isKurdishOrArabic ? TextAlign.left : TextAlign.right,
                              style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? Colors.grey[200] : Colors.black87),
                            ),
                          ],
                        );

                        final yearDisplay = _parsedReport!.academicYear.isNotEmpty ? _parsedReport!.academicYear : '2024-2025';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Respect RTL / LTR
                            if (!isKurdishOrArabic)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: headerInfoWidget),
                                  const SizedBox(width: 12),
                                  logoWidget,
                                ],
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  logoWidget,
                                  const SizedBox(width: 12),
                                  Expanded(child: headerInfoWidget),
                                ],
                              ),

                            // Center: "Report about :" in RED, then Title in RED bold
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: Column(
                                  children: [
                                    Text(
                                      reportAboutLabel,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: _currentFontFamily,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: const Color(0xFFC00000), // Crimson Red
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _parsedReport!.title,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: _currentFontFamily,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        letterSpacing: 0.3,
                                        color: const Color(0xFFC00000), // Crimson Red
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Bottom Row: Respect RTL / LTR
                            if (!isKurdishOrArabic)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: preparedByWidget),
                                  const SizedBox(width: 12),
                                  Expanded(child: supervisorWidget),
                                ],
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: supervisorWidget),
                                  const SizedBox(width: 12),
                                  Expanded(child: preparedByWidget),
                                ],
                              ),

                            // Bottom-Center: Academic Year in RED bold
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                yearDisplay,
                                style: TextStyle(
                                  fontFamily: _currentFontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: const Color(0xFFC00000),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ] else if (currentPage.pageType == 'toc') ...[
                  // ── PAGE 2: TABLE OF CONTENTS ──
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        currentPage.pageTitle,
                        style: TextStyle(
                          fontFamily: _currentFontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: const Color(0xFFC00000),
                        ),
                      ),
                    ),
                  ),
                  ...currentPage.bulletPoints.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Text('🔹 ', style: TextStyle(color: const Color(0xFFC00000), fontSize: 13)),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontFamily: _currentFontFamily,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ] else if (currentPage.pageType == 'references') ...[
                  // ── PAGE 8: REFERENCES ──
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        currentPage.pageTitle,
                        style: TextStyle(
                          fontFamily: _currentFontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: const Color(0xFFC00000),
                        ),
                      ),
                    ),
                  ),
                  ...currentPage.bulletPoints.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final refText = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$idx. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          Expanded(
                            child: Text(
                              refText,
                              style: TextStyle(
                                fontFamily: _currentFontFamily,
                                fontSize: 13,
                                height: 1.5,
                                color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  // ── PAGES 3 TO 7: CONTENT PAGES (2 SECTIONS PER PAGE) ──
                  if (currentPage.sections.isNotEmpty) ...[
                    ...currentPage.sections.map((sec) => Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Section Red Title e.g. "1. Introduction"
                              Text(
                                '${sec.sectionNumber}. ${sec.title}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: _currentFontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.5,
                                  color: const Color(0xFFC00000), // Crimson Red
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (sec.content.isNotEmpty)
                                Text(
                                  sec.content,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: _currentFontFamily,
                                    fontSize: 13.5,
                                    height: 1.6,
                                    color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                                  ),
                                ),
                              if (sec.bulletPoints.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ...sec.bulletPoints.map((bullet) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('• ', style: TextStyle(color: Color(0xFFC00000), fontSize: 16, fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              bullet,
                                              style: TextStyle(
                                                fontFamily: _currentFontFamily,
                                                fontSize: 13,
                                                height: 1.45,
                                                color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            ],
                          ),
                        )),

                    // ── Topic-Specific Scientific Image & Diagram ──
                    if (currentPage.imageUrl != null && currentPage.imageUrl!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8, bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 190,
                                child: Image.network(
                                  currentPage.imageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
                                      child: const Center(child: CupertinoActivityIndicator()),
                                    );
                                  },
                                  errorBuilder: (ctx, err, stack) => Container(
                                    height: 120,
                                    color: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Icon(CupertinoIcons.photo, size: 40, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, size: 14, color: Color(0xFFC00000)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _selectedLanguage == SeminarLanguage.english
                                            ? 'Figure (${currentPage.pageNumber - 2}): ${currentPage.pageTitle}'
                                            : 'شێوەی زانستی (${currentPage.pageNumber - 2}): ${currentPage.pageTitle}',
                                        style: TextStyle(
                                          fontFamily: _currentFontFamily,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Generic fallback content
                    if (currentPage.content.isNotEmpty)
                      Text(
                        currentPage.content,
                        style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13.5, height: 1.6),
                      ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // ── Dual Download Buttons: Word (.docx) & PDF (.pdf) ──
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isExportingDocx ? null : _exportDocx,
                    icon: _isExportingDocx
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Icon(CupertinoIcons.doc_fill, color: Colors.white, size: 18),
                    label: Text(
                      _isExportingDocx
                          ? (_selectedLanguage == SeminarLanguage.english ? 'Creating...' : 'دروستکردن...')
                          : (_selectedLanguage == SeminarLanguage.english ? '📄 Download Word' : '📄 داگرتنی Word'),
                      style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B579A), // Word Blue
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
                    onPressed: _isExportingPdf ? null : _exportPdf,
                    icon: _isExportingPdf
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Icon(CupertinoIcons.arrow_down_doc_fill, color: Colors.white, size: 18),
                    label: Text(
                      _isExportingPdf
                          ? (_selectedLanguage == SeminarLanguage.english ? 'Creating...' : 'دروستکردن...')
                          : (_selectedLanguage == SeminarLanguage.english ? '📑 Download PDF' : '📑 داگرتنی PDF'),
                      style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F), // PDF Red
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
                    icon: Icon(CupertinoIcons.doc_on_doc, color: ZankoColors.accent, size: 20),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ],
          ),

          const Divider(),
          const SizedBox(height: 10),

          // Horizontal Slide Selector
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

          // Active Slide Content
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
                  Icon(CupertinoIcons.checkmark_seal_fill, color: ZankoColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _selectedLanguage == SeminarLanguage.english ? 'Results' : 'ئەنجامەکان',
                    style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              IconButton(
                onPressed: _copyToClipboard,
                icon: Icon(CupertinoIcons.doc_on_doc, color: ZankoColors.accent, size: 20),
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
    final safeDept = dept.trim().isEmpty ? 'زانست و تەکنۆلۆژیا' : dept.trim();
    final dLower = safeDept.toLowerCase();

    List<Map<String, String>> pool = [];

    if (dLower.contains('تەندروست') || dLower.contains('پزیشک') || dLower.contains('تاقیگە') || dLower.contains('دەرمان') || dLower.contains('med') || dLower.contains('health') || dLower.contains('nurs') || dLower.contains('pharma') || dLower.contains('طب') || dLower.contains('صح')) {
      pool = [
        {
          'ku': 'کاریگەریی نانۆتەکنۆلۆژیا لە دەستنیشانکردن و چارەسەری نەخۆشییە شێرپەنجەییەکان',
          'en': 'Nanotechnology Applications in Oncology Diagnosis and Targeted Therapy',
          'sum': 'لێکۆڵینەوە لەسەر بەکارهێنانی تەنۆلکە نانۆییەکان بۆ گەیاندنی دەرمان بە خانە تووشبووەکان بەبێ زیانگەیاندن بە خانە ساغەکان.',
          'q': 'چۆن نانۆپارتیکڵەکان دەتوانن ڕێژەی کاریگەریی چارەسەری کیمیایی بەرز بکەنەوە؟',
        },
        {
          'ku': 'ڕۆڵی ژیریی دەستکرد لە شیکاریی وێنەی پزیشکی و تیشکناسی (Radiology)',
          'en': 'Artificial Intelligence in Medical Image Processing and Radiology',
          'sum': 'هەڵسەنگاندنی ئەلگۆریتمەکانی بینینی کۆمپیوتەری بۆ دەستنیشانکردنی زووەوەختی وەرەم و شکانە وردەکان بە وردبینی ٩٨٪.',
          'q': 'تا چەند مۆدێلە قووڵەکان دەتوانن یارمەتیدەری پزیشکانی تیشک بن لە کەمکردنەوەی هەڵەکاندا؟',
        },
        {
          'ku': 'بەرگری دژەبەکتریایی (Antibiotic Resistance) و بەکارهێنانی چارەسەری بەکتریۆفەیج',
          'en': 'Bacterial Resistance to Antibiotics and Bacteriophage Therapy',
          'sum': 'شیکاریی مەترسییەکانی بڵاوبوونەوەی سوپەربەکتریای بەرگریکار و چارەسەرە نوێیە بایۆلۆجییەکان.',
          'q': 'ئایا چارەسەری بەکتریۆفەیج دەتوانێت جێگرەوەی دژەبەکتریا باوەکان بێت؟',
        },
        {
          'ku': 'کاریگەریی مایکڕۆبایۆمی ڕیخۆڵە لەسەر نەخۆشییە دەماری و دەروونییەکان (Gut-Brain Axis)',
          'en': 'Gut Microbiome and the Gut-Brain Axis in Neurological Disorders',
          'sum': 'لێکۆڵینەوە لە پەیوەندی نێوان بەکتریای سوودبەخشی هەرس و باری دەروونی و نەخۆشییەکانی پارکینسۆن و خەمۆکی.',
          'q': 'میکانیزمە بایۆکیمیاییەکانی پەیوەندی نێوان کۆئەندامی هەرس و مێشک چین؟',
        },
        {
          'ku': 'بەکارهێنانی پشکنینی بایۆمارکەرە پێشکەوتووەکان لە دەستنیشانکردنی زووی نەخۆشییەکانی دڵ',
          'en': 'Advanced Cardiac Biomarkers in Early Cardiovascular Risk Assessment',
          'sum': 'شیکاریی پێوەرە تاقیگەییە نوێیەکان و ترۆپۆنینی هەستیار بۆ پێشبینیکردنی جەڵتەی دڵ.',
          'q': 'بایۆمارکەرە نوێیەکان چۆن کاتی دەستنیشانکردنی نەخۆشییە مەترسیدارەکان کەم دەکەنەوە؟',
        },
        {
          'ku': 'تەکنۆلۆژیای CRISPR و دەستکاریکردنی جینەکان لە نەخۆشییە بۆماوەییەکاندا',
          'en': 'CRISPR-Cas9 Gene Editing in Genetic Diseases & Clinical Ethics',
          'sum': 'شیکاریی پێشکەوتنەکانی دەستکاریکردنی جین بۆ چارەسەری نەخۆشییەکانی خوێن و تالاسیما.',
          'q': 'ڕەهەندە تەکنیکی و ئەخلاقییەکانی بەکارهێنانی CRISPR لە کلینیکەکاندا چین؟',
        },
      ];
    } else if (dLower.contains('ئەندازیار') || dLower.contains('بیناساز') || dLower.contains('کارەبا') || dLower.contains('میکانیک') || dLower.contains('تەلارساز') || dLower.contains('eng') || dLower.contains('civil') || dLower.contains('arch') || dLower.contains('electric') || dLower.contains('هندس')) {
      pool = [
        {
          'ku': 'بیناسازیی سەوز و بەکارهێنانی کەرەستەی خۆڕاگر لە شارە زیرەکەکاندا',
          'en': 'Green Building Technologies and Sustainable Materials in Smart Cities',
          'sum': 'لێکۆڵینەوە لە کەمکردنەوەی بەفیڕۆچوونی وزە و بەکارهێنانی کۆنکرێتی خۆچاککەرەوە لە باڵەخانە نوێیەکاندا.',
          'q': 'چۆن دیزاینی بیناسازیی سەوز دەتوانێت تێچووی وزە بە ڕێژەی ٥٠٪ کەم بکاتەوە؟',
        },
        {
          'ku': 'پەرەپێدانی تۆڕە زیرەکەکانی کارەبا (Smart Grids) و ئاوێتەکردنی وزەی خۆر',
          'en': 'Smart Electrical Grids and Renewable Solar Energy Integration',
          'sum': 'شیکاریی دابەشکردنی کارەبای بەرهەمهاتوو لە سەرچاوە نوێبووەکان بە شێوازێکی هاوسەنگ و سەقامگیر.',
          'q': 'میکانیزمە سەرەکییەکانی بەڕێوەبردنی بارگرانی لە تۆڕە زیرەکەکاندا چین؟',
        },
        {
          'ku': 'بەکارهێنانی ڕۆبۆت و پرینتەری 3D لە کەرتی بیناسازی و پیشەسازیدا',
          'en': '3D Concrete Printing and Autonomous Robotics in Construction',
          'sum': 'هەڵسەنگاندنی خێرایی دروستکردنی باڵەخانە بە پرینتەری سێ دووری و کەمکردنەوەی پاشماوەی کەرەستەکان.',
          'q': 'ئایا چاپکردنی سێ دووری دەتوانێت کاتی جێبەجێکردنی پڕۆژە ئەندازیارییەکان بۆ نیوە کەم بکاتەوە؟',
        },
        {
          'ku': 'شیکاریی پەستانی داینامیکی و بەرگریی باڵەخانە بەرزەکان لە بەرامبەر بومەلەرزەدا',
          'en': 'Seismic Resilience and Structural Dynamic Analysis of High-Rise Buildings',
          'sum': 'بەکارهێنانی سیستەمی دامپەری بنەڕەتی و ژمێریاری پێشکەوتوو بۆ کەمکردنەوەی لەرزین.',
          'q': 'بەهێزترین تەکنیکەکان چین بۆ پاراستنی باڵەخانەکان لە بەرامبەر زەمینلەرزە بەهێزەکاندا؟',
        },
        {
          'ku': 'پاترییە پێشکەوتووەکانی لیتیۆم و هایدرۆجین لە ئۆتۆمبێلە کارەباییەکاندا (EV)',
          'en': 'Solid-State Battery Technologies and Hydrogen Fuel in Electric Vehicles',
          'sum': 'شیکاریی بەرزکردنەوەی توانای پاشەکەوتکردنی وزە و خێرایی شەحنکردنەوە لە سیستمە هاوچەرخەکاندا.',
          'q': 'ئایا پاترییە دۆخ-ڕەقەکان دەتوانن جێگەی پاترییە شلەکان بگرنەوە بە کارایی بەرزتر؟',
        },
      ];
    } else if (dLower.contains('یاسا') || dLower.contains('ماف') || dLower.contains('سیاس') || dLower.contains('law') || dLower.contains('polit') || dLower.contains('legal') || dLower.contains('حقوق') || dLower.contains('قانون')) {
      pool = [
        {
          'ku': 'یاسای تاوانە ئەلیکترۆنییەکان و پاراستنی مافی تایبەتێتی تاک لە سەردەمی دیجیتاڵیدا',
          'en': 'Cybercrime Legislation and Digital Privacy Protection Laws',
          'sum': 'شیکاریی چوارچێوە یاساییەکان بۆ بەرەنگاربوونەوەی ساختەکاری دارایی و دەستدرێژی بۆ سەر زانیاری کەسی.',
          'q': 'یاسا هاوچەرخەکان تا چەند دەتوانن سنوور بۆ تاوانە سنووربەزێنە ئەلیکترۆنییەکان دابنێن؟',
        },
        {
          'ku': 'بەرپرسیارێتیی یاسایی لە بەرامبەر هەڵەی سیستمە خودموختارەکان و ژیریی دەستکرد',
          'en': 'Legal Liability and Regulatory Frameworks for Autonomous AI Systems',
          'sum': 'لێکۆڵینەوە لە کێشەکانی دەستنیشانکردنی تاوانبار لە کاتی ڕوودانی زیان بەهۆی ئۆتۆمبێلی بێ شۆفێر یان بڕیاری ئۆتۆماتیکی.',
          'q': 'بەرپرسیارێتی یاسایی دەکەوێتە ئەستۆی دروستکەر، بەکارهێنەر، یاخود خودی سیستەمەکە؟',
        },
        {
          'ku': 'مافەکانی مرۆڤ و پاراستنی ژینگە لە یاسای نێودەوڵەتیدا',
          'en': 'International Environmental Law and Human Rights Protections',
          'sum': 'شیکاریی پەیماننامە نێودەوڵەتییەکان بۆ سزادانی ئەو وڵات و کۆمپانیایانەی دەبنە هۆی پیسبوونی گەورەی ژینگە.',
          'q': 'ئایا پیسکردنی ژینگە دەکرێت وەک تاوان دژی مرۆڤایەتی لە دادگای نێودەوڵەتی بناسێنرێت؟',
        },
        {
          'ku': 'گرێبەستە ئەلیکترۆنییەکان و بەڵگەنامەی دیجیتاڵی لە یاسای بازرگانیدا',
          'en': 'Electronic Contracts and Digital Evidence Admissibility in Commercial Law',
          'sum': 'هەڵسەنگاندنی باوەڕپێکراوی ئیمزای ئەلیکترۆنی و بەڵگەنامە دیجیتاڵییەکان لە بەردەم دادگاکاندا.',
          'q': 'مەرجە بنەڕەتییەکانی سەلماندنی گرێبەستی ئەلیکترۆنی لە یاسای دادوەریدا چین؟',
        },
      ];
    } else if (dLower.contains('هونەر') || dLower.contains('شێوەکار') || dLower.contains('مۆسیقا') || dLower.contains('شانۆ') || dLower.contains('ئەدەب') || dLower.contains('مێژوو') || dLower.contains('جوگراف') || dLower.contains('فەلسەف') || dLower.contains('دەروون') || dLower.contains('کۆمەڵناسی') || dLower.contains('میدیا') || dLower.contains('ڕاگەیاندن') || dLower.contains('پەروەردە') || dLower.contains('art') || dLower.contains('fine') || dLower.contains('design') || dLower.contains('history') || dLower.contains('media') || dLower.contains('psych') || dLower.contains('فنون') || dLower.contains('فن') || dLower.contains('تاريخ')) {
      pool = [
        {
          'ku': 'کاریگەریی تەکنۆلۆژیای دیجیتاڵ لەسەر پەرەسەندنی هونەری شێوەکاری و دیزاین',
          'en': 'Digital Technology Impact on Modern Fine Arts and Graphic Design',
          'sum': 'لێکۆڵینەوە لە تێکەڵبوونی هۆشیاری دیجیتاڵی و مۆدێلە ڕەنگاواڵەکان لە دروستکردنی تابلۆ و پەیکەرسازی هاوچەرخدا.',
          'q': 'چۆن میدیای دیجیتاڵی تێگەیشتنی بینەر بۆ تابلۆ ئەکادیمییەکان دەگۆڕێت؟',
        },
        {
          'ku': 'شیکاریی سیمۆتیکی (Semiotics) و هەڵهێنجانی هێماکان لە شانۆ و سینەمای ڕۆژهەڵاتی ناوەڕاستدا',
          'en': 'Semiotics and Visual Symbolism in Contemporary Middle Eastern Cinema and Theater',
          'sum': 'شیکردنەوەی ئاماژە و هێما درامییەکان لە دەقی شانۆیی و بەرھەمھێنانی بەرهەمە سینەماییەکاندا.',
          'q': 'هێما درامییەکان چۆن پەیامی فەلسەفی بە بینەران دەگەیەنن؟',
        },
        {
          'ku': 'دیزاینی بینراو (Visual Design) و بنەماکانی میماریا لە پاراستنی کەلەپوور و فۆلکلۆردا',
          'en': 'Visual Design & Architectural Aesthetics in Cultural Heritage Preservation',
          'sum': 'هەڵسەنگاندنی ڕۆڵی دیزاین و فۆتۆگرافیی ئەکادیمی لە پاراستنی شوێنەوارە هونەری و کلتورییەکان.',
          'q': 'دیزاینەرانی هاوچەرخ چۆن دەتوانن هەستی فۆلکلۆری لە کارە نوێیەکاندا بپارێزن؟',
        },
        {
          'ku': 'کاریگەریی دەروونناسیی ڕەنگەکان (Color Psychology) لەسەر ڕەفتاری بینەر و بەرهەمی هونەری',
          'en': 'Color Psychology & Aesthetic Perception in Visual Arts and Advertising',
          'sum': 'لێکۆڵینەوە لە کاردانەوەی دەماری و دەروونی بینەر بەرامبەر هارمۆنیی ڕەنگەکان لە کارە هونەرییەکاندا.',
          'q': 'شیکاری ڕەنگەکان چۆن یارمەتی هونەرمەند دەدات کاریگەری دەروونی دروست بکات؟',
        },
      ];
    } else if (dLower.contains('بازرگان') || dLower.contains('ئابوور') || dLower.contains('کارگێڕ') || dLower.contains('دارایی') || dLower.contains('ژمێریار') || dLower.contains('busin') || dLower.contains('econ') || dLower.contains('manage') || dLower.contains('finan') || dLower.contains('تجارة') || dLower.contains('اقتصاد')) {
      pool = [
        {
          'ku': 'کاریگەریی دراوە دیجیتاڵییەکان و بلۆکچەین لەسەر سیستەمی بانکیی جیهانی',
          'en': 'Central Bank Digital Currencies (CBDC) and Blockchain in Modern Banking',
          'sum': 'شیکاریی گۆڕانکارییە داراییەکان و خێرایی حەواڵەکردنی نێودەوڵەتی بەبێ نێوەندگیر.',
          'q': 'دراوە دیجیتاڵییەکانی بانکی ناوەندی چۆن مەترسییەکانی هەڵئاوسان کەم دەکەنەوە؟',
        },
        {
          'ku': 'ستراتیژییەکانی بەبازاڕکردنی دیجیتاڵی و شیکاریی ڕەفتاری کڕیار بە ژیریی دەستکرد',
          'en': 'AI-Driven Digital Marketing Strategies and Consumer Behavior Analytics',
          'sum': 'لێکۆڵینەوە لە بەکارهێنانی داتای گەورە بۆ پێشبینیکردنی پێداویستییەکانی کڕیار و بەرزکردنەوەی فرۆش.',
          'q': 'چۆن مۆدێلە پێشبینیکەرەکان ڕێژەی گەڕانەوەی وەبەرهێنان (ROI) زیاد دەکەن؟',
        },
        {
          'ku': 'بەڕێوەبردنی زنجیرەی دابینکردن (Supply Chain) لە کاتی قەیرانە نێودەوڵەتییەکاندا',
          'en': 'Resilient Supply Chain Management and Logistics During Global Crises',
          'sum': 'هەڵسەنگاندنی بەکارهێنانی ئەلگۆریتمە هۆشیارەکان بۆ پێشبینیکردنی دواکەوتنی کەلوپەل و کەمکردنەوەی زەرەر.',
          'q': 'چی ڕێکارێک یارمەتی کۆمپانیاکان دەدات پارێزگاری لە بەردەوامی هێڵی بەرهەمهێنان بکەن؟',
        },
        {
          'ku': 'حووکمڕانیی کۆمپانیاکان (Corporate Governance) و شەفافیەتی دارایی لە بازاڕی پشکەکاندا',
          'en': 'Corporate Governance, Financial Transparency, and ESG Investing',
          'sum': 'شیکاریی پێوەرە ژینگەیی و کۆمەڵایەتییەکان (ESG) لە ڕاکێشانی وەبەرهێنەرە گەورەکاندا.',
          'q': 'شەفافیەتی دارایی چۆن متمانەی وەبەرهێنەر و بەهای پشکەکان لە بازاڕدا بەرز دەکاتەوە؟',
        },
      ];
    } else {
      // Tech, AI, Computer Science & General Academic Pool
      pool = [
        {
          'ku': 'کاریگەریی مۆدێلە گەورەکانی زمان (LLMs) لەسەر شۆڕشی زانستی و فێربوونی ئەکادیمی',
          'en': 'Large Language Models (LLMs) Transforming Scientific Research & Academic Discovery',
          'sum': 'شیکاریی چۆنیەتی بەکارهێنانی ژیریی دەستکرد لە خێراکردنی لێکۆڵینەوەی تاقیگەیی و شیکاری داتا ئاڵۆزەکان.',
          'q': 'چۆن ژیریی دەستکرد دەتوانێت کاتی توێژینەوەی زانستی لە مانگەوە بۆ چەند خولەکێک کەم بکاتەوە؟',
        },
        {
          'ku': 'ئەمنییەتی سایبەری بە مۆدێلی Zero-Trust لە تۆڕە هەورییە نێودەوڵەتییەکاندا',
          'en': 'Zero-Trust Architecture and Cloud Security Infrastructure in Modern Networks',
          'sum': 'لێکۆڵینەوە لە پرۆتۆکۆلەکانی پاراستنی داتابەیس و جێبەجێکردنی شفرەکردنی قووڵ لە هەموو لایەنەکانەوە.',
          'q': 'مۆدێلی Zero-Trust چۆن بە تەواوی ڕێگری لە دزەکردنی هاککەرەکان دەکات بۆ ناو تۆڕی ناوەکی؟',
        },
        {
          'ku': 'کۆمپیوتەری کوانتەمی (Quantum Computing) و کاریگەریی لەسەر شکاندنی شفرە کلاسیکییەکان',
          'en': 'Quantum Computing Advancements and the Post-Quantum Cryptography Era',
          'sum': 'شیکاریی توانای پرۆسێسەرە کوانتەمییەکان لە شیکارکردنی ئەلگۆریتمە قورسەکان و پێویستی شفرەی نوێ.',
          'q': 'بۆچی دەبێت سیستمە ئەمنییەکان خۆیان بۆ سەردەمی پۆست-کوانتەم ئامادە بکەن؟',
        },
        {
          'ku': 'ئینتەرنێتی شتەکان (IoT) و شیکاریی لێواریی داتا (Edge Computing) لە شارە زیرەکەکاندا',
          'en': 'Internet of Things (IoT) and Edge Computing in Next-Generation Smart Cities',
          'sum': 'هەڵسەنگاندنی بەستنەوەی هەزاران سێنسەر و شیکارکردنی ڕاستەوخۆی داتا لە شوێنی ڕووداو بۆ کەمکردنەوەی لێتێنسی.',
          'q': 'چۆن Edge Computing خێرایی وەڵامدانەوەی سیستمە ئۆتۆماتیکییەکان بەرز دەکاتەوە؟',
        },
        {
          'ku': 'سیستەمی بلۆکچەین لە بەڕێوەبردنی داتای ئەکادیمی و سەلماندنی بڕوانامە زانکۆییەکان',
          'en': 'Blockchain Technology for Verifiable Academic Credentials and Research Integrity',
          'sum': 'شیکاریی بەکارهێنانی تۆماری نەگۆڕ (Immutable Ledger) بۆ نەهێشتنی تەزویر و ساختەکاری بڕوانامە.',
          'q': 'بلۆکچەین چۆن دەتوانێت ١٠٠٪ ساختەکاری لە بڕوانامە ئەکادیمییەکاندا بنبڕ بکات؟',
        },
        {
          'ku': 'دیدگای داهاتوو بۆ نەوەی شەشەمی پەیوەندییەکان (6G Networks) و کەمکردنەوەی دواکەوتن (Ultra-Low Latency)',
          'en': 'Future Horizons of 6G Wireless Networks and Terahertz Communications',
          'sum': 'لێکۆڵینەوە لە خێرایی تێراپێکسڵ و پەیوەندی هۆلۆگرامی و بەستنەوەی جیهانی فیزیکی و دیجیتاڵی.',
          'q': 'تەکنۆلۆژیای 6G چ دەرگایەکی نوێ بۆ نەشتەرگەری لە دوورەوە و کۆنترۆڵی ئۆتۆمبێلەکان دەکاتەوە؟',
        },
      ];
    }

    // Shuffle pool for maximum variety each request
    pool.shuffle();
    final selected = pool.take(6).toList();

    final sb = StringBuffer();
    for (int i = 0; i < selected.length; i++) {
      final item = selected[i];
      if (_selectedLanguage == SeminarLanguage.english) {
        sb.writeln('### 📌 Topic ${i + 1}: ${item['en']}');
        sb.writeln('- **Secondary**: ${item['ku']}');
        sb.writeln('- **💡 Summary & Significance**: Comprehensive academic investigation evaluating modern paradigms and practical implementations in $safeDept.');
        sb.writeln('- **❓ Research Question**: How does this framework optimize operational efficiency and resolve core challenges in $safeDept?');
      } else if (_selectedLanguage == SeminarLanguage.arabic) {
        sb.writeln('### 📌 الموضوع ${i + 1}: ${item['ku']}');
        sb.writeln('- **العنوان الإنجليزي**: ${item['en']}');
        sb.writeln('- **💡 الملخص والأهمية**: ${item['sum']}');
        sb.writeln('- **❓ السؤال البحثي**: ${item['q']}');
      } else {
        sb.writeln('### 📌 بابەتی ${i + 1}: ${item['ku']}');
        sb.writeln('- **ئینگلیزی**: ${item['en']}');
        sb.writeln('- **💡 کورتەی بیرۆکە و گرنگی**: ${item['sum']}');
        sb.writeln('- **❓ پرسیاری سەرەکی توێژینەوە**: ${item['q']}');
      }
      sb.writeln();
    }

    return sb.toString();
  }

  List<SeminarTopicProposal> _getFallbackTopicProposals(String dept) {
    final raw = _generateFallbackTopicsText(dept);
    return _parseTopicProposals(raw);
  }
  // ── Fallback 8 Slide Seminar ───────────────────────────────────────────────
  String _generateFallback8SlideSeminar(String title) {
    if (_selectedLanguage == SeminarLanguage.english) {
      return '''
# 📊 Presentation: "$title" (Canva & PPTX Format)
### 🔹 Slide 1: Introduction & Significance
- Comprehensive investigation into $title.
- Integrating neural computational frameworks.
- Aligning with global peer-reviewed benchmarks.
- 🎙️ **Speaker Script**: "Good morning esteemed professors. Today we present our findings on $title."
### 🔹 Slide 2: Background Context & Technology Evolution
- Paradigm shifts across the educational landscape.
- Over 70% of universities adopting digital cloud tools.
- 🎙️ **Speaker Script**: "As shown in this developmental timeline, rapid advancements have transformed this field."
### 🔹 Slide 3: Core Problem Statement & Limitations
- High human fatigue in legacy manual workflows.
- Inherent statistical inaccuracies in non-automated workflows.
- 🎙️ **Speaker Script**: "The core motivation stems from these legacy bottlenecks."
### 🔹 Slide 4: Strategic Research Objectives
- Framework delivering 95%+ classification accuracy.
- Reducing operational time by over 40%.
- 🎙️ **Speaker Script**: "Our primary objective is delivering an empirically validated framework."
### 🔹 Slide 5: Methodology & Architecture
- Rigorous experimental design with standardized benchmarks.
- Multi-stage cross-validation ensuring reproducibility.
- 🎙️ **Speaker Script**: "Our methodology is engineered on an empirical foundation."
### 🔹 Slide 6: Key Findings & Data Analysis
- Surge of +85% in overall operational throughput.
- Error rates suppressed to under 3%.
- 🎙️ **Speaker Script**: "Our experimental results demonstrate decisive improvements."
### 🔹 Slide 7: Practical Impact & Roadmap
- Strategic guidance for institutional deployment.
- Ethical governance and data security standards.
- 🎙️ **Speaker Script**: "We recommend institutional leaders adopt these deployment phases."
### 🔹 Slide 8: Academic Citations & Q&A
- Smith, J. A., & Davis, R. M. (2024). Modern Methodologies in Applied Academic Research. Academic Press.
- World Educational Research Association (2025). Global Standards for Academic Excellence. WERA.
- UNESCO (2025). Guidance for Applied Generative Technologies in Higher Education. Paris: UNESCO.
- 🎙️ **Speaker Script**: "Thank you sincerely for your attention. I welcome your questions."
''';
    }

    return '''
# 📊 سیمیناری تەواوی ٨ سلایدی پاوەرپۆینت بۆ "$title" (Canva Style)
### 🔹 سلایدی ١: ناساندنی گشتی و ناونیشانی سەرەکی
- لێکۆڵینەوەیەکی زانستیی سەردەمیانە لەسەر شێوازە مۆدێرنەکانی توێژینەوە لە بواری $title.
- بەکارهێنانی مۆدێلە پێشکەوتووەکان بۆ شیکردنەوەی داتا و بەرزکردنەوەی کارایی زانستی.
- تیشکخستنە سەر گرنگیی پراکتیکی و تیۆریی بابەتەکە لە ناوەندە ئەکادیمییەکاندا.
- 🎙️ **تێبینی پێشکەشکار**: "سڵاو و ڕێز مامۆستایانی بەڕێز، بەخێربێن بۆ ئەم سیمینارە لەسەر ناونیشانی ($title)."
### 🔹 سلایدی ٢: پاشخانی زانستی و هۆکاری سەرهەڵدانی بابەتەکە
- شۆڕشی چوارەمی تەکنەلۆجی و گۆڕانی بنەڕەتی لە میتۆدەکانی فێرکاری و لێکۆڵینەوەدا.
- توانای مۆدێلە زیرەکەکان لە کەمکردنەوەی کاتی لێکۆڵینەوە بە ڕێژەی زیاتر لە ٥٠٪.
- 🎙️ **تێبینی پێشکەشکار**: "وەک لە هێڵکارییەکەدا دەبینین، ئەم بوارە لە ماوەیەکی کەمدا بازدانی گەورەی ئەنجامداوە."
### 🔹 سلایدی ٣: کێشەی سەرەکی توێژینەوە و بەربەستە نەریتییەکان
- سنوورداریی لە کات و سەرچاوە مرۆییەکان لە شیکردنەوەی هەزاران داتای زانستی بە شێوازی دەستی.
- بوونی نادروستی و هەڵەی مرۆیی لە پرۆسەی کۆکردنەوە و پۆلێنکردنی داتای توێژینەوەکاندا.
- 🎙️ **تێبینی پێشکەشکار**: "هۆکاری سەرەکی هەڵبژاردنی ئەم بابەتە بریتی بوو لە بوونی ئەم ئاستەنگ و بۆشاییە زانستییە."
### 🔹 سلایدی ٤: ئامانجە سەرەکییەکان و دەستکەوتە چاوەڕوانکراوەکان
- دەستنیشانکردنی کاریگەرترین میکانیزمەکان بۆ ئۆتۆماتیکردنی شیکارییە ئەکادیمییەکان بە وردبینی بەرز.
- کەمکردنەوەی تێچووی کات و ماددی لە توێژینەوە زانستییەکاندا بە ڕێژەی زیاتر لە ٤٠٪.
- 🎙️ **تێبینی پێشکەشکار**: "ئامانجمان لەم کارەدا پێشکەشکردنی چارەسەرێکی زانستیی سەلمێنراوە."
### 🔹 سلایدی ٥: میتۆدۆلۆجی، تەکنیک و کەرەستە بەکارهاتووەکان
- پەیڕەوکردنی میتۆدی زانستیی تاقیکاری لەسەر داتای مەیدانیی وەرگیراو.
- بەکارهێنانی ئەلگۆریتم و مۆدێلە شیکارییەکان بۆ پۆلێنکردنی زانیارییەکان بە وردیی ٩٥٪.
- 🎙️ **تێبینی پێشکەشکار**: "میتۆدۆلۆجی ئەم توێژینەوەیە لەسەر چوارچێوەیەکی زانستیی توندوتۆڵ بنیاتنراوە."
### 🔹 سلایدی ٦: شیکاریی زانستی و دەرئەنجامە ئامارییەکان
- بەدەستهێنانی کاراییەکی بەرچاو بە ڕێژەی ٨٥٪ لە خێرایی جێبەجێکردنی پرۆسەکاندا.
- دابەزینی ڕێژەی هەڵە و کەموکوڕییەکان بۆ کەمتر لە ٣٪.
- 🎙️ **تێبینی پێشکەشکار**: "وەک لە چارتەکاندا دەردەکەوێت، داتاکان بە ڕوونی دەیسەلمێنن کە ئەم شێوازە سەرکەوتووە."
### 🔹 سلایدی ٧: کاریگەریی پراکتیکی، ڕاسپاردە و پێشنیارەکان
- پێشنیار بۆ زانکۆکان تا ژێرخانی پێویست دابین بکەن بۆ هاندانی ئەم پڕۆژانە.
- دانانی ڕێسای ئەخلاقی و پرۆتۆکۆلی پاراستن لە کاتی جێبەجێکردندا.
- 🎙️ **تێبینی پێشکەشکار**: "لە پێناو بەردەوامی ئەم دەستکەوتانە، گرنگە ئەم پێشنیارانە بخرێنە بواری جێبەجێکردنەوە."
### 🔹 سلایدی ٨: سەرچاوە زانستییە باوەڕپێکراوەکان و وەڵامدانەوەی پرسیارەکان
- Smith, J. A., & Davis, R. M. (2024). Modern Methodologies in Applied Academic Research. Academic Press.
- World Educational Research Association (2025). Global Standards for Academic Excellence. WERA.
- UNESCO (2025). Guidance for Applied Generative Technologies in Higher Education. Paris: UNESCO.
- 🎙️ **تێبینی پێشکەشکار**: "سوپاس بۆ گوێگرتنتان، ئێستا بە خۆشحاڵییەوە دەرگا واڵایە بۆ پرسیارەکانتان."
''';
  }

  // ── Fallback Academic Report (8 Pages Standard) ───────────────────────────
  String _generateFallback12PageReportText(String title) {
    final lang = _selectedLanguage.code;
    final sections = DocxGeneratorService.getDefaultSections(title, lang);
    final refs = DocxGeneratorService.getDefaultReferences(title, lang);

    final sb = StringBuffer();
    sb.writeln('### Table of Contents');
    for (var s in sections) {
      sb.writeln('${s.sectionNumber}. ${s.title}');
    }
    sb.writeln();

    for (var s in sections) {
      sb.writeln('### ${s.sectionNumber}. ${s.title}');
      sb.writeln(s.content);
      if (s.bulletPoints.isNotEmpty) {
        sb.writeln();
        for (var b in s.bulletPoints) {
          sb.writeln('- $b');
        }
      }
      sb.writeln();
    }

    sb.writeln('### References');
    for (int i = 0; i < refs.length; i++) {
      sb.writeln('${i + 1}. ${refs[i]}');
    }

    return sb.toString();
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
