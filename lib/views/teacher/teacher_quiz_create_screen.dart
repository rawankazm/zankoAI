import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/ai_service.dart';
import '../../models/quiz_model.dart';

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

    try {
      final quiz = await aiService.generateQuiz(
        _topicController.text.trim(),
        _courseController.text.trim().isEmpty
            ? 'تۆڕەکان'
            : _courseController.text.trim(),
      );

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
            content: Text('هەڵەیەک ڕوویدا لە دروستکردنی کویز: $e',
                style: const TextStyle()),
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
    const purple = Color(0xFF7C3AED);

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('teacher_quiz_title'),
              style: const TextStyle()),
          centerTitle: true,
          backgroundColor: purple,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Course field ───────────────────────────────────
              TextField(
                controller: _courseController,
                decoration: InputDecoration(
                  labelText: t('quiz_for_course'),
                  prefixIcon: const Icon(Icons.book_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                style: const TextStyle(),
              ),
              const SizedBox(height: 14),

              // ─── Topic field ────────────────────────────────────
              TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  labelText: t('topic_field'),
                  hintText: t('quiz_topic_hint'),
                  prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                maxLines: 2,
                style: const TextStyle(),
              ),
              const SizedBox(height: 20),

              // ─── Number of Questions slider ─────────────────────
              Row(
                children: [
                  Text(t('quiz_num_questions'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$_numQuestions',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: purple,
                            fontSize: 16)),
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
              Text(t('quiz_difficulty'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: ['easy', 'medium', 'hard'].map((d) {
                  final label = d == 'easy'
                      ? t('difficulty_easy')
                      : d == 'medium'
                          ? t('difficulty_medium')
                          : t('difficulty_hard');
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
                          border:
                              Border.all(color: color, width: isSelected ? 0 : 1),
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _isGenerating
                      ? t('generating_quiz_wait')
                      : t('generate_and_share'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),

              // ─── Generated Questions Preview ────────────────────
              if (_quizCreated && _generatedQuestions.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Text(t('quiz_created_success'),
                        style: const TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                ...List.generate(_generatedQuestions.length, (i) {
                  final q = _generatedQuestions[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: purple.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ${q.questionText}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (q.options != null)
                          ...q.options!.map((opt) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(opt,
                                    style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.7))),
                              )),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                // Share button
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('کویزەکە بە قوتابییەکان ناردرا! 🎉',
                            style: const TextStyle()),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: Text(t('generate_and_share'),
                      style: const TextStyle()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: purple,
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
