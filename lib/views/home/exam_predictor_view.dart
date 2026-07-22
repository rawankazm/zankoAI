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
        SnackBar(content: Text('${Provider.of<LanguageProvider>(context, listen: false).translate('error')}: $e')),
      );
    }
  }

  Future<void> _getPrediction() async {
    final notes = _textController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('please_enter_notes'))),
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

    final lang = Provider.of<LanguageProvider>(context);
    String t(String key) => lang.translate(key);

    // Translations
    final String title = t('exam_predictor_title');
    final String inputLabel = t('exam_predictor_input_label');
    final String orLabel = t('exam_predictor_or_label');
    final String uploadButton = t('exam_predictor_upload_btn');
    final String predictButton = t('exam_predictor_predict_btn');
    final String resultLabel = t('exam_predictor_result_label');
    final String loadingText = t('exam_predictor_loading');

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
                          t('exam_predictor_info'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant,
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: t('exam_predictor_hint'),
                  hintStyle: const TextStyle(fontSize: 13, ),
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
                  label: Text(uploadButton, style: const TextStyle()),
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
                      : Text(predictButton, style: const TextStyle(fontSize: 15, )),
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
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, ),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, ),
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
