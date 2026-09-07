import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/lecture_audio_job_model.dart';
import '../../services/audio_lecture_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';

/// Screen for teachers to record or upload lecture audio,
/// track the 7-state AI processing pipeline, and view study materials.
class TeacherLectureRecorderScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const TeacherLectureRecorderScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<TeacherLectureRecorderScreen> createState() =>
      _TeacherLectureRecorderScreenState();
}

class _TeacherLectureRecorderScreenState
    extends State<TeacherLectureRecorderScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _titleController = TextEditingController();

  // State
  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  String? _recordedFilePath;
  Uint8List? _audioBytes;
  String? _audioFileName;
  String _selectedLanguage = 'ku';

  bool _isSubmitting = false;
  String? _errorMessage;
  LectureAudioJobModel? _currentJob;

  late TabController _tabController;
  int _currentFlashcardIndex = 0;
  bool _showFlashcardBack = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _titleController.text = 'وانەی نوێ - ${widget.courseTitle}';
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _titleController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─── Recording Actions ───────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String path = '';
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path =
              '${tempDir.path}/lecture_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

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
          _isRecording = true;
          _recordDurationSeconds = 0;
          _recordedFilePath = path;
          _audioBytes = null;
          _audioFileName = 'وانەی تۆمارکراو.m4a';
          _errorMessage = null;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDurationSeconds++;
            });
          }
        });
      } else {
        _showErrorSnackBar('ڕێگەپێدانی مایکرۆفۆن پێویستە بۆ تۆمارکردن');
      }
    } catch (e) {
      _showErrorSnackBar('هەڵە لە دەستپێکردنی تۆمار: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      final filePath = path ?? _recordedFilePath;

      Uint8List? bytes;
      if (!kIsWeb && filePath != null) {
        final file = io.File(filePath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      setState(() {
        _isRecording = false;
        _recordedFilePath = filePath;
        _audioBytes = bytes;
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      _showErrorSnackBar('هەڵە لە تەواوکردنی تۆمار: $e');
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'webm', 'flac', 'aac'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        Uint8List? bytes = file.bytes;

        if (!kIsWeb && bytes == null && file.path != null) {
          final localFile = io.File(file.path!);
          if (await localFile.exists()) {
            bytes = await localFile.readAsBytes();
          }
        }

        if (bytes == null || bytes.isEmpty) {
          _showErrorSnackBar('فایلەکە بەتاڵە یان نەتوانرا بخوێندرێتەوە');
          return;
        }

        setState(() {
          _audioBytes = bytes;
          _audioFileName = file.name;
          _recordedFilePath = file.path;
          _recordDurationSeconds = 60; // default estimated duration if file pick
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar('هەڵە لە هەڵبژاردنی فایلی دەنگی: $e');
    }
  }

  // ─── Submit to AI Pipeline ───────────────────────────────────────────────────

  Future<void> _submitLecture() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showErrorSnackBar('تکایە ناونیشانی وانەکە بنووسە');
      return;
    }

    if (_audioBytes == null && _recordedFilePath == null) {
      _showErrorSnackBar('تکایە سەرەتا وانەکە تۆماربکە یان فایلێکی دەنگی هەڵبژێرە');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _currentJob = null;
    });

    try {
      final duration = _recordDurationSeconds > 0 ? _recordDurationSeconds : 30;

      io.File? fileToPass;
      if (!kIsWeb && _recordedFilePath != null) {
        fileToPass = io.File(_recordedFilePath!);
      }

      final completedJob = await AudioLectureService.instance.submitAndWait(
        file: fileToPass,
        bytes: _audioBytes,
        filename: _audioFileName,
        courseId: widget.courseId,
        title: title,
        language: _selectedLanguage,
        durationSeconds: duration,
        onStatusUpdate: (job) {
          if (mounted) {
            setState(() {
              _currentJob = job;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _currentJob = completedJob;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تۆمارکردنی وانەی مامۆستا',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: lang.textDirection,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Course Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ZankoColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ZankoColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTeacher,
                      size: 20,
                      color: ZankoColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'کۆرسی پەیوەندیدار',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ZankoColors.primary,
                            ),
                          ),
                          Text(
                            widget.courseTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Title input
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'ناونیشانی وانە',
                  hintText: 'نموونە: بەشی ٣ - شەپۆل و کارەبا',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Language selector
              Row(
                children: [
                  const Text(
                    'زمانی وانە:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('کوردی'),
                    selected: _selectedLanguage == 'ku',
                    onSelected: (val) {
                      if (val) setState(() => _selectedLanguage = 'ku');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('English'),
                    selected: _selectedLanguage == 'en',
                    onSelected: (val) {
                      if (val) setState(() => _selectedLanguage = 'en');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('عربي'),
                    selected: _selectedLanguage == 'ar',
                    onSelected: (val) {
                      if (val) setState(() => _selectedLanguage = 'ar');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Recorder / Picker Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? ZankoColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Timer display
                    Text(
                      _formatTimer(_recordDurationSeconds),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: _isRecording ? Colors.redAccent : ZankoColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRecording
                          ? 'تۆمارکردنی دەنگ بەردەوامە...'
                          : (_audioFileName != null
                              ? 'فایلی ئامادەکراو: $_audioFileName'
                              : 'دەستبەکاربە بە تۆمارکردن یان هەڵبژاردنی فایل'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : ZankoColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Record Button
                        ElevatedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : (_isRecording ? _stopRecording : _startRecording),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording
                                ? Colors.redAccent
                                : ZankoColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            _isRecording ? 'ڕاگرتنی تۆمار' : 'تۆمارکردنی نوێ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Pick File Button
                        OutlinedButton.icon(
                          onPressed: (_isRecording || _isSubmitting)
                              ? null
                              : _pickAudioFile,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text(
                            'فایلی دەنگ',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                onPressed: (_isRecording || _isSubmitting) ? null : _submitLecture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZankoColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'خەریکی پڕۆسێسکردنە بە ژیری دەستکرد...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAiMagic,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ناردن و پڕۆسێسکردن بە ژیری دەستکرد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ─── 7-State Pipeline Progress Indicator ─────────────────────────
              if (_currentJob != null) ...[
                const SizedBox(height: 24),
                _buildPipelineProgressCard(_currentJob!, isDark),
              ],

              // ─── Study Materials Results ─────────────────────────────────────
              if (_currentJob?.result != null) ...[
                const SizedBox(height: 24),
                _buildResultsView(_currentJob!.result!, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── 7-State Pipeline Progress UI ────────────────────────────────────────────

  Widget _buildPipelineProgressCard(LectureAudioJobModel job, bool isDark) {
    final states = [
      {'status': AudioJobStatus.queued, 'label': 'لە نۆرەدا'},
      {'status': AudioJobStatus.processing, 'label': 'ئامادەکردن'},
      {'status': AudioJobStatus.transcribing, 'label': 'دەرهێنانی دەق'},
      {'status': AudioJobStatus.summarizing, 'label': 'کورتکردنەوە'},
      {'status': AudioJobStatus.generating, 'label': 'دروستکردنی کویز'},
      {'status': AudioJobStatus.completed, 'label': 'تەواوبوو'},
    ];

    final currentIndex = states.indexWhere((s) => s['status'] == job.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: job.status == AudioJobStatus.failed
              ? Colors.redAccent
              : ZankoColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'دۆخی ئەرک: ${job.status.displayNameKu}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (job.isProcessing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Stepper row
          Row(
            children: List.generate(states.length, (idx) {
              final isPassed = currentIndex >= idx;
              final isCurrent = currentIndex == idx;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPassed
                            ? ZankoColors.primary
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                        border: isCurrent
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isPassed
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (idx < states.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: currentIndex > idx
                              ? ZankoColors.primary
                              : (isDark ? Colors.white12 : Colors.grey.shade300),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Study Materials Results View ────────────────────────────────────────────

  Widget _buildResultsView(LectureAudioResultModel res, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: ZankoColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: ZankoColors.primary,
          tabs: const [
            Tab(text: 'پوختە'),
            Tab(text: 'دەقی وانە'),
            Tab(text: 'فلاشکارت'),
            Tab(text: 'کویز'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 480,
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. Summary & Takeaways Tab
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? ZankoColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        res.summary,
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ),
                    if (res.keyTakeaways.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'خاڵە سەرەکییەکان:',
                        style:
                            TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ...res.keyTakeaways.map(
                        (point) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  point,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 2. Transcript Tab
              SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? ZankoColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'دەقی تەواوی وانەکە:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: res.transcript));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('دەق لەبەرگیرایەوە! 📋')),
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        res.transcript,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Flashcards Tab
              res.flashcards.isEmpty
                  ? const Center(child: Text('فلاشکارت بوونی نییە'))
                  : Column(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showFlashcardBack = !_showFlashcardBack;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _showFlashcardBack
                                      ? [
                                          ZankoColors.success,
                                          ZankoColors.success
                                              .withValues(alpha: 0.8)
                                        ]
                                      : [
                                          ZankoColors.primary,
                                          ZankoColors.primary
                                              .withValues(alpha: 0.8)
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  _showFlashcardBack
                                      ? res.flashcards[_currentFlashcardIndex]
                                          .back
                                      : res.flashcards[_currentFlashcardIndex]
                                          .front,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'کارت: ${_currentFlashcardIndex + 1} لە ${res.flashcards.length} (کرتە بکە بۆ پێچەوانەکردنەوە)',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _currentFlashcardIndex > 0
                                  ? () {
                                      setState(() {
                                        _currentFlashcardIndex--;
                                        _showFlashcardBack = false;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_back),
                            ),
                            IconButton(
                              onPressed: _currentFlashcardIndex <
                                      res.flashcards.length - 1
                                  ? () {
                                      setState(() {
                                        _currentFlashcardIndex++;
                                        _showFlashcardBack = false;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ],
                        ),
                      ],
                    ),

              // 4. Quiz Tab
              (res.quiz == null || res.quiz!.questions.isEmpty)
                  ? const Center(child: Text('کویز بوونی نییە'))
                  : ListView.builder(
                      itemCount: res.quiz!.questions.length,
                      itemBuilder: (context, qIdx) {
                        final q = res.quiz!.questions[qIdx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${qIdx + 1}. ${q.question}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...List.generate(q.options.length, (optIdx) {
                                  final isCorrect = q.correctAnswer == optIdx;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isCorrect
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCorrect
                                            ? Colors.green
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCorrect
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          size: 16,
                                          color: isCorrect
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            q.options[optIdx],
                                            style: TextStyle(
                                              fontWeight: isCorrect
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (q.explanation.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'ڕوونکردنەوە: ${q.explanation}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
