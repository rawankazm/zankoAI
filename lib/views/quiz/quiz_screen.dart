import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/ai_service.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
import '../../models/quiz_model.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();

  String? _quizFileName;
  String? _quizFileContent;
  bool _isGenerating = false;
  QuizModel? _activeQuiz;
  int _currentQuestionIndex = 0;
  Map<int, String> _userAnswers = {}; // Maps question index to selected answer
  bool _quizCompleted = false;
  int _score = 0;

  // Controllers for Fill in the Blank inputs
  final Map<int, TextEditingController> _blankControllers = {};

  @override
  void dispose() {
    _topicController.dispose();
    _courseController.dispose();
    for (var controller in _blankControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Helper to extract text from PDF binary
  String _extractTextFromPdfBytes(Uint8List bytes) {
    final pdfString = String.fromCharCodes(bytes);
    final regex = RegExp(r'\((.*?)\)\s*Tj|\((.*?)\)\s*TJ');
    final matches = regex.allMatches(pdfString);
    
    StringBuffer buffer = StringBuffer();
    for (var match in matches) {
      final text = match.group(1) ?? match.group(2) ?? '';
      if (text.isNotEmpty) {
        buffer.write(text);
        buffer.write(' ');
      }
    }
    
    if (buffer.isEmpty) {
      final fallbackRegex = RegExp(r'\(([^)]+)\)');
      final fallbackMatches = fallbackRegex.allMatches(pdfString);
      for (var match in fallbackMatches) {
        final text = match.group(1) ?? '';
        if (text.length > 3 && !text.startsWith('/') && !text.contains(RegExp(r'[0-9]{4}'))) {
          buffer.write(text);
          buffer.write(' ');
        }
      }
    }
    
    return buffer.toString().trim();
  }

  Future<void> _pickQuizFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md'],
      );

      if (result != null) {
        final file = result.files.single;
        
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        
        if (bytes != null) {
          String text = '';
          if (file.name.toLowerCase().endsWith('.pdf')) {
            text = _extractTextFromPdfBytes(bytes);
          } else {
            text = String.fromCharCodes(bytes);
          }
          
          setState(() {
            _quizFileName = file.name;
            _quizFileContent = text;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load file: $e')),
      );
    }
  }

  Future<void> _generateQuiz() async {
    final topic = _topicController.text.trim();
    final course = _courseController.text.trim();
    
    if (course.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە ناوی وانە بنووسە', style: TextStyle(fontFamily: 'Noto Sans Arabic'))),
      );
      return;
    }

    if (topic.isEmpty && _quizFileContent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە بابەت یان فایلێک دیاری بکە', style: TextStyle(fontFamily: 'Noto Sans Arabic'))),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _activeQuiz = null;
      _quizCompleted = false;
      _userAnswers.clear();
      _currentQuestionIndex = 0;
      _blankControllers.clear();
    });

    final aiService = Provider.of<AiService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    try {
      QuizModel quiz;
      if (_quizFileContent != null && _quizFileContent!.isNotEmpty) {
        quiz = await aiService.generateQuizFromText(_quizFileContent!, course);
      } else {
        quiz = await aiService.generateQuiz(topic, course);
      }

      await dbService.addQuiz(quiz);
      
      // Initialize text controllers for fill-in-the-blank questions
      for (int i = 0; i < quiz.questions.length; i++) {
        if (quiz.questions[i].type == QuestionType.fillInBlank) {
          _blankControllers[i] = TextEditingController();
        }
      }

      setState(() {
        _activeQuiz = quiz;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('هەڵەیەک ڕوویدا لە دروستکردنی کویز: $e', style: const TextStyle(fontFamily: 'Noto Sans Arabic'))),
      );
    }
  }

  void _submitQuiz() {
    if (_activeQuiz == null) return;
    
    int score = 0;
    for (int i = 0; i < _activeQuiz!.questions.length; i++) {
      final q = _activeQuiz!.questions[i];
      String userAnswer = '';
      
      if (q.type == QuestionType.fillInBlank) {
        userAnswer = _blankControllers[i]?.text.trim() ?? '';
      } else {
        userAnswer = _userAnswers[i] ?? '';
      }

      if (userAnswer.toLowerCase() == q.correctAnswer.toLowerCase()) {
        score++;
      }
    }

    setState(() {
      _score = score;
      _quizCompleted = true;
    });
  }

  void _exportQuizText() {
    if (_activeQuiz == null) return;
    
    StringBuffer buffer = StringBuffer();
    buffer.writeln('==============================');
    buffer.writeln('ZankoAI - ${_activeQuiz!.title}');
    buffer.writeln('وانە: ${_activeQuiz!.courseName}');
    buffer.writeln('==============================\n');
    
    for (int i = 0; i < _activeQuiz!.questions.length; i++) {
      final q = _activeQuiz!.questions[i];
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
      buffer.writeln('   وەڵامی ڕاست (Correct Answer): ${q.correctAnswer}\n');
    }
    
    showDialog(
      context: context,
      builder: (context) {
        final text = buffer.toString();
        return AlertDialog(
          title: const Text('تاقیکردنەوەی ئامادەکراو بۆ چاپ', style: TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(text, style: const TextStyle(fontFamily: 'Courier', fontSize: 11)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کۆپیکرا بۆ Clipboard!', style: TextStyle(fontFamily: 'Noto Sans Arabic'))),
                );
                Navigator.pop(context);
              },
              child: const Text('کۆپیکردن', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('داخستن', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
            ),
          ],
        );
      },
    );
  }

  void _resetScreen() {
    setState(() {
      _activeQuiz = null;
      _quizCompleted = false;
      _userAnswers.clear();
      _currentQuestionIndex = 0;
      _blankControllers.clear();
      _quizFileName = null;
      _quizFileContent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dbService = Provider.of<DatabaseService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('quiz_title')),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_activeQuiz == null && !_isGenerating) ...[
                // Quiz Generator Form
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('generate_quiz_title'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Noto Sans Arabic'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('generate_quiz_desc'),
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Noto Sans Arabic'),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _courseController,
                          decoration: InputDecoration(
                            labelText: t('course_name_field'),
                            hintText: 'e.g. Operating Systems, Networks',
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Option 1: File Pick
                        SizedBox(
                          width: double.maxFinite,
                          child: OutlinedButton.icon(
                            onPressed: _pickQuizFile,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: Text(_quizFileName != null ? _quizFileName! : 'بارکردنی پەڕگە / فایل (PDF, TXT)'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        const Center(child: Text('یان / Or', style: TextStyle(fontSize: 12, color: Colors.grey))),
                        const SizedBox(height: 12),
                        
                        // Option 2: Topic name text
                        TextField(
                          controller: _topicController,
                          decoration: InputDecoration(
                            labelText: t('topic_field'),
                            hintText: 'e.g. Memory management, TCP/IP',
                          ),
                          enabled: _quizFileContent == null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.maxFinite,
                          child: ElevatedButton(
                            onPressed: _generateQuiz,
                            child: Text(t('generate_quiz_btn')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quiz History
                Text(
                  t('previous_quizzes'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Noto Sans Arabic',
                  ),
                ),
                const SizedBox(height: 12),
                if (dbService.quizzes.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('هیچ کویزێکی پێشوو نییە', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
                    ),
                  )
                else
                  ...dbService.quizzes.map((quiz) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.assignment, color: Colors.white),
                        ),
                        title: Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic', fontSize: 13)),
                        subtitle: Text(quiz.courseName, style: const TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 11)),
                        trailing: const Icon(Icons.play_arrow, color: Colors.green),
                        onTap: () {
                          setState(() {
                            _activeQuiz = quiz;
                            _quizCompleted = false;
                            _currentQuestionIndex = 0;
                            _userAnswers.clear();
                            _blankControllers.clear();
                            for (int i = 0; i < quiz.questions.length; i++) {
                              if (quiz.questions[i].type == QuestionType.fillInBlank) {
                                _blankControllers[i] = TextEditingController();
                              }
                            }
                          });
                        },
                      ),
                    );
                  }),
              ],

              if (_isGenerating)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          t('generating_quiz_wait'),
                          style: const TextStyle(fontFamily: 'Noto Sans Arabic'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Active Quiz Screen
              if (_activeQuiz != null && !_quizCompleted) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _activeQuiz!.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Noto Sans Arabic'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${t('question_progress')} ${_currentQuestionIndex + 1} / ${_activeQuiz!.questions.length}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'Noto Sans Arabic'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _activeQuiz!.questions.length,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 24),
                
                // Question Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeQuiz!.questions[_currentQuestionIndex].questionText,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic'),
                        ),
                        const SizedBox(height: 20),
                        
                        // Question Options
                        ..._buildQuestionInputs(_activeQuiz!.questions[_currentQuestionIndex], _currentQuestionIndex),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Navigation Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentQuestionIndex > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _currentQuestionIndex--;
                            });
                          },
                          child: Text(t('previous_btn')),
                        ),
                      )
                    else
                      const Spacer(),
                      
                    const SizedBox(width: 12),
                    
                    if (_currentQuestionIndex < _activeQuiz!.questions.length - 1)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _currentQuestionIndex++;
                            });
                          },
                          child: Text(t('next_btn')),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitQuiz,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: Text(t('submit_btn')),
                        ),
                      ),
                  ],
                ),
              ],

              // Quiz Score Screen
              if (_quizCompleted && _activeQuiz != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, size: 80, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text(
                          t('quiz_completed'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${t('your_score')}: $_score / ${_activeQuiz!.questions.length}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _score == _activeQuiz!.questions.length ? Colors.green : Colors.blue,
                            fontFamily: 'Noto Sans Arabic',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _score == _activeQuiz!.questions.length
                              ? t('score_perfect')
                              : t('score_good'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Noto Sans Arabic', color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _resetScreen,
                              child: Text(t('back_to_quiz_home')),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _exportQuizText,
                              icon: const Icon(Icons.print_rounded),
                              label: const Text('چاپ / Export', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuestionInputs(QuestionModel question, int questionIndex) {
    if (question.type == QuestionType.trueFalse) {
      return [
        ListTile(
          title: const Text('ڕاستە / True', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
          leading: Radio<String>(
            value: 'ڕاستە',
            groupValue: _userAnswers[questionIndex],
            onChanged: (val) {
              setState(() {
                _userAnswers[questionIndex] = val!;
              });
            },
          ),
        ),
        ListTile(
          title: const Text('هەڵەیە / False', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
          leading: Radio<String>(
            value: 'هەڵەیە',
            groupValue: _userAnswers[questionIndex],
            onChanged: (val) {
              setState(() {
                _userAnswers[questionIndex] = val!;
              });
            },
          ),
        ),
      ];
    } else if (question.type == QuestionType.multipleChoice && question.options != null) {
      return question.options!.map((opt) {
        return ListTile(
          title: Text(opt, style: const TextStyle(fontFamily: 'Noto Sans Arabic')),
          leading: Radio<String>(
            value: opt,
            groupValue: _userAnswers[questionIndex],
            onChanged: (val) {
              setState(() {
                _userAnswers[questionIndex] = val!;
              });
            },
          ),
        );
      }).toList();
    } else if (question.type == QuestionType.fillInBlank) {
      final controller = _blankControllers[questionIndex] ?? TextEditingController();
      return [
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Type answer...',
          ),
          onChanged: (value) {
            _userAnswers[questionIndex] = value.trim();
          },
        ),
      ];
    }
    
    return [const SizedBox()];
  }
}
