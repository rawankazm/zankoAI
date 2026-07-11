import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';

class ExamPredictorView extends StatefulWidget {
  const ExamPredictorView({super.key});

  @override
  State<ExamPredictorView> createState() => _ExamPredictorViewState();
}

class _ExamPredictorViewState extends State<ExamPredictorView> {
  final TextEditingController _textController = TextEditingController();
  String _fileName = '';
  String _fileContent = '';
  bool _isLoading = false;
  String _predictionResult = '';

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md'],
      );

      if (result != null) {
        final file = result.files.single;
        setState(() {
          _fileName = file.name;
          if (file.bytes != null) {
            _fileContent = String.fromCharCodes(file.bytes!);
            _textController.text = _fileContent;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _getPrediction() async {
    final notes = _textController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter notes or upload a file first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _predictionResult = '';
    });

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final res = await aiService.predictExam(_fileName.isNotEmpty ? _fileName : 'CustomNotes.txt', notes);
      setState(() {
        _predictionResult = res['prediction'] ?? '';
      });
    } catch (e) {
      setState(() {
        _predictionResult = 'Error generating prediction: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    // Translations
    final String title = langProvider.currentLanguage == AppLanguage.english
        ? 'Exam Predictor'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'مستشار الامتحان الذكي'
            : 'پێشبینیکەری تاقیکردنەوە';

    final String inputLabel = langProvider.currentLanguage == AppLanguage.english
        ? 'Paste your study notes or lesson contents'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'الصق ملاحظات الدراسة أو محتوى الدرس'
            : 'تێبینییەکانی خوێندن یان دەقی بابەتەکە لێرە دابنێ';

    final String orLabel = langProvider.currentLanguage == AppLanguage.english
        ? 'OR'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'أو'
            : 'یاخود';

    final String uploadButton = langProvider.currentLanguage == AppLanguage.english
        ? 'Upload Text/Markdown File'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'تحميل ملف نصي (Text/Markdown)'
            : 'بارکردنی فایلی دەقی (Text/Markdown)';

    final String predictButton = langProvider.currentLanguage == AppLanguage.english
        ? 'Predict Exam Questions'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'توقع أسئلة الامتحان'
            : 'پێشبینیکردنی پرسیارەکان';

    final String resultLabel = langProvider.currentLanguage == AppLanguage.english
        ? 'Predicted Questions & Tips'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'الأسئلة المتوقعة والنصائح'
            : 'پرسیارە پێشبینیکراوەکان و ڕێنماییەکان';

    final String loadingText = langProvider.currentLanguage == AppLanguage.english
        ? 'AI is analyzing your notes & predicting questions...'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'يقوم الذكاء الاصطناعي بتحليل الملاحظات وتوقع الأسئلة...'
            : 'ژیری دەستکرد خەریکی شیکردنەوەی تێبینییەکان و پێشبینیکردنی پرسیارەکانە...';

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
              // Info Card
              Card(
                color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.psychology_outlined, color: theme.colorScheme.primary, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          langProvider.currentLanguage == AppLanguage.english
                              ? 'Enter your lectures notes, syllabus, or content to let Gemini AI predict what is likely to show up in your exam.'
                              : langProvider.currentLanguage == AppLanguage.arabic
                                  ? 'أدخل ملاحظات المحاضرة أو المنهج ليقوم الذكاء الاصطناعي بتوقع الأسئلة المتوقعة في الامتحان.'
                                  : 'تێبینییەکانی وانەکەت یان دەستپێکی بەشەکە بنووسە بۆ ئەوەی ژیری دەستکرد پێشبینی ئەو پرسیارانە بکات کە ئەگەری زۆرە لە تاقیکردنەوەدا بێنەوە.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: 'Noto Sans Arabic',
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Text Field Input
              Text(
                inputLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Noto Sans Arabic'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: langProvider.currentLanguage == AppLanguage.english
                      ? 'Type or paste here...'
                      : langProvider.currentLanguage == AppLanguage.arabic
                          ? 'اكتب أو الصق هنا...'
                          : 'لێرە بنووسە یان کۆپی بکە...',
                  hintStyle: const TextStyle(fontSize: 13, fontFamily: 'Noto Sans Arabic'),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),

              Center(
                child: Text(
                  orLabel,
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary.withOpacity(0.6)),
                ),
              ),
              const SizedBox(height: 12),

              // File Picker
              SizedBox(
                width: double.maxFinite,
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(uploadButton, style: const TextStyle(fontFamily: 'Noto Sans Arabic')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_fileName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '📂 $_fileName',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),

              // Predict Button
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _getPrediction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(predictButton, style: const TextStyle(fontSize: 15, fontFamily: 'Noto Sans Arabic')),
                ),
              ),
              const SizedBox(height: 24),

              if (_isLoading) ...[
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        loadingText,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Noto Sans Arabic'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

              // Results Screen
              if (_predictionResult.isNotEmpty) ...[
                Text(
                  resultLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Noto Sans Arabic'),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectionArea(
                      child: Text(
                        _predictionResult,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.6,
                          fontFamily: 'Noto Sans Arabic',
                        ),
                      ),
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
}
