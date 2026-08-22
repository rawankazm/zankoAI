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

enum AssistantMode {
  seminar, // سیمینار (PowerPoint / Canva 8 Slides)
  report,  // ڕاپۆرت (Academic Report 10 Sections / Word & PDF)
}

enum SeminarLanguage {
  kurdishSorani('کوردی (سۆرانی)', 'ku', '☀️'),
  kurdishBadini('کوردی (بادینی)', 'badini', '🏔️'),
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
  words4000, // ئێجگار درێژ و زۆرترین وردەکاری (٤٠٠٠+ وشە)
  words3000, // زۆر درێژ و تێروتەسەل (٣٠٠٠+ وشە)
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
  AssistantMode _selectedMode = AssistantMode.seminar;
  SeminarLanguage _selectedLanguage = SeminarLanguage.kurdishSorani;
  ReportWritingStyle _selectedReportStyle = ReportWritingStyle.academicComprehensive;
  ReportLengthLevel _selectedReportLength = ReportLengthLevel.words4000;

  // Controllers
  final TextEditingController _topicSearchController = TextEditingController();
  final TextEditingController _seminarNotesController = TextEditingController();

  // Report Specific Controllers
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _supervisorNameController = TextEditingController();
  final TextEditingController _universityController = TextEditingController(text: 'زانکۆی سەڵاحەدین - هەولێر');
  final TextEditingController _reportDeptController = TextEditingController(text: 'کۆلێژی زانست - بەشی تەکنەلۆجیای زانیاری');
  final TextEditingController _academicYearController = TextEditingController(text: '2025 - 2026');
  final TextEditingController _reportNotesController = TextEditingController();

  // University Logo Bytes
  Uint8List? _universityLogoBytes;
  String? _universityLogoName;

  bool _isLoading = false;
  bool _isExportingPptx = false;
  bool _isExportingDocx = false;
  bool _isExportingPdf = false;
  bool _showReportAdvancedOptions = false;

  String? _generatedResult;
  String? _activeGeneratedTitle;
  List<SeminarTopicProposal> _suggestedTopics = [];

  // Slides State
  List<SlideModel> _parsedSlides = [];
  int _selectedSlideIndex = 0;

  // Report State
  AcademicReportModel? _parsedReport;
  int _selectedReportPageIndex = 0;

  @override
  void dispose() {
    _topicSearchController.dispose();
    _seminarNotesController.dispose();
    _studentNameController.dispose();
    _supervisorNameController.dispose();
    _universityController.dispose();
    _reportDeptController.dispose();
    _academicYearController.dispose();
    _reportNotesController.dispose();
    super.dispose();
  }

  /// Returns Calibri for Kurdish/Arabic and Times New Roman for English
  String? get _currentFontFamily =>
      _selectedLanguage == SeminarLanguage.english ? 'Times New Roman' : 'Calibri';

  bool get _isEnglish => _selectedLanguage == SeminarLanguage.english;
  bool get _isArabic => _selectedLanguage == SeminarLanguage.arabic;
  bool get _isBadini => _selectedLanguage == SeminarLanguage.kurdishBadini;

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
        _showSnackBar(_isEnglish
            ? '✅ University logo loaded successfully'
            : (_isBadini ? '✅ لۆگۆیێ زانکۆیێ ب سەرکەفتیانە هاتە دیاریکرن' : '✅ لۆگۆی زانکۆ بە سەرکەوتوویی دیاریکرا'));
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

