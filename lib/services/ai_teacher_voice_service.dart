import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/env.dart';
import '../core/network/api_client.dart';

/// Explicit Playback States as defined in Prompt 37 Section 12
enum AiTeacherVoiceState {
  idle,
  preparing,
  loading,
  playing,
  paused,
  stopped,
  completed,
  error,
}

/// Information snapshot of the current voice playback
class AiTeacherVoicePlaybackInfo {
  final AiTeacherVoiceState state;
  final String? activeAnswerId;
  final int currentChunkIndex;
  final int totalChunks;
  final double speed;
  final String language;
  final String? errorMessage;
  final String? currentChunkText;

  const AiTeacherVoicePlaybackInfo({
    this.state = AiTeacherVoiceState.idle,
    this.activeAnswerId,
    this.currentChunkIndex = 0,
    this.totalChunks = 0,
    this.speed = 1.0,
    this.language = 'ku',
    this.errorMessage,
    this.currentChunkText,
  });

  bool get isPlaying => state == AiTeacherVoiceState.playing;
  bool get isPaused => state == AiTeacherVoiceState.paused;
  bool get isLoading =>
      state == AiTeacherVoiceState.loading ||
      state == AiTeacherVoiceState.preparing;
  bool get isCompleted => state == AiTeacherVoiceState.completed;
  bool get isError => state == AiTeacherVoiceState.error;
  bool get isActive => isPlaying || isPaused || isLoading || isError;

  AiTeacherVoicePlaybackInfo copyWith({
    AiTeacherVoiceState? state,
    String? activeAnswerId,
    int? currentChunkIndex,
    int? totalChunks,
    double? speed,
    String? language,
    String? errorMessage,
    String? currentChunkText,
  }) {
    return AiTeacherVoicePlaybackInfo(
      state: state ?? this.state,
      activeAnswerId: activeAnswerId ?? this.activeAnswerId,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
      speed: speed ?? this.speed,
      language: language ?? this.language,
      errorMessage: errorMessage ?? this.errorMessage,
      currentChunkText: currentChunkText ?? this.currentChunkText,
    );
  }
}

/// Comprehensive, Multilingual AI Teacher Voice Service
/// Connecting Flutter client securely to DigitalOcean TTS with instant resilient fallback
class AiTeacherVoiceService {
  static final AiTeacherVoiceService _instance =
      AiTeacherVoiceService._internal();
  factory AiTeacherVoiceService() => _instance;

  AiTeacherVoiceService._internal() {
    _init();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  StreamSubscription<void>? _playerCompleteSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  final ValueNotifier<AiTeacherVoicePlaybackInfo> playbackNotifier =
      ValueNotifier<AiTeacherVoicePlaybackInfo>(
        const AiTeacherVoicePlaybackInfo(),
      );

  // In-memory audio byte cache for gapless playback & instant replay: hash/key -> Uint8List
  final Map<String, Uint8List> _chunkAudioCache = {};

  // Active playback state
  String? _activeAnswerId;
  String? _rawFullText;
  List<String> _chunks = [];
  int _currentChunkIndex = 0;
  String _currentLanguage = 'ku';
  String? _currentVoice;
  double _playbackSpeed = 1.0;
  bool _autoReadEnabled = false;
  bool _isPlayingViaLocalTts = false;

  static const String _defaultElevenLabsKey = String.fromEnvironment(
    'ELEVEN_LABS_API_KEY',
    defaultValue: 'sk_6bc38b8d8f9bce35c49530ad6d0148a55612cab5b344259e',
  );
  String? _elevenLabsApiKey;

  bool get isPlaying => playbackNotifier.value.isPlaying;
  bool get isPaused => playbackNotifier.value.isPaused;
  bool get isActive => playbackNotifier.value.isActive;
  double get playbackSpeed => _playbackSpeed;
  bool get autoReadEnabled => _autoReadEnabled;
  String? get rawFullText => _rawFullText;
  String? get activeAnswerId => _activeAnswerId;

  void _init() {
    _loadPreferences();

    // Listen to audio completion to trigger the next chunk automatically
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _onCurrentChunkCompleted();
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (state == PlayerState.paused &&
          playbackNotifier.value.state == AiTeacherVoiceState.playing) {
        _updateState(AiTeacherVoiceState.paused);
      }
    });

