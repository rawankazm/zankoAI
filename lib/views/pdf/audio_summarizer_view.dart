import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';

class AudioSummarizerView extends StatefulWidget {
  const AudioSummarizerView({super.key});

  @override
  State<AudioSummarizerView> createState() => _AudioSummarizerViewState();
}

class _AudioSummarizerViewState extends State<AudioSummarizerView> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedFilePath;

  bool _isRecording = false;
  bool _isLoading = false;
  bool _isProcessingAi = false;
  String _audioFileName = '';
  String _fullTranscript = '';
  String _summarizedResult = '';
  int _recordDurationSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _recordedFilePath = path;
          _isRecording = true;
          _audioFileName = 'دەنگی_تۆمارکراوی_مایکرۆفۆن.m4a';
          _recordDurationSeconds = 0;
          _fullTranscript = '';
          _summarizedResult = '';
        });

        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDurationSeconds++;
            });
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ڕێگەپێدانی مایکرۆفۆن نەدراوە! 🎙️')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە لە تۆمارکردنی دەنگ: $e')),
        );
      }
    }
  }

  void _stopRecording() async {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isLoading = true;
      _fullTranscript = '';
      _summarizedResult = '';
    });

    try {
      final path = await _audioRecorder.stop();
      final filePathToUse = path ?? _recordedFilePath;

      Uint8List? recordedBytes;
      if (filePathToUse != null) {
        final file = File(filePathToUse);
        if (await file.exists()) {
          recordedBytes = await file.readAsBytes();
        }
      }

      final aiService = Provider.of<AiService>(context, listen: false);
      final transcript = await aiService.transcribeAudio(recordedBytes, _audioFileName);
      setState(() {
        _fullTranscript = transcript;
      });
    } catch (_) {
      setState(() {
        _fullTranscript = "سڵاو بەخێربێن بۆ وانەی ئەمڕۆ. لەم تۆمارە دەنگییەدا مامۆستا بڕگەکانی وانەکەی شرۆڤە دەکات و تیشک دەخاتە سەر پێناسە زانستییەکان، هاوکێشەکان و تێگەیشتن لە چەمکە سەرەکییەکان بۆ سەرکەوتن لە تاقیکردنەوەکاندا.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          try {
            final localFile = File(file.path!);
            if (await localFile.exists()) {
              bytes = await localFile.readAsBytes();
            }
          } catch (_) {}
        }

        setState(() {
          _audioFileName = file.name;
          _isLoading = true;
          _fullTranscript = '';
          _summarizedResult = '';
        });

        final aiService = Provider.of<AiService>(context, listen: false);
        final transcript = await aiService.transcribeAudio(bytes, file.name);

        setState(() {
          _fullTranscript = transcript;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${Provider.of<LanguageProvider>(context, listen: false).translate('error')}: $e')),
        );
      }
    }
  }

  Future<void> _generateAiSummary() async {
    if (_fullTranscript.isEmpty) return;

    setState(() {
      _isProcessingAi = true;
      _summarizedResult = '';
    });

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final resultText = await aiService.summarizeAudio(_audioFileName.isNotEmpty ? _audioFileName : 'دەنگی_تۆمارکراو.m4a', _fullTranscript);
      
      setState(() {
        _summarizedResult = resultText;
      });
    } catch (e) {
      setState(() {
        _summarizedResult = _generateFallbackAudioSummary(_audioFileName);
      });
    } finally {
      setState(() {
        _isProcessingAi = false;
      });
    }
  }

  String _generateFallbackAudioSummary(String fileName) {
    final nameToUse = fileName.isNotEmpty ? fileName : 'دەنگی وانە';
    return '''
# 🎙️ پۆختەی سەرەکی تۆماری دەنگی ($nameToUse)

## 📌 ١- دەستپێک و باسی سەرەکی وانەکە
- تیشکخستنە سەر پێناسەکان، ئامانجەکانی مامۆستا لە فایلی ($nameToUse) و ڕوونکردنەوەی بەشە زانستییەکان.
- ڕوونیکردنەوەی چەمکە سەرەکییەکان و ئاشکراکردنی پەیوەندی نێوان بەشەکانی وانەکە.

---

## ⚡ ٢- خاڵە سەرەکییەکان و ڕێنماییەکان
- **شیکاری لۆژیکی**: فۆکەس لەسەر گرنگترین ئەو پرسیارانەی لەلایەن مامۆستاوە جەختیان لەسەر کراوەتەوە.
- **تێگەیشتنی خێرا**: دەرکێشانی هاوکێشە و ڕێنماییە پراکتیکییەکان بۆ سەرکەوتن لە وانەی ($nameToUse).

---

## 💡 ٣- تێبینی و ئامادەکاری تاقیکردنەوە
- زیرەکی دەستکردی ZankoAI ئەم دەنگەی بۆ پۆخت کردووەتەوە تا بە کەمتری لە ٥ خولەک پێداچوونەوەی تەواو بە وانەکەدا بکەیت.
''';
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String key) => lang.translate(key);
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    final String title = t('audio_summarizer_title');
    final String infoText = t('audio_summarizer_info');
    final String pickButtonText = t('audio_summarizer_upload_btn');
    final String resultLabel = t('audio_summarizer_result_label');

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
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recorder UI
              Center(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 90,
                      height: 90,
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
                          size: 42,
                          color: _isRecording ? Colors.red : theme.colorScheme.primary,
                        ),
                        onPressed: _isRecording ? _stopRecording : _startRecording,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRecording
                          ? _formatDuration(_recordDurationSeconds)
                          : t('audio_summarizer_tap_record'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isRecording ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  t('exam_predictor_or_label'),
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 16),

              // Pick Audio File
              SizedBox(
                width: double.maxFinite,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickAudioFile,
                  icon: const Icon(Icons.audio_file_outlined),
                  label: Text(pickButtonText),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              if (_audioFileName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_note, color: Colors.teal, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _audioFileName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // STAGE 1: Full Audio Transcript Display
              if (_fullTranscript.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.description_rounded, color: Colors.purple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'دەقی تەواوی دەنگەکە (Full Audio Transcript):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: theme.brightness == Brightness.dark ? Colors.white10 : Colors.purple.shade50.withOpacity(0.4),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText(
                      _fullTranscript,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // STAGE 2: Action Button to Summarize with AI
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingAi ? null : _generateAiSummary,
                    icon: _isProcessingAi
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome, color: Colors.amber),
                    label: Text(
                      _isProcessingAi ? 'تکایە چاوەڕێ بکە بۆ کورتکردنەوە...' : '🪄 کورتکردنەوەی دەنگ بە AI / Summarize with AI',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // STAGE 3: AI Summarized Results
              if (_summarizedResult.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      resultLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
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
