import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
  VoidCallback? _onDone;

  void _init() {
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _playNextChunk();
    });
  }

  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
  }

  /// Clean text from Markdown, code, emojis, math and prepare phonetics for Kurdish Sorani
  String _cleanText(String rawText) {
    String text = rawText
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`[\s\S]*?`'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        .replaceAll(RegExp(r'[\*\#\_~>\-\🔹\🔸\🎯\⭐\👑\💡\📌\⚡\✅\❌\🎧\🎓\🔴\💬]'), ' ')
        .replaceAll(RegExp(r'\\\[[\s\S]*?\\\]'), '')
        .replaceAll(RegExp(r'\\\([\s\S]*?\\\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return _prepareKurdishPhonetics(text);
  }

  /// Phonetically normalize Kurdish Sorani text for natural spoken flow
  String _prepareKurdishPhonetics(String text) {
    String result = text;

    // 1. Convert technical acronyms into clear spoken syllables
    result = result.replaceAll(RegExp(r'\bPDF\b', caseSensitive: false), 'پی دی ئێف');
    result = result.replaceAll(RegExp(r'\bAI\b', caseSensitive: false), 'ئەی ئای');
    result = result.replaceAll(RegExp(r'\bIT\b', caseSensitive: false), 'ئای تی');
    result = result.replaceAll(RegExp(r'\bRAM\b', caseSensitive: false), 'ڕام');
    result = result.replaceAll(RegExp(r'\bCPU\b', caseSensitive: false), 'سی پی یو');
    result = result.replaceAll(RegExp(r'\bOS\b', caseSensitive: false), 'ئۆ ئێس');
    result = result.replaceAll(RegExp(r'\bUI\b', caseSensitive: false), 'یوو ئای');
    result = result.replaceAll(RegExp(r'\bUX\b', caseSensitive: false), 'یوو ئێکس');
    result = result.replaceAll(RegExp(r'\bAPI\b', caseSensitive: false), 'ئەی پی ئای');
    result = result.replaceAll(RegExp(r'\bHTML\b', caseSensitive: false), 'ئێچ تی ئێم ئێڵ');
    result = result.replaceAll(RegExp(r'\bCSS\b', caseSensitive: false), 'سی ئێس ئێس');
    result = result.replaceAll(RegExp(r'\bSQL\b', caseSensitive: false), 'ئێس کیوو ئێڵ');

    // 2. Convert digits into smooth spoken Kurdish words
    result = result.replaceAll('0', ' صفر ').replaceAll('٠', ' صفر ');
    result = result.replaceAll('1', ' یەک ').replaceAll('١', ' یەک ');
    result = result.replaceAll('2', ' دوو ').replaceAll('٢', ' دوو ');
    result = result.replaceAll('3', ' سێ ').replaceAll('٣', ' سێ ');
    result = result.replaceAll('4', ' چوار ').replaceAll('٤', ' چوار ');
    result = result.replaceAll('5', ' پێنج ').replaceAll('٥', ' پێنج ');
    result = result.replaceAll('6', ' شەش ').replaceAll('٦', ' شەش ');
    result = result.replaceAll('7', ' حەوت ').replaceAll('٧', ' حەوت ');
    result = result.replaceAll('8', ' هەشت ').replaceAll('٨', ' هەشت ');
    result = result.replaceAll('9', ' نۆ ').replaceAll('٩', ' نۆ ');

    // 3. Normalize punctuation for smooth natural speech pacing
    result = result.replaceAll(';', '،');
    result = result.replaceAll('؛', '،');
    result = result.replaceAll(':', '، ');
    result = result.replaceAll('—', '، ');
    result = result.replaceAll('–', '، ');
    result = result.replaceAll(RegExp(r'[«»"“”]'), '');

    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Split long text into natural chunks for speech synthesis (<= 300 chars)
  List<String> _splitIntoChunks(String text) {
    final List<String> chunks = [];
    final sentences = text.split(RegExp(r'(?<=[.،!؟\n;؛?])\s+'));

    String current = '';
    for (var sentence in sentences) {
      final s = sentence.trim();
      if (s.isEmpty) continue;

      if (current.isEmpty) {
        current = s;
      } else if (current.length + s.length < 280) {
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
      if (c.length <= 320) {
        finalChunks.add(c);
      } else {
        final words = c.split(' ');
        String sub = '';
        for (var w in words) {
          if (sub.length + w.length < 280) {
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

  String? _customApiKey;
  double _playbackSpeed = 1.0;

  /// Fetch HD Neural AI Voice audio (Wavenet) from Google Cloud TTS API
  Future<Uint8List?> _fetchGoogleCloudNeuralAudio(String text, {String? apiKey}) async {
    if (kIsWeb) return null;

    final keysToTry = <String>[
      if (apiKey != null && apiKey.trim().isNotEmpty) apiKey.trim(),
      if (_customApiKey != null && _customApiKey!.trim().isNotEmpty) _customApiKey!.trim(),
    ];

    if (keysToTry.isEmpty) return null;

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      for (final key in keysToTry) {
        if (key.trim().isEmpty) continue;
        try {
          final uri = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$key');
          final request = await client.postUrl(uri);
          request.headers.set('content-type', 'application/json');

          final isEn = _currentLangCode == 'en';
          final bodyMap = {
            'input': {'text': text},
            'voice': {
              'languageCode': isEn ? 'en-US' : 'ar-XA',
              'name': isEn ? 'en-US-Neural2-D' : 'ar-XA-Wavenet-B',
              'ssmlGender': 'MALE'
            },
            'audioConfig': {
              'audioEncoding': 'MP3',
              'speakingRate': (0.92 * _playbackSpeed).clamp(0.5, 2.0),
              'pitch': -0.5
            }
          };

          request.add(utf8.encode(jsonEncode(bodyMap)));
          final response = await request.close().timeout(const Duration(seconds: 6));
          final respStr = await response.transform(utf8.decoder).join();

          if (response.statusCode == 200) {
            final data = jsonDecode(respStr);
            final audioContent = data['audioContent'] as String?;
            if (audioContent != null && audioContent.isNotEmpty) {
              return base64Decode(audioContent);
            }
          }
        } catch (e) {
          debugPrint('Google Cloud Wavenet Neural TTS attempt error: $e');
        }
      }
    } catch (e) {
      debugPrint('Google Cloud Neural TTS client error: $e');
    } finally {
      client?.close();
    }

    return null;
  }

  static const String _defaultElevenLabsKey = String.fromEnvironment('ELEVEN_LABS_API_KEY', defaultValue: '');

  String? _elevenLabsApiKey;
  String _elevenLabsVoiceId = 'CwhRBWXzGAHq8TQ4Fs17'; // Roger (ElevenLabs)

  /// Configure custom ElevenLabs credentials & voice
  void setElevenLabsConfig({String? apiKey, String? voiceId}) {
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      _elevenLabsApiKey = apiKey.trim();
    }
    if (voiceId != null && voiceId.trim().isNotEmpty) {
      _elevenLabsVoiceId = voiceId.trim();
    }
  }

  /// Fetch ultra-realistic studio voice audio from ElevenLabs (Eleven Multilingual v2)
  Future<Uint8List?> _fetchElevenLabsAudio(String text, {String? apiKey, String? voiceId}) async {
    if (kIsWeb) return null;

    final key = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : (_elevenLabsApiKey != null && _elevenLabsApiKey!.trim().isNotEmpty)
            ? _elevenLabsApiKey!.trim()
            : _defaultElevenLabsKey;

    if (key.isEmpty) return null;

    final targetVoice = (voiceId != null && voiceId.trim().isNotEmpty)
        ? voiceId.trim()
        : _elevenLabsVoiceId;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final uri = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$targetVoice');
      final request = await client.postUrl(uri);
      request.headers.set('xi-api-key', key);
      request.headers.set('content-type', 'application/json');
      request.headers.set('accept', 'audio/mpeg');

      final bodyMap = {
        'text': text,
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.75,
          'style': 0.0,
          'use_speaker_boost': true
        }
      };

      request.add(utf8.encode(jsonEncode(bodyMap)));
      final response = await request.close().timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final builder = BytesBuilder();
        await for (final byteChunk in response) {
          builder.add(byteChunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isNotEmpty) {
          return bytes;
        }
      } else {
        final errBody = await response.transform(utf8.decoder).join();
        debugPrint('ElevenLabs API response (${response.statusCode}): $errBody');
      }
    } catch (e) {
      debugPrint('ElevenLabs audio fetch error: $e');
    } finally {
      client.close();
    }

    return null;
  }

  /// Start speaking text
  Future<void> speak(
    String rawText, {
    String? languageCode,
    String? apiKey,
    String? elevenLabsKey,
    String? elevenLabsVoiceId,
    double speed = 1.0,
    VoidCallback? onDone,
  }) async {
    await stop();

    _onDone = onDone;
    _customApiKey = apiKey;
    if (elevenLabsKey != null && elevenLabsKey.isNotEmpty) {
      _elevenLabsApiKey = elevenLabsKey;
    }
    if (elevenLabsVoiceId != null && elevenLabsVoiceId.isNotEmpty) {
      _elevenLabsVoiceId = elevenLabsVoiceId;
    }
    _playbackSpeed = speed;
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
      final cb = _onDone;
      _onDone = null;
      await stop();
      cb?.call();
      return;
    }

    final chunk = _chunks[_currentChunkIndex];
    _currentChunkIndex++;

    // 1. TOP PRIORITY: ElevenLabs (Eleven Multilingual v2 - Roger Voice)
    try {
      final elevenBytes = await _fetchElevenLabsAudio(chunk);
      if (elevenBytes != null && elevenBytes.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.play(
          BytesSource(elevenBytes),
          mode: PlayerMode.mediaPlayer,
        );
        return;
      }
    } catch (e) {
      debugPrint('ElevenLabs Voice failed, falling back: $e');
    }

    // 2. Try High-Quality Google Cloud Neural Voice with Enhanced Kurdish Phonetics
    try {
      final neuralBytes = await _fetchGoogleCloudNeuralAudio(chunk, apiKey: _customApiKey);
      if (neuralBytes != null && neuralBytes.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.play(
          BytesSource(neuralBytes),
          mode: PlayerMode.mediaPlayer,
        );
        return;
      }
    } catch (e) {
      debugPrint('Neural Voice failed, trying standard endpoint: $e');
    }

    // 2. Fallback to enhanced Google Translate Audio endpoint
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

      await _flutterTts.setSpeechRate((0.48 * _playbackSpeed).clamp(0.2, 1.0));
      await _flutterTts.setVolume(1.0);
      _flutterTts.setCompletionHandler(() {
        if (_isSpeaking && _currentChunkIndex < _chunks.length) {
          _playNextChunk();
        } else if (_isSpeaking) {
          // All chunks done via local TTS — fire onDone
          final cb = _onDone;
          _onDone = null;
          stop().then((_) => cb?.call());
        }
      });
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error in fallback local TTS: $e');
      await stop();
    }
  }

  /// Stop playback immediately (does NOT call onDone — user-initiated stop)
  Future<void> stop() async {
    _isSpeaking = false;
    isSpeakingNotifier.value = false;
    _onDone = null; // Clear pending callback on explicit stop
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

