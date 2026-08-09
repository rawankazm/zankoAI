import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../models/quiz_model.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../services/score_service.dart';
import '../ai_teacher/ai_teacher_chat_screen.dart';

class AiExamGeneratorScreen extends StatefulWidget {
  final String? initialCourse;
  final String? initialTopic;

  const AiExamGeneratorScreen({
    super.key,
    this.initialCourse,
    this.initialTopic,
  });

  @override
  State<AiExamGeneratorScreen> createState() => _AiExamGeneratorScreenState();
}

class _AiExamGeneratorScreenState extends State<AiExamGeneratorScreen> {
  // Config state
  String _selectedDifficulty = 'Medium'; // Easy, Medium, Hard
  String _selectedQuestionType = 'Mixed'; // MCQ, TrueFalse, Mixed
  int _questionCount = 10; // 5, 10, 15, 20
  int _durationMinutes = 15; // 5, 10, 15, 30

  String? _pdfFileName;
  String? _pdfFileContent;
  Uint8List? _pdfFileBytes;

  // Active exam state
  bool _isGenerating = false;
  QuizModel? _activeExam;
  int _currentQuestionIndex = 0;
  final Map<int, String> _userAnswers = {};
  bool _examCompleted = false;
  int _timeRemainingSeconds = 0;
  Timer? _examTimer;
  int _secondsSpent = 0;

  @override
  void dispose() {
    _examTimer?.cancel();
    super.dispose();
  }

  // ─── PDF Picker ─────────────────────────────────────────────────────────────
  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        final bytes = file.bytes!;
        final text = _extractTextFromBytes(bytes);

