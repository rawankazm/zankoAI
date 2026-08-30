import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Stats
  int _completedSessionsToday = 0;
  int _totalStudyMinutesToday = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _focusDurationMinutes * 60;
    _loadStats();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().split('T').first;
    if (mounted) {
      setState(() {
        _completedSessionsToday = prefs.getInt('pomo_sessions_$todayKey') ?? 0;
        _totalStudyMinutesToday = prefs.getInt('pomo_minutes_$todayKey') ?? 0;
      });
    }
  }

  Future<void> _saveSessionCompleted(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().split('T').first;
    _completedSessionsToday += 1;
    _totalStudyMinutesToday += minutes;
    await prefs.setInt('pomo_sessions_$todayKey', _completedSessionsToday);
    await prefs.setInt('pomo_minutes_$todayKey', _totalStudyMinutesToday);
    if (mounted) {
      setState(() {});
    }
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) {
          setState(() => _remainingSeconds--);
        }
      } else {
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() => _isRunning = false);
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _remainingSeconds = _getDurationForMode(_mode) * 60;
      });
    }
  }

  void _onTimerComplete() {
    _timer?.cancel();
    if (mounted) {
      setState(() => _isRunning = false);
    }

    if (_mode == _PomodoroMode.focus) {
      _saveSessionCompleted(_focusDurationMinutes);
      _showBreakSelectionModal();
    } else {
      _showResumeFocusDialog();
    }
  }

  void _switchMode(_PomodoroMode newMode, {bool autoStart = false}) {
    _timer?.cancel();
    setState(() {
      _mode = newMode;
      _isRunning = false;
      _remainingSeconds = _getDurationForMode(newMode) * 60;
    });
    if (autoStart) {
      _startTimer();
    }
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

  /// Displays the interactive modal after 25 min of focus with options for 5 min or 15 min break
  void _showBreakSelectionModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Icon & Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🎉', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'خولەکە بە سەرکەوتوویی تەواو بوو!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ئێستا کاتی پشوودانە، جۆری پشووەکەت هەڵبژێرە:',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Option 1: Short Break (5 min)
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _switchMode(_PomodoroMode.shortBreak, autoStart: true);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('☕', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'پشووی کورت (٥ خولەک)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'پشوویەکی خێرا بۆ چاوەکانت و ئاو خواردنەوە',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(CupertinoIcons.play_circle_fill, color: Color(0xFF10B981), size: 28),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Long Break (15 min)
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _switchMode(_PomodoroMode.longBreak, autoStart: true);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('🌴', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'پشووی درێژ (١٥ خولەک)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'پشوویەکی تەواو دوای چەند خولێکی تەرکیز',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(CupertinoIcons.play_circle_fill, color: Color(0xFF3B82F6), size: 28),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Dialog shown when break time finishes to resume 25-minute focus session
  void _showResumeFocusDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('💪', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('پشوودان تەواو بوو!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'کاتی پشوودان کۆتایی هات. ئایا ئامادەیت بۆ دەستپێکردنی خولێکی نوێی ٢٥ خولەکی تەرکیز؟',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _switchMode(_PomodoroMode.focus, autoStart: true);
            },
            icon: const Icon(CupertinoIcons.play_fill, size: 16, color: Colors.white),
            label: const Text(
              'دەستپێکردنی تەرکیز (٢٥خ) 🎯',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        _showBreakSelectionModal();
                      } else {
                        _switchMode(_PomodoroMode.focus, autoStart: true);
                      }
                    },
                    iconSize: 28,
                    tooltip: 'پەڕینەوە',
                    icon: Icon(CupertinoIcons.forward_fill, color: isDark ? Colors.white60 : Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Pomodoro Technique Tips Card ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: modeColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.lightbulb_fill, color: modeColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'یاسای تەرکیزی پۆمۆدۆرۆ (Pomodoro Rule)',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '• ٢٥ خولەک بە تەواوی تەرکیز بکە بەبێ ئەوەی دەست بۆ مۆبایل و تۆڕە کۆمەڵایەتییەکان ببەیت.\n'
                      '• دوای هەر خولێک ٥ خولەک پشووی کورت وەربگرە.\n'
                      '• دوای ٤ خولی تەواو، پشووی درێژی ١٥ خولەکی وەربگرە بۆ نوێکردنەوەی وزەی مێشکت.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: isDark ? Colors.grey[300] : ZankoColors.textSecondary,
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
