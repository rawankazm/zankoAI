import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';
import '../../models/study_plan_model.dart';

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(text: '7');
  bool _isGenerating = false;
  List<StudyPlanDayModel> _studyPlan = [];

  @override
  void dispose() {
    _topicController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    final topic = _topicController.text.trim();
    final days = int.tryParse(_daysController.text.trim()) ?? 7;

    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە ناوی بابەتەکە بنووسە', style: TextStyle(fontFamily: 'Noto Sans Arabic'))),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _studyPlan.clear();
    });

    final aiService = Provider.of<AiService>(context, listen: false);
    try {
      final plan = await aiService.generateStudyPlan(topic, days);
      setState(() {
        _studyPlan = plan;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate study plan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    // Translations
    final String title = langProvider.currentLanguage == AppLanguage.english
        ? 'AI Study Planner'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'مخطط الدراسة الذكي'
            : 'داڕشتنی پلانی خوێندن بە AI';

    final String cardTitle = langProvider.currentLanguage == AppLanguage.english
        ? 'Create Study Schedule'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'إنشاء جدول دراسة جديد'
            : 'پلانێکی نوێ داڕێژە';

    final String topicLabel = langProvider.currentLanguage == AppLanguage.english
        ? 'Course / Exam Topic'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'المادة أو موضوع الامتحان'
            : 'ناوی بابەت یان تاقیکردنەوە';

    final String daysLabel = langProvider.currentLanguage == AppLanguage.english
        ? 'Days Remaining'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'الأيام المتبقية'
            : 'ڕۆژەکانی ماوە بۆ تاقیکردنەوە';

    final String generateBtn = langProvider.currentLanguage == AppLanguage.english
        ? 'Generate Study Plan'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'توليد خطة الدراسة'
            : 'پلانی خوێندن داڕێژە';

    final String emptyState = langProvider.currentLanguage == AppLanguage.english
        ? 'Your generated study schedule will appear here.'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'ستظهر خطتك الدراسية المقترحة هنا.'
            : 'پلانەکەت لێرەدا نیشان دەدرێت.';

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Inputs card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        cardTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Noto Sans Arabic'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _topicController,
                        decoration: InputDecoration(
                          labelText: topicLabel,
                          hintText: 'e.g. Operating Systems Final Exam',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _daysController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: daysLabel,
                          hintText: '7',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _isGenerating
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _generatePlan,
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(generateBtn),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_studyPlan.isEmpty && !_isGenerating)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(emptyState, style: const TextStyle(fontFamily: 'Noto Sans Arabic', color: Colors.grey)),
                  ),
                )
              else ...[
                // Vertical Timeline
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _studyPlan.length,
                  itemBuilder: (context, index) {
                    final day = _studyPlan[index];
                    return IntrinsicHeight(
                      child: Row(
                        children: [
                          // Left side line nodes
                          Column(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    (index + 1).toString(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ),
                              if (index < _studyPlan.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 2.5,
                                    color: theme.colorScheme.primary.withOpacity(0.3),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Content Card
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        day.dayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: theme.colorScheme.primary,
                                          fontFamily: 'Noto Sans Arabic',
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        day.taskDescription,
                                        style: const TextStyle(fontFamily: 'Noto Sans Arabic', height: 1.4, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
