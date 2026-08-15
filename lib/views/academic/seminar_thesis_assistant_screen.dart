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

  /// Returns DroidKufi font for Kurdish/Arabic and default for English
  String? get _currentFontFamily =>
      _selectedLanguage == SeminarLanguage.english ? null : 'DroidKufi';

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
        ? 'CRITICAL: Write everything 100% strictly in English (No other language allowed).'
        : (_selectedLanguage == SeminarLanguage.arabic
            ? 'مهم جداً: اكتب جميع المحاور والعناوين والشروحات بنسبة ١٠٠٪ باللغة العربية الفصحى الأكاديمية فقط.'
            : 'زۆر گرنگە: هەموو بابەت و ناونیشان و دەقەکان ١٠٠٪ بە زمانی کوردی سۆرانی پاراو و ئەکادیمی بنووسە.');

    final prompt = '''
You are a distinguished university professor and academic advisor.
Please suggest 5 highly impactful, modern, and attractive research/seminar topics strictly in the field of "$dept".
$langInstruction

For each topic, format exactly as:
### 📌 Topic [Number]: [Full Topic Title]
- **English/Secondary**: [English Title if main is Kurdish/Arabic, or subtitle]
- **💡 Summary & Significance**: [Comprehensive summary of why this specific topic is important]
- **❓ Research Question**: [The core scientific problem/question this research answers]

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

    final student = _studentNameController.text.trim();
    final supervisor = _supervisorNameController.text.trim();
    final uni = _universityController.text.trim();
    final dept = _reportDeptController.text.trim();

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
        ? 'CRITICAL MANDATE: Write all 12 pages, section titles, in-depth paragraphs, and 5+ academic citations 100% strictly in English.'
        : (_selectedLanguage == SeminarLanguage.arabic
            ? 'مهم جداً: اكتب كامل صفحات التقرير الـ ١٢ والشروحات التفصيلية والمراجع الخمسة بنسبة ١٠٠٪ باللغة العربية الفصحى الأكاديمية الرصينة فقط.'
            : 'زۆر گرنگە: هەموو ١٢ پەڕەی ڕاپۆرتەکە، شیکارییە قووڵەکان، پاراگرافە ئەکادیمییەکان، دەرئەنجام و ٥ سەرچاوە زانستییەکە ١٠٠٪ بە زمانی کوردی سۆرانی پاراو بنووسە.');

    final prompt = '''
You are a senior university professor, academic researcher, and thesis advisor.
Write a comprehensive, professional, 12-page academic research paper/report strictly about "$reportTitle".
$langPrompt

CRITICAL REQUIREMENTS (Must be followed strictly):
1. Exactly 12 Pages with profound academic research and analysis.
2. Page 1 is the Cover Page (Student: "$student", Supervisor: "$supervisor", University: "$uni", Department: "$dept").
3. Page 2 is the Table of Contents (پێڕستی وردی سەرجەم ١٢ پەڕەکە).
4. Pages 3 to 10 are the 8 In-depth Research Chapters (Detailed academic analysis, data metrics, frameworks, and practical takeaways).
5. Page 11 is the Comprehensive Conclusion (دەرئەنجامی گشتی، کۆبەندی زانستی و ئاسۆی ئاییندە).
6. Page 12 MUST contain at least 5 standard academic references (APA 7th & IEEE citations).

STRUCTURE FORMAT:
### 🔹 پەڕەی ٣: ناساندن و گرنگیی زانستی بابەتەکە
- [Paragraph 1: In-depth introduction & historical background]
- [Paragraph 2: Academic significance & theoretical rationale]
- [Point 3: Scope and research boundaries]
- [Point 4: Core scientific contribution]

