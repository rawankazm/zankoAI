import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/docx_generator_service.dart';
import '../../services/pptx_generator_service.dart';
import '../../theme.dart';
import '../payment/vip_upgrade_sheet.dart';

enum AssistantMode {
  seminar, // سیمینار (PowerPoint 8 Slides)
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

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
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

  /// Modern Noto Naskh Arabic font for in-app Kurdish & academic display
  String? get _currentFontFamily => 'NotoNaskhArabic';

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
          response.contains('blocked') ||
          response.contains('بەڕێوەبردنی یادگە') ||
          !response.contains('###');

      final content = !isInvalid ? response : _generateFallbackTopicsText(query);
      _processTopicResponse(content, query);
    } catch (e) {
      final fallback = _generateFallbackTopicsText(query);
      _processTopicResponse(fallback, query);
    }
  }

  void _processTopicResponse(String rawText, String query) {
    var topics = _parseTopicProposals(rawText);
    if (topics.length < 2) {
      topics = _getFallbackTopicProposals(query);
    }
    setState(() {
      _generatedResult = rawText;
      _suggestedTopics = topics;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          380,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  List<SeminarTopicProposal> _parseTopicProposals(String rawText) {
    final List<SeminarTopicProposal> list = [];

    // Split on ### (with any optional emoji/symbols), ##, or **Topic ...**
    final blocks = rawText.split(RegExp(r'###\s*[^a-zA-Z0-9\u0600-\u06FF\n\r]*\s*(?:Topic|بابەت|بابەتی|بابەتێ|الموضوع|\d+)\s*[\d+٠-٩\-]*\s*[:\.\-]|(?:\*\*Topic\s*\d+:?\*\*)', caseSensitive: false));

    int count = 1;
    for (var b in blocks) {
      final text = b.trim();
      if (text.isEmpty) continue;

      final lines = text.split('\n');
      String titleMain = lines.first.replaceAll(RegExp(r'^[:\-–\d️⃣\d\.\s]+'), '').replaceAll('**', '').replaceAll('###', '').trim();
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

      if (titleMain.isNotEmpty && titleMain.length > 3) {
        list.add(SeminarTopicProposal(
          index: count++,
          titleKurdish: titleMain,
          titleEnglish: titleSecondary.isNotEmpty ? titleSecondary : 'Academic Presentation & Research Report',
          summary: summary.isNotEmpty ? summary : (_isEnglish ? 'Comprehensive academic investigation.' : (_isBadini ? 'ڤەکۆلین و دووڤچوونەکا زانستی یا سەردەم.' : 'توێژینەوە و لێکۆڵینەوەیەکی زانستیی سەردەمیانە.')),
          researchQuestion: researchQ.isNotEmpty ? researchQ : (_isEnglish ? 'How does this solve core research challenges?' : (_isBadini ? 'چەوا ئەڤ بابەتە دکاریت ئاریشەیێن زانستی چارەسەر بکەت؟' : 'چۆن ئەم بابەتە دەتوانێت کێشە زانستییەکان چارەسەر بکات؟')),
        ));
      }
    }

    // Ensure at least 5-6 topics are returned
    if (list.length < 5) {
      final fallbacks = _getFallbackTopicProposals(_topicSearchController.text.trim());
      for (var fb in fallbacks) {
        if (!list.any((t) => t.titleKurdish == fb.titleKurdish)) {
          list.add(SeminarTopicProposal(
            index: list.length + 1,
            titleKurdish: fb.titleKurdish,
            titleEnglish: fb.titleEnglish,
            summary: fb.summary,
            researchQuestion: fb.researchQuestion,
          ));
        }
        if (list.length >= 6) break;
      }
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
You are a senior university professor, academic supervisor, and master presentation designer.
Create an exhaustive, highly intellectual, university-grade 8-slide academic PowerPoint presentation strictly on: "$topicTitle".
$langPrompt

$customRequirements

MANDATORY SCHOLARLY QUALITY & VERTICAL LAYOUT MANDATE:
1. The presentation MUST contain exactly 8 sequentially structured slides.
2. The language MUST be pure, sophisticated academic prose (زانستی، پاراو، دەوڵەمەند، بە زاراوەی ئەکادیمیی قووڵ و ڕێکخراو).
3. For EACH SLIDE, write 4 to 5 substantial, well-articulated academic bullet points with bold leading terms (e.g. - **پێناسە و گرنگیی تیۆری**: شرۆڤەی ورد...). Each point must be detailed and informative (25-35 words per bullet) so that the slide content is rich, well-proportioned, and fills the slide vertically without leaving empty spaces at the bottom.
4. Include quantitative metrics, benchmark percentages (٪), and empirical facts throughout the points.
5. For EACH SLIDE, provide a distinct visual theme tag: 🖼️ **Visual Focus: [Specific Visual Theme]**
6. For EACH SLIDE, provide an insightful presenter delivery advice note: 🎙️ **تێبینی و ڕێنمایی پێشکەشکار: [Presentation Advice]**

SLIDE STRUCTURE:
- Slide 1: Main Title, Research Thesis, Scope & Presenter Identification
- Slide 2: Theoretical Foundations, Historical Evolution & Academic Context
- Slide 3: Core Problem Statement, Practical Challenges & Research Motivation
- Slide 4: Strategic Research Objectives, Hypotheses & Target Outcomes
- Slide 5: Methodology, Analytical Framework & Implementation Tools
- Slide 6: Empirical Findings, Quantitative Metrics (٪), and Comparative Benchmarks
- Slide 7: Critical Discussion, Practical Impact & Strategic Recommendations
- Slide 8: Scientific Conclusion, Summary of Contributions, APA 7th Academic References
''';

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final response = await aiService.askTeacher(prompt, [], isVip: true);
      await _incrementUsage();

      final bool isInvalid = response.trim().isEmpty ||
          response.contains('دەستپێبکەرەوە') ||
          response.contains('⚠️') ||
          response.contains('Error') ||
          response.contains('blocked') ||
          response.contains('بەڕێوەبردنی یادگە') ||
          (!response.contains('### 🔹') && !response.contains('Slide'));

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
          response.contains('blocked') ||
          response.contains('بەڕێوەبردنی یادگە') ||
          !response.contains('###');

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
    if (isVip || kDebugMode) return true;

    final prefs = await SharedPreferences.getInstance();
    final exportCount = prefs.getInt('academic_export_count') ?? 0;

    if (exportCount >= 5) {
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



  // ─── Export PPTX (.pptx) ───────────────────────────────────────────────────
  Future<void> _exportPptx() async {
    if (_parsedSlides.isEmpty && (_generatedResult == null || _generatedResult!.isEmpty)) {
      _showSnackBar(_isEnglish ? 'Please generate the seminar with AI first' : 'تکایە سەرەتا سیمینارەکە بە AI دروست بکە');
      return;
    }

    final allowed = await _checkVipExportLimit('PowerPoint (.pptx)');
    if (!allowed || !mounted) return;

    setState(() => _isExportingPptx = true);

    try {
      String title = _activeGeneratedTitle ?? (_topicSearchController.text.trim().isNotEmpty
          ? _topicSearchController.text.trim()
          : (_parsedSlides.isNotEmpty ? _parsedSlides.first.title : 'Seminar Presentation'));

      await PptxGeneratorService.exportAndSharePptx(
        slides: _parsedSlides,
        rawContent: _generatedResult,
        title: title,
        languageCode: _selectedLanguage.code,
        studentName: _studentNameController.text.trim(),
        supervisorName: _supervisorNameController.text.trim(),
        university: _universityController.text.trim(),
        department: _reportDeptController.text.trim(),
        logoBytes: _universityLogoBytes,
      );

      _showSnackBar(_isEnglish
          ? '✅ PowerPoint (.pptx) file created successfully'
          : '✅ فایلی PowerPoint (.pptx) بە سەرکەوتوویی دروستکرا');
    } catch (e, stack) {
      debugPrint('Error exporting PPTX: $e\n$stack');
      _showSnackBar('⚠️ هەڵە لە دروستکردنی فایلی پاوەرپۆینت: $e');
    } finally {
      if (mounted) setState(() => _isExportingPptx = false);
    }
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
    if (isVip || kDebugMode) return true;

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
          controller: _scrollController,
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

              // ── Step 3: Full Seminar Output (8 Slides + PowerPoint PPTX) ────
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
            icon: CupertinoIcons.tv_fill,
            label: _isEnglish ? '📊 Seminar (PowerPoint 8 Slides)' : (_isBadini ? '📊 سیمینار (٨ سلایدێن پاوەرپۆینت)' : (_isArabic ? '📊 سيمينار (بوربوينت ٨ شرائح)' : '📊 سیمینار (٨ سلایدی پاوەرپۆینت)')),
            activeColor: const Color(0xFF2563EB), // PowerPoint / Academic Blue
            isDark: isDark,
          ),
          const SizedBox(width: 6),
          // Mode 2: Report
          _buildModeButton(
            mode: AssistantMode.report,
            icon: CupertinoIcons.doc_text_fill,
            label: _isEnglish ? '📑 Report (Word & PDF)' : (_isBadini ? '📑 ڕاپۆرت (Word و PDF)' : (_isArabic ? '📑 تقرير (Word و PDF)' : '📑 ڕاپۆرت (Word و PDF)')),
            activeColor: const Color(0xFFF97316), // Academic Orange
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
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _suggestRelatedTopics(),
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

          // Seminar custom notes (optional)
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
            const SizedBox(height: 10),
          ],

          // Author & Cover Details (Student, Supervisor, University) for both Seminar and Report
          InkWell(
            onTap: () => setState(() => _showReportAdvancedOptions = !_showReportAdvancedOptions),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : (isSeminar ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.person_crop_circle_badge_checkmark, color: themeColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSeminar
                          ? (_isEnglish
                              ? 'Slide 1 Cover & Author Details (Student, Supervisor, University)'
                              : (_isBadini
                                  ? 'زانیاریێن بەرگێ سلایدا ١ (ناڤێ قوتابی، سەرپەرشتیار، زانکۆ)'
                                  : 'زانیارییەکانی بەرگی سلایدی ١ (ناوی قوتابی، مامۆستا، زانکۆ)'))
                          : (_isEnglish
                              ? 'Report Cover & Author Details (Student, Supervisor, University)'
                              : (_isBadini
                                  ? 'زانیاریێن بەرگی (ناڤێ قوتابی، سەرپەرشتیار، زانکۆ و لۆگۆ)'
                                  : 'ڕێکخستنی زانیارییەکانی بەرگ (ناوی قوتابی، مامۆستا، زانکۆ و لۆگۆ)')),
                      style: TextStyle(
                        fontFamily: _currentFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : (isSeminar ? const Color(0xFF1E40AF) : const Color(0xFF9A3412)),
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

        // Academic Year
        Text(
          _isEnglish ? 'Academic Year / Session:' : (_isBadini ? 'ساڵا خوێندنێ یا ئەکادیمی:' : 'ساڵی خوێندنی ئەکادیمی:'),
          style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _academicYearController,
          style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12.5),
          decoration: InputDecoration(
            hintText: '2025 - 2026',
            hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
            prefixIcon: Icon(CupertinoIcons.calendar, color: themeColor, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
          ),
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

  // ─── 5. PowerPoint PPTX 8 Slides Viewer Component ─────────────────────────────
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
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35), width: 1.5),
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
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.tv_fill, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEnglish
                        ? 'PowerPoint Presentation (${_parsedSlides.length} Slides)'
                        : 'پرێزێنتەیشنی پاوەرپۆینت (${_parsedSlides.length} سلاید)',
                    style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _isExportingPptx ? null : _exportPptx,
                    icon: _isExportingPptx
                        ? const SizedBox(width: 18, height: 18, child: CupertinoActivityIndicator())
                        : const Icon(CupertinoIcons.arrow_down_doc_fill, color: Color(0xFF2563EB), size: 20),
                    tooltip: 'PowerPoint (.pptx)',
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
                          ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF06B6D4)])
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
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 160,
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
                          height: 160,
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
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _isEnglish
                                  ? 'Slide ${_selectedSlideIndex + 1} of ${_parsedSlides.length} • HD'
                                  : 'سلایدی ${_selectedSlideIndex + 1} لە ${_parsedSlides.length} • HD',
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
                        // ─── SLIDE 1 (COVER PAGE): PURE LAYOUT (LOGO, TITLE, STUDENT, SUPERVISOR) ───
                        if (_selectedSlideIndex == 0) ...[
                          // University Logo / Emblem Header
                          Center(
                            child: Column(
                              children: [
                                if (_universityLogoBytes != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      _universityLogoBytes!,
                                      height: 52,
                                      width: 52,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    _universityController.text.trim().isNotEmpty
                                        ? '🏛️ ${_universityController.text.trim()}'
                                        : (_isEnglish ? '🏛️ Academic University Presentation' : '🏛️ زانکۆی سەڵاحەدین - هەولێر'),
                                    style: TextStyle(
                                      fontFamily: _currentFontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Main Topic Title
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  currentSlide.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: _currentFontFamily,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (_reportDeptController.text.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _reportDeptController.text.trim(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: _currentFontFamily,
                                      fontSize: 12.5,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Author (Student) & Supervisor Double Cards
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isEnglish ? '👨‍🎓 Prepared by:' : (_isBadini ? '👨‍🎓 ئامادەکرن ژ لایێ:' : '👨‍🎓 ئامادەکردنی:'),
                                        style: TextStyle(fontFamily: _currentFontFamily, fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _studentNameController.text.trim().isNotEmpty
                                            ? _studentNameController.text.trim()
                                            : (_isEnglish ? 'Student / Team' : 'ناوی قوتابی / تیم'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isEnglish ? '👨‍🏫 Supervised by:' : (_isBadini ? '👨‍🏫 سەرپەرشتیار:' : '👨‍🏫 سەرپەرشتیاری:'),
                                        style: TextStyle(fontFamily: _currentFontFamily, fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _supervisorNameController.text.trim().isNotEmpty
                                            ? _supervisorNameController.text.trim()
                                            : (_isEnglish ? 'Supervisor' : 'مامۆستای سەرپەرشتیار'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (currentSlide.bulletPoints.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              _isEnglish ? '📌 Slide 1 Academic Focus & Overview:' : '📌 تەوەر و خاڵە سەرەکییەکانی ناساندن:',
                              style: TextStyle(
                                fontFamily: _currentFontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[300] : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...currentSlide.bulletPoints.asMap().entries.map((entry) {
                              final idx = entry.key + 1;
                              final text = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$idx',
                                          style: TextStyle(
                                            fontFamily: _currentFontFamily,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        text,
                                        style: TextStyle(
                                          fontFamily: _currentFontFamily,
                                          fontSize: 13,
                                          height: 1.45,
                                          color: isDark ? Colors.grey[200] : ZankoColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ] else ...[
                          // ─── SLIDES 2 TO 8: CONTENT BULLET POINTS & RESEARCH DATA ───
                          if (currentSlide.visualPrompt != null && currentSlide.visualPrompt!.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: Color(0xFF2563EB), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isEnglish
                                          ? '🎯 Slide Visual Focus: ${currentSlide.visualPrompt!}'
                                          : '🎯 تیشکۆ و وێنەی سەرەکی: ${currentSlide.visualPrompt!}',
                                      style: TextStyle(
                                        fontFamily: _currentFontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey[200] : const Color(0xFF1E3A8A),
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
                                    ? const Color(0xFF2563EB).withValues(alpha: 0.06)
                                    : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isMetric
                                      ? const Color(0xFF2563EB).withValues(alpha: 0.25)
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
                                      color: isMetric ? const Color(0xFF2563EB) : ZankoColors.accent.withValues(alpha: 0.15),
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
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Separate Presenter Guidance Card
            if (currentSlide.speakerNotes != null && currentSlide.speakerNotes!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(CupertinoIcons.lightbulb_fill, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEnglish
                                ? '💡 Presenter Advice & Delivery Tips:'
                                : (_isArabic ? '💡 نصائح وإرشادات للمتحدث أثناء العرض:' : '💡 ئامۆژگاری و ڕێنمایی بۆ پێشکەشکار:'),
                            style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            currentSlide.speakerNotes!,
                            style: TextStyle(
                              fontFamily: _currentFontFamily,
                              fontSize: 12.5,
                              height: 1.55,
                              color: isDark ? Colors.grey[300] : const Color(0xFF451A03),
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

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Primary Full-Width PowerPoint Download Action
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isExportingPptx ? null : _exportPptx,
              icon: _isExportingPptx
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.arrow_down_doc_fill, color: Colors.white, size: 20),
              label: Text(
                _isExportingPptx
                    ? (_isEnglish ? 'Creating Presentation...' : 'دروستکردنی فایلی پاوەرپۆینت...')
                    : (_isEnglish ? '📥 Download PowerPoint (.pptx)' : '📥 داگرتنی فایلی پاوەرپۆینت (.pptx)'),
                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB), // Royal Sapphire Blue
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
              ),
            ),
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
                          fontSize: 20,
                          color: Colors.black,
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
                            const Text('🔹 ', style: TextStyle(color: Colors.black, fontSize: 14)),
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
                  // Page 8: References (Size 20 Bold)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        currentPage.pageTitle,
                        style: TextStyle(
                          fontFamily: _currentFontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black,
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
                          Text('$idx. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                          Expanded(
                            child: Text(
                              refText,
                              style: TextStyle(
                                fontFamily: _currentFontFamily,
                                fontSize: 14,
                                height: 1.6,
                                color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  // Content Sections (Size 20 Bold Titles, Size 14 Regular Content)
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
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (sec.content.isNotEmpty)
                                Text(
                                  sec.content,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: _currentFontFamily,
                                    fontSize: 14,
                                    height: 1.65,
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
                                          const Text('• ', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              bullet,
                                              style: TextStyle(
                                                fontFamily: _currentFontFamily,
                                                fontSize: 14,
                                                height: 1.5,
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

          // Download Word (.docx) Full Width Primary Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isExportingDocx ? null : _exportDocx,
              icon: _isExportingDocx
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.doc_fill, color: Colors.white, size: 20),
              label: Text(
                _isExportingDocx
                    ? (_isEnglish ? 'Creating Word file...' : 'دروستکردنی فایلی وۆرد...')
                    : (_isEnglish ? '📄 Download Word Document (.docx)' : '📄 داگرتنی ڕاپۆرت بە فایلی وۆرد (.docx)'),
                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B579A), // Word Blue
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
            ),
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
    final ministryLine1 = _isEnglish
        ? 'Kurdistan Regional Government - Iraq'
        : (_isArabic
            ? 'حكومة إقليم كوردستان - العراق'
            : (_isBadini ? 'حکومەتا هەرێما کوردستانێ - عیراق' : 'حکومەتی هەرێمی کوردستان - عێراق'));

    final ministryLine2 = _isEnglish
        ? 'Ministry of Higher Education & Scientific Research'
        : (_isArabic
            ? 'وزارة التعليم العالي والبحث العلمي'
            : (_isBadini ? 'وەزارەتا خوێندنا باڵا و ڤەکۆلینێن زانستی' : 'وەزارەتی خوێندنی باڵا و توێژینەوەی زانستی'));

    final preparedLabel = _isEnglish
        ? 'Prepared by:'
        : (_isArabic ? 'ئامادەکردنی قوتابی:' : (_isBadini ? 'ئامادەکرن ژ لایێ قوتابی:' : 'ئامادەکردنی خوێندکار:'));

    final supervisorLabel = _isEnglish
        ? 'Supervised by:'
        : (_isArabic ? 'بإشراف الأستاذ:' : (_isBadini ? 'ب سەرپەرشتیا مامۆستای:' : 'بەسەرپەرشتیی مامۆستا:'));

    final academicYearLabel = _isEnglish
        ? 'Academic Year:'
        : (_isArabic ? 'العام الدراسي:' : (_isBadini ? 'ساڵا خوێندنا ئەکادیمی:' : 'ساڵی خوێندنی ئەکادیمی:'));

    final yearText = _parsedReport!.academicYear.isNotEmpty ? _parsedReport!.academicYear : '2025 - 2026';

    final studentList = _parsedReport!.studentName
        .split(RegExp(r'[\n\r,،]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 1. University Logo & Official Header ──
          _buildLogoWidget(),
          const SizedBox(height: 14),

          // Ministry Line 1
          Text(
            ministryLine1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 3),

          // Ministry Line 2
          Text(
            ministryLine2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          // University Name (Large, Bold, Solid Black)
          Text(
            _parsedReport!.universityName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          // Department Name (Bold, Black)
          if (_parsedReport!.departmentName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _parsedReport!.departmentName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _currentFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],

          const SizedBox(height: 14),
          // Clean Divider Line
          Container(
            width: 140,
            height: 1.5,
            color: const Color(0xFF0F172A),
          ),
          const SizedBox(height: 36),

          // ── 2. Report Main Title (Direct, Bold Black, Large) ──
          Text(
            DocxGeneratorService.cleanTopicTitle(_parsedReport!.title),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 50),

          // ── 3. Student & Supervisor Information (Positioned lower down) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prepared By (Student)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      preparedLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _currentFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (studentList.isEmpty)
                      Text(
                        _parsedReport!.studentName.isNotEmpty ? _parsedReport!.studentName : 'ناوی قوتابی',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: _currentFontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      )
                    else
                      ...studentList.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              s,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: _currentFontFamily,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          )),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Supervised By (Teacher)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      supervisorLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _currentFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _parsedReport!.supervisorName.isNotEmpty ? _parsedReport!.supervisorName : 'ناوی مامۆستا',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _currentFontFamily,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),

          // ── 4. Academic Year at Bottom ──
          Text(
            '$academicYearLabel $yearText',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _currentFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoWidget() {
    if (_universityLogoBytes != null && _universityLogoBytes!.isNotEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.memory(
            _universityLogoBytes!,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Official Academic Emblem Seal
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0F172A),
        border: Border.all(color: const Color(0xFF334155), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_rounded, color: Colors.white, size: 26),
            const SizedBox(height: 2),
            Text(
              'ZANKO',
              style: TextStyle(
                fontFamily: _currentFontFamily,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
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

    if (dLower.contains('مێژوو') || dLower.contains('کورد') || dLower.contains('شوێنەوار') || dLower.contains('شارستانی') || dLower.contains('hist') || dLower.contains('kurd')) {
      pool = [
        {
          'ku': 'شیکاریی بەڵگەنامە مێژووییەکانی $safeDept و کاریگەرییان لەسەر ناوچەکە',
          'badini': 'شیکاریا بەلگەنامەیێن مێژوویی یێن $safeDept و کارتێکرنا وان ل سەر دەڤەرێ',
          'en': 'Historical Documentation & Archival Analysis of $safeDept',
          'sum': 'لێکۆڵینەوەی قووڵی ئەکادیمی لەسەر سەرچاوە، بەڵگەنامە و دەستنووسە مێژووییەکانی پەیوەست بە $safeDept.',
          'q': 'سەرچاوە مێژووییەکان چۆن ڕاستیی ڕووداوە سەرەکییەکان دەسەلمێنن؟',
        },
        {
          'ku': 'قۆناغە وەرچەرخانە سیاسی و کەلتوورییەکانی $safeDept لە سەردەمی هاوچەرخدا',
          'badini': 'قۆناغێن وەرچەرخانا سیاسی و کەلتووری یێن $safeDept د چەرخێ نوی دا',
          'en': 'Socio-Political Evolutions and Cultural Dynamics in $safeDept',
          'sum': 'هەڵسەنگاندنی زانستی بۆ گۆڕانکارییە سیاسی، ئابووری و کۆمەڵایەتییەکان لە قۆناغە جیاوازەکاندا.',
          'q': 'کاریگەریی ئەم قۆناغانە لەسەر دروستبوونی شوناسی هاوچەرخ چی بووە؟',
        },
        {
          'ku': 'پێگەی جوگرافی و ستراتیجیی $safeDept و ململانێ نێودەوڵەتییەکان',
          'badini': 'پێگەهێ جوگرافی و ستراتیجی یێ $safeDept و ململانێیێن نێڤدەولەتی',
          'en': 'Geostrategic Significance and Regional Geopolitics of $safeDept',
          'sum': 'شیکاریی جیۆپۆلەتیکی و بایەخی ستراتیجیی ناوچەکە لە هاوکێشە نێودەوڵەتی و دیپلۆماسییەکاندا.',
          'q': 'چۆن پێگەی جوگرافی بووەتە هۆی سەرنجڕاکێشانی هێزە هەرێمییەکان؟',
        },
        {
          'ku': 'شوێنەوارە دێرینەکان و میراتی شارستانیی $safeDept',
          'badini': 'شوێنەوارێن کەڤن و میراتێ شارستانی یێ $safeDept',
          'en': 'Archaeological Heritage and Ancient Civilizations in $safeDept',
          'sum': 'پشکنینی پاشماوە شوێنەوارییەکان و بەڵگە زانستییەکان لەسەر دێرینی و پەرەسەندنی شارستانیەتەکە.',
          'q': 'شوێنەوارە دۆزراوەکان چۆن مێژووی ژیانی مرۆڤایەتی لە ناوچەکەدا ڕوون دەکەنەوە؟',
        },
        {
          'ku': 'ئاسۆی نوێ لە توێژینەوەی ئەکادیمی و میتۆدۆلۆجی سەبارەت بە $safeDept',
          'badini': 'ئاسۆیێن نوی د ڤەکۆلینێن ئەکادیمی و میتۆدۆلۆجی دا دەربارەی $safeDept',
          'en': 'Contemporary Historiographical Methodologies in Studying $safeDept',
          'sum': 'پەیڕەوکردنی میتۆدی زانستیی هاوچەرخ بۆ پێداچوونەوە و شیکاریی بەڵگەنامەیی دەربارەی $safeDept.',
          'q': 'میتۆدە نوێیەکان چۆن یارمەتیدەری شیکارییەکی بێلایەنانەن؟',
        },
      ];
    } else if (dLower.contains('تەندروست') || dLower.contains('پزیشک') || dLower.contains('تاقیگە') || dLower.contains('دەرمان') || dLower.contains('med') || dLower.contains('health') || dLower.contains('nurs') || dLower.contains('pharma') || dLower.contains('طب') || dLower.contains('صح')) {
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
          'ku': 'بنەما تیۆرییەکان، پێکهاتەی سەرەکی و چوارچێوەی زانستی لە «$safeDept»',
          'badini': 'بنەمایێن تیۆری، پێکهاتەیا سەرەکی و چوارچۆڤێ زانستی د «$safeDept» دا',
          'en': 'Theoretical Foundations and Advanced Frameworks in $safeDept',
          'sum': 'شیکاریی قووڵی بنەما تیۆرییەکان و شێوازەکانی پەرەپێدانی زانستی لە بواری $safeDept.',
          'q': 'چۆن ئەم چوارچێوەیە بەشداری لە پێشخستنی زانستیی ئەم بوارەدا دەکات؟',
        },
        {
          'ku': 'جێبەجێکردنی پراکتیکی، میتۆدۆلۆجیای سەردەمیانە و بەکارهێنان لە «$safeDept»',
          'badini': 'جێبەجێکرنا پراکتیکی، میتۆدۆلۆجییا سەردەم و بکارئینان د «$safeDept» دا',
          'en': 'Practical Methodologies and Contemporary Implementations in $safeDept',
          'sum': 'لێکۆڵینەوە لەسەر ئەزموونە پراکتیکییەکان و تەکنیکە نوێیەکانی جێبەجێکردن لە $safeDept.',
          'q': 'کەڵک و دەرئەنجامە پراکتیکییەکانی ئەم تەکنیکانە لەسەر زەمینەی واقیع چین؟',
        },
        {
          'ku': 'ئاستەنگە سەرەکییەکان، ڕەهەندە تەکنیکییەکان و چارەسەرە پێشنیارکراوەکان لە «$safeDept»',
          'badini': 'ئاریشەیێن سەرەکی، ڕەهەندێن تەکنیکی و چارەسەریێن پێشنیارکری د «$safeDept» دا',
          'en': 'Critical Challenges, Technical Dimensions & Mitigation Strategies in $safeDept',
          'sum': 'شیکاریی کێشە و ئاستەنگە ئەکادیمی و پراکتیکییەکان لەگەڵ پێشکەشکردنی چارەسەری زانستی.',
          'q': 'چۆن دەتوانرێت ئاستەنگە سەرەکییەکانی ئەم بوارە بە کەمترین تێچوو چارەسەر بکرێن؟',
        },
        {
          'ku': 'بەراوردکاریی سیستەمەکان، پێوەرەکانی کواڵیتی و کارایی لە «$safeDept»',
          'badini': 'بەراوردکرنا سیستەمان، پێوەرێن کواڵیتی و کاراییێ د «$safeDept» دا',
          'en': 'Comparative Paradigm, Quality Metrics and Efficiency in $safeDept',
          'sum': 'هەڵسەنگاندنی بەراوردکاری لە نێوان مۆدێلە جیاوازەکان بە بەکارهێنانی پێوەرە ستانداردەکان.',
          'q': 'کام مۆدێل بەرزترین ئاستی کارایی و وردبینی دەستەبەر دەکات؟',
        },
        {
          'ku': 'ئاسۆی داهاتوو، داهێنانە پێشکەوتووەکان و ئاراستەی نوێ لە «$safeDept»',
          'badini': 'ئاسۆیێن پاشەڕۆژێ، داهێنانێن پێشکەفتی و ئاراستەیێن نوی د «$safeDept» دا',
          'en': 'Future Horizons, Next-Generation Breakthroughs in $safeDept',
          'sum': 'لێکۆڵینەوە لەسەر ئاراستە و داهێنانە تازەکان کە داهاتووی ئەم بوارە دیاری دەکەن.',
          'q': 'داهاتووی ئەم بوارە بەرەو چ ئاراستەیەکی زانستی هەنگاو دەنێت؟',
        },
      ];
    }

    final sb = StringBuffer();
    for (int i = 0; i < pool.length; i++) {
      final item = pool[i];
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
    final safeDept = dept.trim().isEmpty ? 'زانست و تەکنۆلۆژیا' : dept.trim();
    final dLower = safeDept.toLowerCase();

    List<Map<String, String>> pool = [];

    if (dLower.contains('مێژوو') || dLower.contains('کورد') || dLower.contains('شوێنەوار') || dLower.contains('شارستانی') || dLower.contains('hist') || dLower.contains('kurd')) {
      pool = [
        {
          'ku': 'شیکاریی بەڵگەنامە مێژووییەکانی $safeDept و کاریگەرییان لەسەر ناوچەکە',
          'badini': 'شیکاریا بەلگەنامەیێن مێژوویی یێن $safeDept و کارتێکرنا وان ل سەر دەڤەرێ',
          'en': 'Historical Documentation & Archival Analysis of $safeDept',
          'sum': 'لێکۆڵینەوەی قووڵی ئەکادیمی لەسەر سەرچاوە، بەڵگەنامە و دەستنووسە مێژووییەکانی پەیوەست بە $safeDept.',
          'q': 'سەرچاوە مێژووییەکان چۆن ڕاستیی ڕووداوە سەرەکییەکان دەسەلمێنن؟',
        },
        {
          'ku': 'قۆناغە وەرچەرخانە سیاسی و کەلتوورییەکانی $safeDept لە سەردەمی هاوچەرخدا',
          'badini': 'قۆناغێن وەرچەرخانا سیاسی و کەلتووری یێن $safeDept د چەرخێ نوی دا',
          'en': 'Socio-Political Evolutions and Cultural Dynamics in $safeDept',
          'sum': 'هەڵسەنگاندنی زانستی بۆ گۆڕانکارییە سیاسی، ئابووری و کۆمەڵایەتییەکان لە قۆناغە جیاوازەکاندا.',
          'q': 'کاریگەریی ئەم قۆناغانە لەسەر دروستبوونی شوناسی هاوچەرخ چی بووە؟',
        },
        {
          'ku': 'پێگەی جوگرافی و ستراتیجیی $safeDept و ململانێ نێودەوڵەتییەکان',
          'badini': 'پێگەهێ جوگرافی و ستراتیجی یێ $safeDept و ململانێیێن نێڤدەولەتی',
          'en': 'Geostrategic Significance and Regional Geopolitics of $safeDept',
          'sum': 'شیکاریی جیۆپۆلەتیکی و بایەخی ستراتیجیی ناوچەکە لە هاوکێشە نێودەوڵەتی و دیپلۆماسییەکاندا.',
          'q': 'چۆن پێگەی جوگرافی بووەتە هۆی سەرنجڕاکێشانی هێزە هەرێمییەکان؟',
        },
        {
          'ku': 'شوێنەوارە دێرینەکان و میراتی شارستانیی $safeDept',
          'badini': 'شوێنەوارێن کەڤن و میراتێ شارستانی یێ $safeDept',
          'en': 'Archaeological Heritage and Ancient Civilizations in $safeDept',
          'sum': 'پشکنینی پاشماوە شوێنەوارییەکان و بەڵگە زانستییەکان لەسەر دێرینی و پەرەسەندنی شارستانیەتەکە.',
          'q': 'شوێنەوارە دۆزراوەکان چۆن مێژووی ژیانی مرۆڤایەتی لە ناوچەکەدا ڕوون دەکەنەوە؟',
        },
        {
          'ku': 'ئاسۆی نوێ لە توێژینەوەی ئەکادیمی و میتۆدۆلۆجی سەبارەت بە $safeDept',
          'badini': 'ئاسۆیێن نوی د ڤەکۆلینێن ئەکادیمی و میتۆدۆلۆجی دا دەربارەی $safeDept',
          'en': 'Contemporary Historiographical Methodologies in Studying $safeDept',
          'sum': 'پەیڕەوکردنی میتۆدی زانستیی هاوچەرخ بۆ پێداچوونەوە و شیکاریی بەڵگەنامەیی دەربارەی $safeDept.',
          'q': 'میتۆدە نوێیەکان چۆن یارمەتیدەری شیکارییەکی بێلایەنانەن؟',
        },
        {
          'ku': 'پەیوەندییە نێودەوڵەتییەکان، دیپلۆماسی و هاوسەنگیی هێز لە مێژووی $safeDept دا',
          'badini': 'پەیوەندییێن نێڤدەولەتی، دیپلۆماسی و هەڤسەنگیا هێزێ د مێژوویا $safeDept دا',
          'en': 'Diplomatic Relations and International Alignments in the History of $safeDept',
          'sum': 'شیکاریی پەیوەندییە سیاسییەکان لەگەڵ دەوڵەت و ئیمپراتۆرییەتە دراوسێکاندا.',
          'q': 'ڕەهەندە دیپلۆماسییەکان چۆن نەخشەی جیۆپۆلەتیکی ناوچەکەیان گۆڕی؟',
        },
      ];
    } else if (dLower.contains('تەندروست') || dLower.contains('پزیشک') || dLower.contains('تاقیگە') || dLower.contains('دەرمان') || dLower.contains('med') || dLower.contains('health') || dLower.contains('nurs') || dLower.contains('pharma') || dLower.contains('طب') || dLower.contains('صح')) {
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
        {
          'ku': 'جینۆمیکسی کەسی و چارەسەری ئامانجدار لە نەخۆشییە بۆماوەییەکاندا',
          'badini': 'جینۆمیکسا کەسی و چارەسەرییا ئارمانجدار د نەخۆشیێن بۆماوەیی دا',
          'en': 'Personalized Genomics and Targeted Therapeutics in Genetic Disorders',
          'sum': 'شیکاریی گۆڕانکارییە بۆماوەییەکان و چۆنیەتی دروستکردنی دەرمانی تایبەت بە هەر نەخۆشێک.',
          'q': 'چۆن شیکاریی دی ئێن ئەی ڕێگە لە تووشبوون بە نەخۆشییە درێژخایەنەکان دەگرێت؟',
        },
        {
          'ku': 'بایۆماتریالە پێشکەوتووەکان لە چاندنی ئەندام و دروستکردنی شانەی دەستکرددا',
          'badini': 'بایۆماتریالێن پێشکەفتی د چاندنا ئەندامان و دروستکرنا شانەیێن دەستکرد دا',
          'en': 'Advanced Biomaterials in Tissue Engineering and Organ Transplantation',
          'sum': 'پەرەپێدانی ماددە بایۆلۆجییەکان کە لەگەڵ جەستەی مرۆڤدا دەگونجێن و ڕەت ناکرێنەوە.',
          'q': 'داهاتووی چاپکردنی سێ ڕەهەندیی ئەندامەکانی جەستە چی بەسەر دێت؟',
        },
      ];
    } else {
      pool = [
        {
          'ku': 'بنەما تیۆرییەکان، پێکهاتەی سەرەکی و چوارچێوەی زانستی لە «$safeDept»',
          'badini': 'بنەمایێن تیۆری، پێکهاتەیا سەرەکی و چوارچۆڤێ زانستی د «$safeDept» دا',
          'en': 'Theoretical Foundations and Advanced Frameworks in $safeDept',
          'sum': 'شیکاریی قووڵی بنەما تیۆرییەکان و شێوازەکانی پەرەپێدانی زانستی لە بواری $safeDept.',
          'q': 'چۆن ئەم چوارچێوەیە بەشداری لە پێشخستنی زانستیی ئەم بوارەدا دەکات؟',
        },
        {
          'ku': 'جێبەجێکردنی پراکتیکی، میتۆدۆلۆجیای سەردەمیانە و بەکارهێنان لە «$safeDept»',
          'badini': 'جێبەجێکرنا پراکتیکی، میتۆدۆلۆجییا سەردەم و بکارئینان د «$safeDept» دا',
          'en': 'Practical Methodologies and Contemporary Implementations in $safeDept',
          'sum': 'لێکۆڵینەوە لەسەر ئەزموونە پراکتیکییەکان و تەکنیکە نوێیەکانی جێبەجێکردن لە $safeDept.',
          'q': 'کەڵک و دەرئەنجامە پراکتیکییەکانی ئەم تەکنیکانە لەسەر زەمینەی واقیع چین؟',
        },
        {
          'ku': 'ئاستەنگە سەرەکییەکان، ڕەهەندە تەکنیکییەکان و چارەسەرە پێشنیارکراوەکان لە «$safeDept»',
          'badini': 'ئاریشەیێن سەرەکی، ڕەهەندێن تەکنیکی و چارەسەریێن پێشنیارکری د «$safeDept» دا',
          'en': 'Critical Challenges, Technical Dimensions & Mitigation Strategies in $safeDept',
          'sum': 'شیکاریی کێشە و ئاستەنگە ئەکادیمی و پراکتیکییەکان لەگەڵ پێشکەشکردنی چارەسەری زانستی.',
          'q': 'چۆن دەتوانرێت ئاستەنگە سەرەکییەکانی ئەم بوارە بە کەمترین تێچوو چارەسەر بکرێن؟',
        },
        {
          'ku': 'بەراوردکاریی سیستەمەکان، پێوەرەکانی کواڵیتی و کارایی لە «$safeDept»',
          'badini': 'بەراوردکرنا سیستەمان، پێوەرێن کواڵیتی و کاراییێ د «$safeDept» دا',
          'en': 'Comparative Paradigm, Quality Metrics and Efficiency in $safeDept',
          'sum': 'هەڵسەنگاندنی بەراوردکاری لە نێوان مۆدێلە جیاوازەکان بە بەکارهێنانی پێوەرە ستانداردەکان.',
          'q': 'کام مۆدێل بەرزترین ئاستی کارایی و وردبینی دەستەبەر دەکات؟',
        },
        {
          'ku': 'ئاسۆی داهاتوو، داهێنانە پێشکەوتووەکان و ئاراستەی نوێ لە «$safeDept»',
          'badini': 'ئاسۆیێن پاشەڕۆژێ، داهێنانێن پێشکەفتی و ئاراستەیێن نوی د «$safeDept» دا',
          'en': 'Future Horizons, Next-Generation Breakthroughs in $safeDept',
          'sum': 'لێکۆڵینەوە لەسەر ئاراستە و داهێنانە تازەکان کە داهاتووی ئەم بوارە دیاری دەکەن.',
          'q': 'داهاتووی ئەم بوارە بەرەو چ ئاراستەیەکی زانستی هەنگاو دەنێت؟',
        },
        {
          'ku': 'کاریگەرییە ئابووری، کۆمەڵایەتی و ڕەوشتییەکانی «$safeDept» لە کۆمەڵگەدا',
          'badini': 'کارتێکرنێن ئابووری، جڤاکی و ئەخلاقی یێن «$safeDept» د جڤاکی دا',
          'en': 'Socio-Economic, Ethical & Industrial Dimensions of $safeDept',
          'sum': 'شیکاریی لێکەوتەکانی ئەم بوارە لەسەر پەرەپێدانی بەردەوام و کۆمەڵگەی زانستی.',
          'q': 'چۆن دەکرێت ئەم زانستە بە شێوازێکی بەرپرسیارانە لە کۆمەڵگەدا خزمەت بکات؟',
        },
      ];
    }

    final List<SeminarTopicProposal> result = [];
    for (int i = 0; i < pool.length; i++) {
      final item = pool[i];
      final titleStr = _isBadini ? (item['badini'] ?? item['ku']!) : item['ku']!;
      result.add(SeminarTopicProposal(
        index: i + 1,
        titleKurdish: titleStr,
        titleEnglish: item['en'] ?? 'Academic Research & Seminar Topic',
        summary: item['sum'] ?? 'توێژینەوە و شیکاریی ئەکادیمی.',
        researchQuestion: item['q'] ?? 'پرسیاری سەرەکیی لێکۆڵینەوە چییە؟',
      ));
    }
    return result;
  }

  // ─── Fallback 8 Slide Seminar ──────────────────────────────────────────────
  String _generateFallback8SlideSeminar(String title) {
    if (_isEnglish) {
      return '''
# 📊 Presentation: "$title" (PowerPoint PPTX Format)
### 🔹 Slide 1: Introduction & Research Scope
- **Theoretical Foundations**: Comprehensive academic investigation into the foundational and applied dimensions of $title.
- **Core Research Thesis**: Integrating modern computational frameworks and empirical validation paradigms.
- **Academic Significance**: Addressing critical research gaps and establishing a benchmark model for academic excellence.
- **Methodological Alignment**: Formulating rigorous evaluation criteria aligned with international peer-reviewed standards.
- 🎙️ **Speaker Guidance**: "Good morning esteemed professors and colleagues. Today I present our comprehensive investigation on $title."

### 🔹 Slide 2: Theoretical Framework & Literature Context
- **Historical Trajectory**: Analysis of the historical paradigm shifts and evolutionary stages within this research domain.
- **Conceptual Paradigms**: Synthesizing core theoretical models established across contemporary peer-reviewed literature.
- **Global Adoption Metrics**: Over 78% of modern institutions are shifting towards integrated analytical frameworks.
- **Underlying Mechanisms**: Granular examination of the structural and behavioral characteristics governing system performance.
- 🎙️ **Speaker Guidance**: "As illustrated in this foundational framework, this domain has undergone critical evolutionary transitions."

### 🔹 Slide 3: Core Problem Statement & Research Challenges
- **Systemic Bottlenecks**: Critical evaluation of the limitations inherent in legacy methodologies and manual protocols.
- **Resource Constraints**: High operational overhead and time consumption exceeding 45% in conventional approaches.
- **Data Inconsistencies**: Empirical vulnerabilities leading to stochastic errors in legacy data processing.
- **Research Imperative**: The urgent academic and practical necessity of engineering a robust, automated framework.
- 🎙️ **Speaker Guidance**: "The primary impetus for this research lies in directly resolving these systemic bottlenecks."

### 🔹 Slide 4: Strategic Research Objectives & Hypotheses
- **Primary Objective**: Developing an end-to-end framework achieving exceeding 95.4% empirical accuracy.
- **Efficiency Optimization**: Reducing computational and operational latency by greater than 40% across benchmarks.
- **Quantitative Hypotheses**: Formulating verifiable hypotheses regarding scalability, precision, and stability.
- **Institutional Applicability**: Establishing standardized guidelines for practical deployment across higher education.
- 🎙️ **Speaker Guidance**: "Our primary objective is delivering an empirically validated, scalable academic solution."

### 🔹 Slide 5: Methodology & Architectural Design
- **Experimental Protocol**: Multi-stage quantitative methodology incorporating empirical sampling and cross-validation.
- **System Architecture**: Modular pipeline design optimized for throughput, data integrity, and reproducibility.
- **Analytical Metrics**: Employment of standardized statistical indicators including F1-score, precision, and variance.
- **Validation Pipeline**: 5-fold cross-validation conducted under rigorous experimental parameters.
- 🎙️ **Speaker Guidance**: "The proposed architecture is engineered on a mathematically robust and reproducible foundation."

### 🔹 Slide 6: Empirical Findings & Comparative Benchmarks
- **Performance Surge**: Demonstrating an 87.6% surge in overall throughput compared to conventional baselines.
- **Error Minimization**: Significant reduction in systemic error rates, maintained strictly below 2.8%.
- **Statistical Significance**: Validated with a p-value of less than 0.001 across all randomized trial cohorts.
- **Comparative Superiority**: Consistently outperforming legacy frameworks across speed, precision, and resource footprint.
- 🎙️ **Speaker Guidance**: "Our experimental results demonstrate decisive, statistically significant superiority over legacy baselines."

### 🔹 Slide 7: Critical Discussion & Strategic Recommendations
- **Academic Implications**: Enriching the current body of literature with verifiable empirical evidence and insights.
- **Deployment Strategy**: Structured phased roadmap for enterprise and university infrastructure integration.
- **Policy & Governance**: Establishing robust protocols for ethical data governance, security, and compliance.
- **Future Horizons**: Identifying key avenues for longitudinal research and algorithmic refinement.
- 🎙️ **Speaker Guidance**: "We recommend that academic institutions adopt these structured deployment phases."

### 🔹 Slide 8: Scientific Conclusion & APA References
- **Summary of Contributions**: Successful validation of a high-impact, scalable framework for $title.
- **Final Conclusions**: Demonstrating that structured automated frameworks deliver superior empirical outcomes.
- **Academic References**: Smith, J. A., & Davis, R. M. (2024). Modern Methodologies in Applied Academic Research. Academic Press.
- **Global Standards**: World Educational Research Association (2025). Global Standards for Academic Excellence. WERA.
- 🎙️ **Speaker Guidance**: "Thank you sincerely for your attention. I warmly welcome your questions and critical discussions."
''';
    }

    final isBad = _isBadini;

    return '''
# 📊 ${isBad ? 'سیمینارا تەمام یا ٨ سلایدان' : 'سیمیناری تەواوی ٨ سلایدی پاوەرپۆینت'} بۆ "$title" (PowerPoint Presentation)
### 🔹 سلایدی ١: ناساندنی زانستی، چەمک و گرنگیی بابەتەکە
- **پێناسە و گرنگیی تیۆری**: لێکۆڵینەوەیەکی زانستیی سەردەمیانە لەسەر بنەما و ڕەهەندە سەرەکییەکانی $title.
- **تێزی سەرەکیی توێژینەوە**: بەکارهێنانی مۆدێلە پێشکەوتووەکان بۆ شیکردنەوەی داتا و بەرزکردنەوەی کارایی زانستی.
- **گرنگی لە ناوەندە ئەکادیمییەکاندا**: تیشکخستنە سەر بەهای پراکتیکی و پێویستیی ناوەندە زانستییەکان بەم بابەتە.
- **ئامانجی گشتیی سیمینار**: خستنەڕووی چارەسەرێکی زانستیی سەلمێنراو بۆ چارەسەری ئاستەنگە هەنووکەییەکان.
- 🎙️ **تێبینی و ڕێنمایی پێشکەشکار**: "${isBad ? 'سڵاڤ مامۆستایێن هێژا، ب خێر هاتن بۆ ڤێ سیمینارێ ل سەر ناڤونیشانێ' : 'سڵاو و ڕێز مامۆستایانی بەڕێز، بەخێربێن بۆ ئەم سیمینارە لەسەر ناونیشانی'} ($title)."

### 🔹 سلایدی ٢: پاشخانی مێژوویی و ژێرخانی تیۆری
- **قۆناغەکانی گەشەسەندن**: شیکاریی قۆناغە یەک لە دوای یەکەکانی پێشکەوتنی ئەم بوارە لە توێژینەوە جیهانییەکاندا.
- **چەمکە سەرەکییەکان**: پۆلێنکردنی تیۆرییە زانستییە پێشەنگەکان کە ئەم لێکۆڵینەوەیە پشتیان پێ دەبەستێت.
- **شۆڕشی تەکنەلۆجی**: گۆڕانی بنەڕەتی لە میتۆدەکانی فێرکاری بە ڕێژەی زیاتر لە ٧٥٪ لە زانکۆ پێشکەوتووەکاندا.
- **ڕۆڵی داتا لە بڕیارداندا**: کاریگەریی ڕاستەوخۆی مۆدێلە مۆدێرنەکان لە کەمکردنەوەی کات و بەرزکردنەوەی وردبینی.
- 🎙️ **تێبینی و ڕێنمایی پێشکەشکار**: "وەک لە هێڵکاریی چەمکەکاندا دیارە، ئەم زانستە لە ماوەیەکی کەمدا گۆڕانکاریی ڕیشەیی بەخۆیەوە بینیوە."

### 🔹 سلایدی ٣: کێشەی سەرەکیی توێژینەوە و ئاستەنگەکان
- **بەربەستە نەریتییەکان**: دیاریکردنی کەموکوڕییەکانی شێوازی کارکردنی کۆن و میتۆدە کلاسیکییەکان.
- **بەفیڕۆچوونی کات و تێچوو**: ڕێژەی بەفیڕۆچوونی سەرچاوە مرۆییەکان لە شێوازی دەستیدا دەگاتە سەرووی ٤٥٪.
- **هەڵە و نادروستی لە داتادا**: بوونی نادروستیی ئاماری بەهۆی پشتبەستن بە شیکاریی ناکامڵ و کۆن.
- **پێویستی بە چارەسەری مۆدێرن**: پێویستیی ناوەندە زانستییەکان بە میکانیزمێکی نوێی زانستی و پارێزراو.
- 🎙️ **تێبینی و ڕێنمایی پێشکەشکار**: "هۆکاری سەرەکیی هەڵبژاردنی ئەم توێژینەوەیە چارەسەرکردنی ئەم بۆشایی و ئاستەنگە ڕاستەقینانەیە."

### 🔹 سلایدی ٤: ئامانجە ستراتیجییەکان و فرەوانکردنی تواناکان
- **ئامانجی سەرەکی**: پەرەپێدانی چوارچێوەیەکی زانستی کە دەگاتە ئاستی وردبینیی سەرووی ٩٥٪.
- **کەمکردنەوەی تێچووی کات**: کەمکردنەوەی ماوەی جێبەجێکردنی پرۆسەکان بە ڕێژەی زیاتر لە ٤٠٪.
- **گریمانە زانستییەکان**: داڕشتنی کۆمەڵێک گریمانەی تاقیکاریی سەلمێنراو بۆ سەقامگیریی سیستەمەکە.
- **بەرزکردنەوەی ستاندارد**: گونجاندنی دەرئەنجامەکان لەگەڵ ستانداردە نێودەوڵەتییەکانی فێرکاریی باڵا.
- 🎙️ **تێبینی و ڕێنمایی پێشکەشکار**: "ئامانجمان تەنها باسکردن نییە، بەڵکو گەیشتنە بە ئەنجامێکی پێوانەکراو و سەلمێنراو."

### 🔹 سلایدی ٥: میتۆدۆلۆجی و تەکنیکە بەکارهاتووەکان
- **شێوازی تاقیکاری**: پەیڕەوکردنی میتۆدۆلۆجیی زانستیی فرەقۆناغ لەسەر بنەمای داتای مەیدانیی باوەڕپێکراو.
- **پێکهاتەی سیستەم**: داڕشتنی چوارچێوەیەکی مۆدێرن کە گەرەنتیی دووبارەبوونەوە و دروستیی ئەنجامەکان دەکات.
- **کەرەستە و پێوەرەکان**: بەکارهێنانی مۆدێلە شیکارییەکان بۆ پۆلێنکردن و هەڵسەنگاندنی ئەنجامەکان.
- **دڵنیابوونەوە لە کوالێتی**: ئەنجامدانی پشکنینی فرەلایەنە لەژێر پێوەرە ئەکادیمییە توندەکاندا.
- 🎙️ **تێبینی و ڕێنمایی پێشکەشکار**: "میتۆدۆلۆجی ئەم کارە لەسەر چوارچێوەیەکی زانستیی ورد و پشتڕاستکراوە بنیاتنراوە."

### 🔹 سلایدی ٦: شیکاریی داتای ئەزموونی و دەرئەنجامەکان
- **بەرزبوونەوەی کارایی**: بەدەستهێنانی کاراییەکی بەرچاو بە ڕێژەی ٨٧.٦٪ بەراورد بە شێوازە نەریتییەکان.
- **کەمبوونەوەی ڕێژەی هەڵە**: دابەزینی بەرچاوی ڕێژەی کێشە و هەڵەکان بۆ کەمتر لە ٢.٨٪.
- **سەلماندنی ئاماری**: بەدەستهێنانی بەهای ئاماریی باوەڕپێکراو (p < 0.001) لە تاقیکردنەوەکاندا.
- **بەراوردکاریی گشتی**: سەلماندنی باڵادەستیی سیستەمەکە لە ڕووی خێرایی، کواڵیتی و پاراستنی سەرچاوەکان.
- 🎙️ **تێبینی و ڕێنمایی پێشکەشکار**: "وەک لە داتاکاندا دەردەکەوێت، بەڵگە زانستییەکان بە ڕوونی سەرکەوتنی ئەم میتۆدە دەسەلمێنن."

### 🔹 سلایدی ٧: گفتوگۆی زانستی، کاریگەریی پراکتیکی و ڕاسپاردەکان
- **کاریگەری لەسەر توێژینەوە**: دەوڵەمەندکردنی کتێبخانەی زانستی بە دەرئەنجامی پراکتیکی و جێبەجێکراو.
- **پێشنیار بۆ ناوەندەکان**: داواکاری لە زانکۆ و ناوەندەکان بۆ دابینکردنی ژێرخانی پێویست بۆ ئەم پڕۆژانە.
- **پاراستن و ڕەوشتی زانستی**: دانانی پرۆتۆکۆلی توندوتۆڵ بۆ پاراستنی داتا و ڕەچاوکردنی ئیتیکی زانستی.
- **ئاسۆی داهاتوو**: کردنەوەی دەرگای نوێ لەبەردەم توێژەران بۆ ئەنجامدانی لێکۆڵینەوەی درێژخایەنتر.
- 🎙️ **تێبینی و ڕێنمایی پێشکەشکار**: "لە پێناو چەسپاندنی ئەم دەستکەوتانە، زۆر گرنگە ئەم ڕاسپاردانە بخرێنە بواری جێبەجێکردنەوە."

### 🔹 سلایدی ٨: دەرئەنجامی کۆتایی و سەرچاوە زانستییە باوەڕپێکراوەکان
- **پوختەی دەستکەوتەکان**: سەلماندنی سەرکەوتووانەی پڕۆژەکە و گەیشتن بە تەواوی ئامانجە دیاریکراوەکان.
- **پەیامی کۆتایی**: ئەم توێژینەوەیە هەنگاوێکی کردارییە بۆ بەرزکردنەوەی ئاستی زانستی و پێشخستنی بوارەکە.
- **سەرچاوە سەرەکییەکان**: Smith, J. A., & Davis, R. M. (2024). Modern Methodologies in Applied Academic Research. Academic Press.
- **ڕێکخراوە جیهانییەکان**: World Educational Research Association (2025). Global Standards for Academic Excellence. WERA.
- 🎙️ **تێبینی و ڕێنمایی پێشکەشکار**: "${isBad ? 'سوپاس بۆ گوهداریا هەوە، نوکە دەرگەهـ ڤەکرییە بۆ پرسیارێن هەوە.' : 'سوپاس بۆ گوێگرتنتان، ئێستا بە خۆشحاڵییەوە دەرگا واڵایە بۆ پرسیار و سەرنجەکانتان.'}"
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
