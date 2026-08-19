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

  /// Clean text from Markdown, code and prepare phonetics for Kurdish Sorani
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

    return _prepareKurdishPhonetics(text);
  }

  /// Phonetically normalize Kurdish Sorani text for smooth speech synthesis
  String _prepareKurdishPhonetics(String text) {
    String result = text;

    // Normalize common Kurdish Sorani prepositions & words
    result = result.replaceAll(RegExp(r'\bلە\b'), 'لَ');
    result = result.replaceAll(RegExp(r'\bبە\b'), 'بَ');
    result = result.replaceAll(RegExp(r'\bدە\b'), 'دَ');
    result = result.replaceAll(RegExp(r'\bکە\b'), 'كـَ');
    result = result.replaceAll(RegExp(r'\bئەمە\b'), 'أَمَا');
    result = result.replaceAll(RegExp(r'\bئەوە\b'), 'أَوَا');

    // Replace word-final Kurdish short vowel 'ە' (U+06D5) with Fatha 'َ' (U+064E) or 'ا'
    // so TTS engine reads short vowel /a/ or /e/ instead of consonant 'H'
    result = result.replaceAll(RegExp(r'([آأإابپتثجچحخدرڕزژسشصضطظعغفقڤککگلڵمنهویێۆ])ە\b'), r'$1َ');

    // Replace internal Kurdish short vowel 'ە' with Fatha 'َ'
    result = result.replaceAll(RegExp(r'([آأإابپتثجچحخدرڕزژسشصضطظعغفقڤککگلڵمنهویێۆ])ە([آأإابپتثجچحخدرڕزژسشصضطظعغفقڤککگلڵمنهویێۆ])'), r'$1َ$2');

    // Clean remaining isolated 'ە'
    result = result.replaceAll('ە', 'َ');

    // Map Kurdish vowels/consonants for natural Arabic-script speech synthesizer
    result = result.replaceAll('ێ', 'ي');
    result = result.replaceAll('ۆ', 'و');

    return result;
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
      final ttsLang = (_currentLangCode == 'ku' || _currentLangCode == 'ckb') ? 'ar' : _currentLangCode;
      final url = 'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$ttsLang&q=$encodedText';

      await _audioPlayer.stop();
      await _audioPlayer.play(
        UrlSource(url),
        mode: PlayerMode.mediaPlayer,
      );
    } catch (e) {
      debugPrint('Error playing TTS chunk via Google online endpoint: $e');
      await _fallbackToLocalTts(chunk, _currentLangCode);
    }
  }

  Future<void> _fallbackToLocalTts(String text, String langCode) async {
    try {
      if (langCode == 'ar' || langCode == 'ku' || langCode == 'ckb') {
        final hasKu = await _flutterTts.isLanguageAvailable("ku") ?? false;
        if (hasKu) {
          await _flutterTts.setLanguage("ku");
        } else {
          final hasCkb = await _flutterTts.isLanguageAvailable("ckb") ?? false;
          if (hasCkb) {
            await _flutterTts.setLanguage("ckb");
          } else {
            await _flutterTts.setLanguage("ar");
          }
        }
      } else {
        await _flutterTts.setLanguage("en-US");
      }

      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      _flutterTts.setCompletionHandler(() {
        if (_currentChunkIndex < _chunks.length) {
          _playNextChunk();
        } else {
          stop();
        }
      });
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error in fallback local TTS: $e');
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