        setState(() {
          _pdfFileName = file.name;
          _pdfFileBytes = bytes;
          _pdfFileContent = text.isNotEmpty ? text : 'Lecture Content of ${file.name}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('فایلی $_pdfFileName بە سەرکەوتوویی بارکرا 📄')),
                ],
              ),
              backgroundColor: ZankoColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵەیەک ڕوویدا لە بارکردنی فایل: $e'),
            backgroundColor: ZankoColors.error,
          ),
        );
      }
    }
  }

  String _sanitizeExtractedText(String input) {
    if (input.isEmpty) return '';

    final RegExp cleanPattern = RegExp(
      r'[^a-zA-Z0-9\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\s\.,\?\!\:\-\(\)]',
    );
    String cleaned = input.replaceAll(cleanPattern, ' ');

    cleaned = cleaned.replaceAll(
      RegExp(r'\b(obj|endobj|stream|endstream|xref|trailer|FlateDecode|Font|CIDFont|FontDescriptor|ProcSet|MediaBox|Type1|WinAnsiEncoding|Identity-H)\b', caseSensitive: false),
      ' ',
    );

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    final words = cleaned.split(' ').where((w) {
      if (w.length < 2) return false;
      return RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(w);
    }).toList();

    return words.join(' ');
  }

  String _extractTextFromBytes(Uint8List bytes) {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();

      String cleanText = _sanitizeExtractedText(extractedText);
      if (cleanText.length > 20) {
        return cleanText.length > 10000 ? cleanText.substring(0, 10000) : cleanText;
      }
    } catch (_) {}

    try {
      final StringBuffer extractedBuffer = StringBuffer();

      // Scan PDF stream objects and decompress FlateDecode streams using zlib
      final List<int> streamSeq = [115, 116, 114, 101, 97, 109]; // 'stream'
      final List<int> endStreamSeq = [101, 110, 100, 115, 116, 114, 101, 97, 109]; // 'endstream'

      int p = 0;
      while (p < bytes.length - 10) {
        int streamStart = -1;
        for (int i = p; i < bytes.length - 6; i++) {
          if (bytes[i] == streamSeq[0] &&
              bytes[i + 1] == streamSeq[1] &&
              bytes[i + 2] == streamSeq[2] &&
              bytes[i + 3] == streamSeq[3] &&
              bytes[i + 4] == streamSeq[4] &&
              bytes[i + 5] == streamSeq[5]) {
            streamStart = i + 6;
            break;
          }
        }
        if (streamStart == -1) break;

        if (streamStart < bytes.length && bytes[streamStart] == 13) streamStart++;
        if (streamStart < bytes.length && bytes[streamStart] == 10) streamStart++;

        int streamEnd = -1;
        for (int i = streamStart; i < bytes.length - 9; i++) {
          if (bytes[i] == endStreamSeq[0] &&
              bytes[i + 1] == endStreamSeq[1] &&
              bytes[i + 2] == endStreamSeq[2] &&
              bytes[i + 3] == endStreamSeq[3] &&
              bytes[i + 4] == endStreamSeq[4] &&
              bytes[i + 5] == endStreamSeq[5]) {
            streamEnd = i;
            break;
          }
        }
        if (streamEnd == -1) break;

        final rawStreamBytes = bytes.sublist(streamStart, streamEnd);
        p = streamEnd + 9;

        if (rawStreamBytes.length > 5) {
          String streamStr = "";
          try {
            final decompressed = zlib.decode(rawStreamBytes);
            streamStr = String.fromCharCodes(decompressed);
          } catch (_) {
            streamStr = String.fromCharCodes(rawStreamBytes);
          }

          int startParen = -1;
          for (int k = 0; k < streamStr.length; k++) {
            final c = streamStr[k];
            if (c == '(') {
              startParen = k + 1;
            } else if (c == ')' && startParen != -1) {
              final snippet = streamStr.substring(startParen, k).trim();
              if (snippet.length > 3 && !snippet.startsWith('/') && !snippet.contains('font')) {
                extractedBuffer.write('$snippet ');
              }
              startParen = -1;
            }
          }
        }
      }

      String extracted = _sanitizeExtractedText(extractedBuffer.toString());
      if (extracted.length > 20) {
        return extracted.length > 8000 ? extracted.substring(0, 8000) : extracted;
      }

      final maxBytes = bytes.length > 250000 ? bytes.sublist(0, 250000) : bytes;
      final rawStr = String.fromCharCodes(maxBytes);
      return _sanitizeExtractedText(rawStr);
    } catch (_) {
      return '';
    }
  }

  // ─── Start Exam ────────────────────────────────────────────────────────────
  Future<void> _generateAndStartExam() async {
    if (_pdfFileContent == null || _pdfFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('تکایە سەرەتا فایلی PDFی وانەکە باربکە بۆ ئەوەی پرسیارەکان دروست بکرێن! 📄')),
            ],
          ),
          backgroundColor: ZankoColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _pickPdfFile();
      return;
    }

    final aiService = Provider.of<AiService>(context, listen: false);

    setState(() {
      _isGenerating = true;
      _activeExam = null;
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _examCompleted = false;
      _secondsSpent = 0;
    });

    final String rawName = _pdfFileName!.replaceAll(RegExp(r'\.(pdf|txt)$', caseSensitive: false), '');
    final String cleanFileName = _sanitizeExtractedText(rawName);
    final courseToUse = cleanFileName.isNotEmpty ? cleanFileName : 'فایلی PDFی بارکراو';
    final topicToUse = 'ناوەرۆکی $courseToUse';

    try {
      QuizModel exam;
      if (aiService is ZankoAiService) {
        exam = await aiService.generateCustomExam(
          courseName: courseToUse,
          topic: topicToUse,
          difficulty: _selectedDifficulty,
          questionType: _selectedQuestionType,
          questionCount: _questionCount,
          durationMinutes: _durationMinutes,
          pdfContent: _pdfFileContent,
          pdfBytes: _pdfFileBytes,
        );
      } else {
        exam = await aiService.generateQuiz(topicToUse, courseToUse);
      }

      if (mounted) {
        setState(() {
          _activeExam = exam;
          _isGenerating = false;
          _timeRemainingSeconds = (exam.durationMinutes > 0 ? exam.durationMinutes : _durationMinutes) * 60;
        });

        _startTimer();
      }
    } catch (e) {
      final fallbackExam = _generateFallbackExam(topicToUse, courseToUse, _questionCount, _durationMinutes);
      if (mounted) {
        setState(() {
          _activeExam = fallbackExam;
          _isGenerating = false;
          _timeRemainingSeconds = fallbackExam.durationMinutes * 60;
        });
        _startTimer();
      }
    }
  }

  bool _isJunkMetadataLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('copyright') ||
        lower.contains('permission') ||
        lower.contains('reproduction') ||
        lower.contains('all rights reserved') ||
        lower.contains('disclaimer') ||
        lower.contains('chapter') ||
        lower.contains('page ') ||
        lower.contains('dr.') ||
        lower.contains('professor') ||
        lower.contains('instructor') ||
        lower.contains('university') ||
        lower.contains('department') ||
        lower.contains('edition') ||
        lower.contains('isbn') ||
        lower.contains('lecture note') ||
        line.trim().length < 10;
  }

  QuizModel _generateFallbackExam(String topic, String course, int count, int duration) {
    List<String> pdfSnippets = [];
    if (_pdfFileContent != null && _pdfFileContent!.trim().isNotEmpty) {
      pdfSnippets = _pdfFileContent!
          .split(RegExp(r'[\.\?\!\n;]'))
          .map((s) => _sanitizeExtractedText(s))
          .where((s) => s.length > 15 && !_isJunkMetadataLine(s) && RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(s))
          .toList();
    }

    final List<QuestionModel> questions = [];
    final cleanTitle = _sanitizeExtractedText(course.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$', caseSensitive: false), ''));
    final displayTitle = cleanTitle.isNotEmpty ? cleanTitle : 'فایلی PDFی وانەکە';

    if (pdfSnippets.length >= 2) {
      for (int i = 0; i < count; i++) {
        final snippet = pdfSnippets[i % pdfSnippets.length];
        final words = snippet.split(' ').where((w) => w.length > 3 && !_isJunkMetadataLine(w)).toList();
        final keyword = words.isNotEmpty ? words[i % words.length] : 'چەمکی زانستی';

        if (i % 2 == 0) {
          questions.add(
            QuestionModel(
              id: 'pdf_fallback_$i',
              questionText: 'لە وانەی «$displayTitle»دا، مەبەستی سەرەکی لە تێگەیشتنی «$keyword» چییە؟',
              type: QuestionType.multipleChoice,
              options: [
                'شیکارکردن و جێبەجێکردنی بنەما زانستییەکانی «$keyword»',
                'ڕەتکردنەوەی تیۆرییە سەرەتاییەکان بەبێ بەڵگەی زانستی',
                'گۆڕینی پێناسە بنەڕەتییەکان بە داتای نەناسراو',
                'پشتگوێخستنی بەشە کردارییەکان لە تاقیکردنەوەدا'
              ],
              correctAnswer: 'شیکارکردن و جێبەجێکردنی بنەما زانستییەکانی «$keyword»',
              explanation: 'ئەم پرسیارە ڕاستەوخۆ لەسەر تێگەیشتنی ناوەڕۆکی زانستی وانەکەوە دەرهێنراوە.',
            ),
          );
        } else {
          questions.add(
            QuestionModel(
              id: 'pdf_fallback_$i',
              questionText: 'ئایا چەمکی «$keyword» بەشێکی سەرەکییە لە تێگەیشتنی بابەتەکانی «$displayTitle»؟',
              type: QuestionType.trueFalse,
              options: ['ڕاستە', 'هەڵەیە'],
              correctAnswer: 'ڕاستە',
              explanation: 'ئەم زانیارییە یەکێکە لە بنەما گرنگەکانی وانەکە.',
            ),
          );
        }
      }
    } else {
      final List<QuestionModel> academicTemplates = [
        QuestionModel(
          id: 'fb_1',
          questionText: 'کامیان بنەمای سەرەکی شیکارکردنی بابەتە زانستییەکانە؟',
          type: QuestionType.multipleChoice,
          options: [
            'تێگەیشتن لە چەمکە سەرەکییەکان و شیکاری لۆژیکی',
            'پشتگوێخستنی سەرچاوەکان',
            'ڕەتکردنەوەی بەشە سەرەکییەکان بەبێ تاقیکردنەوە',
            'پشتڕاستکردنەوەی زانیاری ناراست بەبێ بەڵگە'
          ],
          correctAnswer: 'تێگەیشتن لە چەمکە سەرەکییەکان و شیکاری لۆژیکی',
          explanation: 'شیکاری لۆژیکی و تێگەیشتنی قووڵ بنەمای بەدەستهێنانی نمرەی بەرزە.',
        ),
        QuestionModel(
          id: 'fb_2',
          questionText: 'ئایا پێداچوونەوەی وردی بابەتەکان ئامادەکاری تاقیکردنەوە بەهێزتر دەکات؟',
          type: QuestionType.trueFalse,
          options: ['ڕاستە', 'هەڵەیە'],
          correctAnswer: 'ڕاستە',
          explanation: 'پێداچوونەوەی دووبارە زانیارییەکان لە مێشکدا دەچەسپێنێت.',
        ),
      ];

      for (int i = 0; i < count; i++) {
        final q = academicTemplates[i % academicTemplates.length];
        questions.add(QuestionModel(
          id: 'fb_${i + 1}',
          questionText: q.questionText,
          type: q.type,
          options: q.options,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
        ));
      }
    }

    return QuizModel(
      id: 'fallback_exam_${DateTime.now().millisecondsSinceEpoch}',
      title: 'تاقیکردنەوە لەسەر PDF - $displayTitle',
      courseName: displayTitle,
      questions: questions.take(count > 0 ? count : 5).toList(),
      durationMinutes: duration > 0 ? duration : 15,
      isExam: true,
    );
  }

  void _startTimer() {
    _examTimer?.cancel();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsSpent++;
        if (_timeRemainingSeconds > 0) {
          _timeRemainingSeconds--;
        } else {
          _finishExam();
        }
      });
    });
  }

  void _finishExam() {
    _examTimer?.cancel();
    final score = _calculateScore();
    final total = _activeExam?.questions.length ?? 0;
    if (total > 0) {
      ScoreService.instance.addExamResult(correct: score, total: total);
    }
    setState(() {
      _examCompleted = true;
    });
  }

  int _calculateScore() {
    if (_activeExam == null) return 0;
    int score = 0;
    for (int i = 0; i < _activeExam!.questions.length; i++) {
      final userAns = _userAnswers[i]?.trim().toLowerCase();
      final correctAns = _activeExam!.questions[i].correctAnswer.trim().toLowerCase();
      if (userAns != null && userAns == correctAns) {
        score++;
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: langProvider.textDirection,
      child: PopScope(
        canPop: _activeExam == null || _examCompleted,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _activeExam != null && !_examCompleted) {
            _showExitConfirmDialog(context, isDark);
          }
        },
        child: Scaffold(
          backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
          appBar: AppBar(
            backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.95),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () {
                if (_activeExam != null && !_examCompleted) {
                  _showExitConfirmDialog(context, isDark);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ZankoColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.sparkles, color: ZankoColors.primary, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  langProvider.translate('create_exam'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: _isGenerating
                ? _buildGeneratingState(isDark)
                : _activeExam == null
                    ? _buildConfigState(isDark, langProvider)
                    : _examCompleted
                        ? _buildResultsState(isDark, langProvider)
                        : _buildExamRunningState(isDark, langProvider),
          ),
        ),
      ),
    );
  }

  void _showExitConfirmDialog(BuildContext context, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('دڵنیایت لە دەرچوون؟'),
        content: const Text('ئەگەر لە تاقیکردنەوەکە بێیتەدەرێ، نمرەکەت تۆمار ناکرێت و وەڵامەکانت دەسڕێنەوە.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('مانەوە'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('دەرچوون'),
            onPressed: () {
              _examTimer?.cancel();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. CONFIG STATE (سازدانی تاقیکردنەوە لەسەر PDF)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildConfigState(bool isDark, LanguageProvider langProvider) {
    final bool hasPdf = _pdfFileName != null && _pdfFileContent != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ZankoColors.primary, ZankoColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ZankoColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(CupertinoIcons.doc_text_search, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دروستکردنی تاقیکردنەوە لە فایلی PDF 🎯',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'سەرەتا فایلی PDFی وانەکەت بنێرە، AI دەستبەجێ پرسیار لەسەر دەقی فایلەکەت ئامادە دەکات.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1. STEP 1: Upload PDF File (REQUIRED)
          _buildLabel('١. بارکردنی فایلی PDFی وانەکە (پێویستە 📄)', isDark),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickPdfFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: hasPdf
                    ? (isDark ? ZankoColors.darkCard : const Color(0xFFF0FDF4))
                    : (isDark ? ZankoColors.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasPdf
                      ? ZankoColors.success
                      : (isDark ? ZankoColors.primary.withValues(alpha: 0.5) : ZankoColors.primary),
                  width: hasPdf ? 2.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (hasPdf ? ZankoColors.success : ZankoColors.primary).withValues(alpha: isDark ? 0.15 : 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (hasPdf ? ZankoColors.success : ZankoColors.primary).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasPdf ? CupertinoIcons.doc_checkmark_fill : CupertinoIcons.cloud_upload_fill,
                      color: hasPdf ? ZankoColors.success : ZankoColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasPdf ? _pdfFileName! : 'کلیک لێرە بکە بۆ هەڵبژاردن و بارکردنی فایلی PDF',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: hasPdf
                                ? (isDark ? Colors.white : ZankoColors.textPrimary)
                                : (isDark ? Colors.grey[300] : ZankoColors.primary),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasPdf
                              ? 'فایلی PDF بە سەرکەوتوویی ئامادەکرا ✅ (دەقەکە شیکارکرا)'
                              : 'تکایە سەرەتا فایلی PDFی وانەکەت هەڵبژێرە لە مۆبایلەکەت',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: hasPdf ? FontWeight.w600 : FontWeight.normal,
                            color: hasPdf
                                ? ZankoColors.success
                                : (isDark ? Colors.grey[500] : ZankoColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasPdf)
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey, size: 22),
                      onPressed: () => setState(() {
                        _pdfFileName = null;
                        _pdfFileContent = null;
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Difficulty Level
          _buildLabel('٢. ئاستی زەحمەتی (Difficulty)', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPillChoice('ئاسان 🟢', 'Easy', _selectedDifficulty == 'Easy', isDark, () {
                setState(() => _selectedDifficulty = 'Easy');
              }),
              const SizedBox(width: 8),
              _buildPillChoice('ناوەند 🟡', 'Medium', _selectedDifficulty == 'Medium', isDark, () {
                setState(() => _selectedDifficulty = 'Medium');
              }),
              const SizedBox(width: 8),
              _buildPillChoice('سەخت 🔥', 'Hard', _selectedDifficulty == 'Hard', isDark, () {
                setState(() => _selectedDifficulty = 'Hard');
              }),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Question Type
          _buildLabel('٣. جۆری پرسیارەکان (Question Type)', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPillChoice('تێکەڵ 🎯', 'Mixed', _selectedQuestionType == 'Mixed', isDark, () {
                setState(() => _selectedQuestionType = 'Mixed');
              }),
              const SizedBox(width: 8),
              _buildPillChoice('فرەبژاردە 📋', 'MCQ', _selectedQuestionType == 'MCQ', isDark, () {
                setState(() => _selectedQuestionType = 'MCQ');
              }),
              const SizedBox(width: 8),
              _buildPillChoice('ڕاست/هەڵە ⚖️', 'TrueFalse', _selectedQuestionType == 'TrueFalse', isDark, () {
                setState(() => _selectedQuestionType = 'TrueFalse');
              }),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Question Count & Duration
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('ژمارەی پرسیار', isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? ZankoColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _questionCount,
                          isExpanded: true,
                          dropdownColor: isDark ? ZankoColors.darkCard : Colors.white,
                          items: [5, 10, 15, 20]
                              .map((cnt) => DropdownMenuItem(
                                    value: cnt,
                                    child: Text('$cnt پرسیار'),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _questionCount = val ?? 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('کاتی تاقیکردنەوە', isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? ZankoColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _durationMinutes,
                          isExpanded: true,
                          dropdownColor: isDark ? ZankoColors.darkCard : Colors.white,
                          items: [5, 10, 15, 30]
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text('$m خولەک'),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _durationMinutes = val ?? 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _generateAndStartExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasPdf ? ZankoColors.primary : ZankoColors.primary.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 6,
                shadowColor: ZankoColors.primary.withValues(alpha: 0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(hasPdf ? CupertinoIcons.sparkles : CupertinoIcons.cloud_upload_fill, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    hasPdf ? '🚀 دروستکردنی تاقیکردنەوە لە PDF' : '📄 سەرەتا فایلی PDF باربکە',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : ZankoColors.textPrimary,
      ),
    );
  }

  Widget _buildPillChoice(String label, String value, bool isSelected, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? ZankoColors.primary
                : (isDark ? ZankoColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? ZankoColors.primary
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7)),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ZankoColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. GENERATING STATE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGeneratingState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: ZankoColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(color: ZankoColors.primary, strokeWidth: 3.5),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '🤖 AI خەریکی داڕشتنی پرسیارەکانە لەسەر فایلی PDF...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'پرسیارەکان دەقاو دەق لەسەر ناوەڕۆکی فایلی PDFی بارکراو بە شێوازێکی زانستی ئامادە دەکرێن.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. EXAM RUNNING STATE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildExamRunningState(bool isDark, LanguageProvider langProvider) {
    if (_activeExam == null || _activeExam!.questions.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentQuestion = _activeExam!.questions[_currentQuestionIndex];
    final totalQuestions = _activeExam!.questions.length;

    final minutes = _timeRemainingSeconds ~/ 60;
    final seconds = _timeRemainingSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Column(
      children: [
        // Top Timer & Progress Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Timer Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _timeRemainingSeconds < 60
                          ? ZankoColors.error.withValues(alpha: 0.15)
                          : ZankoColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.timer,
                          size: 18,
                          color: _timeRemainingSeconds < 60 ? ZankoColors.error : ZankoColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _timeRemainingSeconds < 60 ? ZankoColors.error : ZankoColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Question index indicator
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'پرسیاری ${_currentQuestionIndex + 1} لە $totalQuestions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${((_currentQuestionIndex + 1) / totalQuestions * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_currentQuestionIndex + 1) / totalQuestions,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7),
                            valueColor: const AlwaysStoppedAnimation<Color>(ZankoColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Question Jump Bar
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: totalQuestions,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final isCurrent = idx == _currentQuestionIndex;
                    final isAnswered = _userAnswers.containsKey(idx);

                    return GestureDetector(
                      onTap: () => setState(() => _currentQuestionIndex = idx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? ZankoColors.primary
                              : (isAnswered
                                  ? ZankoColors.primary.withValues(alpha: 0.25)
                                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200])),
                          border: Border.all(
                            color: isCurrent
                                ? ZankoColors.primary
                                : (isAnswered ? ZankoColors.primary.withValues(alpha: 0.5) : Colors.transparent),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent || isAnswered ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent
                                  ? Colors.white
                                  : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Question Content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Badge & Text
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? ZankoColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0F0F6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: ZankoColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currentQuestion.type == QuestionType.trueFalse
                                  ? 'ڕاست یان هەڵە'
                                  : 'هەڵبژاردن (MCQ)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ZankoColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            '📄 لە فایلی PDF',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        currentQuestion.questionText,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Options List
                if (currentQuestion.options != null && currentQuestion.options!.isNotEmpty)
                  ...currentQuestion.options!.map((opt) {
                    final isSelected = _userAnswers[_currentQuestionIndex] == opt;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _userAnswers[_currentQuestionIndex] = opt;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ZankoColors.primary.withValues(alpha: 0.15)
                                : (isDark ? ZankoColors.darkCard : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? ZankoColors.primary
                                  : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0F0F6)),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? ZankoColors.primary
                                      : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),
                                ),
                                child: Center(
                                  child: isSelected
                                      ? const Icon(CupertinoIcons.checkmark_alt, size: 18, color: Colors.white)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  opt,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? Colors.white : ZankoColors.primary)
                                        : (isDark ? Colors.grey[200] : ZankoColors.textPrimary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        // Bottom Navigation Buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEFEFF7),
              ),
            ),
          ),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentQuestionIndex--),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('پێشوو'),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentQuestionIndex < totalQuestions - 1) {
                      setState(() => _currentQuestionIndex++);
                    } else {
                      _finishExam();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZankoColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _currentQuestionIndex < totalQuestions - 1 ? 'داهاتوو ➔' : '🏁 کۆتاییهێنان بە تاقیکردنەوە',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. RESULTS STATE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildResultsState(bool isDark, LanguageProvider langProvider) {
    if (_activeExam == null) return const SizedBox.shrink();

    final score = _calculateScore();
    final total = _activeExam!.questions.length;
    final percentage = (score / total) * 100;
    final isPassed = percentage >= 60;

    final minutesSpent = _secondsSpent ~/ 60;
    final secondsSpent = _secondsSpent % 60;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPassed
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isPassed ? ZankoColors.success : ZankoColors.error).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  isPassed ? '🎉 پیرۆزە! لە تاقیکردنەوەکە دەرچوویت' : '⚠️ تاقیکردنەوەکەت تەواو کرد',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Score Circle
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${percentage.toInt()}%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isPassed ? ZankoColors.success : ZankoColors.error,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'نمرەکەت: $score لە $total پرسیار • کاتی سەرفکراو: ${minutesSpent}خ $secondsSpentچ',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Section Title
          Text(
            '💡 شیکاری پرسیارەکان و وەڵامی AI',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ZankoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Questions Review List
          ..._activeExam!.questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final q = entry.value;
            final userAns = _userAnswers[idx];
            final isCorrect = userAns != null && userAns.trim().toLowerCase() == q.correctAnswer.trim().toLowerCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCorrect
                      ? ZankoColors.success.withValues(alpha: 0.4)
                      : ZankoColors.error.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill,
                        color: isCorrect ? ZankoColors.success : ZankoColors.error,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'پرسیاری ${idx + 1}: ${q.questionText}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Answers Breakdown
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'وەڵامی تۆ: ${userAns ?? "وەڵام نەدراوەتەوە"}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isCorrect ? ZankoColors.success : ZankoColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'وەڵامی ڕاست: ${q.correctAnswer}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: ZankoColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // AI Explanation
                  if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(CupertinoIcons.lightbulb_fill, color: ZankoColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'شیکردنەوەی مامۆستا AI 🤖:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: ZankoColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  q.explanation!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[200] : ZankoColors.textPrimary,
                                    height: 1.4,
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
            );
          }),

          const SizedBox(height: 20),

          // Retake & Ask AI Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _activeExam = null;
                      _examCompleted = false;
                    });
                  },
                  icon: const Icon(CupertinoIcons.refresh),
                  label: const Text('دووبارەکردنەوە'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const AiTeacherChatScreen()),
                    );
                  },
                  icon: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white),
                  label: const Text('پرسیار لە AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZankoColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