  // ─── Step 1: Suggest Related Topics ────────────────────────────────────────
  Future<void> _suggestRelatedTopics() async {
    final query = _topicSearchController.text.trim();
    if (query.isEmpty) {
      _showSnackBar(_isEnglish
          ? 'Please enter your topic or academic field'
          : (_isArabic
              ? 'يرجى كتابة الموضوع أو التخصص العلمي'
              : (_isBadini
                  ? 'تکایە ناڤێ بابەتی یان پشکا زانستی بنڤێسە'
                  : 'تکایە ناوی بابەت یان بەشی زانستی بنووسە')));
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

    final String langInstruction;
    if (_isEnglish) {
      langInstruction = 'CRITICAL: Write all topic titles, summaries, and research questions 100% strictly in formal English.';
    } else if (_isArabic) {
      langInstruction = 'مهم جداً: اكتب جميع العناوين والمحاور والملخصات والأسئلة البحثية بنسبة ١٠٠٪ باللغة العربية الفصحى الأكاديمية الرصينة.';
    } else if (_isBadini) {
      langInstruction = 'زۆر گرنگە: هەموو ناونیشان، کورتەیا بیرۆکەیێ و پرسیارێن زانستی ١٠٠٪ ب زمانی کوردی بادینی (شێوەزارێ بەهدینی/بادینی یێ پاراو و ئەکادیمی وەک: ئەڤە، دێ، شێن، دڤێت، چێکرن، زانستی، و پەیڤێن بادینی) بنڤێسە.';
    } else {
      langInstruction = 'زۆر گرنگە: هەموو ناونیشان، کورتە، و پرسیارە زانستییەکان ١٠٠٪ بە زمانی کوردی سۆرانی پاراو و ئەکادیمی بنووسە.';
    }

    final randomSeed = DateTime.now().millisecondsSinceEpoch % 10000;
    final modeLabel = _selectedMode == AssistantMode.seminar ? 'presentation seminar' : 'academic research report';

    final prompt = '''
You are a senior university professor, academic research director, and thesis committee chair.
Suggest 6 to 8 highly creative, diverse, innovative, and attractive $modeLabel topic proposals strictly related to: "$query".
$langInstruction

CRITICAL MANDATE FOR VARIETY & FRESHNESS (Seed: $randomSeed):
- Provide diverse, distinct angles (e.g. Theoretical Foundations, Cutting-edge Applied Innovations, Emerging Breakthroughs, Practical Case Studies, Policy & Ethical Dimensions, and System Optimization).
- DO NOT provide generic, repetitive, or cliché topics. Make every single topic compelling, academic, and specific to "$query".

Format each topic strictly as:
### 📌 Topic [Number]: [Specific Professional Topic Title]
- **Secondary**: [English Title if main is Kurdish/Arabic, or subtitle]
- **💡 Summary & Significance**: [Clear, comprehensive summary explaining the scientific value, real-world relevance, and depth of this topic]
- **❓ Research Question**: [The core scientific or practical question investigated by this topic]
''';

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final response = await aiService.askTeacher(prompt, [], isVip: true);
      await _incrementUsage();

      final bool isInvalid = response.trim().isEmpty ||
          response.contains('دەستپێبکەرەوە') ||
          response.contains('⚠️') ||
          response.contains('Error') ||
          response.contains('blocked');

      final content = !isInvalid ? response : _generateFallbackTopicsText(query);
      _processTopicResponse(content);
    } catch (e) {
      final fallback = _generateFallbackTopicsText(query);
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
    final blocks = rawText.split(RegExp(r'###\s+.*(Topic|بابەت|بابەتی|بابەتێ|الموضوع)\s*'));

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
        } else if (line.contains('کورتە') || line.contains('پوختە') || line.contains('بیرۆکە') || line.contains('گرنگی') || line.contains('Summary') || line.contains('الملخص') || line.contains('الأهمية')) {
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
          summary: summary.isNotEmpty ? summary : (_isEnglish ? 'Comprehensive academic investigation.' : (_isBadini ? 'ڤەکۆلین و دووڤچوونەکا زانستی یا سەردەم.' : 'توێژینەوە و لێکۆڵینەوەیەکی زانستیی سەردەمیانە.')),
          researchQuestion: researchQ.isNotEmpty ? researchQ : (_isEnglish ? 'How does this solve core research challenges?' : (_isBadini ? 'چەوا ئەڤ بابەتە دکاریت ئاریشەیێن زانستی چارەسەر بکەت؟' : 'چۆن ئەم بابەتە دەتوانێت کێشە زانستییەکان چارەسەر بکات؟')),
        ));
      }
    }

    if (list.isEmpty) {
      list.addAll(_getFallbackTopicProposals(_topicSearchController.text.trim()));
    }

    return list;
  }

  // ─── Step 2: Generate Full Seminar Presentation (8 Slides) ────────────────
  Future<void> _generateFullSeminar(String topicTitle) async {
    final canProceed = await _checkVipLimit();
    if (!canProceed || !mounted) return;

    setState(() {
      _activeGeneratedTitle = topicTitle;
      _isLoading = true;
      _generatedResult = null;
      _parsedSlides = [];
      _parsedReport = null;
      _selectedSlideIndex = 0;
    });

    final String langPrompt;
    if (_isEnglish) {
      langPrompt = 'CRITICAL MANDATE: Write all 8 slides, slide titles, paragraphs, metrics, and speaker notes 100% strictly in English.';
    } else if (_isArabic) {
      langPrompt = 'مهم جداً: اكتب الشرائح الـ 8 والعناوين والشروحات والأرقام وملاحظات المتحدث بنسبة ١٠٠٪ باللغة العربية الفصحى الأكاديمية فقط.';
    } else if (_isBadini) {
      langPrompt = 'زۆر گرنگە: هەموو ٨ سلایدان، ناڤ و ناونیشان، پاراگراف، ئامار و پەیڤێن پێشکێشکەری ١٠٠٪ ب زمانی کوردی بادینی (بەهدینی پاراو) بنڤێسە.';
    } else {
      langPrompt = 'زۆر گرنگە: هەموو ٨ سلایدەکە، ناونیشانەکان، پاراگرافەکان، ئامار و وتاری پێشکەشکار ١٠٠٪ بە زمانی کوردی سۆرانی پاراو بنووسە.';
    }

    final customNotes = _seminarNotesController.text.trim();
    final customRequirements = customNotes.isNotEmpty
        ? '''
CRITICAL STUDENT CUSTOM REQUIREMENTS & FOCUS INSTRUCTIONS (HIGHEST PRIORITY):
The student specified the following specific focus areas, guidelines, or instructor notes:
"$customNotes"
You MUST strictly integrate, address, and highlight these exact points throughout the presentation.
'''
        : '';

    final prompt = '''
You are a premier presentation designer and university professor specialized in creating Canva-style modern academic presentations.
Write a full, ready-to-present, 8-slide seminar presentation strictly and exclusively about the selected topic: "$topicTitle".
$langPrompt

$customRequirements

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
      final response = await aiService.askTeacher(prompt, [], isVip: true);
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

  // ─── Step 3: Generate Academic Report ──────────────────────────────────────
  Future<void> _generateAcademicReport(String reportTitle) async {
    final canProceed = await _checkVipLimit();
    if (!canProceed || !mounted) return;

    if (reportTitle.isEmpty) {
      _showSnackBar(_isEnglish
          ? 'Please enter the report title'
          : (_isArabic
              ? 'يرجى إدخال عنوان التقرير الأكاديمي'
              : (_isBadini ? 'تکایە ناڤێ ڕاپۆرتێ بنڤێسە' : 'تکایە ناونیشانی سەرەکی ڕاپۆرت بنووسە')));
      return;
    }

    setState(() {
      _activeGeneratedTitle = reportTitle;
      _isLoading = true;
      _generatedResult = null;
      _parsedReport = null;
      _parsedSlides = [];
      _selectedReportPageIndex = 0;
    });

    final String langPrompt;
    if (_isEnglish) {
      langPrompt = 'CRITICAL MANDATE: Write all 10 numbered sections, Table of Contents, and 6 references 100% strictly in English.';
    } else if (_isArabic) {
      langPrompt = 'مهم جداً: اكتب كامل المحاور العشرة المرقمة وفهرس المحتويات والمراجع الستة بنسبة ١٠٠٪ باللغة العربية الفصحى الأكاديمية الرصينة الخالية تماماً من الأخطاء النحوية والإملائية.';
    } else if (_isBadini) {
      langPrompt = 'زۆر گرنگە: هەموو ١٠ تەوەرێن سەرەکی، پێڕستا ناڤەڕۆکێ و ٦ ژێدەرێن زانستی ب زمانی کوردیێ بادینی یێ ئەکادیمی و پاراو بنڤێسە. پیتێن (ڕ، ڵ، ۆ، ێ، ە، ڤ) ب دروستی بنڤێسە و ڕستەیان ب شێوازەکێ دەولەمەندێ زانستی دابڕێژە.';
    } else {
      langPrompt = 'زۆر گرنگە: هەموو ١٠ تەوەرە سەرەکییەکان، پێڕستی ناوەڕۆک و ٦ سەرچاوە زانستییەکان بە زمانی کوردیی سۆرانیی ئەکادیمیی پاراو و بە ڕێنووسێکی یەکگرتووی بێ خەوش و بێ هەڵەی ڕێزمانی بنووسە. پیتەکانی (ڕ، ڵ، ۆ، ێ، ە) بە دروستی بنووسە و ڕستەکان بە شێوازی دەوڵەمەندی زانستی دابڕێژە.';
    }

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
- References: Must be formatted in standard APA 7th Edition or IEEE format including credible authors/institutions, publication year, comprehensive publication title, journal/publisher, and DOI/URL.
''';

    final customNotes = _reportNotesController.text.trim();
    final customRequirements = customNotes.isNotEmpty
        ? '''
CRITICAL STUDENT CUSTOM REQUIREMENTS & FOCUS INSTRUCTIONS (HIGHEST PRIORITY):
The student specified the following specific focus areas, sub-topics, guidelines, or instructor notes:
"$customNotes"
You MUST strictly integrate, address, and thoroughly analyze these exact requirements within the 10 report sections.
'''
        : '';

    final prompt = '''
You are a distinguished university professor, research scientist, and academic author.
Write a comprehensive, publication-grade, exceptionally thorough 8-page academic research report specifically and exclusively about the topic: "$reportTitle".
$langPrompt

$customRequirements

$formalToneMandate

$stylePrompt

$depthPrompt

CRITICAL REPORT STRUCTURE:
You MUST structure the report into exactly 10 comprehensive, logically progressive academic sections strictly customized to "$reportTitle":

### Table of Contents
1. [Section 1 Title - Introduction & Scientific Scope]
2. [Section 2 Title - Foundational Theories, Concepts & Background]
3. [Section 3 Title - Core Architecture, Key Components & Structures]
4. [Section 4 Title - Operational Mechanisms, Methodologies & Workflows]
5. [Section 5 Title - In-Depth Scientific Analysis & Functional Dynamics]
6. [Section 6 Title - Practical Implementations, Contemporary Innovations & Case Studies]
7. [Section 7 Title - Comparative Matrix, Performance Metrics & System Integration]
8. [Section 8 Title - Challenges, Technical/Ethical Limitations & Risk Management]
9. [Section 9 Title - Future Horizons, Emerging Trends & Next-Generation Paradigms]
10. [Section 10 Title - Academic Findings, Strategic Recommendations & Comprehensive Conclusion]

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
      final response = await aiService.askTeacher(prompt, [], isVip: true);
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
      _showSnackBar(_isEnglish ? 'Please generate the report first' : 'تکایە سەرەتا ڕاپۆرتەکە دروست بکە');
      return;
    }

    final allowed = await _checkVipExportLimit('Word (.docx)');
    if (!allowed || !mounted) return;

    setState(() => _isExportingDocx = true);
    try {
      await DocxGeneratorService.exportAndShareDocx(_parsedReport!);
      _showSnackBar(_isEnglish
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
      _showSnackBar(_isEnglish ? 'Please generate the report first' : 'تکایە سەرەتا ڕاپۆرتەکە دروست بکە');
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      await ReportPdfGeneratorService.exportAndSharePdf(_parsedReport!);
      _showSnackBar(_isEnglish
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
      _showSnackBar(_isEnglish ? 'Please generate the seminar with AI first' : 'تکایە سەرەتا سیمینارەکە بە AI دروست بکە');
      return;
    }

    final allowed = await _checkVipExportLimit('PowerPoint (.pptx)');
    if (!allowed || !mounted) return;

    setState(() => _isExportingPptx = true);

    try {
      String title = _activeGeneratedTitle ?? (_topicSearchController.text.trim().isNotEmpty
          ? _topicSearchController.text.trim()
          : 'Seminar Presentation');

      await PptxGeneratorService.exportAndSharePptx(
        rawContent: _generatedResult!,
        title: title,
        languageCode: _selectedLanguage.code,
      );

      _showSnackBar(_isEnglish
          ? '✅ PowerPoint (.pptx) file created successfully'
          : '✅ فایلی PowerPoint (.pptx) بە سەرکەوتوویی دروستکرا');
    } catch (e) {
      _showSnackBar('⚠️ Error creating PPT file: $e');
    } finally {
      if (mounted) setState(() => _isExportingPptx = false);
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
                          _isEnglish ? 'Import to Canva 🎨' : 'هاوردەکردن بۆ Canva 🎨',
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
              _buildCanvaStep(_isEnglish
                  ? '1. Download the PowerPoint (.pptx) file with the button below.'
                  : '١. فایلی PowerPoint (.pptx) دابگرە بە دوگمەی خوارەوە.'),
              _buildCanvaStep(_isEnglish
                  ? '2. Open Canva App or go to canva.com.'
                  : '٢. ئەپی Canva یان ماڵپەڕی canva.com بکەرەوە.'),
              _buildCanvaStep(_isEnglish
                  ? '3. Click on "Upload / Drag & Drop" at the top.'
                  : '٣. لە بەشی سەرەوە کلیک لەسەر «Upload / Drag and Drop» بکە.'),
              _buildCanvaStep(_isEnglish
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
                    _isEnglish ? 'Download PPTX for Canva 🚀' : 'داگرتنی فایلی PPTX بۆ Canva 🚀',
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
      _showSnackBar(_isEnglish ? '✅ Text copied to clipboard' : '✅ دەقەکە کۆپی کرا');
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

  // ─── Trigger generation directly from topic proposal or input ─────────────
  void _handleTopicSelection(String topicTitle) {
    if (_selectedMode == AssistantMode.seminar) {
      _generateFullSeminar(topicTitle);
    } else {
      _generateAcademicReport(topicTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLtr = _isEnglish;

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
              Icon(
                _selectedMode == AssistantMode.seminar ? CupertinoIcons.paintbrush_fill : CupertinoIcons.doc_text_fill,
                color: _selectedMode == AssistantMode.seminar ? const Color(0xFF7D2AE8) : const Color(0xFFF97316),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedMode == AssistantMode.seminar
                    ? (_isEnglish ? 'Academic Seminar (8 Slides)' : (_isBadini ? 'سیمینارا ئەکادیمی (٨ سلاید)' : (_isArabic ? 'السيمينار الأكاديمي (٨ شرائح)' : 'سیمیناری ئەکادیمی (٨ سلاید)')))
                    : (_isEnglish ? 'Academic Report (Word & PDF)' : (_isBadini ? 'ڕاپۆرتا ئەکادیمی (Word و PDF)' : (_isArabic ? 'التقرير الأكاديمي (Word و PDF)' : 'ڕاپۆرتی ئەکادیمی (Word و PDF)'))),
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
              // ── 1. Top Two-Mode Switch (سیمینار ، ڕاپۆرت) ─────────────────
              _buildTwoModeHeader(isDark),

              const SizedBox(height: 16),

              // ── 2. Language Selector List (سۆرانی، بادینی، ئینگلیزی، عەرەبی)
              _buildLanguageListSelector(isDark),

              const SizedBox(height: 16),

              // ── VIP Promotion Banner (If not VIP) ────────────────────────
              if (!(Provider.of<AuthService>(context, listen: false).currentUser?.isVip ?? false))
                _buildVipBanner(isDark),

              // ── 3. Step 1: Topic Input & Related Topics Discovery Card ───
              _buildTopicDiscoveryCard(isDark),

              const SizedBox(height: 24),

              // ── Step 2: Suggested Related Topics (چەند بابەتێکی پەیوەندیدار) ──
              if (_suggestedTopics.isNotEmpty && _parsedSlides.isEmpty && _parsedReport == null) ...[
                _buildSuggestedTopicsSection(isDark),
                const SizedBox(height: 20),
              ],

              // ── Step 3: Full Seminar Output (8 Slides + Canva + PPTX) ────
              if (_selectedMode == AssistantMode.seminar && _parsedSlides.isNotEmpty) ...[
                _buildSlidesViewerCard(isDark),
                const SizedBox(height: 24),
              ],

              // ── Step 3: Full Report Output (12-Page Live View + DOCX + PDF)
              if (_selectedMode == AssistantMode.report && _parsedReport != null) ...[
                _buildReportViewerCard(isDark),
                const SizedBox(height: 24),
              ],

              // Raw Fallback if text exists without parsed models
              if (_generatedResult != null && _suggestedTopics.isEmpty && _parsedSlides.isEmpty && _parsedReport == null) ...[
                _buildRawResultCard(isDark),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── 1. Two-Mode Switcher (سیمینار ، ڕاپۆرت) ─────────────────────────────
  Widget _buildTwoModeHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Mode 1: Seminar
          _buildModeButton(
            mode: AssistantMode.seminar,
            icon: CupertinoIcons.paintbrush_fill,
            label: _isEnglish ? '📊 Seminar (8 Slides)' : (_isBadini ? '📊 سیمینار (٨ سلاید)' : (_isArabic ? '📊 سيمينار (٨ شرائح)' : '📊 سیمینار (٨ سلاید)')),
            activeColor: const Color(0xFF7D2AE8), // Canva / Seminar Purple
            isDark: isDark,
          ),
          const SizedBox(width: 6),
          // Mode 2: Report
          _buildModeButton(
            mode: AssistantMode.report,
            icon: CupertinoIcons.doc_text_fill,
            label: _isEnglish ? '📑 Report (Word & PDF)' : (_isBadini ? '📑 ڕاپۆرت (Word و PDF)' : (_isArabic ? '📑 تقرير (Word و PDF)' : '📑 ڕاپۆرت (Word و PDF)')),
            activeColor: const Color(0xFFF97316), // Academic Orange / Blue
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required AssistantMode mode,
    required IconData icon,
    required String label,
    required Color activeColor,
    required bool isDark,
  }) {
    final isSel = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedMode != mode) {
            setState(() {
              _selectedMode = mode;
              _generatedResult = null;
              _suggestedTopics = [];
              _parsedSlides = [];
              _parsedReport = null;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSel ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSel ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _currentFontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isSel ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 2. Language Selector List (وەکو لیستێک) ───────────────────────────────
  Widget _buildLanguageListSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: isDark ? [] : ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.globe, color: ZankoColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                _isEnglish ? 'Select Language:' : (_isArabic ? 'لغة المحتوى:' : (_isBadini ? 'زمانێ بابەت و داڕشتنێ:' : 'زمانی بابەت و داڕشتن:')),
                style: TextStyle(
                  fontFamily: _currentFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[200] : ZankoColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 4-item horizontal or grid list
          Row(
            children: SeminarLanguage.values.map((lang) {
              final isSel = _selectedLanguage == lang;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedLanguage = lang),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSel ? ZankoColors.accent : (isDark ? Colors.white10 : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? ZankoColors.accent : (isDark ? Colors.white12 : Colors.grey[300]!),
                        width: isSel ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lang.flag, style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 3),
                        Text(
                          lang.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: lang == SeminarLanguage.english ? null : 'DroidKufi',
                            fontSize: 10.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                            color: isSel ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textSecondary),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── VIP Banner ────────────────────────────────────────────────────────────
  Widget _buildVipBanner(bool isDark) {
    return GestureDetector(
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
    );
  }

  // ─── 3. Topic Discovery Card (Input & Suggest Topics) ──────────────────────
  Widget _buildTopicDiscoveryCard(bool isDark) {
    final isSeminar = _selectedMode == AssistantMode.seminar;
    final themeColor = isSeminar ? const Color(0xFF7D2AE8) : const Color(0xFFF97316);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColor.withValues(alpha: 0.35), width: 1.5),
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
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSeminar ? CupertinoIcons.lightbulb_fill : CupertinoIcons.doc_text_search,
                  color: themeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEnglish
                          ? (isSeminar ? 'Step 1: Enter Topic / Academic Field' : 'Step 1: Enter Report Topic / Field')
                          : (_isArabic
                              ? (isSeminar ? 'الخطوة الأولى: موضوع أو تخصص السيمينار' : 'الخطوة الأولى: موضوع أو تخصص التقرير')
                              : (_isBadini
                                  ? (isSeminar ? 'هەنگاڤا ئێکێ: ناڤێ بابەت یان پشکا زانستی' : 'هەنگاڤا ئێکێ: ناڤێ بابەتێ ڕاپۆرتێ')
                                  : (isSeminar ? 'هەنگاوی یەکەم: ناونیشانی بابەت یان بەشی زانستی' : 'هەنگاوی یەکەم: ناونیشانی بابەت یان بواری ڕاپۆرت'))),
                      style: TextStyle(fontFamily: _currentFontFamily, fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _isEnglish
                          ? 'AI will suggest related topics tailored to your input'
                          : (_isArabic
                              ? 'سيقترح الذكاء الاصطناعي موضوعات مرتبطة ومتميزة'
                              : (_isBadini
                                  ? 'ژیرییا دەستکرد چەندین بابەتێن گرێدای پێشنیار دکەت'
                                  : 'AI چەند بابەتێکی پەیوەندیدار بەو بوارەت پێ دەدات تا هەڵیبژێریت')),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Topic Input
          TextField(
            controller: _topicSearchController,
            style: TextStyle(fontFamily: _currentFontFamily),
            decoration: InputDecoration(
              hintText: _isEnglish
                  ? 'e.g. Artificial Intelligence, Medicine, Cyber Law, Accounting...'
                  : (_isArabic
                      ? 'مثال: الذكاء الاصطناعي، الطب البشري، القانون السيبراني، المحاسبة...'
                      : (_isBadini
                          ? 'نموونە: ژیرییا دەستکرد، پزیشکی، یاسا، ژمێریاری، ئەندازیاری...'
                          : 'نموونە: ژیریی دەستکرد، پزیشکی، یاسا، ژمێریاری، ئەندازیاری...')),
              hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 13),
              prefixIcon: Icon(CupertinoIcons.search, color: themeColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),

          const SizedBox(height: 12),

          // Seminar or Report custom notes (expandable/direct)
          if (isSeminar) ...[
            TextField(
              controller: _seminarNotesController,
              minLines: 1,
              maxLines: 2,
              style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13),
              decoration: InputDecoration(
                hintText: _isEnglish
                    ? 'Optional: Student focus or instructor requirements...'
                    : (_isArabic
                        ? 'اختياري: ملاحظات أو متطلبات خاصة من الأستاذ...'
                        : (_isBadini
                            ? 'ئارەزوومەندانە: داواکاری یان تێبینییا تایبەت بۆ سێمینارێ...'
                            : 'ئارەزوومەندانە: داواکاری یان تێبینی تایبەت بۆ سێمینارەکە...')),
                hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                prefixIcon: Icon(CupertinoIcons.text_quote, color: themeColor, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
              ),
            ),
          ] else ...[
            // Report specific toggle for details
            InkWell(
              onTap: () => setState(() => _showReportAdvancedOptions = !_showReportAdvancedOptions),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.person_crop_circle_badge_checkmark, color: themeColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isEnglish
                            ? 'Report Cover & Author Details (Student, Supervisor, University)'
                            : (_isBadini
                                ? 'زانیاریێن بەرگی (ناڤێ قوتابی، سەرپەرشتیار، زانکۆ و لۆگۆ)'
                                : 'ڕێکخستنی زانیارییەکانی بەرگ (ناوی قوتابی، مامۆستا، زانکۆ و لۆگۆ)'),
                        style: TextStyle(
                          fontFamily: _currentFontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : const Color(0xFF9A3412),
                        ),
                      ),
                    ),
                    Icon(
                      _showReportAdvancedOptions ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                      color: themeColor,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            if (_showReportAdvancedOptions) ...[
              const SizedBox(height: 12),
              _buildReportDetailsSection(isDark, themeColor),
            ],
          ],

          const SizedBox(height: 16),

          // Primary Button: Suggest Related Topics
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _suggestRelatedTopics,
              icon: _isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
              label: Text(
                _isLoading
                    ? (_isEnglish ? 'Analyzing and discovering topics...' : (_isBadini ? 'لێگەڕیانا بابەتێن گرێدای...' : 'دۆزینەوەی بابەتە پەیوەندیدارەکان...'))
                    : (_isEnglish
                        ? 'Suggest Related Topics 💡'
                        : (_isArabic
                            ? 'اقتراح الموضوعات المرتبطة 💡'
                            : (_isBadini
                                ? 'پێشنیارکرنا بابەتێن پەیوەندیدار 💡'
                                : 'پێشنیارکردنی بابەتە پەیوەندیدارەکان 💡'))),
                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),

          // Secondary Quick Option: Direct Generate using exact typed text
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      final q = _topicSearchController.text.trim();
                      if (q.isEmpty) {
                        _showSnackBar(_isEnglish ? 'Please enter a topic title first' : 'تکایە سەرەتا ناونیشانی بابەت بنووسە');
                        return;
                      }
                      _handleTopicSelection(q);
                    },
              icon: Icon(CupertinoIcons.play_circle_fill, size: 15, color: themeColor),
              label: Text(
                _isEnglish
                    ? 'Or generate directly with this exact title ⚡'
                    : (_isBadini ? 'یان ڕاستەوخۆ ب ڤێ ناڤونیشانێ چێکە ⚡' : 'یان ڕاستەوخۆ بەم ناونیشانە دروستی بکە ⚡'),
                style: TextStyle(fontFamily: _currentFontFamily, fontSize: 11.5, fontWeight: FontWeight.w600, color: themeColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Report Details Sub-form ───────────────────────────────────────────────
  Widget _buildReportDetailsSection(bool isDark, Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student Name
        Text(
          _isEnglish ? 'Student Name(s) / Team:' : (_isBadini ? 'ناڤێ قوتابی یان تیمێ:' : 'ناوی قوتابی یان گرووپ:'),
          style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _studentNameController,
          style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12.5),
          decoration: InputDecoration(
            hintText: _isEnglish ? 'e.g. John Doe, Sarah Smith...' : 'نموونە: ئاراس علی، سارا محمد...',
            hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
            prefixIcon: Icon(CupertinoIcons.person_2_fill, color: themeColor, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
          ),
        ),
        const SizedBox(height: 10),

        // Supervisor
        Text(
          _isEnglish ? 'Academic Supervisor:' : (_isBadini ? 'ناڤێ مامۆستایێ سەرپەرشتیار:' : 'ناوی مامۆستای سەرپەرشتیار:'),
          style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _supervisorNameController,
          style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12.5),
          decoration: InputDecoration(
            hintText: _isEnglish ? 'e.g. Dr. Alan Smith' : 'نموونە: د. نەبەز عومەر / پ.ی.د. ئاراس...',
            hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
            prefixIcon: Icon(CupertinoIcons.person_badge_plus_fill, color: themeColor, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
          ),
        ),
        const SizedBox(height: 10),

        // University & Dept
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isEnglish ? 'University:' : 'ناوی زانکۆ:', style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _universityController,
                    style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'زانکۆی سەڵاحەدین...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isEnglish ? 'Department:' : 'کۆلێژ و بەش:', style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _reportDeptController,
                    style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'کۆلێژی زانست...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // University Logo Picker
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: themeColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              if (_universityLogoBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_universityLogoBytes!, width: 36, height: 36, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _universityLogoName ?? 'Logo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _removeUniversityLogo,
                  icon: const Icon(CupertinoIcons.trash_fill, color: Colors.red, size: 16),
                ),
              ] else ...[
                Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: themeColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEnglish ? 'University Logo (Optional)' : 'لۆگۆی زانکۆ بۆ سەر بەرگی ڕاپۆرت',
                    style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                  ),
                ),
                OutlinedButton(
                  onPressed: _pickUniversityLogo,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    side: BorderSide(color: themeColor),
                  ),
                  child: Text(_isEnglish ? 'Upload' : 'دیاریکردن', style: TextStyle(fontSize: 11, color: themeColor)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Report Writing Style & Volume
        Text(
          _isEnglish ? 'Writing Style & Depth:' : 'شێوازی نووسین و ئاستی درێژی:',
          style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedReportStyle = ReportWritingStyle.academicComprehensive),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: _selectedReportStyle == ReportWritingStyle.academicComprehensive
                        ? themeColor.withValues(alpha: 0.15)
                        : (isDark ? Colors.white10 : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedReportStyle == ReportWritingStyle.academicComprehensive
                          ? themeColor
                          : (isDark ? Colors.white12 : Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    _isEnglish ? '📚 Prose' : '📚 پەڕەگرافی ئەکادیمی',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _currentFontFamily,
                      fontSize: 11,
                      fontWeight: _selectedReportStyle == ReportWritingStyle.academicComprehensive ? FontWeight.bold : FontWeight.normal,
                      color: _selectedReportStyle == ReportWritingStyle.academicComprehensive ? themeColor : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedReportStyle = ReportWritingStyle.balancedStandard),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: _selectedReportStyle == ReportWritingStyle.balancedStandard
                        ? themeColor.withValues(alpha: 0.15)
                        : (isDark ? Colors.white10 : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedReportStyle == ReportWritingStyle.balancedStandard
                          ? themeColor
                          : (isDark ? Colors.white12 : Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    _isEnglish ? '⚖️ Balanced' : '⚖️ هاوسەنگ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _currentFontFamily,
                      fontSize: 11,
                      fontWeight: _selectedReportStyle == ReportWritingStyle.balancedStandard ? FontWeight.bold : FontWeight.normal,
                      color: _selectedReportStyle == ReportWritingStyle.balancedStandard ? themeColor : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedReportStyle = ReportWritingStyle.bulletStructured),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: _selectedReportStyle == ReportWritingStyle.bulletStructured
                        ? themeColor.withValues(alpha: 0.15)
                        : (isDark ? Colors.white10 : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedReportStyle == ReportWritingStyle.bulletStructured
                          ? themeColor
                          : (isDark ? Colors.white12 : Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    _isEnglish ? '📑 Structured' : '📑 خاڵبەندی',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _currentFontFamily,
                      fontSize: 11,
                      fontWeight: _selectedReportStyle == ReportWritingStyle.bulletStructured ? FontWeight.bold : FontWeight.normal,
                      color: _selectedReportStyle == ReportWritingStyle.bulletStructured ? themeColor : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildLengthChoiceCard('🔥 4000+', ReportLengthLevel.words4000, themeColor, isDark),
            const SizedBox(width: 6),
            _buildLengthChoiceCard('⭐ 3000+', ReportLengthLevel.words3000, themeColor, isDark),
            const SizedBox(width: 6),
            _buildLengthChoiceCard('🌟 2000+', ReportLengthLevel.words2000, themeColor, isDark),
            const SizedBox(width: 6),
            _buildLengthChoiceCard('📖 Standard', ReportLengthLevel.standard, themeColor, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildLengthChoiceCard(String label, ReportLengthLevel level, Color themeColor, bool isDark) {
    final isSel = _selectedReportLength == level;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedReportLength = level),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? themeColor.withValues(alpha: 0.15) : (isDark ? Colors.white10 : Colors.grey[100]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSel ? themeColor : (isDark ? Colors.white12 : Colors.grey[300]!),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 10.5,
              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              color: isSel ? themeColor : null,
            ),
          ),
        ),
      ),
    );
  }

  // ─── 4. Suggested Related Topics Section ───────────────────────────────────
  Widget _buildSuggestedTopicsSection(bool isDark) {
    final isSeminar = _selectedMode == AssistantMode.seminar;
    final themeColor = isSeminar ? const Color(0xFF7D2AE8) : const Color(0xFFF97316);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.square_grid_2x2_fill, color: themeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isEnglish
                      ? 'Suggested Related Topics (Choose one to create):'
                      : (_isArabic
                          ? 'الموضوعات المقترحة (اختر موضوعاً للبدء):'
                          : (_isBadini
                              ? 'بابەتێن پێشنیارکری (ئێکێ هەلبژێرە بۆ چێکرنێ):'
                              : 'بابەتە پێشنیارکراوەکان (یەکێکیان هەڵبژێرە بۆ دروستکردن):')),
                  style: TextStyle(
                    fontFamily: _currentFontFamily,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._suggestedTopics.map((topic) => _buildTopicProposalCard(topic, isDark, themeColor)),
      ],
    );
  }

  Widget _buildTopicProposalCard(SeminarTopicProposal topic, bool isDark, Color themeColor) {
    final isSeminar = _selectedMode == AssistantMode.seminar;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1.3),
        boxShadow: isDark ? [] : ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _isEnglish ? 'Topic ${topic.index}' : (_isBadini ? 'بابەتێ ${topic.index}' : 'بابەتی ${topic.index}'),
                  style: TextStyle(fontFamily: _currentFontFamily, color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  topic.titleKurdish,
                  style: TextStyle(
                    fontFamily: _currentFontFamily,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (topic.titleEnglish.isNotEmpty && !_isEnglish) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Text(
                topic.titleEnglish,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                ),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('❓ ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    topic.researchQuestion,
                    style: TextStyle(
                      fontFamily: _currentFontFamily,
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? const Color(0xFFA5B4FC) : themeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Direct Generate Button for the chosen topic
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _handleTopicSelection(topic.titleKurdish),
              icon: Icon(
                isSeminar ? CupertinoIcons.play_fill : CupertinoIcons.doc_text_fill,
                color: Colors.white,
                size: 16,
              ),
              label: Text(
                isSeminar
                    ? (_isEnglish ? 'Generate 8 Slides Seminar 🚀' : (_isBadini ? 'چێکرنا سیمینارێ (٨ سلاید) 🚀' : 'دروستکردنی سیمیناری ٨ سلاید 🚀'))
                    : (_isEnglish ? 'Generate Academic Report 📑' : (_isBadini ? 'چێکرنا ڕاپۆرتا ئەکادیمی 📑' : 'دروستکردنی ڕاپۆرتی ئەکادیمی 📑')),
                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. Canva & PPTX 8 Slides Viewer Component ─────────────────────────────
  Widget _buildSlidesViewerCard(bool isDark) {
    final currentSlide = _parsedSlides.isNotEmpty && _selectedSlideIndex < _parsedSlides.length
        ? _parsedSlides[_selectedSlideIndex]
        : null;

    final titleForImage = _activeGeneratedTitle ?? _topicSearchController.text.trim();
    final imgUrl = currentSlide?.imageUrl ??
        PptxGeneratorService.getSlideSpecificImageUrl(
          titleForImage,
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
                    _isEnglish
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
                        _isEnglish ? 'Slide ${i + 1}' : 'سلایدی ${i + 1}',
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
                                    _isEnglish
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
                                        _isEnglish
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
                      _isEnglish ? '🎨 Open in Canva' : '🎨 کردنەوە لە Canva',
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
                          ? (_isEnglish ? 'Creating...' : 'دروستکردن...')
                          : (_isEnglish ? '📥 Download PPTX' : '📥 داگرتنی PPTX'),
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

          // Return to suggested topics button
          if (_suggestedTopics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _parsedSlides = [];
                    _generatedResult = null;
                  });
                },
                icon: const Icon(CupertinoIcons.arrow_left_circle, size: 16),
                label: Text(
                  _isEnglish ? 'Back to suggested topics' : 'گەڕانەوە بۆ لیستی بابەتە پێشنیارکراوەکان',
                  style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 6. Academic Report Viewer & Exporter ──────────────────────────────────
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
          // Header Row
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
                    _isEnglish
                        ? 'Academic Report (${_parsedReport!.pages.length} Pages)'
                        : 'ڕاپۆرتی ئەکادیمی (${_parsedReport!.pages.length} پەڕە)',
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

          // Horizontal Page Switcher
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
                        _isEnglish ? 'Page ${i + 1}' : 'پەڕەی ${i + 1}',
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

          // Active Page Content Display
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
                        color: const Color(0xFFC00000), // Crimson Red
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isEnglish
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

                // Page 1: Cover Page
                if (currentPage.pageType == 'cover') ...[
                  _buildCoverPageView(isDark),
                ] else if (currentPage.pageType == 'toc') ...[
                  // Page 2: Table of Contents
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        currentPage.pageTitle,
                        style: TextStyle(
                          fontFamily: _currentFontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: const Color(0xFFC00000),
                        ),
                      ),
                    ),
                  ),
                  ...currentPage.bulletPoints.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Text('🔹 ', style: TextStyle(color: Color(0xFFC00000), fontSize: 13)),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontFamily: _currentFontFamily,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ] else if (currentPage.pageType == 'references') ...[
                  // Page 8: References
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        currentPage.pageTitle,
                        style: TextStyle(
                          fontFamily: _currentFontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: const Color(0xFFC00000),
                        ),
                      ),
                    ),
                  ),
                  ...currentPage.bulletPoints.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final refText = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$idx. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Expanded(
                            child: Text(
                              refText,
                              style: TextStyle(
                                fontFamily: _currentFontFamily,
                                fontSize: 12.5,
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
                  // Content Sections
                  if (currentPage.sections.isNotEmpty) ...[
                    ...currentPage.sections.map((sec) => Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${sec.sectionNumber}. ${sec.title}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: _currentFontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                  color: const Color(0xFFC00000),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (sec.content.isNotEmpty)
                                Text(
                                  sec.content,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: _currentFontFamily,
                                    fontSize: 13,
                                    height: 1.6,
                                    color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                                  ),
                                ),
                              if (sec.bulletPoints.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...sec.bulletPoints.map((bullet) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('• ', style: TextStyle(color: Color(0xFFC00000), fontSize: 15, fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              bullet,
                                              style: TextStyle(
                                                fontFamily: _currentFontFamily,
                                                fontSize: 12.5,
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

                    // Diagram
                    if (currentPage.imageUrl != null && currentPage.imageUrl!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 6, bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 170,
                                width: double.infinity,
                                child: Image.network(
                                  currentPage.imageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CupertinoActivityIndicator()),
                                  errorBuilder: (ctx, err, stack) => Container(height: 120, color: Colors.grey[900], child: const Center(child: Icon(CupertinoIcons.photo, size: 40, color: Colors.grey))),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                child: Text(
                                  _isEnglish
                                      ? 'Figure (${currentPage.pageNumber - 2}): ${currentPage.pageTitle}'
                                      : 'شێوەی زانستی (${currentPage.pageNumber - 2}): ${currentPage.pageTitle}',
                                  style: TextStyle(fontFamily: _currentFontFamily, fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFC00000)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Download Word & PDF
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
                          ? (_isEnglish ? 'Creating...' : 'دروستکردن...')
                          : (_isEnglish ? '📄 Download Word' : '📄 داگرتنی Word'),
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
                          ? (_isEnglish ? 'Creating...' : 'دروستکردن...')
                          : (_isEnglish ? '📑 Download PDF' : '📑 داگرتنی PDF'),
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

          // Return to suggested topics button
          if (_suggestedTopics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _parsedReport = null;
                    _generatedResult = null;
                  });
                },
                icon: const Icon(CupertinoIcons.arrow_left_circle, size: 16),
                label: Text(
                  _isEnglish ? 'Back to suggested topics' : 'گەڕانەوە بۆ لیستی بابەتە پێشنیارکراوەکان',
                  style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoverPageView(bool isDark) {
    final isKurdishOrArabic = !_isEnglish;
    final ministryLine1 = _isEnglish
        ? 'Ministry of higher education'
        : (_isArabic
            ? 'وزارة التعليم العالي والبحث العلمي'
            : (_isBadini ? 'وەزارەتا خوێندنا باڵا و ڤەکۆلینێن زانستی' : 'وەزارەتی خوێندنی باڵا و توێژینەوەی زانستی'));

    final ministryLine2 = _isEnglish ? 'And science research' : '';

    final reportAboutLabel = _isEnglish
        ? 'Report about :'
        : (_isArabic ? 'تقرير حول :' : (_isBadini ? 'ڕاپۆرت ل دۆر :' : 'ڕاپۆرت لەبارەی :'));

    final preparedLabel = _isEnglish
        ? 'Prepared by :'
        : (_isArabic ? 'إعداد :' : (_isBadini ? 'ئامادەکرن ژ لایێ :' : 'ئامادەکردنی :'));

    final supervisorLabel = _isEnglish
        ? 'supervisor :'
        : (_isArabic ? 'بإشراف :' : (_isBadini ? 'ب سەرپەرشتیا :' : 'بەسەرپەرشتیی :'));

    final stageText = _parsedReport!.academicYear.isNotEmpty
        ? _parsedReport!.academicYear
        : (_isEnglish ? 'Stage : One' : (_isBadini ? 'قۆناغا : ئێکێ' : 'قۆناغی : یەکەم'));

    final studentList = _parsedReport!.studentName
        .split(RegExp(r'[\n\r,،]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isKurdishOrArabic) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ministryLine1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      if (ministryLine2.isNotEmpty) Text(ministryLine2, style: const TextStyle(fontSize: 12)),
                      Text(_parsedReport!.universityName, style: const TextStyle(fontSize: 12)),
                      Text(_parsedReport!.departmentName, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                      Text(stageText, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                ),
                _buildLogoWidget(),
              ] else ...[
                _buildLogoWidget(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(ministryLine1, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(_parsedReport!.universityName, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
                      Text(_parsedReport!.departmentName, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                      Text(stageText, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Column(
                children: [
                  Text(reportAboutLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFC00000))),
                  const SizedBox(height: 8),
                  Text(
                    _parsedReport!.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFC00000)),
                  ),
                ],
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isKurdishOrArabic) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preparedLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (studentList.isEmpty)
                        Text(_parsedReport!.studentName, style: const TextStyle(fontSize: 12.5))
                      else
                        ...studentList.map((s) => Text(s, style: const TextStyle(fontSize: 12.5))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(supervisorLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(_parsedReport!.supervisorName, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supervisorLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(_parsedReport!.supervisorName, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(preparedLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (studentList.isEmpty)
                        Text(_parsedReport!.studentName, style: const TextStyle(fontSize: 12.5))
                      else
                        ...studentList.map((s) => Text(s, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5))),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              _parsedReport!.academicYear.isNotEmpty ? _parsedReport!.academicYear : '2024-2025',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFC00000)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoWidget() {
    return _universityLogoBytes != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(_universityLogoBytes!, width: 56, height: 56, fit: BoxFit.cover),
          )
        : Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFC00000).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC00000).withValues(alpha: 0.3)),
            ),
            child: const Center(child: Text('🎓', style: TextStyle(fontSize: 24))),
          );
  }

  // ─── Raw Result Fallback Card ──────────────────────────────────────────────
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
                    _isEnglish ? 'Results' : 'ئەنجامەکان',
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

  // ─── Fallback Topics Pool ──────────────────────────────────────────────────
  String _generateFallbackTopicsText(String dept) {
    final safeDept = dept.trim().isEmpty ? 'زانست و تەکنۆلۆژیا' : dept.trim();
    final dLower = safeDept.toLowerCase();

    List<Map<String, String>> pool = [];

    if (dLower.contains('تەندروست') || dLower.contains('پزیشک') || dLower.contains('تاقیگە') || dLower.contains('دەرمان') || dLower.contains('med') || dLower.contains('health') || dLower.contains('nurs') || dLower.contains('pharma') || dLower.contains('طب') || dLower.contains('صح')) {
      pool = [
        {
          'ku': 'کاریگەریی نانۆتەکنۆلۆژیا لە دەستنیشانکردن و چارەسەری نەخۆشییە شێرپەنجەییەکان',
          'badini': 'کارتێکرنا نانۆتەکنۆلۆژیایێ د دەستنیشانکرن و چارەسەرکرنا نەخۆشیێن شێرپەنجەیێ دا',
          'en': 'Nanotechnology Applications in Oncology Diagnosis and Targeted Therapy',
          'sum': 'لێکۆڵینەوە لەسەر بەکارهێنانی تەنۆلکە نانۆییەکان بۆ گەیاندنی دەرمان بە خانە تووشبووەکان بەبێ زیانگەیاندن بە خانە ساغەکان.',
          'q': 'چۆن نانۆپارتیکڵەکان دەتوانن ڕێژەی کاریگەریی چارەسەری کیمیایی بەرز بکەنەوە؟',
        },
        {
          'ku': 'ڕۆڵی ژیریی دەستکرد لە شیکاریی وێنەی پزیشکی و تیشکناسی (Radiology)',
          'badini': 'ڕۆلێ ژیرییا دەستکرد د شیکاریا وێنەیێن پزیشکی و تیشکێ دا (Radiology)',
          'en': 'Artificial Intelligence in Medical Image Processing and Radiology',
          'sum': 'هەڵسەنگاندنی ئەلگۆریتمەکانی بینینی کۆمپیوتەری بۆ دەستنیشانکردنی زووەوەختی وەرەم و شکانە وردەکان بە وردبینی ٩٨٪.',
          'q': 'تا چەند مۆدێلە قووڵەکان دەتوانن یارمەتیدەری پزیشکانی تیشک بن لە کەمکردنەوەی هەڵەکاندا؟',
        },
        {
          'ku': 'بەرگری دژەبەکتریایی (Antibiotic Resistance) و بەکارهێنانی چارەسەری بەکتریۆفەیج',
          'badini': 'بەرگرییا دژەبەکتریایی (Antibiotic Resistance) و بکارئینانا چارەسەرییا بەکتریۆفەیج',
          'en': 'Bacterial Resistance to Antibiotics and Bacteriophage Therapy',
          'sum': 'شیکاریی مەترسییەکانی بڵاوبوونەوەی سوپەربەکتریای بەرگریکار و چارەسەرە نوێیە بایۆلۆجییەکان.',
          'q': 'ئایا چارەسەری بەکتریۆفەیج دەتوانێت جێگرەوەی دژەبەکتریا باوەکان بێت؟',
        },
        {
          'ku': 'کاریگەریی مایکڕۆبایۆمی ڕیخۆڵە لەسەر نەخۆشییە دەماری و دەروونییەکان (Gut-Brain Axis)',
          'badini': 'کارتێکرنا مایکڕۆبایۆما ڕیڤیکان ل سەر نەخۆشیێن دەماری و دەروونی (Gut-Brain Axis)',
          'en': 'Gut Microbiome and the Gut-Brain Axis in Neurological Disorders',
          'sum': 'لێکۆڵینەوە لە پەیوەندی نێوان بەکتریای سوودبەخشی هەرس و باری دەروونی و نەخۆشییەکانی پارکینسۆن و خەمۆکی.',
          'q': 'میکانیزمە بایۆکیمیاییەکانی پەیوەندی نێوان کۆئەندامی هەرس و مێشک چین؟',
        },
      ];
    } else {
      pool = [
        {
          'ku': 'کاریگەریی مۆدێلە گەورەکانی زمان (LLMs) لەسەر شۆڕشی زانستی و فێربوونی ئەکادیمی',
          'badini': 'کارتێکرنا مۆدێلێن مەزنێن زمان (LLMs) ل سەر شۆڕشا زانستی و فێربوونا ئەکادیمی',
          'en': 'Large Language Models (LLMs) Transforming Scientific Research & Academic Discovery',
          'sum': 'شیکاریی چۆنیەتی بەکارهێنانی ژیریی دەستکرد لە خێراکردنی لێکۆڵینەوەی تاقیگەیی و شیکاری داتا ئاڵۆزەکان.',
          'q': 'چۆن ژیریی دەستکرد دەتوانێت کاتی توێژینەوەی زانستی لە مانگەوە بۆ چەند خولەکێک کەم بکاتەوە؟',
        },
        {
          'ku': 'ئەمنییەتی سایبەری بە مۆدێلی Zero-Trust لە تۆڕە هەورییە نێودەوڵەتییەکاندا',
          'badini': 'ئەمنییەتا سایبەری ب مۆدێلا Zero-Trust د تۆڕێن عەورێن نێڤدەولەتی دا',
          'en': 'Zero-Trust Architecture and Cloud Security Infrastructure in Modern Networks',
          'sum': 'لێکۆڵینەوە لە پرۆتۆکۆلەکانی پاراستنی داتابەیس و جێبەجێکردنی شفرەکردنی قووڵ لە هەموو لایەنەکانەوە.',
          'q': 'مۆدێلی Zero-Trust چۆن بە تەواوی ڕێگری لە دزەکردنی هاککەرەکان دەکات بۆ ناو تۆڕی ناوەکی؟',
        },
        {
          'ku': 'کۆمپیوتەری کوانتەمی (Quantum Computing) و کاریگەریی لەسەر شکاندنی شفرە کلاسیکییەکان',
          'badini': 'کۆمپیوتەرا کوانتەمی (Quantum Computing) و کارتێکرنا وێ ل سەر شکاندنا شفرەیێن کەڤن',
          'en': 'Quantum Computing Advancements and the Post-Quantum Cryptography Era',
          'sum': 'شیکاریی توانای پرۆسێسەرە کوانتەمییەکان لە شیکارکردنی ئەلگۆریتمە قورسەکان و پێویستی شفرەی نوێ.',
          'q': 'بۆچی دەبێت سیستمە ئەمنییەکان خۆیان بۆ سەردەمی پۆست-کوانتەم ئامادە بکەن؟',
        },
        {
          'ku': 'سیستەمی بلۆکچەین لە بەڕێوەبردنی داتای ئەکادیمی و سەلماندنی بڕوانامە زانکۆییەکان',
          'badini': 'سیستەمێ بلۆکچەین د بڕێڤەبرنا داتایێن ئەکادیمی و باوەرپێکرنا باوەرنامەیێن زانکۆیێ دا',
          'en': 'Blockchain Technology for Verifiable Academic Credentials and Research Integrity',
          'sum': 'شیکاریی بەکارهێنانی تۆماری نەگۆڕ (Immutable Ledger) بۆ نەهێشتنی تەزویر و ساختەکاری بڕوانامە.',
          'q': 'بلۆکچەین چۆن دەتوانێت ١٠٠٪ ساختەکاری لە بڕوانامە ئەکادیمییەکاندا بنبڕ بکات؟',
        },
      ];
    }

    pool.shuffle();
    final selected = pool.take(5).toList();

    final sb = StringBuffer();
    for (int i = 0; i < selected.length; i++) {
      final item = selected[i];
      final titleStr = _isBadini ? (item['badini'] ?? item['ku']!) : item['ku']!;
      if (_isEnglish) {
        sb.writeln('### 📌 Topic ${i + 1}: ${item['en']}');
        sb.writeln('- **Secondary**: $titleStr');
        sb.writeln('- **💡 Summary & Significance**: Comprehensive academic investigation evaluating modern paradigms in $safeDept.');
        sb.writeln('- **❓ Research Question**: How does this framework optimize operational efficiency in $safeDept?');
      } else if (_isArabic) {
        sb.writeln('### 📌 الموضوع ${i + 1}: $titleStr');
        sb.writeln('- **العنوان الإنجليزي**: ${item['en']}');
        sb.writeln('- **💡 الملخص والأهمية**: ${item['sum']}');
        sb.writeln('- **❓ السؤال البحثي**: ${item['q']}');
      } else if (_isBadini) {
        sb.writeln('### 📌 بابەتێ ${i + 1}: $titleStr');
        sb.writeln('- **ئینگلیزی**: ${item['en']}');
        sb.writeln('- **💡 پوختەیا بیرۆکەیێ و گرنگی**: ${item['sum']}');
        sb.writeln('- **❓ پرسیارا سەرەکییا ڤەکۆلینێ**: ${item['q']}');
      } else {
        sb.writeln('### 📌 بابەتی ${i + 1}: $titleStr');
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

  // ─── Fallback 8 Slide Seminar ──────────────────────────────────────────────
  String _generateFallback8SlideSeminar(String title) {
    if (_isEnglish) {
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

    final isBad = _isBadini;

    return '''
# 📊 ${isBad ? 'سیمینارا تەمام یا ٨ سلایدان' : 'سیمیناری تەواوی ٨ سلایدی پاوەرپۆینت'} بۆ "$title" (Canva Style)
### 🔹 سلایدی ١: ناساندنی گشتی و ناونیشانی سەرەکی
- ${isBad ? 'ڤەکۆلینەکا زانستی یا سەردەم ل دۆر شێوازێن مۆدێرن د بواری $title دا.' : 'لێکۆڵینەوەیەکی زانستیی سەردەمیانە لەسەر شێوازە مۆدێرنەکانی توێژینەوە لە بواری $title.'}
- بەکارهێنانی مۆدێلە پێشکەوتووەکان بۆ شیکردنەوەی داتا و بەرزکردنەوەی کارایی زانستی.
- تیشکخستنە سەر گرنگیی پراکتیکی و تیۆریی بابەتەکە لە ناوەندە ئەکادیمییەکاندا.
- 🎙️ **تێبینی پێشکەشکار**: "${isBad ? 'سڵاڤ مامۆستایێن هێژا، ب خێر هاتن بۆ ڤێ سیمینارێ ل سەر ناڤونیشانێ' : 'سڵاو و ڕێز مامۆستایانی بەڕێز، بەخێربێن بۆ ئەم سیمینارە لەسەر ناونیشانی'} ($title)."
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
- 🎙️ **تێبینی پێشکەشکار**: "${isBad ? 'سوپاس بۆ گوهداریا هەوە، نوکە دەرگەهـ ڤەکرییە بۆ پرسیارێن هەوە.' : 'سوپاس بۆ گوێگرتنتان، ئێستا بە خۆشحاڵییەوە دەرگا واڵایە بۆ پرسیارەکانتان.'}"
''';
  }

  // ─── Fallback Academic Report (8 Pages Standard) ───────────────────────────
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
}
