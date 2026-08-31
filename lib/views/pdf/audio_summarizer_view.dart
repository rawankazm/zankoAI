import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';

class AudioSummarizerView extends StatefulWidget {
  const AudioSummarizerView({super.key});

  @override
  State<AudioSummarizerView> createState() => _AudioSummarizerViewState();
}

class _AudioSummarizerViewState extends State<AudioSummarizerView> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _transcriptController = TextEditingController();
  String? _recordedFilePath;

  bool _isRecording = false;
  bool _isLoading = false;
  String _audioFileName = '';
  int _recordDurationSeconds = 0;
  String _selectedLocaleId = 'ku';
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  void _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            bitRate: 128000,
            numChannels: 1,
          ),
          path: path,
        );

        setState(() {
          _recordedFilePath = path;
          _isRecording = true;
          _isLoading = false;
          _audioFileName = 'دەنگی مایکرۆفۆن.m4a';
          _recordDurationSeconds = 0;
          _transcriptController.clear();
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
      _transcriptController.clear();
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

      if (!mounted) return;
      if (recordedBytes == null || recordedBytes.length < 300) {
        setState(() {
          _transcriptController.text = "دەنگەکە زۆر کورت بوو، تکایە کەمێک زیاتر قسە بکە و دووبارە تاقی بکەرەوە.";
        });
        return;
      }

      final aiService = Provider.of<AiService>(context, listen: false);
      final transcript = await aiService.transcribeAudio(
        recordedBytes,
        _audioFileName,
        mimeType: 'audio/mp4',
        language: _selectedLocaleId,
      );

      setState(() {
        _transcriptController.text = transcript.isNotEmpty
            ? transcript
            : "نەتوانرا دەنگەکە بە تەواوی بناسرێتەوە. تکایە دڵنیابە لە پەیوەندی ئینتەرنێت و کلیلی Gemini API.";
      });
    } catch (_) {
      setState(() {
        _transcriptController.text = "هەڵەیەک ڕوویدا لە کاتی پەیوەندی بە ژیری دەستکرد. تکایە ئینتەرنێتەکەت بپشکنە.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

        if (!mounted) return;
        final aiService = Provider.of<AiService>(context, listen: false);
        setState(() {
          _audioFileName = file.name;
          _isLoading = true;
          _transcriptController.clear();
        });

        String mime = 'audio/mp4';
        final ext = file.name.toLowerCase();
        if (ext.endsWith('.wav')) {
          mime = 'audio/wav';
        } else if (ext.endsWith('.mp3')) {
          mime = 'audio/mp3';
        } else if (ext.endsWith('.aac')) {
          mime = 'audio/aac';
        } else if (ext.endsWith('.ogg')) {
          mime = 'audio/ogg';
        } else if (ext.endsWith('.flac')) {
          mime = 'audio/flac';
        }

        final transcript = await aiService.transcribeAudio(
          bytes,
          file.name,
          mimeType: mime,
          language: _selectedLocaleId,
        );

        setState(() {
          _transcriptController.text = transcript.isNotEmpty
              ? transcript
              : "نەتوانرا دەنگەکە بە تەواوی بناسرێتەوە. تکایە دڵنیابە فایلی دەنگییەکە قسەکردنی تێدایە و ڕوونە.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە لە بارکردنی فایلی دەنگی: $e')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _copyText() {
    if (_transcriptController.text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _transcriptController.text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('دەقەکە بە سەرکەوتوویی لەبەرگیرایەوە! 📋'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareText() {
    if (_transcriptController.text.trim().isEmpty) return;
    Share.share(_transcriptController.text.trim(), subject: 'دەقی وەرگێڕدراوی دەنگ - ZankoAI');
  }

  void _clearText() {
    setState(() {
      _transcriptController.clear();
      _audioFileName = '';
      _recordDurationSeconds = 0;
    });
  }

  void _showApiKeyDialog(BuildContext context) {
    final aiService = Provider.of<AiService>(context, listen: false);
    final textController = TextEditingController(text: aiService.apiKey ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.purple),
              SizedBox(width: 8),
              Text('کلیلی Gemini API', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'کلیلی فەرمی Gemini API لێرە دابنێ بۆ وەرگێڕانی خێرای دەنگ بۆ نووسین بە Gemini 3.7 Flash:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText: 'AQ.Ab8... یان AIzaSy...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.key),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('داخستن'),
            ),
            ElevatedButton(
              onPressed: () {
                final newKey = textController.text.trim();
                aiService.apiKey = newKey;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کلیلی API بە سەرکەوتوویی نوێکرایەوە! 🎉')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('پاشەکەوتکردن'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String key) => lang.translate(key);
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final aiService = Provider.of<AiService>(context);

    final String title = t('audio_summarizer_title');
    final String infoText = t('audio_summarizer_info');
    final String pickButtonText = t('audio_summarizer_upload_btn');

    final bool hasText = _transcriptController.text.trim().isNotEmpty &&
        !_transcriptController.text.startsWith('نەتوانرا') &&
        !_transcriptController.text.startsWith('هەڵەیەک') &&
        !_transcriptController.text.startsWith('دەنگەکە زۆر کورت');

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: Icon(
                aiService.hasRealApiKey ? Icons.vpn_key_rounded : Icons.key_off_rounded,
                color: aiService.hasRealApiKey ? Colors.green : Colors.amber,
              ),
              tooltip: 'Gemini API Key',
              onPressed: () => _showApiKeyDialog(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Banner
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Icon(Icons.mic_none_rounded, color: theme.colorScheme.primary, size: 32),
                      const SizedBox(width: 14),
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
              const SizedBox(height: 16),

              // Language Selector Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('خۆکار (Auto)', style: TextStyle(fontSize: 12)),
                      selected: _selectedLocaleId == 'auto',
                      onSelected: (val) {
                        if (val) setState(() => _selectedLocaleId = 'auto');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('کوردی / فارسی', style: TextStyle(fontSize: 12)),
                      selected: _selectedLocaleId == 'ku',
                      onSelected: (val) {
                        if (val) setState(() => _selectedLocaleId = 'ku');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('العربية', style: TextStyle(fontSize: 12)),
                      selected: _selectedLocaleId == 'ar',
                      onSelected: (val) {
                        if (val) setState(() => _selectedLocaleId = 'ar');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('English', style: TextStyle(fontSize: 12)),
                      selected: _selectedLocaleId == 'en',
                      onSelected: (val) {
                        if (val) setState(() => _selectedLocaleId = 'en');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Recorder UI
              Center(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? Colors.red.withValues(alpha: 0.18)
                            : theme.colorScheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording ? Colors.red : theme.colorScheme.primary,
                          width: _isRecording ? 3.5 : 2,
                        ),
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.4),
                                  blurRadius: 18,
                                  spreadRadius: 4,
                                )
                              ]
                            : null,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 46,
                          color: _isRecording ? Colors.red : theme.colorScheme.primary,
                        ),
                        onPressed: _isRecording ? _stopRecording : _startRecording,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRecording
                          ? 'تۆمارکردن: ${_formatDuration(_recordDurationSeconds)}'
                          : t('audio_summarizer_tap_record'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isRecording ? Colors.red : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Center(
                child: Text(
                  'یان',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Pick Audio File
              SizedBox(
                width: double.maxFinite,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickAudioFile,
                  icon: const Icon(Icons.audio_file_rounded),
                  label: Text(pickButtonText),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              if (_audioFileName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note_rounded, color: Colors.teal, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _audioFileName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Loading Indicator
              if (_isLoading) ...[
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(strokeWidth: 3),
                        const SizedBox(height: 16),
                        Text(
                          t('audio_summarizer_loading'),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // RESULT: Transcribed Text Box
              if (_transcriptController.text.isNotEmpty && !_isLoading) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            hasText ? Icons.text_snippet_rounded : Icons.info_outline_rounded,
                            color: hasText ? theme.colorScheme.primary : Colors.amber,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasText ? 'دەقی دەنگەکە:' : 'تێبینی:',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasText)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            tooltip: 'لەبەرگرتنەوە',
                            onPressed: _copyText,
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_rounded, size: 20),
                            tooltip: 'هاوبەشکردن',
                            onPressed: _shareText,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                            tooltip: 'سڕینەوە',
                            onPressed: _clearText,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _transcriptController,
                          maxLines: null,
                          style: const TextStyle(fontSize: 14.5, height: 1.7),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'دەقی دەنگەکە لێرە دەردەکەوێت...',
                          ),
                        ),
                        if (hasText) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_transcriptController.text.trim().split(RegExp(r'\s+')).length} وشە | ${_transcriptController.text.length} پیت',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _copyText,
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('لەبەرگرتنەوە (Copy)', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _shareText,
                                  icon: const Icon(Icons.share_rounded, size: 16),
                                  label: const Text('هاوبەشکردن (Share)', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
}
