import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' hide BoxShadow, Offset;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../theme.dart';

class VoiceDictationSheet extends StatefulWidget {
  final Function(String audioPath) onAudioRecorded;
  final String title;

  const VoiceDictationSheet({
    super.key,
    required this.onAudioRecorded,
    this.title = 'تۆمارکردنی دەنگ بۆ زیرەکی دەستکرد',
  });

  static Future<void> show(BuildContext context, {required Function(String audioPath) onAudioRecorded}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceDictationSheet(onAudioRecorded: onAudioRecorded),
    );
  }

  @override
  State<VoiceDictationSheet> createState() => _VoiceDictationSheetState();
}

class _VoiceDictationSheetState extends State<VoiceDictationSheet> with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  Timer? _timer;
  String? _recordedFilePath;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/zanko_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _recordDurationSeconds = 0;
          _recordedFilePath = filePath;
        });

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
            const SnackBar(content: Text('تکایە ڕێگەپێدانی مایکڕۆفۆن پێمبەخشە')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopAndSubmitRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });

    final finalPath = path ?? _recordedFilePath;
    if (finalPath != null && File(finalPath).existsSync()) {
      widget.onAudioRecorded(finalPath);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _audioRecorder.stop();
    if (_recordedFilePath != null) {
      final file = File(_recordedFilePath!);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            widget.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : ZankoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            _isRecording ? 'تۆمارکردن چالاکە... قسە بکە' : 'تۆمارکردن ڕاوەستا',
            style: TextStyle(
              fontSize: 13,
              color: _isRecording ? ZankoColors.accent : Colors.grey,
            ),
          ),
          const SizedBox(height: 24),

          // Animated Microphone Pulse Button
          ScaleTransition(
            scale: _isRecording ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [ZankoColors.primary, const Color(0xFFEF4444)]
                      : [ZankoColors.primary, ZankoColors.accent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ZankoColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.mic_fill,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Timer Counter
          Text(
            _formatDuration(_recordDurationSeconds),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDark ? Colors.white : ZankoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 28),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _cancelRecording,
                  child: const Text('پاشگەزبوونەوە', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: ZankoColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _stopAndSubmitRecording,
                  icon: const Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 18),
                  label: const Text('ناردن بۆ AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
