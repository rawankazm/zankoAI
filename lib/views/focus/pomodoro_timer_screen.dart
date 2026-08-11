import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';

enum _PomodoroMode { focus, shortBreak, longBreak }

class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen>
    with SingleTickerProviderStateMixin {
  _PomodoroMode _mode = _PomodoroMode.focus;

  // Preset Durations in Minutes
  final int _focusDurationMinutes = 25;
  final int _shortBreakDurationMinutes = 5;
  final int _longBreakDurationMinutes = 15;

  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;

  late final AudioPlayer _audioPlayer;
  String _selectedSound = 'rain';
  bool _isPlayingSound = false;

  // Stats
  int _completedSessionsToday = 0;
  int _totalStudyMinutesToday = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _remainingSeconds = _focusDurationMinutes * 60;
    _loadStats();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String soundId) async {
    final soundUrls = {
      'lofi': 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
      'piano': 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      'rain': 'https://actions.google.com/sounds/v1/weather/rain_heavy_loud.ogg',
      'waves': 'https://actions.google.com/sounds/v1/water/ocean_waves.ogg',
      'forest': 'https://actions.google.com/sounds/v1/ambiences/outdoor_forest.ogg',
      'zen': 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a8018e.mp3',
      'alpha': 'https://cdn.pixabay.com/download/audio/2022/10/14/audio_9939f73f27.mp3',
      'library': 'https://actions.google.com/sounds/v1/ambiences/coffee_shop.ogg',
    };

    try {
      final url = soundUrls[soundId];
      if (url != null) {
        await _audioPlayer.stop();
        setState(() {
          _selectedSound = soundId;
          _isPlayingSound = true;
        });
        await _audioPlayer.play(UrlSource(url));
      }
    } catch (e) {
      if (kDebugMode) print('Audio play error: $e');
    }
  }

  Future<void> _toggleSound() async {
    if (_isPlayingSound) {
      await _audioPlayer.pause();
      setState(() => _isPlayingSound = false);
    } else {
      await _playSound(_selectedSound);
    }
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().split('T').first;
    setState(() {
      _completedSessionsToday = prefs.getInt('pomo_sessions_$todayKey') ?? 0;
      _totalStudyMinutesToday = prefs.getInt('pomo_minutes_$todayKey') ?? 0;
    });
  }

  Future<void> _saveSessionCompleted(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().split('T').first;
    _completedSessionsToday += 1;
    _totalStudyMinutesToday += minutes;
    await prefs.setInt('pomo_sessions_$todayKey', _completedSessionsToday);
    await prefs.setInt('pomo_minutes_$todayKey', _totalStudyMinutesToday);
    setState(() {});
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _getDurationForMode(_mode) * 60;
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    setState(() => _isRunning = false);

    if (_mode == _PomodoroMode.focus) {
      _saveSessionCompleted(_focusDurationMinutes);
      _switchMode(_PomodoroMode.shortBreak);
      _showCompletionDialog('🎉 کاتی خوێندن بە سەرکەوتوویی تەواو بوو! کاتی ٥ خولەک پشوودانە.');
    } else {
      _switchMode(_PomodoroMode.focus);
      _showCompletionDialog('💪 پشوودان تەواو بوو! ئامادەیت بۆ خولێکی نوێی خوێندن؟');
    }
  }

  void _switchMode(_PomodoroMode newMode) {
    _timer?.cancel();
    setState(() {
      _mode = newMode;
      _isRunning = false;
      _remainingSeconds = _getDurationForMode(newMode) * 60;
    });
  }

  int _getDurationForMode(_PomodoroMode mode) {
    switch (mode) {
      case _PomodoroMode.focus:
        return _focusDurationMinutes;
      case _PomodoroMode.shortBreak:
        return _shortBreakDurationMinutes;
      case _PomodoroMode.longBreak:
        return _longBreakDurationMinutes;
    }
  }

  void _showCompletionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('⏱️ کاتژمێری تەرکیز', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZankoColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('دەستپێکردنەوە', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);

    final totalSecsForMode = _getDurationForMode(_mode) * 60;
    final progress = totalSecsForMode > 0 ? (totalSecsForMode - _remainingSeconds) / totalSecsForMode : 0.0;

    final modeColor = _mode == _PomodoroMode.focus
        ? const Color(0xFFEF4444)
        : (_mode == _PomodoroMode.shortBreak ? const Color(0xFF10B981) : const Color(0xFF3B82F6));

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.timer, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 8),
              Text(
                'کاتژمێری تەرکیز (Pomodoro)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // ── Mode Switcher Selector ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? ZankoColors.darkCard : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildModeTab(_PomodoroMode.focus, '🧠 تەرکیز (٢٥خ)', modeColor, isDark),
                    _buildModeTab(_PomodoroMode.shortBreak, '☕ پشووی کورت (٥خ)', modeColor, isDark),
                    _buildModeTab(_PomodoroMode.longBreak, '🌿 پشووی درێژ (١٥خ)', modeColor, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Circular Timer Display ────────────────────────────────────
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: modeColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(modeColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: modeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _mode == _PomodoroMode.focus
                                ? 'کاتژمێری خوێندن'
                                : (_mode == _PomodoroMode.shortBreak ? 'پشووی کورت' : 'پشووی درێژ'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: modeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Timer Controls (Start / Pause / Reset) ────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _resetTimer,
                    iconSize: 28,
                    icon: Icon(CupertinoIcons.refresh_thin, color: isDark ? Colors.white60 : Colors.grey[600]),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: modeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 8,
                      shadowColor: modeColor.withValues(alpha: 0.4),
                    ),
                    child: Row(
                      children: [
                        Icon(_isRunning ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          _isRunning ? 'وەستاندن' : 'دەستپێکردن',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      if (_mode == _PomodoroMode.focus) {
                        _switchMode(_PomodoroMode.shortBreak);
                      } else {
                        _switchMode(_PomodoroMode.focus);
                      }
                    },
                    iconSize: 28,
                    icon: Icon(CupertinoIcons.forward_fill, color: isDark ? Colors.white60 : Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Ambient Focus Sounds Player (Lo-Fi & Nature) ───────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? ZankoColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[200]!,
                  ),
                  boxShadow: isDark ? [] : ZankoShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.music_note_2, color: ZankoColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'مۆسیقا و دەنگی هێمنکەرەوە (Focus Music)',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleSound,
                          icon: Icon(
                            _isPlayingSound ? CupertinoIcons.speaker_2_fill : CupertinoIcons.speaker_slash_fill,
                            color: _isPlayingSound ? ZankoColors.primary : Colors.grey,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Sound presets chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSoundChip('lofi', '🎧 Lo-Fi Study Beats'),
                          _buildSoundChip('piano', '🎹 پیانۆی هێمنی خوێندن'),
                          _buildSoundChip('rain', '🌧️ بارانی هێمن'),
                          _buildSoundChip('waves', '🌊 شەپۆلی دەریا'),
                          _buildSoundChip('forest', '🍃 بای دارستان'),
                          _buildSoundChip('zen', '🧘 مۆسیقای تەرکیزی قووڵ'),
                          _buildSoundChip('alpha', '🧠 شەپۆلی ئەلفا'),
                          _buildSoundChip('library', '📚 دەنگی کتێبخانە'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Today's Study Stats Summary ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '🍅 خولەکانی ئەمرۆ',
                      '$_completedSessionsToday دانیشتن',
                      CupertinoIcons.checkmark_seal_fill,
                      const Color(0xFFEF4444),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildStatCard(
                      '⏱️ کاتژمێری خوێندن',
                      '$_totalStudyMinutesToday خولەک',
                      CupertinoIcons.time_solid,
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(_PomodoroMode mode, String label, Color color, bool isDark) {
    final isSel = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSel ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSoundChip(String id, String label) {
    final isSel = _selectedSound == id && _isPlayingSound;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
        selected: isSel,
        selectedColor: ZankoColors.primary.withValues(alpha: 0.2),
        backgroundColor: Colors.transparent,
        side: BorderSide(color: isSel ? ZankoColors.primary : Colors.grey[400]!),
        onSelected: (sel) {
          if (sel) {
            _playSound(id);
          } else {
            _audioPlayer.pause();
            setState(() => _isPlayingSound = false);
          }
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final brightColor = (color == const Color(0xFFEF4444))
        ? (isDark ? const Color(0xFFFF6B6B) : const Color(0xFFDC2626))
        : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: brightColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: brightColor.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  brightColor,
                  brightColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: brightColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
