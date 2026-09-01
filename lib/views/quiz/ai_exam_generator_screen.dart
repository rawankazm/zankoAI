import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/quiz_model.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/document_parser_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../services/score_service.dart';
import '../ai_teacher/ai_teacher_chat_screen.dart';
import '../payment/vip_upgrade_sheet.dart';

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
  String _inputMode = 'pdf'; // 'pdf' or 'topic'
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final Map<int, TextEditingController> _blankControllers = {};

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
  void initState() {
    super.initState();
    if (widget.initialCourse != null && widget.initialCourse!.isNotEmpty) {
      _courseController.text = widget.initialCourse!;
      _inputMode = 'topic';
    }
    if (widget.initialTopic != null && widget.initialTopic!.isNotEmpty) {
      _topicController.text = widget.initialTopic!;
      _inputMode = 'topic';
    }
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _courseController.dispose();
    _topicController.dispose();
    for (var c in _blankControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── PDF Picker ─────────────────────────────────────────────────────────────
  Future<void> _pickPdfFile() async {
    try {
      final parsed = await DocumentParserService.pickAndExtractDocument();

      if (parsed != null) {
        setState(() {
          _pdfFileName = parsed.fileName;
          _pdfFileContent = parsed.content;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('فایلی $_pdfFileName بە سەرکەوتوویی بارکرا [${parsed.typeDisplayName}] 📄')),
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
    if (input.trim().isEmpty) return '';
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ─── VIP Limit Check ──────────────────────────────────────────────────────
  Future<bool> _checkVipExamLimit() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isVip = authService.currentUser?.isVip ?? false;
    if (isVip) return true;

    // Check if free user selected more than 5 questions
    if (_questionCount > 5) {
      _showVipExamDialog('دروستکردنی تاقیکردنەوەی زیاتر لە ٥ پرسیار تایبەتە بە ئەندامانی VIP 👑');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('exam_gen_date') ?? '';
    int count = prefs.getInt('exam_gen_count') ?? 0;

    if (lastDate != today) {
      count = 0;
    }

    if (count >= 1) {
      _showVipExamDialog('بەکارهێنەرانی ئاسایی تەنها دەتوانن ڕۆژانە ١ تاقیکردنەوە بە AI دروست بکەن.\nبۆ دروستکردنی تاقیکردنەوەی بێسنوور هەژمارەکەت بەرزبکەرەوە بۆ VIP 👑');
      return false;
    }

    await prefs.setString('exam_gen_date', today);
    await prefs.setInt('exam_gen_count', count + 1);
    return true;
  }

  void _showVipExamDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('👑', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تایبەتمەندی بەشداربووانی VIP',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, height: 1.5),
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
                      'بە تەنها ٥,٠٠٠ د.ع بێسنوور تاقیکردنەوە، سێمینار و ڕاپۆرت دروست بکە!',
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
                    VipUpgradeSheet.show(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB8860B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('بوون بە VIP 👑', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Start Exam ────────────────────────────────────────────────────────────
  Future<void> _generateAndStartExam() async {
    final courseText = _courseController.text.trim();
    final topicText = _topicController.text.trim();

    if (_inputMode == 'pdf' && (_pdfFileContent == null || _pdfFileName == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('تکایە سەرەتا فایلی PDFی وانەکە باربکە یان بپەڕەرەوە بۆ بەشی دەق! 📄')),
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

    if (_inputMode == 'topic' && courseText.isEmpty && topicText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تکایە ناوی وانە یان بابەت بنووسە'),
          backgroundColor: ZankoColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final allowed = await _checkVipExamLimit();
    if (!allowed || !mounted) return;

    final aiService = Provider.of<AiService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    setState(() {
      _isGenerating = true;
      _activeExam = null;
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _blankControllers.clear();
      _examCompleted = false;
      _secondsSpent = 0;
    });

    String courseToUse;
    String topicToUse;

    if (_inputMode == 'pdf' && _pdfFileName != null) {
      final String rawName = _pdfFileName!.replaceAll(RegExp(r'\.(pdf|txt)$', caseSensitive: false), '');
      final String cleanFileName = _sanitizeExtractedText(rawName);
      courseToUse = cleanFileName.isNotEmpty ? cleanFileName : 'فایلی PDFی بارکراو';
      topicToUse = 'ناوەڕۆکی $courseToUse';
    } else {
      courseToUse = courseText.isNotEmpty ? courseText : (topicText.isNotEmpty ? topicText : 'تاقیکردنەوەی گشتی');
      topicToUse = topicText.isNotEmpty ? topicText : courseToUse;
    }

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
          pdfContent: _inputMode == 'pdf' ? _pdfFileContent : null,
          pdfBytes: _inputMode == 'pdf' ? _pdfFileBytes : null,
        );
      } else {
        exam = await aiService.generateQuiz(topicToUse, courseToUse);
      }

      await dbService.addQuiz(exam);

      // Initialize blank controllers
      for (int i = 0; i < exam.questions.length; i++) {
        if (exam.questions[i].type == QuestionType.fillInBlank) {
          _blankControllers[i] = TextEditingController();
        }
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
      final fallbackExam = _generateFallbackExam(
        topicToUse,
        courseToUse,
        _questionCount,
        _durationMinutes,
        pdfText: _inputMode == 'pdf' ? _pdfFileContent : null,
      );

      await dbService.addQuiz(fallbackExam);

      for (int i = 0; i < fallbackExam.questions.length; i++) {
        if (fallbackExam.questions[i].type == QuestionType.fillInBlank) {
          _blankControllers[i] = TextEditingController();
        }
      }

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

  QuizModel _generateFallbackExam(String topic, String course, int count, int duration, {String? pdfText}) {
    List<String> pdfSnippets = [];
    if (pdfText != null && pdfText.trim().isNotEmpty) {
      pdfSnippets = pdfText
          .split(RegExp(r'[\.\?\!\n;]'))
          .map<String>((s) => _sanitizeExtractedText(s))
          .where((String s) => s.length > 15 && !_isJunkMetadataLine(s) && RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(s))
          .toList();
    }

    final List<QuestionModel> questions = [];
    final cleanTitle = _sanitizeExtractedText(course.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$', caseSensitive: false), ''));
    final displayTitle = cleanTitle.isNotEmpty ? cleanTitle : 'وانەی دیاریکراو';

    final int targetCount = count > 0 ? count : 5;

    if (pdfSnippets.length >= 2) {
      for (int i = 0; i < targetCount; i++) {
        final snippet = pdfSnippets[i % pdfSnippets.length].trim();
        final words = snippet.split(' ').where((w) => w.length > 3 && !_isJunkMetadataLine(w)).toList();
        final mainTerm = words.isNotEmpty ? words[i % words.length] : 'چەمکی سەرەکی';

        if (i % 3 == 0) {
          // Factual Multiple Choice
          final truncatedSnippet = snippet.length > 100 ? '${snippet.substring(0, 100)}...' : snippet;
          final wrong1 = (pdfSnippets.length > 1) ? pdfSnippets[(i + 1) % pdfSnippets.length].trim() : 'ناچالاککردنی سەرجەم پرۆتۆکۆلەکان';
          final wrong2 = (pdfSnippets.length > 2) ? pdfSnippets[(i + 2) % pdfSnippets.length].trim() : 'سڕینەوەی هەموو تێکستەکان بەرامبەر داتای نادیار';
          final wrong1Truncated = wrong1.length > 80 ? '${wrong1.substring(0, 80)}...' : (wrong1.isNotEmpty ? wrong1 : 'ڕەتکردنەوەی یاساکانی وانەکە');
          final wrong2Truncated = wrong2.length > 80 ? '${wrong2.substring(0, 80)}...' : (wrong2.isNotEmpty ? wrong2 : 'ناچالاککردنی کردارەکان لە سیستەمەکە');

          final rawOpts = [truncatedSnippet, wrong1Truncated, wrong2Truncated, 'هیچ کام لەمانە'];
          final shuffledOpts = List<String>.from(rawOpts)..shuffle();

          questions.add(
            QuestionModel(
              id: 'fallback_gen_$i',
              questionText: 'کامیان زانیارییەکی ڕاستە دەربارەی بابەتی «$displayTitle»؟',
              type: QuestionType.multipleChoice,
              options: shuffledOpts,
              correctAnswer: truncatedSnippet,
              explanation: 'ئەم زانیارییە بە دروستی دەربارەی دەقی وانەکەت دەرهێنراوە.',
            ),
          );
        } else if (i % 3 == 1) {
          // Fill-in-the-blank
          final blankedSnippet = snippet.length > 90
              ? snippet.substring(0, 90).replaceAll(mainTerm, '___')
              : snippet.replaceAll(mainTerm, '___');

          questions.add(
            QuestionModel(
              id: 'fallback_gen_$i',
              questionText: 'بۆشایی لە دەقی وانەکەدا پڕبکەرەوە: "$blankedSnippet"',
              type: QuestionType.fillInBlank,
              options: null,
              correctAnswer: mainTerm,
              explanation: 'زاراوەی «$mainTerm» دەقی دروستی بۆشایی وانەکەیە.',
            ),
          );
        } else {
          // True/False
          final truncatedSnippet = snippet.length > 120 ? snippet.substring(0, 120) : snippet;
          final isTrue = i % 2 == 0;
          questions.add(
            QuestionModel(
              id: 'fallback_gen_$i',
              questionText: isTrue
                  ? 'دەربارەی وانەی «$displayTitle»: "$truncatedSnippet". ئایا ئەم زانیارییە ڕاستە؟'
                  : 'ئایا چەمکی "$mainTerm" لە وانەی «$displayTitle» بە تەواوی ناچالاک دەکرێت؟',
              type: QuestionType.trueFalse,
              options: ['ڕاستە', 'هەڵەیە'],
              correctAnswer: isTrue ? 'ڕاستە' : 'هەڵەیە',
              explanation: isTrue ? 'ئەم زانیارییە ڕاستە بەپێی وانەکە.' : 'ئەم زانیارییە پێچەوانەی چەمکی زانستی وانەکەیە.',
            ),
          );
        }
      }
    } else {
      for (int i = 0; i < targetCount; i++) {
        final isTrue = i % 2 == 0;
        questions.add(
          QuestionModel(
            id: 'fallback_gen_$i',
            questionText: isTrue
                ? 'لە بابەتی ($displayTitle)، پێداچوونەوە بە چەمکە سەرەکییەکان گرنگە بۆ ئامادەکاری تاقیکردنەوەی فاینەڵ؟'
                : 'لە بابەتی ($displayTitle)، بابەتە تیۆرییەکان گرنگ نین بۆ سەرکەوتن لە تاقیکردنەوەدا؟',
            type: QuestionType.trueFalse,
            options: ['ڕاستە', 'هەڵەیە'],
            correctAnswer: isTrue ? 'ڕاستە' : 'هەڵەیە',
            explanation: isTrue ? 'پێداچوونەوەی ئەم بابەتانە نمرەی بەرز دەستەبەر دەکات.' : 'سەرجەم بابەتەکان بۆ تاقیکردنەوە پێویستن.',
          ),
        );
      }
    }

    return QuizModel(
      id: 'exam_${DateTime.now().millisecondsSinceEpoch}',
      title: 'تاقیکردنەوە لەسەر $displayTitle',
      courseName: displayTitle,
      questions: questions.take(targetCount).toList(),
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
      final q = _activeExam!.questions[i];
      String? userAns = _userAnswers[i];
      if (q.type == QuestionType.fillInBlank) {
        userAns = _blankControllers[i]?.text.trim() ?? userAns;
      }
      if (AiService.isAnswerCorrect(userAns, q.correctAnswer, options: q.options)) {
        score++;
      }
    }
    return score;
  }

  void _exportExamText() {
    if (_activeExam == null) return;

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('==============================');
    buffer.writeln('ZankoAI - ${_activeExam!.title}');
    buffer.writeln('وانە: ${_activeExam!.courseName}');
    buffer.writeln('ماوە: ${_activeExam!.durationMinutes} خولەک');
    buffer.writeln('==============================\n');

    for (int i = 0; i < _activeExam!.questions.length; i++) {
      final q = _activeExam!.questions[i];
      buffer.writeln('${i + 1}. ${q.questionText}');
      if (q.type == QuestionType.multipleChoice && q.options != null) {
        for (var opt in q.options!) {
          buffer.writeln('   [ ] $opt');
        }
      } else if (q.type == QuestionType.trueFalse) {
        buffer.writeln('   [ ] ڕاستە / True');
        buffer.writeln('   [ ] هەڵەیە / False');
      } else if (q.type == QuestionType.fillInBlank) {
        buffer.writeln('   بۆشایی پڕ بکەرەوە: __________________');
      }
      buffer.writeln('   وەڵامی ڕاست: ${q.correctAnswer}');
      if (q.explanation != null && q.explanation!.isNotEmpty) {
        buffer.writeln('   شیکردنەوە: ${q.explanation}');
      }
      buffer.writeln();
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final text = buffer.toString();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تاقیکردنەوەی ئامادەکراو بۆ چاپ', style: TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(text, style: const TextStyle(fontFamily: 'Courier', fontSize: 11.5)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کۆپیکرا بۆ Clipboard!', style: TextStyle(fontFamily: 'Noto Sans Arabic'))),
                );
                Navigator.pop(ctx);
              },
              child: const Text('کۆپیکردن', style: TextStyle(fontFamily: 'Noto Sans Arabic', fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('داخستن', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
            ),
          ],
        );
      },
    );
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
                  child: Icon(CupertinoIcons.sparkles, color: ZankoColors.primary, size: 18),
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
              gradient: LinearGradient(
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
          const SizedBox(height: 16),

          if (!(Provider.of<AuthService>(context, listen: false).currentUser?.isVip ?? false)) ...[
            GestureDetector(
              onTap: () => VipUpgradeSheet.show(context),
              child: Container(
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
                      color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                      blurRadius: 12,
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
                            'تاقیکردنەوەی بێسنووری فاینەڵ (VIP)',
                            style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'تا ٢٠ پرسیاری ئاڵۆز لەسەر هەموو مەلزەمەکانت بەبێ سنوور دروستبکە',
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
            const SizedBox(height: 16),
          ],

          // 1. STEP 1: Source Selection (PDF or Topic)
          _buildLabel('١. سەرچاوەی تاقیکردنەوە (Source)', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPillChoice('📄 لە فایلی PDF', 'pdf', _inputMode == 'pdf', isDark, () {
                setState(() => _inputMode = 'pdf');
              }),
              const SizedBox(width: 8),
              _buildPillChoice('✍️ نووسینی وانە و بابەت', 'topic', _inputMode == 'topic', isDark, () {
                setState(() => _inputMode = 'topic');
              }),
            ],
          ),
          const SizedBox(height: 14),

          if (_inputMode == 'pdf') ...[
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
                                : 'تکایە فایلی PDFی وانەکەت هەڵبژێرە لە مۆبایلەکەت',
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
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEFEFF7),
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _courseController,
                    decoration: InputDecoration(
                      labelText: 'ناوی وانە / کۆرس',
                      hintText: 'نموونە: Operating Systems، فیزیا، یاسا...',
                      prefixIcon: Icon(CupertinoIcons.book_fill, color: ZankoColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _topicController,
                    decoration: InputDecoration(
                      labelText: 'بابەتی دیاریکراو (ئارەزوومەندانە)',
                      hintText: 'نموونە: Memory Management، هاوکێشەکان...',
                      prefixIcon: Icon(CupertinoIcons.tag_fill, color: ZankoColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                          items: const [
                            DropdownMenuItem(value: 5, child: Text('٥ پرسیار (ئاسایی)')),
                            DropdownMenuItem(value: 10, child: Text('١٠ پرسیار 👑 VIP')),
                            DropdownMenuItem(value: 15, child: Text('١٥ پرسیار 👑 VIP')),
                            DropdownMenuItem(value: 20, child: Text('٢٠ پرسیار 👑 VIP')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              final isVip = Provider.of<AuthService>(context, listen: false).currentUser?.isVip ?? false;
                              if (val > 5 && !isVip) {
                                _showVipExamDialog('هەڵبژاردنی $val پرسیار تایبەتە بە ئەندامانی VIP 👑');
                              } else {
                                setState(() => _questionCount = val);
                              }
                            }
                          },
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
                backgroundColor: ZankoColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 6,
                shadowColor: ZankoColors.primary.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.sparkles, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    '🚀 دەستپێکردنی تاقیکردنەوە بە AI',
                    style: TextStyle(
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
              child: Center(
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
                            Expanded(
                              child: Text(
                                'پرسیاری ${_currentQuestionIndex + 1} لە $totalQuestions',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
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
                            valueColor: AlwaysStoppedAnimation<Color>(ZankoColors.primary),
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
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
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
                                  : (currentQuestion.type == QuestionType.fillInBlank
                                      ? 'بۆشایی پڕبکەرەوە'
                                      : 'هەڵبژاردن (MCQ)'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ZankoColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            _inputMode == 'pdf' ? '📄 لە فایلی PDF' : '📚 بەپێی بابەت',
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

                // Question Inputs based on type
                if (currentQuestion.type == QuestionType.fillInBlank) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? ZankoColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0F0F6),
                      ),
                    ),
                    child: TextField(
                      controller: _blankControllers[_currentQuestionIndex] ??= TextEditingController(text: _userAnswers[_currentQuestionIndex] ?? ''),
                      decoration: InputDecoration(
                        labelText: 'وەڵامەکەت لێرە بنووسە',
                        hintText: 'وەڵامی دروستی بۆشایییەکە بنووسە...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(CupertinoIcons.pencil, color: ZankoColors.primary),
                      ),
                      onChanged: (val) {
                        _userAnswers[_currentQuestionIndex] = val.trim();
                      },
                    ),
                  ),
                ] else if (currentQuestion.type == QuestionType.trueFalse) ...[
                  ...['ڕاستە', 'هەڵەیە'].map((opt) {
                    final isSelected = _userAnswers[_currentQuestionIndex] == opt;
                    final isTrueOpt = opt == 'ڕاستە';
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
                                ? (isTrueOpt ? ZankoColors.success.withValues(alpha: 0.15) : ZankoColors.error.withValues(alpha: 0.15))
                                : (isDark ? ZankoColors.darkCard : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? (isTrueOpt ? ZankoColors.success : ZankoColors.error)
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
                                      ? (isTrueOpt ? ZankoColors.success : ZankoColors.error)
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
                                  isTrueOpt ? 'ڕاستە / True ✅' : 'هەڵەیە / False ❌',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? (isTrueOpt ? ZankoColors.success : ZankoColors.error)
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
                ] else if (currentQuestion.options != null && currentQuestion.options!.isNotEmpty) ...[
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
                  'نمرەکەت: $score لە $total پرسیار • کاتی سەرفکراو: $minutesSpentخ $secondsSpentچ',
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
            String? userAns = _userAnswers[idx];
            if (q.type == QuestionType.fillInBlank) {
              userAns = _blankControllers[idx]?.text.trim() ?? userAns;
            }
            final isCorrect = AiService.isAnswerCorrect(userAns, q.correctAnswer, options: q.options);

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
                          Icon(CupertinoIcons.lightbulb_fill, color: ZankoColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
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

          // Action Buttons: Export, Retake, Ask AI
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportExamText,
                  icon: const Icon(CupertinoIcons.share, size: 16),
                  label: const Text('چاپ / هەناردە', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _activeExam = null;
                      _examCompleted = false;
                      _userAnswers.clear();
                      _blankControllers.clear();
                    });
                  },
                  icon: const Icon(CupertinoIcons.refresh, size: 16),
                  label: const Text('دووبارەکردنەوە', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const AiTeacherChatScreen()),
                    );
                  },
                  icon: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 16),
                  label: const Text('AI مامۆستا', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
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
