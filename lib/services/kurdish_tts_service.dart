import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ai_teacher_voice_service.dart';

/// KurdishTtsService - Backward compatibility wrapper delegating to
/// the robust, server-backed AiTeacherVoiceService.
class KurdishTtsService {
  static final KurdishTtsService _instance = KurdishTtsService._internal();
  factory KurdishTtsService() => _instance;

  final AiTeacherVoiceService _voiceService = AiTeacherVoiceService();

  KurdishTtsService._internal() {
    _voiceService.playbackNotifier.addListener(_onStateChanged);
  }

  bool get isSpeaking => _voiceService.isPlaying || _voiceService.playbackNotifier.value.isLoading;
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  VoidCallback? _onDone;

  void _onStateChanged() {
    final info = _voiceService.playbackNotifier.value;
    final speaking = info.isPlaying || info.isLoading;
    if (isSpeakingNotifier.value != speaking) {
      isSpeakingNotifier.value = speaking;
    }

    if (info.isCompleted) {
      final cb = _onDone;
      _onDone = null;
      cb?.call();
    }
  }

  /// Configure custom voice id (mapped to server voice)
  void setElevenLabsConfig({String? apiKey, String? voiceId}) {
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      _voiceService.setElevenLabsApiKey(apiKey);
    }
  }

  /// Start speaking text using the robust multilingual queue engine
  Future<void> speak(
    String rawText, {
    String? languageCode,
    String? apiKey,
    String? elevenLabsKey,
    String? elevenLabsVoiceId,
    double speed = 1.0,
    VoidCallback? onDone,
  }) async {
    _onDone = onDone;
    await _voiceService.readAloud(
      answerId: 'kurdish_tutor_${DateTime.now().millisecondsSinceEpoch}',
      text: rawText,
      language: languageCode ?? 'ku',
      speed: speed,
    );
  }

  /// Stop playback immediately
  Future<void> stop() async {
    _onDone = null;
    await _voiceService.stop();
  }

  void dispose() {
    _voiceService.playbackNotifier.removeListener(_onStateChanged);
  }
}
