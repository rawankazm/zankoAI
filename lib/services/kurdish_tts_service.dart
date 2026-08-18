import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class KurdishTtsService {
  static final KurdishTtsService _instance = KurdishTtsService._internal();
  factory KurdishTtsService() => _instance;

  KurdishTtsService._internal() {
    _init();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  List<String> _chunks = [];
  int _currentChunkIndex = 0;
  String _currentLangCode = 'ku';
  StreamSubscription? _playerCompleteSubscription;

  void _init() {
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _playNextChunk();
    });
  }

  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
  }

  /// Clean text from Markdown and code
  String _cleanText(String rawText) {
    String text = rawText
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`[\s\S]*?`'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        .replaceAll(RegExp(r'[\*\#\_~>\-\🔹\🔸\🎯\⭐\👑\💡\📌\⚡\✅\❌]'), ' ')
        .replaceAll(RegExp(r'\\\[[\s\S]*?\\\]'), '')
        .replaceAll(RegExp(r'\\\([\s\S]*?\\\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
  }

  /// Split long text into natural chunks for speech synthesis (<= 140 chars)
  List<String> _splitIntoChunks(String text) {
    final List<String> chunks = [];
    final sentences = text.split(RegExp(r'(?<=[.،!؟\n;؛?])\s+'));

    String current = '';
    for (var sentence in sentences) {
      final s = sentence.trim();
      if (s.isEmpty) continue;

      if (current.isEmpty) {
        current = s;
      } else if (current.length + s.length < 130) {
        current += ' $s';
      } else {
        chunks.add(current);
        current = s;
      }
    }

    if (current.isNotEmpty) {
      chunks.add(current);
    }

    // Split any oversized chunk
    final List<String> finalChunks = [];
    for (var c in chunks) {
      if (c.length <= 140) {
        finalChunks.add(c);
      } else {
        final words = c.split(' ');
        String sub = '';
        for (var w in words) {
          if (sub.length + w.length < 130) {
            sub = sub.isEmpty ? w : '$sub $w';
          } else {
            if (sub.isNotEmpty) finalChunks.add(sub);
            sub = w;
          }
        }
        if (sub.isNotEmpty) finalChunks.add(sub);
      }
    }

    return finalChunks;
  }

  /// Detect primary language code (ku, ar, en)
  String _detectLanguageCode(String text, {String? preferredLang}) {
    if (preferredLang != null && preferredLang.isNotEmpty) {
      if (preferredLang == 'ar') return 'ar';
      if (preferredLang == 'en') return 'en';
      if (preferredLang == 'ckb' || preferredLang == 'ku' || preferredLang == 'kmr') return 'ku';
    }

    // Kurdish specific letters
    final kurdishLetters = RegExp(r'[ێەڵڕڤۆژڕپچ]');
    if (kurdishLetters.hasMatch(text)) {
      return 'ku';
    }

    // Arabic specific letters
    final arabicLetters = RegExp(r'[\u0600-\u06FF]');
    if (arabicLetters.hasMatch(text)) {
      return 'ar';
    }

    return 'en';
  }

  /// Start speaking text
  Future<void> speak(
    String rawText, {
    String? languageCode,
  }) async {
    await stop();

    final clean = _cleanText(rawText);
    if (clean.isEmpty) return;

    _chunks = _splitIntoChunks(clean);
    if (_chunks.isEmpty) return;

    _currentChunkIndex = 0;
    _currentLangCode = _detectLanguageCode(clean, preferredLang: languageCode);
    _isSpeaking = true;
    isSpeakingNotifier.value = true;

    try {
      await _playNextChunk();
    } catch (e) {
      await _fallbackToLocalTts(clean, _currentLangCode);
    }
  }

  Future<void> _playNextChunk() async {
    if (!_isSpeaking) return;

    if (_currentChunkIndex >= _chunks.length) {
      await stop();
      return;
    }

    final chunk = _chunks[_currentChunkIndex];
    _currentChunkIndex++;

    try {
      final encodedText = Uri.encodeComponent(chunk);
      final url = 'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$_currentLangCode&q=$encodedText';

      await _audioPlayer.stop();
      await _audioPlayer.play(
        UrlSource(url),
        mode: PlayerMode.mediaPlayer,
      );
    } catch (e) {
      if (_currentChunkIndex < _chunks.length) {
        await _playNextChunk();
      } else {
        await stop();
      }
    }
  }

  Future<void> _fallbackToLocalTts(String text, String langCode) async {
    try {
      if (langCode == 'ar') {
        await _flutterTts.setLanguage("ar");
      } else if (langCode == 'ku') {
        final hasKu = await _flutterTts.isLanguageAvailable("ku") ?? false;
        if (hasKu) {
          await _flutterTts.setLanguage("ku");
        } else {
          final hasCkb = await _flutterTts.isLanguageAvailable("ckb") ?? false;
          if (hasCkb) {
            await _flutterTts.setLanguage("ckb");
          } else {
            // Do not read Kurdish with English voice
            await stop();
            return;
          }
        }
      } else {
        await _flutterTts.setLanguage("en-US");
      }

      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      _flutterTts.setCompletionHandler(() {
        stop();
      });
      await _flutterTts.speak(text);
    } catch (_) {
      await stop();
    }
  }

  /// Stop playback immediately
  Future<void> stop() async {
    _isSpeaking = false;
    isSpeakingNotifier.value = false;
    _chunks.clear();
    _currentChunkIndex = 0;

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
