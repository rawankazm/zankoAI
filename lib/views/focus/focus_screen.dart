import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  Timer? _timer;
  int _secondsRemaining = 1500; // 25 minutes
  int _totalSeconds = 1500;
  bool _isRunning = false;
  bool _isBreakMode = false;

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timerCompleted();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsRemaining = _isBreakMode ? 300 : 1500;
      _totalSeconds = _isBreakMode ? 300 : 1500;
    });
  }

  void _timerCompleted() {
    _timer?.cancel();
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    
    if (!_isBreakMode) {
      dbService.incrementPomodoros();
      // Switched to break mode
      setState(() {
        _isBreakMode = true;
        _secondsRemaining = 300; // 5 min break
        _totalSeconds = 300;
        _isRunning = false;
      });
      _showCompletionDialog(Provider.of<LanguageProvider>(context, listen: false).translate('focus_complete'), Provider.of<LanguageProvider>(context, listen: false).translate('break_session'));
    } else {
      // Switched back to work mode
      setState(() {
        _isBreakMode = false;
        _secondsRemaining = 1500;
        _totalSeconds = 1500;
        _isRunning = false;
      });
      _showCompletionDialog(Provider.of<LanguageProvider>(context, listen: false).translate('break_complete'), Provider.of<LanguageProvider>(context, listen: false).translate('focus_session'));
    }
  }

  void _showCompletionDialog(String title, String desc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(desc, style: const TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('ok')),
          ),
        ],
      ),
    );
  }

  void _toggleMode() {
    _timer?.cancel();
    setState(() {
      _isBreakMode = !_isBreakMode;
      _isRunning = false;
      _secondsRemaining = _isBreakMode ? 300 : 1500;
      _totalSeconds = _isBreakMode ? 300 : 1500;
    });
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    String minStr = minutes.toString().padLeft(2, '0');
    String secStr = seconds.toString().padLeft(2, '0');
    return '$minStr:$secStr';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final __lang = Provider.of<LanguageProvider>(context);
    String t(String key) => __lang.translate(key);
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    // Translations
    final title = t('focus_timer_title');
    final modeStudy = t('focus_session');
    final modeBreak = t('break_session');
    final toggleStudy = t('switch_to_focus');
    final toggleBreak = t('switch_to_break');

    final progress = _secondsRemaining / _totalSeconds;
    final activeColor = _isBreakMode ? Colors.green.shade600 : Colors.deepOrange.shade600;

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mode indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: activeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_isBreakMode ? Icons.coffee_rounded : Icons.local_library_rounded, color: activeColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _isBreakMode ? modeBreak : modeStudy,
                        style: TextStyle(
                          color: activeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Animated Circular Timer Progress
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: TimerPainter(progress: progress, color: activeColor),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatTime(_secondsRemaining),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isBreakMode ? t('break_label') : t('focus_label'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // Control buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.refresh_rounded),
                      iconSize: 28,
                      onPressed: _resetTimer,
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(24),
                        backgroundColor: activeColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isRunning ? _pauseTimer : _startTimer,
                      child: Icon(
                        _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton.filledTonal(
                      icon: Icon(_isBreakMode ? Icons.menu_book_rounded : Icons.coffee_rounded),
                      iconSize: 28,
                      tooltip: _isBreakMode ? toggleStudy : toggleBreak,
                      onPressed: _toggleMode,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Painter to draw Pomodoro Timer ring
class TimerPainter extends CustomPainter {
  final double progress;
  final Color color;

  TimerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = size.center(Offset.zero);

    // Background track ring
    final Paint trackPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc
    final Paint activePaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double sweepAngle = 2 * 3.1415926535 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926535 / 2, // starts from 12 o'clock
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant TimerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