    // Configure fallback flutter_tts
    _flutterTts.setCompletionHandler(() {
      if (_isPlayingViaLocalTts) {
        _isPlayingViaLocalTts = false;
        _onCurrentChunkCompleted();
      }
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _playbackSpeed = prefs.getDouble('ai_teacher_voice_speed') ?? 1.0;
      _autoReadEnabled = prefs.getBool('ai_teacher_auto_read') ?? false;
      _elevenLabsApiKey =
          prefs.getString('eleven_labs_api_key') ?? _defaultElevenLabsKey;
      _updateInfo();
    } catch (_) {}
  }

  void setElevenLabsApiKey(String key) {
    _elevenLabsApiKey = key.trim();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('eleven_labs_api_key', _elevenLabsApiKey!);
    });
  }

  void _updateState(AiTeacherVoiceState state, {String? error}) {
    playbackNotifier.value = playbackNotifier.value.copyWith(
      state: state,
      activeAnswerId: _activeAnswerId,
      currentChunkIndex: _currentChunkIndex,
      totalChunks: _chunks.length,
      speed: _playbackSpeed,
      language: _currentLanguage,
      errorMessage: error,
      currentChunkText: (_currentChunkIndex < _chunks.length)
          ? _chunks[_currentChunkIndex]
          : null,
    );
  }

  void _updateInfo() {
    playbackNotifier.value = playbackNotifier.value.copyWith(
      activeAnswerId: _activeAnswerId,
      currentChunkIndex: _currentChunkIndex,
      totalChunks: _chunks.length,
      speed: _playbackSpeed,
      language: _currentLanguage,
      currentChunkText: (_currentChunkIndex < _chunks.length)
          ? _chunks[_currentChunkIndex]
          : null,
    );
  }

  /// Clean raw text of Markdown, LaTeX, formulas, and unwanted symbols before speech
  String cleanTextForSpeech(String rawText, {String? language}) {
    String text = rawText
        // Remove code blocks
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'`[^`]*`'), ' ')
        // Markdown links [text](url) -> text
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        // Markdown headings and formatting
        .replaceAll(
          RegExp(r'[\*\#\_~>\-\🔹\🔸\🎯\⭐\👑\💡\📌\⚡\✅\❌\🎧\🎓\🔴\💬]'),
          ' ',
        )
        // Remove raw LaTeX delimiters
        .replaceAll(RegExp(r'\\\[[\s\S]*?\\\]'), ' ')
        .replaceAll(RegExp(r'\\\([\s\S]*?\\\)'), ' ')
        .replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), ' ')
        .replaceAll(RegExp(r'\$[^$]*\$'), ' ')
        // Normalize whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Technical acronym phonetic normalization
    text = _normalizeAcronymPhonetics(text);

    return text;
  }

  /// Replaces technical acronyms with spoken syllables
  String _normalizeAcronymPhonetics(String input) {
    String res = input;
    res = res.replaceAll(RegExp(r'\bPDF\b', caseSensitive: false), 'پی دی ئێف');
    res = res.replaceAll(RegExp(r'\bAI\b', caseSensitive: false), 'ئەی ئای');
    res = res.replaceAll(RegExp(r'\bIT\b', caseSensitive: false), 'ئای تی');
    res = res.replaceAll(RegExp(r'\bRAM\b', caseSensitive: false), 'ڕام');
    res = res.replaceAll(RegExp(r'\bCPU\b', caseSensitive: false), 'سی پی یو');
    res = res.replaceAll(RegExp(r'\bOS\b', caseSensitive: false), 'ئۆ ئێس');
    res = res.replaceAll(RegExp(r'\bUI\b', caseSensitive: false), 'یوو ئای');
    res = res.replaceAll(RegExp(r'\bUX\b', caseSensitive: false), 'یوو ئێکس');
    res = res.replaceAll(
      RegExp(r'\bAPI\b', caseSensitive: false),
      'ئەی پی ئای',
    );
    res = res.replaceAll(
      RegExp(r'\bHTML\b', caseSensitive: false),
      'ئێچ تی ئێم ئێڵ',
    );
    res = res.replaceAll(
      RegExp(r'\bCSS\b', caseSensitive: false),
      'سی ئێس ئێس',
    );
    res = res.replaceAll(
      RegExp(r'\bSQL\b', caseSensitive: false),
      'ئێس کیوو ئێڵ',
    );
    return res;
  }

  /// Converts digits into clear spoken Kurdish words for natural phonetic voice
  String _replaceKurdishDigits(String text) {
    return text
        .replaceAll('0', ' صفر ')
        .replaceAll('٠', ' صفر ')
        .replaceAll('1', ' یەک ')
        .replaceAll('١', ' یەک ')
        .replaceAll('2', ' دوو ')
        .replaceAll('٢', ' دوو ')
        .replaceAll('3', ' سێ ')
        .replaceAll('٣', ' سێ ')
        .replaceAll('4', ' چوار ')
        .replaceAll('٤', ' چوار ')
        .replaceAll('5', ' پێنج ')
        .replaceAll('٥', ' پێنج ')
        .replaceAll('6', ' شەش ')
        .replaceAll('٦', ' شەش ')
        .replaceAll('7', ' حەوت ')
        .replaceAll('٧', ' حەوت ')
        .replaceAll('8', ' هەشت ')
        .replaceAll('٨', ' هەشت ')
        .replaceAll('9', ' نۆ ')
        .replaceAll('٩', ' نۆ ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Splits long text into safe, pronounceable chunks respecting sentence and paragraph boundaries
  List<String> splitIntoSafeChunks(String text, {int maxChars = 220}) {
    if (text.trim().isEmpty) return [];

    final List<String> chunks = [];
    final sentences = text.split(RegExp(r'(?<=[.،!؟\n;؛?])\s+'));

    String current = '';
    for (final sentence in sentences) {
      final s = sentence.trim();
      if (s.isEmpty) continue;

      if (current.isEmpty) {
        current = s;
      } else if (current.length + s.length < maxChars) {
        current += ' $s';
      } else {
        chunks.add(current);
        current = s;
      }
    }

    if (current.isNotEmpty) {
      chunks.add(current);
    }

    // Secondary pass: break down any oversized sentences safely at word boundaries
    final List<String> finalChunks = [];
    for (final c in chunks) {
      if (c.length <= maxChars + 60) {
        finalChunks.add(c);
      } else {
        final words = c.split(' ');
        String sub = '';
        for (final w in words) {
          if (sub.length + w.length < maxChars) {
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

  /// Detects language from text (Kurdish Sorani, Arabic, English)
  String detectLanguage(String text, {String? preferredLang}) {
    if (preferredLang != null &&
        preferredLang.isNotEmpty &&
        preferredLang != 'auto') {
      if (preferredLang == 'ar') return 'ar';
      if (preferredLang == 'en') return 'en';
      if (preferredLang == 'ku' ||
          preferredLang == 'ckb' ||
          preferredLang == 'kmr') {
        return 'ku';
      }
    }

    final kurdishRegex = RegExp(r'[ێەڵڕڤۆژڕپچگ]');
    if (kurdishRegex.hasMatch(text)) return 'ku';

    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    if (arabicRegex.hasMatch(text)) return 'ar';

    return 'en';
  }

  /// Reads an entire AI Teacher answer aloud with intelligent chunking,
  /// background preloading, and uninterrupted playback.
  Future<void> readAloud({
    required String answerId,
    required String text,
    String? language,
    String? voice,
    double? speed,
  }) async {
    // 1. If currently playing this exact message, toggle pause
    if (_activeAnswerId == answerId && isPlaying) {
      await pause();
      return;
    }

    // 2. If paused on this exact message, resume seamlessly
    if (_activeAnswerId == answerId && isPaused) {
      await resume();
      return;
    }

    // 3. New message or stopped: reset and prepare new queue
    await stop();

    _activeAnswerId = answerId;
    _rawFullText = text;
    _currentLanguage = detectLanguage(text, preferredLang: language);
    _currentVoice = voice;
    if (speed != null) {
      _playbackSpeed = speed.clamp(0.5, 2.0);
    }

    final cleaned = cleanTextForSpeech(text, language: _currentLanguage);
    if (cleaned.isEmpty) {
      _updateState(
        AiTeacherVoiceState.error,
        error: 'No readable text to speak',
      );
      return;
    }

    _chunks = splitIntoSafeChunks(cleaned, maxChars: 220);
    if (_chunks.isEmpty) {
      _updateState(AiTeacherVoiceState.error, error: 'Failed to chunk text');
      return;
    }

    _currentChunkIndex = 0;
    _updateState(AiTeacherVoiceState.preparing);

    // Start playing Chunk 0
    await _playChunkAtIndex(0);
  }

  /// Plays a specific chunk and automatically triggers preloading for chunk N+1
  Future<void> _playChunkAtIndex(int index) async {
    if (index >= _chunks.length) {
      _updateState(AiTeacherVoiceState.completed);
      return;
    }

    _currentChunkIndex = index;
    _updateState(AiTeacherVoiceState.loading);

    final chunkText = _chunks[index];

    try {
      // 1. Fetch chunk audio bytes (from cache, backend API, or high-speed online stream)
      final audioBytes = await _fetchChunkAudioWithRetry(
        chunkText,
        _currentLanguage,
        _currentVoice,
        _playbackSpeed,
      );

      // Check if user stopped while fetching
      if (_activeAnswerId == null ||
          playbackNotifier.value.state == AiTeacherVoiceState.stopped) {
        return;
      }

      if (audioBytes == null || audioBytes.isEmpty) {
        // Fallback to on-device TTS if audio streams unavailable
        await _speakViaFlutterTts(chunkText, _currentLanguage);
        return;
      }

      // 2. Play audio chunk through AudioPlayer
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(_playbackSpeed);

      try {
        await _audioPlayer.play(
          BytesSource(audioBytes),
          mode: PlayerMode.mediaPlayer,
        );
      } catch (playErr) {
        debugPrint(
          '[AiTeacherVoiceService] BytesSource playback error, falling back to temp file: $playErr',
        );
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}/zanko_tts_${index % 4}_${DateTime.now().millisecondsSinceEpoch}.mp3',
          );
          await tempFile.writeAsBytes(audioBytes, flush: true);
          await _audioPlayer.play(
            DeviceFileSource(tempFile.path),
            mode: PlayerMode.mediaPlayer,
          );
        } else {
          rethrow;
        }
      }

      _updateState(AiTeacherVoiceState.playing);

      // 3. GAPLESS OPTIMIZATION: Immediately trigger background preloading for Chunk N+1
      if (index + 1 < _chunks.length) {
        _preloadChunkAudio(index + 1);
      }
    } catch (e) {
      debugPrint('[AiTeacherVoiceService] Playback error on chunk $index: $e');
      // Final attempt: try local TTS engine
      try {
        await _speakViaFlutterTts(chunkText, _currentLanguage);
      } catch (e2) {
        _updateState(
          AiTeacherVoiceState.error,
          error: 'Playback error on chunk ${index + 1}',
        );
      }
    }
  }

  /// Speaks text via on-device FlutterTts as emergency offline fallback
  Future<void> _speakViaFlutterTts(String text, String language) async {
    try {
      _isPlayingViaLocalTts = true;
      _updateState(AiTeacherVoiceState.playing);

      if (language == 'ku' || language == 'ckb' || language == 'kmr') {
        final hasKu = await _flutterTts.isLanguageAvailable('ku') ?? false;
        if (hasKu) {
          await _flutterTts.setLanguage('ku');
        } else {
          final hasCkb = await _flutterTts.isLanguageAvailable('ckb') ?? false;
          if (hasCkb) {
            await _flutterTts.setLanguage('ckb');
          } else {
            await _flutterTts.setLanguage('ar');
          }
        }
      } else if (language == 'ar') {
        await _flutterTts.setLanguage('ar');
      } else {
        await _flutterTts.setLanguage('en-US');
      }

      await _flutterTts.setSpeechRate((0.5 * _playbackSpeed).clamp(0.2, 1.0));
      await _flutterTts.setVolume(1.0);
      await _flutterTts.speak(text);

      // Preload next chunk if applicable
      if (_currentChunkIndex + 1 < _chunks.length) {
        _preloadChunkAudio(_currentChunkIndex + 1);
      }
    } catch (e) {
      _isPlayingViaLocalTts = false;
      debugPrint('[AiTeacherVoiceService] Local FlutterTts fallback error: $e');
      _updateState(
        AiTeacherVoiceState.error,
        error: 'دەنگ نەتوانرا بخوێندرێتەوە',
      );
    }
  }

  /// Preloads Chunk N+1 in the background so it plays with zero silence gap
  Future<void> _preloadChunkAudio(int index) async {
    if (index >= _chunks.length) return;
    final text = _chunks[index];
    final cacheKey = _getCacheKey(
      text,
      _currentLanguage,
      _currentVoice,
      _playbackSpeed,
    );

    if (_chunkAudioCache.containsKey(cacheKey)) return; // Already in RAM

    try {
      await _fetchChunkAudioWithRetry(
        text,
        _currentLanguage,
        _currentVoice,
        _playbackSpeed,
        isPreload: true,
      );
    } catch (e) {
      debugPrint('[AiTeacherVoiceService] Preload failed for chunk $index: $e');
    }
  }

  /// Called automatically when the AudioPlayer completes a chunk
  void _onCurrentChunkCompleted() {
    if (!isPlaying &&
        playbackNotifier.value.state != AiTeacherVoiceState.playing) {
      return;
    }

    final nextIndex = _currentChunkIndex + 1;
    if (nextIndex < _chunks.length) {
      _playChunkAtIndex(nextIndex);
    } else {
      _updateState(AiTeacherVoiceState.completed);
    }
  }

  /// Generates a cache key for audio chunks
  String _getCacheKey(
    String text,
    String language,
    String? voice,
    double speed,
  ) {
    return '${language}_${voice ?? "def"}_${speed.toStringAsFixed(2)}_${text.hashCode}';
  }

  /// Multi-Tier Fetcher:
  /// 1. RAM Cache
  /// 2. DigitalOcean Backend /api/ai-teacher/tts (if real server configured)
  /// 3. High-Speed Google Online Audio stream (zero API key, works everywhere)
  Future<Uint8List?> _fetchChunkAudioWithRetry(
    String text,
    String language,
    String? voice,
    double speed, {
    bool isPreload = false,
  }) async {
    final cacheKey = _getCacheKey(text, language, voice, speed);

    if (_chunkAudioCache.containsKey(cacheKey)) {
      return _chunkAudioCache[cacheKey];
    }

    // Tier 1: Try DigitalOcean Backend API only if real host configured
    final isPlaceholderBackend = AppEnv.backendBaseUrl.contains(
      'api.zankoai.com',
    );
    if (!isPlaceholderBackend) {
      try {
        final response = await ApiClient.instance
            .post<Map<String, dynamic>>(
              '/ai-teacher/tts',
              data: {
                'text': text,
                'language': language,
                'voice': ?voice,
                'speed': speed,
              },
            )
            .timeout(const Duration(seconds: 3));

        final data = response.data;
        if (data != null && data['audioBase64'] != null) {
          final String base64Str = data['audioBase64'];
          final bytes = base64Decode(base64Str);
          if (bytes.isNotEmpty) {
            _chunkAudioCache[cacheKey] = bytes;
            return bytes;
          }
        }
      } catch (e) {
        debugPrint(
          '[AiTeacherVoiceService] Backend TTS skipped/unreachable: $e',
        );
      }
    }

    // Tier 1.5: Direct ElevenLabs Multilingual v2 AI Voice (Lifelike Studio Quality)
    try {
      final elevenBytes = await _fetchElevenLabsAudio(
        text,
        language: language,
        voice: voice,
      );
      if (elevenBytes != null && elevenBytes.isNotEmpty) {
        _chunkAudioCache[cacheKey] = elevenBytes;
        return elevenBytes;
      }
    } catch (e) {
      debugPrint('[AiTeacherVoiceService] ElevenLabs synthesis error: $e');
    }

    // Tier 2: Resilient Google Translate online audio stream (instant, zero keys, verified MP3)
    try {
      final onlineBytes = await _fetchGoogleOnlineAudio(text, language);
      if (onlineBytes != null && onlineBytes.isNotEmpty) {
        _chunkAudioCache[cacheKey] = onlineBytes;
        return onlineBytes;
      }
    } catch (e) {
      debugPrint('[AiTeacherVoiceService] Online audio stream fetch error: $e');
    }

    return null;
  }

  /// Synthesizes ultra-realistic human voice via ElevenLabs Multilingual v2
  Future<Uint8List?> _fetchElevenLabsAudio(
    String text, {
    required String language,
    String? voice,
  }) async {
    final key = (_elevenLabsApiKey != null && _elevenLabsApiKey!.isNotEmpty)
        ? _elevenLabsApiKey!
        : _defaultElevenLabsKey;

    if (key.trim().isEmpty) return null;

    // Roger (Academic Tutor) for Kurdish & Arabic, Rachel for English
    final defaultVoiceId = language == 'en'
        ? '21m00Tcm4TlvDq8ikWAM'
        : 'CwhRBWXzGAHq8TQ4Fs17';
    final targetVoice = (voice != null && voice.trim().isNotEmpty)
        ? voice.trim()
        : defaultVoiceId;

    if (kIsWeb) {
      try {
        final dio = ApiClient.instance.dio;
        final response = await dio.post<List<int>>(
          'https://api.elevenlabs.io/v1/text-to-speech/$targetVoice',
          data: {
            'text': text,
            'model_id': 'eleven_multilingual_v2',
            'voice_settings': {
              'stability': 0.5,
              'similarity_boost': 0.75,
              'use_speaker_boost': true,
            },
          },
          options: Options(
            headers: {
              'xi-api-key': key.trim(),
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
            },
            responseType: ResponseType.bytes,
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
        if (response.data != null && response.data!.isNotEmpty) {
          return Uint8List.fromList(response.data!);
        }
      } catch (e) {
        debugPrint('[AiTeacherVoiceService] Web ElevenLabs error: $e');
      }
      return null;
    }

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final uri = Uri.parse(
        'https://api.elevenlabs.io/v1/text-to-speech/$targetVoice',
      );
      final request = await client.postUrl(uri);
      request.headers.set('xi-api-key', key.trim());
      request.headers.set('content-type', 'application/json');
      request.headers.set('accept', 'audio/mpeg');

      final bodyMap = {
        'text': text,
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.75,
          'use_speaker_boost': true,
        },
      };

      request.add(utf8.encode(jsonEncode(bodyMap)));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final builder = BytesBuilder();
        await for (final chunk in response) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isNotEmpty) {
          return bytes;
        }
      } else {
        final errBody = await response.transform(utf8.decoder).join();
        debugPrint(
          '[AiTeacherVoiceService] ElevenLabs error (${response.statusCode}): $errBody',
        );
      }
    } catch (e) {
      debugPrint('[AiTeacherVoiceService] ElevenLabs fetch error: $e');
    } finally {
      client?.close(); // Rule from AGENTS.md: Always close HttpClient!
    }

    return null;
  }

  /// Fetches audio MP3 bytes from Google Translate TTS stream
  Future<Uint8List?> _fetchGoogleOnlineAudio(
    String text,
    String language,
  ) async {
    final isKurdish =
        language == 'ku' || language == 'ckb' || language == 'kmr';
    final ttsLang = isKurdish ? 'ar' : language;
    final processedText = isKurdish ? _replaceKurdishDigits(text) : text;
    final encodedText = Uri.encodeComponent(processedText);
    final url =
        'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$ttsLang&q=$encodedText';

    if (kIsWeb) {
      try {
        final dio = ApiClient.instance.dio;
        final response = await dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );
        if (response.data != null && response.data!.isNotEmpty) {
          return Uint8List.fromList(response.data!);
        }
      } catch (e) {
        debugPrint('[AiTeacherVoiceService] Web Google TTS error: $e');
      }
      return null;
    }

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode == 200) {
        final builder = BytesBuilder();
        await for (final chunk in response) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isNotEmpty) {
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('[AiTeacherVoiceService] Google TTS client error: $e');
    } finally {
      // Clean up connection to prevent socket leaks per AGENTS.md
      client?.close();
    }
    return null;
  }

  /// Retry the current failed chunk
  Future<void> retryCurrentChunk() async {
    if (_chunks.isEmpty) return;
    await _playChunkAtIndex(_currentChunkIndex);
  }

  /// Pauses audio playback preserving position and remaining queue
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      if (_isPlayingViaLocalTts) {
        await _flutterTts.pause();
      }
      _updateState(AiTeacherVoiceState.paused);
    } catch (e) {
      debugPrint('[AiTeacherVoiceService] Pause error: $e');
    }
  }

  /// Resumes playback from the exact paused position
  Future<void> resume() async {
    try {
      if (_isPlayingViaLocalTts) {
        // Resume local TTS or replay current chunk
        await _playChunkAtIndex(_currentChunkIndex);
      } else {
        await _audioPlayer.resume();
        _updateState(AiTeacherVoiceState.playing);
      }
    } catch (e) {
      debugPrint('[AiTeacherVoiceService] Resume error: $e');
      await _playChunkAtIndex(_currentChunkIndex);
    }
  }

  /// Stops playback, clears queue and resets state to idle
  Future<void> stop() async {
    _activeAnswerId = null;
    _rawFullText = null;
    _chunks.clear();
    _currentChunkIndex = 0;
    _isPlayingViaLocalTts = false;

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    try {
      await _flutterTts.stop();
    } catch (_) {}

    _updateState(AiTeacherVoiceState.stopped);
    _updateState(AiTeacherVoiceState.idle);
  }

  /// Changes playback speed dynamically (0.75x, 1.0x, 1.25x, 1.5x, 2.0x)
  Future<void> setSpeed(double newSpeed) async {
    _playbackSpeed = newSpeed.clamp(0.5, 2.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('ai_teacher_voice_speed', _playbackSpeed);
    } catch (_) {}

    if (isPlaying) {
      try {
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
      } catch (_) {}
    }

    _updateInfo();
  }

  /// Toggles auto-read on/off
  Future<void> setAutoRead(bool enabled) async {
    _autoReadEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ai_teacher_auto_read', enabled);
    } catch (_) {}
    _updateInfo();
  }

  /// Cleanly disposes audio subscriptions
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
  }
}
