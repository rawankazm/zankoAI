import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/ai_service.dart';
import '../../services/database_service.dart';
import '../../models/quiz_model.dart';
import '../../theme.dart';

class TeacherQuizCreateScreen extends StatefulWidget {
  const TeacherQuizCreateScreen({super.key});

  @override
  State<TeacherQuizCreateScreen> createState() =>
      _TeacherQuizCreateScreenState();
}

class _TeacherQuizCreateScreenState extends State<TeacherQuizCreateScreen> {
  final _topicController = TextEditingController();
  final _courseController = TextEditingController();
  int _numQuestions = 5;
  String _difficulty = 'medium';
  bool _isExam = false;
  int _durationMinutes = 15;
  double _passingScore = 60.0;
  bool _isGenerating = false;
  bool _quizCreated = false;
  List<QuestionModel> _generatedQuestions = [];

  @override
  void dispose() {
    _topicController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  Future<void> _generateQuiz() async {
    if (_topicController.text.trim().isEmpty) return;

    setState(() {
      _isGenerating = true;
      _quizCreated = false;
      _generatedQuestions = [];
    });

    final aiService = Provider.of<AiService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    try {
      final quiz = await aiService.generateQuiz(
        _topicController.text.trim(),
        _courseController.text.trim().isEmpty
            ? 'تۆڕەکان'
            : _courseController.text.trim(),
      );

      final fullQuiz = QuizModel(
        id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
        title: quiz.title,
        courseName: quiz.courseName,
        questions: quiz.questions,
        durationMinutes: _durationMinutes,
        isExam: _isExam,
        passingScorePercentage: _passingScore,
      );

      await db.addQuiz(fullQuiz);

      setState(() {
        _isGenerating = false;
        _quizCreated = true;
        _generatedQuestions = quiz.questions;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _quizCreated = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵەیەک ڕوویدا لە دروستکردن: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Provider.of<LanguageProvider>(context);
    String t(String key) => lang.translate(key);
    final purple = ZankoColors.primary;

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isExam ? t('create_exam') : t('quiz_maker')),
          centerTitle: true,
          backgroundColor: purple,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Mode Switcher (Quiz vs Exam) ─────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isExam = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isExam ? purple : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t('nav_quiz'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_isExam ? Colors.white : purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isExam = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isExam ? purple : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'تاقیکردنەوەی فەرمی (Exam)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isExam ? Colors.white : purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ─── Course field ───────────────────────────────────
              TextField(
                controller: _courseController,
                decoration: InputDecoration(
                  labelText: t('select_course'),
                  prefixIcon: const Icon(Icons.book_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),

              // ─── Topic field ────────────────────────────────────
              TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  labelText: t('select_topic'),
                  prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // ─── Time & Passing Score Controls ────────────────
              if (_isExam) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('duration_minutes'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _durationMinutes,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 15, child: Text('١٥ خولەک')),
                              DropdownMenuItem(value: 30, child: Text('٣٠ خولەک')),
                              DropdownMenuItem(value: 45, child: Text('٤٥ خولەک')),
                              DropdownMenuItem(value: 60, child: Text('٦٠ خولەک')),
                            ],
                            onChanged: (v) => setState(() => _durationMinutes = v ?? 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('passing_score'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<double>(
                            value: _passingScore,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 50.0, child: Text('50%')),
                              DropdownMenuItem(value: 60.0, child: Text('60%')),
                              DropdownMenuItem(value: 70.0, child: Text('70%')),
                              DropdownMenuItem(value: 80.0, child: Text('80%')),
                            ],
                            onChanged: (v) => setState(() => _passingScore = v ?? 60.0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // ─── Number of Questions slider ─────────────────────
              Row(
                children: [
                  Text(t('quizzes'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$_numQuestions',
                        style: TextStyle(fontWeight: FontWeight.bold, color: purple, fontSize: 16)),
                  ),
                ],
              ),
              Slider(
                value: _numQuestions.toDouble(),
                min: 3,
                max: 20,
                divisions: 17,
                activeColor: purple,
                onChanged: (v) => setState(() => _numQuestions = v.round()),
              ),
              const SizedBox(height: 14),

              // ─── Difficulty ─────────────────────────────────────
              Row(
                children: ['easy', 'medium', 'hard'].map((d) {
                  final label = d == 'easy'
                      ? 'ئاسان'
                      : d == 'medium'
                          ? 'ناوەند'
                          : 'سەخت';
                  final color = d == 'easy'
                      ? const Color(0xFF059669)
                      : d == 'medium'
                          ? const Color(0xFFD97706)
                          : const Color(0xFFDC2626);
                  final isSelected = _difficulty == d;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _difficulty = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? color : color.withOpacity(0.08),
                          border: Border.all(color: color, width: isSelected ? 0 : 1),
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : color,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // ─── Generate Button ────────────────────────────────
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateQuiz,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _isGenerating
                      ? 'دروستکردن لەڕێگەی AI...'
                      : _isExam
                          ? 'دروستکردنی تاقیکردنەوە بە AI 🚀'
                          : 'دروستکردنی کویز بە AI 🚀',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),

              // ─── Generated Questions Preview ────────────────────
              if (_quizCreated && _generatedQuestions.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Text(
                      _isExam ? 'تاقیکردنەوەکە دروستکرا و خەزنکرا! ✅' : 'کویزەکە دروستکرا و خەزنکرا! ✅',
                      style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...List.generate(_generatedQuestions.length, (i) {
                  final q = _generatedQuestions[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: purple.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ${q.questionText}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (q.options != null)
                          ...q.options!.map((opt) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(opt, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                              )),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