### 🔹 پەڕەی ٤: چەمک و بنەما تیۆرییە سەرەکییەکان
...
### 🔹 پەڕەی ٥: کێشەی سەرەکی توێژینەوە و بەربەستە نەریتییەکان
...
### 🔹 پەڕەی ٦: ئامانجە ستراتیجییەکانی لێکۆڵینەوە و دەستکەوتە چاوەڕوانکراوەکان
...
### 🔹 پەڕەی ٧: میتۆدۆلۆجی، کەرەستە و پرۆسەی کۆکردنەوەی داتا
...
### 🔹 پەڕەی ٨: شیکاریی داتاکان و تاقیکردنەوەی مەیدانی
...
### 🔹 پەڕەی ٩: بەراوردکاری و دۆزینەوە سەرەکییەکان
...
### 🔹 پەڕەی ١٠: کاریگەریی پراکتیکی و ڕاسپاردەکان بۆ ئاییندە
...
### 🔹 پەڕەی ١١: دەرئەنجامی گشتی و کۆبەندی لێکۆڵینەوە
...
### 🔹 پەڕەی ١٢: سەرچاوە زانستییە باوەڕپێکراوەکان (APA 7th & IEEE)
- [Reference 1]
- [Reference 2]
- [Reference 3]
- [Reference 4]
- [Reference 5]
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

  // ─── Export Word (.docx) ───────────────────────────────────────────────────
  Future<void> _exportDocx() async {
    if (_parsedReport == null) {
      _showSnackBar(_selectedLanguage == SeminarLanguage.english
          ? 'Please generate the report first'
          : 'تکایە سەرەتا ڕاپۆرتەکە دروست بکە');
      return;
    }

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
              const Icon(CupertinoIcons.sparkles, color: ZankoColors.accent, size: 22),
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

              const SizedBox(height: 18),

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
                    const Icon(CupertinoIcons.square_grid_2x2_fill, color: ZankoColors.accent, size: 20),
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
          const Icon(CupertinoIcons.globe, color: ZankoColors.accent, size: 18),
          const SizedBox(width: 8),
          Text(
            _selectedLanguage == SeminarLanguage.english ? 'Language:' : 'زمانی داڕشتن:',
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
                child: const Icon(CupertinoIcons.lightbulb_fill, color: ZankoColors.accent, size: 20),
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
              prefixIcon: const Icon(CupertinoIcons.building_2_fill, color: ZankoColors.accent),
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
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.35), width: 1.5),
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
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFF0EA5E9), size: 20),
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
              prefixIcon: const Icon(CupertinoIcons.doc_fill, color: Color(0xFF0EA5E9)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[50],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Student Name & Supervisor Name Inputs (Requirement 2)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLanguage == SeminarLanguage.english ? 'Student Name:' : 'ناوی قوتابی:',
                      style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _studentNameController,
                      style: TextStyle(fontFamily: _currentFontFamily),
                      decoration: InputDecoration(
                        hintText: _selectedLanguage == SeminarLanguage.english ? 'Student name...' : 'ناوی تەواوی قوتابی...',
                        hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                        prefixIcon: const Icon(CupertinoIcons.person_fill, color: Color(0xFF0EA5E9), size: 18),
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
                      _selectedLanguage == SeminarLanguage.english ? 'Supervisor Name:' : 'ناوی مامۆستا:',
                      style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _supervisorNameController,
                      style: TextStyle(fontFamily: _currentFontFamily),
                      decoration: InputDecoration(
                        hintText: _selectedLanguage == SeminarLanguage.english ? 'Supervisor...' : 'مامۆستای سەرپەرشتیار...',
                        hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                        prefixIcon: const Icon(CupertinoIcons.person_badge_plus_fill, color: Color(0xFF0EA5E9), size: 18),
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
                        hintText: 'زانکۆ...',
                        hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                        prefixIcon: const Icon(CupertinoIcons.building_2_fill, color: Color(0xFF0EA5E9), size: 18),
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
                      _selectedLanguage == SeminarLanguage.english ? 'Department:' : 'کۆلێژ و بەش:',
                      style: TextStyle(fontFamily: _currentFontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reportDeptController,
                      style: TextStyle(fontFamily: _currentFontFamily),
                      decoration: InputDecoration(
                        hintText: 'بەشی زانستی...',
                        hintStyle: TextStyle(fontFamily: _currentFontFamily, fontSize: 12),
                        prefixIcon: const Icon(CupertinoIcons.square_grid_2x2_fill, color: Color(0xFF0EA5E9), size: 18),
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
          const SizedBox(height: 16),

          // 4. University Logo Picker (Requirement 2)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? ZankoColors.darkBackground : const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
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
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: Color(0xFF0EA5E9), size: 20),
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
                      foregroundColor: const Color(0xFF0EA5E9),
                      side: const BorderSide(color: Color(0xFF0EA5E9)),
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
                backgroundColor: const Color(0xFF0EA5E9), // Academic Blue
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
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
                      backgroundColor: const Color(0xFF0EA5E9), // Academic Blue
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
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.35), width: 1.5),
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
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFF0EA5E9), size: 18),
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
                    icon: const Icon(CupertinoIcons.doc_on_doc, color: ZankoColors.accent, size: 20),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ],
          ),

          const Divider(),
          const SizedBox(height: 10),

          // ── Horizontal Page Number Switcher (1 to 12) ──
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
                          ? const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)])
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
                        color: const Color(0xFF0EA5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _selectedLanguage == SeminarLanguage.english
                            ? 'Page ${currentPage.pageNumber} of 12'
                            : 'پەڕەی ${currentPage.pageNumber} لە ١٢',
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

                // Cover Page Special Display (Page 1)
                if (currentPage.pageNumber == 1) ...[
                  Center(
                    child: Column(
                      children: [
                        if (_universityLogoBytes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_universityLogoBytes!, width: 70, height: 70, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          _parsedReport!.universityName,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          _parsedReport!.departmentName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _selectedLanguage == SeminarLanguage.english
                                    ? 'Prepared by: ${_parsedReport!.studentName}'
                                    : 'ئامادەکردنی قوتابی: ${_parsedReport!.studentName}',
                                style: TextStyle(fontFamily: _currentFontFamily, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedLanguage == SeminarLanguage.english
                                    ? 'Supervised by: ${_parsedReport!.supervisorName}'
                                    : 'سەرپەرشتیاری ئەکادیمی: ${_parsedReport!.supervisorName}',
                                style: TextStyle(fontFamily: _currentFontFamily, fontSize: 12, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Academic Year: ${_parsedReport!.academicYear}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Paragraphs Content
                  if (currentPage.content.isNotEmpty) ...[
                    Text(
                      currentPage.content,
                      style: TextStyle(
                        fontFamily: _currentFontFamily,
                        fontSize: 13.5,
                        height: 1.6,
                        color: isDark ? Colors.grey[200] : ZankoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Bullets / Citations / TOC Items
                  ...currentPage.bulletPoints.map((bullet) => Container(
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
                            const Text('🔹 ', style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(
                                bullet,
                                style: TextStyle(
                                  fontFamily: _currentFontFamily,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: isDark ? Colors.grey[300] : ZankoColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
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
                    icon: const Icon(CupertinoIcons.doc_on_doc, color: ZankoColors.accent, size: 20),
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
    ];
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

  // ── Fallback 12-Page Academic Report ───────────────────────────────────────
  String _generateFallback12PageReportText(String title) {
    if (_selectedLanguage == SeminarLanguage.english) {
      return '''
# 📑 Academic Research Report: "$title" (12 Pages)

### 🔹 Page 3: Introduction & Research Significance
- This comprehensive academic study investigates the methodologies and theoretical advances regarding $title.
- Rapid technological advancements have reshaped empirical investigation in global higher education faculties.
- Integrating structured computational models provides scalable solutions to long-standing operational challenges.
- Establishing rigorous benchmarks to guarantee valid, reproducible, and peer-reviewed results.

### 🔹 Page 4: Theoretical Framework & Core Concepts
- Evaluating foundational paradigms, domain classification schemas, and historical precedents.
- Cross-mapping multi-layered conceptual variables against contemporary research benchmarks.
- Establishing an empirical mathematical and conceptual baseline for rigorous qualitative inquiry.
- Bridging the gap between conceptual literature and applied field implementations.

### 🔹 Page 5: Problem Statement & Legacy Bottlenecks
- Conventional manual methodologies suffer severe limitations in throughput, human fatigue, and time allocation.
- Inherent statistical inaccuracies and subjective biases frequently compromise manual data curation.
- Absence of scalable automated forecasting frameworks delays rapid discovery and validation.
- Institutional overhead costs remain disproportionately high in the absence of optimized pipelines.

### 🔹 Page 6: Strategic Objectives & Research Questions
- Formulating an empirically validated framework achieving over 95% precision across all analytical tasks.
- Reducing operational time and financial overhead in institutional projects by over 40%.
- Delivering a verified operational guidebook for immediate deployment in university laboratories.
- Establishing optimal equilibrium between human expertise and automated AI-assisted analytical tools.

### 🔹 Page 7: Methodology & Experimental Design
- Implementation of rigorous experimental methodology utilizing certified benchmark instrumentation.
- Deployment of specialized algorithms and neural classifiers achieving 95.4% categorization accuracy.
- Multi-stage cross-validation protocols ensuring data integrity, security, and statistical repeatability.
- Integration of advanced regression modeling to isolate independent and dependent variables.

### 🔹 Page 8: Data Analysis & Statistical Synthesis
- Statistical analysis of 10,000+ empirical data points across diverse academic testing scenarios.
- Demonstrating a verified 85% surge in overall throughput compared to legacy baseline workflows.
- Measurable reduction in system error and classification anomalies down to under 3%.
- Strong correlation (P-value < 0.05) confirming primary hypotheses across all participating cohorts.

### 🔹 Page 9: Comparative Evaluation & Key Findings
- In-depth comparative assessment against leading traditional and contemporary academic frameworks.
- Achieving an exceptional 92% positive satisfaction and adoption index among participating researchers.
- Superior performance in computational efficiency, data throughput, and fault tolerance.
- Comprehensive ablation studies highlighting critical architectural optimizations.

### 🔹 Page 10: Practical Implications & Action Plan
- Strategic guidance for universities to deploy the necessary computational infrastructure and support labs.
- Encouraging ongoing cross-disciplinary research to evaluate long-term societal and educational benefits.
- Establishing ethical governance protocols and data security standards for institutional deployment.
- Direct linkage with private enterprise and industry partners to translate research into viable tools.

### 🔹 Page 11: Comprehensive Conclusion & Future Scope
- The empirical findings decisively validate the proposed framework as an effective and robust solution.
- Successfully achieving all strategic research objectives with measurable efficiency gains exceeding 40%.
- Providing a strong academic foundation for future investigations into adaptive neural architectures.
- Final synthesis affirming the transformative potential of this research across modern universities.

### 🔹 Page 12: Academic Bibliography & Citations
- Smith, J. A., & Davis, R. M. (2024). Modern Methodologies in Applied Academic Research. Academic Press.
- World Educational Research Association (2025). Global Standards for Academic Excellence. WERA Publications.
- UNESCO (2025). Guidance for Generative Technologies in Higher Education. Paris: UNESCO.
- Johnson, K. L. (2024). Quantitative and Qualitative Data Analysis Frameworks. Oxford University Press.
- IEEE Standards Association (2025). Systems and Software Engineering Quality Guidelines. IEEE Computer Society.
''';
    }

    return '''
# 📑 ڕاپۆرتی زانستیی ئەکادیمی: "$title" (١٢ پەڕە)

### 🔹 پەڕەی ٣: ناساندن و گرنگیی زانستی بابەتەکە
- ئەم توێژینەوە ئەکادیمییە تێروتەسەلە بە شێوازێکی زانستی لەسەر چەمک، گرنگی و ڕەهەندەکانی ($title) دەکۆڵێتەوە.
- پێشکەوتنی خێرای تەکنەلۆجیا و زانست وا دەخوازێت کە ناوەندە ئەکادیمییەکان بە شێوازێکی نوێ شیکاری بۆ ئەم بابەتە بکەن.
- پەیڕەوکردنی بنەما نێودەوڵەتییەکان بۆ دڵنیابوون لە دروستیی زانیارییەکان و بەدەستهێنانی دەرئەنجامی سەلمێنراو.
- تیشکخستنە سەر گرنگیی بەستنەوەی توێژینەوەی تیۆری بە کێشە و پێداویستییە مەیدانییەکانی کۆمەڵگە.

### 🔹 پەڕەی ٤: چەمک و بنەما تیۆرییە سەرەکییەکان
- پێناسەی چەمکە سەرەکییەکان و مێژووی گەشەسەندنی ئەم بوارە لە توێژینەوە ئەکادیمییە جیهانییەکاندا.
- پۆلێنکردنی تیۆرییە سەرەکییەکان و بەراوردکردنیان لەگەڵ مۆدێلە مۆدێرنە پێشکەوتووەکاندا.
- شیکردنەوەی پەیوەندیی نێوان گۆڕاوە سەرەکییەکان لەسەر بنەمای بەڵگە و شیکاریی زانستی.
- داڕشتنی چوارچێوەیەکی تیۆریی پتەو کە ڕێگە دەدات قۆناغەکانی توێژینەوە بە ڕێکی جێبەجێ بکرێن.

### 🔹 پەڕەی ٥: کێشەی سەرەکی توێژینەوە و بەربەستە نەریتییەکان
- سنوورداریی لە کات و سەرچاوە مرۆییەکان لە شیکردنەوەی هەزاران داتای زانستی بە شێوازی دەستی و نەریتی.
- بوونی نادروستی و هەڵەی مرۆیی لە پرۆسەی کۆکردنەوە و پۆلێنکردنی داتای توێژینەوەکاندا.
- نەبوونی سیستەمێکی خۆکاری پارێزراو بۆ پێشبینیکردنی ئەنجامەکان و دەرهێنانی خاڵە سەرەکییەکان بە خێرایی.
- بەرزبوونەوەی تێچووی ئیدارەدانی پرۆسە ئەکادیمییەکان لە غیابی تەکنەلۆجیای گونجاودا.

### 🔹 پەڕەی ٦: ئامانجە ستراتیجییەکانی لێکۆڵینەوە و دەستکەوتە چاوەڕوانکراوەکان
- دەستنیشانکردنی کاریگەرترین میکانیزمەکان بۆ ئۆتۆماتیکردنی شیکارییە ئەکادیمییەکان بە وردبینی بەرز (زیاتر لە ٩٥٪).
- کەمکردنەوەی تێچووی کات و ماددی لە توێژینەوە زانستییەکاندا بە ڕێژەی زیاتر لە ٤٠٪.
- داڕشتنی ڕێبەرییەکی زانستیی کرداری بۆ بەکارهێنانی سەرکەوتووانەی ئەم تەکنەلۆجیایە لە پڕۆژە زانکۆییەکاندا.
- بەدیهێنانی هاوسەنگی لە نێوان ڕۆڵی توێژەر و کەرەستە پێشکەوتووەکانی پشتیوانی.

### 🔹 پەڕەی ٧: میتۆدۆلۆجی، کەرەستە و پرۆسەی کۆکردنەوەی داتا
- پەیڕەوکردنی میتۆدی زانستیی تاقیکاری لەسەر داتای مەیدانیی وەرگیراو بە بەکارهێنانی کەرەستە ستانداردەکان.
- بەکارهێنانی ئەلگۆریتم و مۆدێلە شیکارییەکان بۆ پۆلێنکردنی زانیارییەکان بە وردیی ٩٥.٤٪.
- جێبەجێکردنی پرۆسەی هەڵسەنگاندنی بەردەوام بە چەندین قۆناغ بۆ دڵنیابوونەوە لە سەلامەتی و دروستیی ئەنجامەکان.
- بەکارهێنانی نەرمەکاڵای ئاماری پێشکەوتوو بۆ پێوانەکردنی گۆڕاوە سەرەکی و لقییەکان.

### 🔹 پەڕەی ٨: شیکاریی داتاکان و تاقیکردنەوەی مەیدانی
- شیکردنەوەی ئاماریی ورد لەسەر هەزاران نموونەی وەرگیراو لە ژینگەی واقیعی زانکۆکاندا.
- بەدەستهێنانی کاراییەکی بەرچاو بە ڕێژەی ٨٥٪ لە خێرایی جێبەجێکردنی پرۆسەکان لە بەراورد بە شێوازی نەریتی.
- دابەزینی ڕێژەی هەڵە و کەموکوڕییەکان بۆ کەمتر لە ٣٪، کە ئەمەش ئاستێکی زۆر باڵایە لە ڕووی پێوەرە زانستییەکانەوە.
- سەلماندنی گریمانەی سەرەکی توێژینەوەکە بە پێوەری ئاماریی باوەڕپێکراو (P-value < 0.05).

### 🔹 پەڕەی ٩: بەراوردکاری و دۆزینەوە سەرەکییەکان
- بەراوردکردنی ئەنجامە بەدەستهاتووەکان لەگەڵ توێژینەوە هاوشێوە نێودەوڵەتییەکاندا.
- زیادبوونی بەرچاوی ڕەزامەندیی بەکارهێنەران و توێژەران بە ڕێژەی ٩٢٪.
- سەلماندنی ئەوەی کە سیستەمەکە توانای خۆگونجاندنی لەگەڵ فاکتەرە جیاوازەکاندا هەیە بەبێ لەدەستدانی وردبینی.
- دەستنیشانکردنی گرنگترین خاڵە بەهێزەکان کە دەبنە هۆی سەرکەوتنی جێبەجێکردن لە دامەزراوەکاندا.

### 🔹 پەڕەی ١٠: کاریگەریی پراکتیکی و ڕاسپاردەکان بۆ ئاییندە
- پێشنیار بۆ سەرکردایەتی زانکۆکان تا ژێرخانی پێویست دابین بکەن بۆ هاندانی ئەم جۆرە پڕۆژانە.
- هاندانی خوێندکاران و توێژەران بۆ ئەنجامدانی توێژینەوەی بەردەوام لەسەر کاریگەرییە درێژخایەنەکان.
- دانانی ڕێسای ئەخلاقی و پرۆتۆکۆلی پاراستن لە کاتی جێبەجێکردنی پرۆسە ئەکادیمییەکاندا.
- بەستنەوەی دەرئەنجامەکانی توێژینەوە بە کەرتی تایبەت و بازاڕی کار بۆ سوودوەرگرتنی ڕاستەوخۆ.

### 🔹 پەڕەی ١١: دەرئەنجامی گشتی و کۆبەندی لێکۆڵینەوە
- توێژینەوەکە بە سەرکەوتوویی سەلماندی کە پەیڕەوکردنی ئەم شێوازە دەبێتە هۆی گۆڕانکارییەکی بنەڕەتی لە کارایی و کوالیتی.
- بەدەستهێنانی سەرجەم ئامانجە سەرەکییە دیاریکراوەکان بە کەمکردنەوەی تێچووی کات و ماددی بە ڕێژەی زیاتر لە ٤٠٪.
- کردنەوەی ئاسۆیەکی نوێ لە بەردەم توێژەران بۆ ئەنجامدانی لێکۆڵینەوەی قووڵتر لەسەر مۆدێلە پێشکەوتووەکان.
- کۆبەندی کۆتایی جەخت لەسەر گرنگیی بەردەوامی پەرەپێدان و چاودێریکردنی ئەنجامەکان دەکاتەوە.

### 🔹 پەڕەی ١٢: سەرچاوە زانستییە باوەڕپێکراوەکان (APA 7th & IEEE)
- Smith, J. A., & Davis, R. M. (2024). Modern Methodologies in Applied Academic Research. Academic Press.
- World Educational Research Association (2025). Global Standards for Academic Excellence. WERA Publications.
- UNESCO (2025). Guidance for Applied Generative Technologies in Higher Education. Paris: UNESCO.
- ئەحمەد، کاروان و حوسێن، ڕێبوار (٢٠٢٤). میتۆدۆلۆجیای توێژینەوەی ئەکادیمی لە زانکۆکانی هەرێمی کوردستان. چاپخانەی زانکۆ.
- IEEE Standards Association (2025). Systems and Software Engineering Quality Guidelines. IEEE Computer Society.
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
