import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/quiz_model.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
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
  late String _selectedCourse;
  late String _selectedTopic;
  final TextEditingController _customTopicController = TextEditingController();

  String _selectedDifficulty = 'Medium'; // Easy, Medium, Hard
  String _selectedQuestionType = 'Mixed'; // MCQ, True/False, Mixed
  int _questionCount = 10; // 5, 10, 15, 20
  int _durationMinutes = 15; // 5, 10, 15, 30

  String? _pdfFileName;
  String? _pdfFileContent;

  // Active exam state
  bool _isGenerating = false;
  QuizModel? _activeExam;
  int _currentQuestionIndex = 0;
  final Map<int, String> _userAnswers = {};
  bool _examCompleted = false;
  int _timeRemainingSeconds = 0;
  Timer? _examTimer;
  int _secondsSpent = 0;

  final List<String> _courses = [
    'Calculus & Linear Algebra',
    'Machine Learning Fundamentals',
    'Data Structures & Algorithms',
    'Operating Systems',
    'Python & Data Science',
    'Computer Networks & Security',
    'Database Systems & SQL',
    'Software Engineering',
  ];

  final Map<String, List<String>> _courseTopics = {
    'Calculus & Linear Algebra': ['Derivatives & Integrals', 'Matrix Multiplication', 'Vector Spaces', 'Eigenvalues'],
    'Machine Learning Fundamentals': ['Neural Networks', 'Supervised Learning', 'Regression & Classification', 'Deep Learning'],
    'Data Structures & Algorithms': ['Trees & Binary Search', 'Graph Algorithms', 'Sorting & Searching', 'Dynamic Programming'],
    'Operating Systems': ['Memory Management', 'Process Scheduling', 'Deadlocks & Threads', 'File Systems'],
    'Python & Data Science': ['Pandas & DataFrames', 'NumPy Arrays', 'Data Visualization', 'Scikit-Learn ML'],
    'Computer Networks & Security': ['TCP/IP Protocol Stack', 'IP Addressing & Subnetting', 'Network Security & Firewalls', 'HTTP/HTTPS Protocols'],
    'Database Systems & SQL': ['Relational Database Design', 'SQL Queries & Joins', 'Indexing & Transactions', 'Normalization'],
    'Software Engineering': ['Agile & Scrum', 'Design Patterns', 'Git Version Control', 'Software Testing & QA'],
  };

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.initialCourse ?? _courses[0];
    final topics = _courseTopics[_selectedCourse] ?? ['General Review'];
    _selectedTopic = widget.initialTopic ?? topics[0];
    _customTopicController.text = _selectedTopic;
  }

  @override
  void dispose() {
    _customTopicController.dispose();
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
          _pdfFileContent = text.isNotEmpty ? text : 'Lecture Content of ${file.name}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فایلی ${_pdfFileName} بارکرا بە سەرکەوتوویی 📄'),
              backgroundColor: ZankoColors.success,
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

  String _extractTextFromBytes(Uint8List bytes) {
    final pdfString = String.fromCharCodes(bytes);
    final regex = RegExp(r'\((.*?)\)\s*Tj|\((.*?)\)\s*TJ');
    final matches = regex.allMatches(pdfString);
    final buffer = StringBuffer();
    for (final match in matches) {
      final text1 = match.group(1);
      final text2 = match.group(2);
      if (text1 != null) buffer.write('$text1 ');
      if (text2 != null) buffer.write('$text2 ');
    }
    return buffer.toString().trim();
  }

  // ─── Start Exam ────────────────────────────────────────────────────────────
  Future<void> _generateAndStartExam() async {
    final aiService = Provider.of<AiService>(context, listen: false);

    setState(() {
      _isGenerating = true;
      _activeExam = null;
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _examCompleted = false;
      _secondsSpent = 0;
    });

    final topicToUse = _customTopicController.text.trim().isNotEmpty
        ? _customTopicController.text.trim()
        : _selectedTopic;

    try {
      QuizModel exam;
      if (aiService is ZankoAiService) {
        exam = await aiService.generateCustomExam(
          courseName: _selectedCourse,
          topic: topicToUse,
          difficulty: _selectedDifficulty,
          questionType: _selectedQuestionType,
          questionCount: _questionCount,
          durationMinutes: _durationMinutes,
          pdfContent: _pdfFileContent,
        );
      } else {
        exam = await aiService.generateQuiz(topicToUse, _selectedCourse);
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
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵەیەک ڕوویدا لە دروستکردنی تاقیکردنەوە: $e'),
            backgroundColor: ZankoColors.error,
          ),
        );
      }
    }
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
      child: Scaffold(
        backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
        appBar: AppBar(
          backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.sparkles, color: ZankoColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'دروستکەری تاقیکردنەوەی AI',
                style: TextStyle(
                  fontSize: 18,
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
                  ? _buildConfigState(isDark)
                  : _examCompleted
                      ? _buildResultsState(isDark)
                      : _buildExamRunningState(isDark),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. CONFIG STATE (دەستکاری و سازدانی تاقیکردنەوە)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildConfigState(bool isDark) {
    final topics = _courseTopics[_selectedCourse] ?? ['General Review'];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ZankoColors.primary, ZankoColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: ZankoColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
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
                        'تاقیکردنەوەی ئەزموونی دروست بکە 🎯',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'AI پرسیارەکان لەسەر وانەکەت یان فایلی PDF ڕاستەوخۆ بە زمانی کوردی دروست دەکات.',
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

          // 1. Select Course
          _buildLabel('١. وانەکە هەڵبژێرە (Course)', isDark),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? ZankoColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCourse,
                isExpanded: true,
                dropdownColor: isDark ? ZankoColors.darkCard : Colors.white,
                items: _courses
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCourse = val;
                      final tList = _courseTopics[val] ?? ['General Review'];
                      _selectedTopic = tList[0];
                      _customTopicController.text = _selectedTopic;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Topic
          _buildLabel('٢. بابەت یان بەشی وانەکە (Topic / Chapter)', isDark),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topics.map((tp) {
              final isSel = _selectedTopic == tp;
              return ChoiceChip(
                label: Text(tp),
                selected: isSel,
                selectedColor: ZankoColors.primary,
                backgroundColor: isDark ? ZankoColors.darkCard : Colors.grey[200],
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : (isDark ? Colors.grey[300] : Colors.black87),
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedTopic = tp;
                      _customTopicController.text = tp;
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customTopicController,
            style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'یان بابەتی دیاریکراو بە دەستی خۆت بنووسە...',
              hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[400]),
              filled: true,
              fillColor: isDark ? ZankoColors.darkCard : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Attach PDF Option
          _buildLabel('٣. بارکردنی فایلی PDFی وانەکە (بە ئارەزوومەندانه)', isDark),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickPdfFile,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _pdfFileName != null
                      ? ZankoColors.primary
                      : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7)),
                  width: _pdfFileName != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _pdfFileName != null ? CupertinoIcons.doc_checkmark_fill : CupertinoIcons.arrow_up_doc,
                    color: _pdfFileName != null ? ZankoColors.primary : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _pdfFileName ?? 'بارکردنی فایلی PDF بۆ ئەوەی پرسیارەکان لە فایلی دەرسەکە بن',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _pdfFileName != null ? FontWeight.bold : FontWeight.w500,
                        color: _pdfFileName != null
                            ? ZankoColors.primary
                            : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_pdfFileName != null)
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey, size: 20),
                      onPressed: () => setState(() {
                        _pdfFileName = null;
                        _pdfFileContent = null;
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Difficulty Level
          _buildLabel('٤. ئاستی زەحمەتی (Difficulty)', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPillChoice('Easy (ئاسان)', 'Easy', _selectedDifficulty == 'Easy', isDark, () {
                setState(() => _selectedDifficulty = 'Easy');
              }),
              const SizedBox(width: 8),
              _buildPillChoice('Medium (ناوەند)', 'Medium', _selectedDifficulty == 'Medium', isDark, () {
                setState(() => _selectedDifficulty = 'Medium');
              }),
              const SizedBox(width: 8),
              _buildPillChoice('Hard (زانکۆ🔥)', 'Hard', _selectedDifficulty == 'Hard', isDark, () {
                setState(() => _selectedDifficulty = 'Hard');
              }),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Question Type
          _buildLabel('٥. جۆری پرسیارەکان (Question Type)', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPillChoice('تێکەڵ (Mixed)', 'Mixed', _selectedQuestionType == 'Mixed', isDark, () {
                setState(() => _selectedQuestionType = 'Mixed');
              }),
              const SizedBox(width: 8),
              _buildPillChoice('هەڵبژاردن (MCQ)', 'MCQ', _selectedQuestionType == 'MCQ', isDark, () {
                setState(() => _selectedQuestionType = 'MCQ');
              }),
              const SizedBox(width: 8),
              _buildPillChoice('ڕاست/هەڵە', 'TrueFalse', _selectedQuestionType == 'TrueFalse', isDark, () {
                setState(() => _selectedQuestionType = 'TrueFalse');
              }),
            ],
          ),
          const SizedBox(height: 20),

          // 6. Question Count & Duration
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
                        borderRadius: BorderRadius.circular(14),
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
                        borderRadius: BorderRadius.circular(14),
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
            height: 56,
            child: ElevatedButton(
              onPressed: _generateAndStartExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: ZankoColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    '🚀 دروستکردنی تاقیکردنەوە و دەستپێکردن',
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
          const SizedBox(height: 20),
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
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
  // 2. GENERATING STATE (کاتی دروستکردنی تاقیکردنەوە بە AI)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGeneratingState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ZankoColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(color: ZankoColors.primary, strokeWidth: 3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '🤖 AI خەریکی داڕشتنی پرسیارەکانی تاقیکردنەوەیەکە...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'پرسیارەکان بە هەڵسەنگاندنی تێر و تەسەل و شیکردنەوە بە زمانی کوردی ئامادە دەکرێن.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. EXAM RUNNING STATE (کەشی تاقیکردنەوە)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildExamRunningState(bool isDark) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEFEFF7),
              ),
            ),
          ),
          child: Row(
            children: [
              // Timer Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _timeRemainingSeconds < 60
                      ? ZankoColors.error.withValues(alpha: 0.15)
                      : ZankoColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.timer,
                      size: 16,
                      color: _timeRemainingSeconds < 60 ? ZankoColors.error : ZankoColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _timeRemainingSeconds < 60 ? ZankoColors.error : ZankoColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Question progress
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
                            fontSize: 12,
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
        ),

        // Main Question Content
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
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? ZankoColors.primary
                                      : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),
                                ),
                                child: Center(
                                  child: isSelected
                                      ? const Icon(CupertinoIcons.checkmark_alt, size: 16, color: Colors.white)
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

        // Bottom Navigation Actions
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
  // 4. RESULTS STATE (کارتی ئەنجام و شیکردنەوەی AI)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildResultsState(bool isDark) {
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
          // Header Card
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
                  color: (isPassed ? ZankoColors.success : ZankoColors.error).withValues(alpha: 0.3),
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
