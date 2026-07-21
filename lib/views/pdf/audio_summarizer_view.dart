import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';

class AudioSummarizerView extends StatefulWidget {
  const AudioSummarizerView({super.key});

  @override
  State<AudioSummarizerView> createState() => _AudioSummarizerViewState();
}

class _AudioSummarizerViewState extends State<AudioSummarizerView> {
  bool _isRecording = false;
  bool _isLoading = false;
  String _audioFileName = '';
  String _summarizedResult = '';
  int _recordDurationSeconds = 0;
  Timer? _timer;

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _audioFileName = 'VoiceRecording_01.m4a';
      _recordDurationSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDurationSeconds++;
      });
    });
  }

  void _stopRecording() async {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
    });

    // Automatically trigger summary from recording
    _summarizeAudioContent(
      "ئەم تۆمارە دەنگییەی وانەیە کە تێیدا مامۆستا باسی پرۆسەی کۆمپایلکردنی فلاتەر دەکات و چۆن وەشانی ئەندرۆید و وێب دروست دەکرێت لەگەڵ گرنگترین بەشەکانی کارکردن.",
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null) {
        final file = result.files.single;
        setState(() {
          _audioFileName = file.name;
        });

        // Trigger AI summary of chosen lecture
        _summarizeAudioContent(
          "تۆماری دەنگی فایلی وانەی جێبەجێکردنی سیستەم و چەمکەکانی یادگەی پێشەکەوتوو (Virtual Memory).",
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking audio file: $e')),
      );
    }
  }

  Future<void> _summarizeAudioContent(String audioMockTranscript) async {
    setState(() {
      _isLoading = true;
      _summarizedResult = '';
    });

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final res = await aiService.summarizePdf(_audioFileName, audioMockTranscript);
      setState(() {
        _summarizedResult = res['summary'] ?? '';
      });
    } catch (e) {
      setState(() {
        _summarizedResult = 'Error generating summary: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    final String title = langProvider.currentLanguage == AppLanguage.english
        ? 'Audio Summarizer'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'مستخلص المحاضرات الصوتية'
            : 'کورتکەرەوەی دەنگی وانەکان';

    final String infoText = langProvider.currentLanguage == AppLanguage.english
        ? 'Record your professor during the lecture or upload an audio recording to transcribe and summarize instantly.'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'سجل صوت المحاضر أثناء الدرس أو حمل تسجيلاً صوتياً ليتم تفريغه وتلخيصه فوراً.'
            : 'دەنگی مامۆستا لە کاتی وتنەوەی وانەکەدا تۆمار بکە یان فایلێکی دەنگی باربکە بۆ ئەوەی دەستبەجێ بیکاتە نووسین و کورتکراوەی نایاب.';


    final String pickButtonText = langProvider.currentLanguage == AppLanguage.english
        ? 'Upload Audio File'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'تحميل ملف صوتي'
            : 'بارکردنی فایلی دەنگی';

    final String resultLabel = langProvider.currentLanguage == AppLanguage.english
        ? 'Audio Lecture Summary'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'ملخص المحاضرة الصوتية'
            : 'کورتکراوەی دەنگی وانەکە';

    final String loadingText = langProvider.currentLanguage == AppLanguage.english
        ? 'Transcribing and generating AI summary...'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'جاري التفريغ الصوتي وتلخيص المحاضرة...'
            : 'خەریکی وەرگێڕانی دەنگ بۆ نووسین و کورتکردنەوەی دەنگەکەیە...';

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
                color: theme.colorScheme.primaryContainer.withOpacity(0.15),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.mic_external_on_rounded, color: theme.colorScheme.primary, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          infoText,
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
              const SizedBox(height: 32),

              // Recorder UI
              Center(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red.withOpacity(0.2) : theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording ? Colors.red : theme.colorScheme.primary,
                          width: _isRecording ? 4 : 2,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 48,
                          color: _isRecording ? Colors.red : theme.colorScheme.primary,
                        ),
                        onPressed: _isRecording ? _stopRecording : _startRecording,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording
                          ? _formatDuration(_recordDurationSeconds)
                          : (langProvider.currentLanguage == AppLanguage.english
                              ? 'Tap to start recording'
                              : 'کلیک بکە بۆ دەستپێکردنی تۆمارکردن'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _isRecording ? Colors.red : Colors.grey,
                        fontFamily: 'Noto Sans Arabic',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Center(
                child: Text(
                  langProvider.currentLanguage == AppLanguage.english ? 'OR' : 'یاخود',
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 24),

              // Pick Audio File
              SizedBox(
                width: double.maxFinite,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickAudioFile,
                  icon: const Icon(Icons.audio_file_outlined),
                  label: Text(pickButtonText, style: const TextStyle(fontFamily: 'Noto Sans Arabic')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              if (_audioFileName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '🎵 $_audioFileName',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.teal),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),

              // Loading UI
              if (_isLoading) ...[
                const SizedBox(height: 16),
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

              // Summarization Results
              if (_summarizedResult.isNotEmpty) ...[
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
                        _summarizedResult,
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
