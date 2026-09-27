import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/schedule_model.dart';
import '../../services/ai_service.dart';
import '../../services/database_service.dart';
import '../../services/kurdish_tts_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../widgets/ad_banner_widget.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _courseController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  final _teacherController = TextEditingController();

  late String _selectedDay;
  bool _viewAllDays = false;
  String? _editingLectureId;
  bool _isPlayingVoice = false;
  String? _speakingText;

  final List<String> _kurdishDays = const [
    'شەممە',
    'یەکشەممە',
    'دووشەممە',
    'سێشەممە',
    'چوارشەممە',
    'پێنجشەممە',
    'هەینی',
  ];

  final List<Color> _cardColors = const [
    Color(0xFF3B82F6), // Vibrant Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
  ];

  final List<String> _timePresets = const [
    '08:30 - 10:00',
    '10:15 - 11:45',
    '12:00 - 01:30',
    '01:45 - 03:15',
    '03:30 - 05:00',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _getTodayKurdishDay();
  }

  @override
  void dispose() {
    _courseController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _teacherController.dispose();
    KurdishTtsService().stop();
    super.dispose();
  }

  String _getDaySummaryText(
    String dayName,
    List<ScheduleModel> dayLectures,
    LanguageProvider lang,
  ) {
    final translatedDay = _translateDay(dayName, lang);
    if (dayLectures.isEmpty) {
      if (lang.isEnglish) {
        return 'No lectures scheduled for $translatedDay. Enjoy your day off! 🎉';
      } else if (lang.isArabic) {
        return 'لا توجد أي محاضرات مجدولة ليوم $translatedDay. عطلة سعيدة! 🎉';
      } else {
        return 'لە ڕۆژی $translatedDay دا پشووی فەرمییە و هیچ وانەیەکت نییە! 🎉';
      }
    }

    if (lang.isEnglish) {
      final lessons = dayLectures.map((l) {
        final loc = (l.location.isNotEmpty && l.location != 'Not specified' && l.location != 'دیارینەکراوە')
            ? ' in ${l.location}'
            : '';
        return '${l.courseName} (${l.time})$loc';
      }).join(', ');
      return 'On $translatedDay, you have ${dayLectures.length} lecture${dayLectures.length > 1 ? 's' : ''}: $lessons.';
    } else if (lang.isArabic) {
      final lessons = dayLectures.map((l) {
        final loc = (l.location.isNotEmpty && l.location != 'دیارینەکراوە')
            ? ' في ${l.location}'
            : '';
        return '${l.courseName} (${l.time})$loc';
      }).join('، ');
      return 'في يوم $translatedDay لديك ${dayLectures.length} محاضرات: $lessons.';
    } else {
      final lessons = dayLectures.map((l) {
        final loc = (l.location.isNotEmpty && l.location != 'دیارینەکراوە')
            ? ' لە ${l.location}'
            : '';
        return '${l.courseName} کاتژمێر (${l.time})$loc';
      }).join('، ');
      return 'لە ڕۆژی $translatedDay دا ${dayLectures.length} وانەت هەیە: $lessons.';
    }
  }

  void _toggleSpeakText(String text) {
    HapticFeedback.lightImpact();
    if (_isPlayingVoice && _speakingText == text) {
      KurdishTtsService().stop();
      setState(() {
        _isPlayingVoice = false;
        _speakingText = null;
      });
      return;
    }

    setState(() {
      _isPlayingVoice = true;
      _speakingText = text;
    });

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    KurdishTtsService().speak(
      text,
      languageCode: lang.languageCode,
      onDone: () {
        if (mounted) {
          setState(() {
            _isPlayingVoice = false;
            _speakingText = null;
          });
        }
      },
    );
  }

  void _showWeeklySummarySheet() {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String t(String key) => lang.translate(key);

    final StringBuffer fullTextBuffer = StringBuffer();
    if (lang.isEnglish) {
      fullTextBuffer.writeln('Weekly Schedule Breakdown:');
    } else if (lang.isArabic) {
      fullTextBuffer.writeln('جدول المحاضرات الأسبوعي:');
    } else {
      fullTextBuffer.writeln('پوختەی هەفتانەی وانەکان:');
    }

    for (final day in _kurdishDays) {
      final lectures = dbService.schedule
          .where((l) => _isSameDay(l.dayName, day))
          .toList();
      final daySummary = _getDaySummaryText(day, lectures, lang);
      fullTextBuffer.writeln(daySummary);
    }
    final fullText = fullTextBuffer.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setSheetState) {
            final isSpeakingAll = _isPlayingVoice && _speakingText == fullText;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Directionality(
                textDirection: lang.textDirection,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.sparkles,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('schedule_summary_title'),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${dbService.schedule.length} ${t('schedule_lectures_count')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill),
                          color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                          onPressed: () {
                            KurdishTtsService().stop();
                            Navigator.pop(sheetCtx);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Voice reading banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ZankoColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSpeakingAll
                                ? CupertinoIcons.speaker_3_fill
                                : CupertinoIcons.speaker_2_fill,
                            color: ZankoColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isSpeakingAll
                                  ? 'دەنگی خوێندنەوەی هەفتانە چالاکە...'
                                  : t('listen_schedule'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ZankoColors.primary,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _toggleSpeakText(fullText);
                              setSheetState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSpeakingAll
                                  ? const Color(0xFFEF4444)
                                  : ZankoColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: Icon(
                              isSpeakingAll
                                  ? CupertinoIcons.stop_fill
                                  : CupertinoIcons.play_arrow_solid,
                              size: 14,
                            ),
                            label: Text(
                              isSpeakingAll ? 'وەستان' : 'گوێگرتن',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // List of days
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _kurdishDays.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final day = _kurdishDays[idx];
                          final lectures = dbService.schedule
                              .where((l) => _isSameDay(l.dayName, day))
                              .toList();
                          final dayColor = _cardColors[idx % _cardColors.length];
                          final hasLectures = lectures.isNotEmpty;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: hasLectures
                                    ? dayColor.withValues(alpha: 0.3)
                                    : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: dayColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _translateDay(day, lang),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: hasLectures
                                            ? dayColor.withValues(alpha: 0.15)
                                            : const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        hasLectures
                                            ? '${lectures.length} ${t('schedule_lectures_count')}'
                                            : '🎉 ${t('off_day')}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: hasLectures ? dayColor : const Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (!hasLectures)
                                  Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.sun_max_fill,
                                        size: 15,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          t('day_off_desc'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? const Color(0xFF6EE7B7)
                                                : const Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  ...lectures.map((l) => Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.circle_fill,
                                          size: 5,
                                          color: dayColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${l.courseName} (${l.time})${l.location.isNotEmpty && l.location != 'دیارینەکراوە' ? ' - ${l.location}' : ''}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.grey[200] : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndScanScheduleImage() async {
    HapticFeedback.lightImpact();
    if (kIsWeb) {
      _executeImageSelection(ImageSource.gallery);
      return;
    }

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String t(String key) => lang.translate(key);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 25,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Directionality(
            textDirection: lang.textDirection,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.sparkles,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('scan_schedule_ai'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                          ),
                          Text(
                            t('scan_schedule_subtitle'),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(CupertinoIcons.camera_fill, color: ZankoColors.primary, size: 22),
                    ),
                    title: Text(
                      t('take_photo'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _executeImageSelection(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        CupertinoIcons.photo_fill_on_rectangle_fill,
                        color: Color(0xFF8B5CF6),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      t('choose_from_gallery'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _executeImageSelection(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeImageSelection(ImageSource source) async {
    Uint8List? imageBytes;
    String mimeType = 'image/jpeg';

    if (kIsWeb) {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final f = result.files.single;
          imageBytes = f.bytes;
          final name = f.name.toLowerCase();
          if (name.endsWith('.png')) mimeType = 'image/png';
          if (name.endsWith('.webp')) mimeType = 'image/webp';
        }
      } catch (e) {
        debugPrint('Web FilePicker error: $e');
      }
    } else {
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 88,
        );
        if (picked != null) {
          imageBytes = await picked.readAsBytes();
          final name = picked.name.toLowerCase();
          if (name.endsWith('.png')) mimeType = 'image/png';
          if (name.endsWith('.webp')) mimeType = 'image/webp';
        }
      } catch (e) {
        debugPrint('Mobile ImagePicker error: $e');
        try {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
            withData: true,
          );
          if (result != null && result.files.isNotEmpty) {
            final f = result.files.single;
            imageBytes = f.bytes;
            final name = f.name.toLowerCase();
            if (name.endsWith('.png')) mimeType = 'image/png';
            if (name.endsWith('.webp')) mimeType = 'image/webp';
          }
        } catch (_) {}
      }
    }

    if (imageBytes == null || !mounted) return;
    _processScheduleImage(imageBytes, mimeType);
  }

  Future<void> _processScheduleImage(Uint8List imageBytes, String mimeType) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String t(String key) => lang.translate(key);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ZankoColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                Text(
                  t('scanning_schedule_image'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gemini Multimodal AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ZankoColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final result = await aiService.extractScheduleFromImage(
        imageBytes,
        mimeType: mimeType,
      );

      if (mounted) Navigator.pop(context); // dismiss loading dialog

      final lectures = (result['lectures'] as List<dynamic>? ?? []);
      final summary = (result['summary'] ?? '').toString().trim();

      if (lectures.isEmpty && summary.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('no_lectures_detected')),
              backgroundColor: ZankoColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
        return;
      }

      if (mounted) {
        _showScheduleReviewSheet(imageBytes, result);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ZankoColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
  }

  String _normalizeStage(String rawStage, String courseName) {
    final rs = rawStage.trim();
    if (rs.isNotEmpty) {
      final s = rs.toLowerCase();
      if (s.contains('4') || s.contains('چوار') || s.contains('fourth') || s.contains('رابع')) return 'قۆناغی ٤';
      if (s.contains('3') || s.contains('سێ') || s.contains('third') || s.contains('ثالث')) return 'قۆناغی ٣';
      if (s.contains('2') || s.contains('دوو') || s.contains('second') || s.contains('ثان')) return 'قۆناغی ٢';
      if (s.contains('1') || s.contains('یەک') || s.contains('first') || s.contains('اول') || s.contains('أول')) return 'قۆناغی ١';
      return rs;
    }
    final c = courseName.toLowerCase();
    if (c.contains('stage 4') || c.contains('year 4') || c.contains('قۆناغی ٤') || c.contains('قۆناغی چوار')) return 'قۆناغی ٤';
    if (c.contains('stage 3') || c.contains('year 3') || c.contains('قۆناغی ٣') || c.contains('قۆناغی سێ')) return 'قۆناغی ٣';
    if (c.contains('stage 2') || c.contains('year 2') || c.contains('قۆناغی ٢') || c.contains('قۆناغی دوو')) return 'قۆناغی ٢';
    if (c.contains('stage 1') || c.contains('year 1') || c.contains('قۆناغی ١') || c.contains('قۆناغی یەک')) return 'قۆناغی ١';
    return '';
  }

  bool _matchesStage(ScheduleModel l, String targetStage) {
    if (targetStage == 'all') return true;
    if (l.stage == targetStage) return true;
    final combined = '${l.stage} ${l.courseName}'.toLowerCase();
    if (targetStage == 'قۆناغی ١') {
      return combined.contains('stage 1') || combined.contains('year 1') || combined.contains('قۆناغی ١') || combined.contains('قۆناغی یەک') || combined.contains('1st');
    }
    if (targetStage == 'قۆناغی ٢') {
      return combined.contains('stage 2') || combined.contains('year 2') || combined.contains('قۆناغی ٢') || combined.contains('قۆناغی دوو') || combined.contains('2nd');
    }
    if (targetStage == 'قۆناغی ٣') {
      return combined.contains('stage 3') || combined.contains('year 3') || combined.contains('قۆناغی ٣') || combined.contains('قۆناغی سێ') || combined.contains('3rd');
    }
    if (targetStage == 'قۆناغی ٤') {
      return combined.contains('stage 4') || combined.contains('year 4') || combined.contains('قۆناغی ٤') || combined.contains('قۆناغی چوار') || combined.contains('4th');
    }
    return false;
  }

  String _stageDisplayTitle(String stg, LanguageProvider lang) {
    if (stg == 'all') {
      return lang.isEnglish
          ? '🎓 All Stages'
          : (lang.isArabic ? '🎓 جميع المراحل' : '🎓 هەموو قۆناغەکان');
    }
    if (stg == 'قۆناغی ١') {
      return lang.isEnglish
          ? '1️⃣ Stage 1 (First Year)'
          : (lang.isArabic ? '1️⃣ المرحلة الأولى' : '1️⃣ قۆناغی یەکەم');
    }
    if (stg == 'قۆناغی ٢') {
      return lang.isEnglish
          ? '2️⃣ Stage 2 (Second Year)'
          : (lang.isArabic ? '2️⃣ المرحلة الثانية' : '2️⃣ قۆناغی دووەم');
    }
    if (stg == 'قۆناغی ٣') {
      return lang.isEnglish
          ? '3️⃣ Stage 3 (Third Year)'
          : (lang.isArabic ? '3️⃣ المرحلة الثالثة' : '3️⃣ قۆناغی سێیەم');
    }
    if (stg == 'قۆناغی ٤') {
      return lang.isEnglish
          ? '4️⃣ Stage 4 (Fourth Year)'
          : (lang.isArabic ? '4️⃣ المرحلة الرابعة' : '4️⃣ قۆناغی چوارەم');
    }
    return '📚 $stg';
  }

  void _showScheduleReviewSheet(
    Uint8List imageBytes,
    Map<String, dynamic> rawResult,
  ) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String t(String key) => lang.translate(key);

    final rawLectures = (rawResult['lectures'] as List<dynamic>? ?? []);
    final List<ScheduleModel> parsedLectures = [];
    for (final item in rawLectures) {
      if (item is Map) {
        final cName = (item['courseName'] ?? '').toString().trim();
        if (cName.isEmpty) continue;
        final dName = (item['dayName'] ?? '').toString().trim();
        String resolvedDay = 'شەممە';
        for (final kd in _kurdishDays) {
          if (_isSameDay(dName, kd)) {
            resolvedDay = kd;
            break;
          }
        }
        final rawStg = (item['stage'] ?? '').toString().trim();
        final resolvedStage = _normalizeStage(rawStg, cName);

        parsedLectures.add(
          ScheduleModel(
            id: const Uuid().v4(),
            courseName: cName,
            time: (item['time'] ?? '08:30 - 10:00').toString().trim(),
            location: (item['location'] ?? '').toString().trim(),
            dayName: resolvedDay,
            teacherName: (item['teacherName'] ?? '').toString().trim(),
            stage: resolvedStage,
          ),
        );
      }
    }

    final String summary = (rawResult['summary'] ?? '').toString().trim();

    // Collect all detected stages
    final Set<String> detectedStages = {};
    for (final l in parsedLectures) {
      if (l.stage.isNotEmpty) detectedStages.add(l.stage);
    }
    final rawAvailable = (rawResult['availableStages'] as List<dynamic>? ?? []);
    for (final s in rawAvailable) {
      final norm = _normalizeStage(s.toString(), '');
      if (norm.isNotEmpty) detectedStages.add(norm);
    }

    final List<String> stageOptions = [
      'all',
      'قۆناغی ١',
      'قۆناغی ٢',
      'قۆناغی ٣',
      'قۆناغی ٤',
      ...detectedStages.where((s) => !['قۆناغی ١', 'قۆناغی ٢', 'قۆناغی ٣', 'قۆناغی ٤'].contains(s)),
    ];

    String selectedStage = 'all';
    final Set<String> selectedIds = parsedLectures.map((l) => l.id).toSet();
    bool replaceExisting = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setSheetState) {
            final isSpeakingSummary = _isPlayingVoice && _speakingText == summary;

            List<ScheduleModel> getVisibleLectures() {
              if (selectedStage == 'all') return parsedLectures;
              return parsedLectures.where((l) => _matchesStage(l, selectedStage)).toList();
            }

            final visibleLectures = getVisibleLectures();
            final selectedVisibleLectures =
                visibleLectures.where((l) => selectedIds.contains(l.id)).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Directionality(
                textDirection: lang.textDirection,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('schedule_review_title'),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${selectedVisibleLectures.length} / ${visibleLectures.length} ${t('schedule_lectures_count')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill),
                          color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                          onPressed: () {
                            KurdishTtsService().stop();
                            Navigator.pop(sheetCtx);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Scanned Image Preview + AI Summary Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                                      : [const Color(0xFFEFF6FF), const Color(0xFFF3E8FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: ZankoColors.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      imageBytes,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              CupertinoIcons.sparkles,
                                              size: 15,
                                              color: ZankoColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              t('schedule_summary_title'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: ZankoColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          summary.isNotEmpty
                                              ? summary
                                              : 'خشتەکە بە سەرکەوتوویی لە وێنەکەوە شیکار کرا و وانەکان بە پێی ڕۆژەکان دۆزرانەوە.',
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey[200] : const Color(0xFF334155),
                                            height: 1.4,
                                          ),
                                        ),
                                        if (summary.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          GestureDetector(
                                            onTap: () {
                                              _toggleSpeakText(summary);
                                              setSheetState(() {});
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isSpeakingSummary
                                                      ? CupertinoIcons.stop_circle_fill
                                                      : CupertinoIcons.volume_up,
                                                  size: 14,
                                                  color: ZankoColors.primary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isSpeakingSummary
                                                      ? 'وەستان'
                                                      : t('listen_schedule'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: ZankoColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Replace or Append Option Switcher
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setSheetState(() => replaceExisting = true),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: replaceExisting
                                              ? ZankoColors.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            t('replace_existing_schedule'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: replaceExisting
                                                  ? Colors.white
                                                  : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setSheetState(() => replaceExisting = false),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: !replaceExisting
                                              ? ZankoColors.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            t('append_to_schedule'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: !replaceExisting
                                                  ? Colors.white
                                                  : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Academic Stage Dropdown Selector
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2530) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: ZankoColors.primary.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: ZankoColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.square_stack_3d_up_fill,
                                      color: ZankoColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t('select_academic_stage'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                          ),
                                        ),
                                        DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: selectedStage,
                                            isDense: true,
                                            isExpanded: true,
                                            icon: Icon(
                                              CupertinoIcons.chevron_down,
                                              size: 16,
                                              color: ZankoColors.primary,
                                            ),
                                            dropdownColor:
                                                isDark ? const Color(0xFF161B22) : Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                                            ),
                                            items: stageOptions.map((stg) {
                                              final count = stg == 'all'
                                                  ? parsedLectures.length
                                                  : parsedLectures
                                                      .where((l) => _matchesStage(l, stg))
                                                      .length;
                                              final label = _stageDisplayTitle(stg, lang);
                                              return DropdownMenuItem<String>(
                                                value: stg,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(label),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: ZankoColors.primary
                                                            .withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        '$count ${t('schedule_lectures_count')}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: ZankoColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (newStage) {
                                              if (newStage == null) return;
                                              HapticFeedback.selectionClick();
                                              setSheetState(() {
                                                selectedStage = newStage;
                                                final visible = getVisibleLectures();
                                                if (newStage != 'all') {
                                                  selectedIds.clear();
                                                  selectedIds.addAll(visible.map((l) => l.id));
                                                } else {
                                                  selectedIds.addAll(parsedLectures.map((l) => l.id));
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (visibleLectures.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                margin: const EdgeInsets.only(top: 8, bottom: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E2530) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      CupertinoIcons.calendar_badge_minus,
                                      size: 38,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      lang.isEnglish
                                          ? 'No lectures detected for this stage.'
                                          : (lang.isArabic
                                              ? 'لم يتم العثور على محاضرات لهذه المرحلة.'
                                              : 'هیچ وانەیەک بۆ ئەم قۆناغە نەدۆزرایەوە لە وێنەکەدا.'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.grey[300] : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed: () {
                                        setSheetState(() => selectedStage = 'all');
                                      },
                                      icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 16),
                                      label: Text(t('all_stages')),
                                    ),
                                  ],
                                ),
                              ),

                            // List of Detected Lectures Grouped by Day
                            ..._kurdishDays
                                .where((day) => visibleLectures.any((l) => _isSameDay(l.dayName, day)))
                                .map((day) {
                              final dayLectures = visibleLectures
                                  .where((l) => _isSameDay(l.dayName, day))
                                  .toList();
                              final dayColor =
                                  _cardColors[_kurdishDays.indexOf(day) % _cardColors.length];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: dayColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            _translateDay(day, lang),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: dayColor,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${dayLectures.length} ${t('schedule_lectures_count')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...dayLectures.map((lecture) {
                                      final isSelected = selectedIds.contains(lecture.id);
                                      return GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setSheetState(() {
                                            if (isSelected) {
                                              selectedIds.remove(lecture.id);
                                            } else {
                                              selectedIds.add(lecture.id);
                                            }
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF161B22) : Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected
                                                  ? dayColor.withValues(alpha: 0.5)
                                                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                activeColor: dayColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                onChanged: (val) {
                                                  setSheetState(() {
                                                    if (val == true) {
                                                      selectedIds.add(lecture.id);
                                                    } else {
                                                      selectedIds.remove(lecture.id);
                                                    }
                                                  });
                                                },
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            lecture.courseName,
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w800,
                                                              fontSize: 14,
                                                              color: isDark
                                                                  ? Colors.white
                                                                  : ZankoColors.textPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                        if (lecture.stage.isNotEmpty)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: dayColor.withValues(alpha: 0.12),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              lecture.stage,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: dayColor,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Wrap(
                                                      spacing: 6,
                                                      children: [
                                                        Text(
                                                          lecture.time,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: dayColor,
                                                          ),
                                                        ),
                                                        if (lecture.location.isNotEmpty &&
                                                            lecture.location != 'دیارینەکراوە')
                                                          Text(
                                                            '• ${lecture.location}',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: isDark
                                                                  ? Colors.grey[400]
                                                                  : const Color(0xFF64748B),
                                                            ),
                                                          ),
                                                        if (lecture.teacherName.isNotEmpty &&
                                                            lecture.teacherName != 'دیارینەکراوە')
                                                          Text(
                                                            '• ${lecture.teacherName}',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: isDark
                                                                  ? Colors.grey[400]
                                                                  : const Color(0xFF64748B),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),

                            // Off Days Section in Review Sheet
                            Builder(
                              builder: (ctx) {
                                final offDays = _kurdishDays
                                    .where((day) => !visibleLectures.any((l) => _isSameDay(l.dayName, day)))
                                    .toList();
                                if (offDays.isEmpty || visibleLectures.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              CupertinoIcons.sun_max_fill,
                                              color: Color(0xFF10B981),
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${t('off_days_title')} (${offDays.length})',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            t('enjoy_day_off'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: offDays.map((od) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF161B22) : Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _translateDay(od, lang),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    t('off_day'),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w900,
                                                      color: Color(0xFF10B981),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Save Button
                    ElevatedButton(
                      onPressed: selectedVisibleLectures.isEmpty
                          ? null
                          : () async {
                              final dbService =
                                  Provider.of<DatabaseService>(context, listen: false);
                              HapticFeedback.heavyImpact();

                              if (replaceExisting) {
                                for (final existing in List<ScheduleModel>.from(dbService.schedule)) {
                                  await dbService.deleteScheduleItem(existing.id);
                                }
                              }

                              for (final l in selectedVisibleLectures) {
                                await dbService.addScheduleItem(l);
                              }

                              if (selectedVisibleLectures.isNotEmpty) {
                                setState(() {
                                  _selectedDay = selectedVisibleLectures.first.dayName;
                                });
                              }

                              KurdishTtsService().stop();
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          CupertinoIcons.checkmark_alt_circle_fill,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${selectedVisibleLectures.length} ${t('schedule_imported_success')}',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: ZankoColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZankoColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 3,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.checkmark_circle_fill, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${t('import_schedule_btn')} (${selectedVisibleLectures.length})',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  String _getTodayKurdishDay() {
    final weekday = DateTime.now().weekday;
    switch (weekday) {
      case DateTime.saturday:
        return 'شەممە';
      case DateTime.sunday:
        return 'یەکشەممە';
      case DateTime.monday:
        return 'دووشەممە';
      case DateTime.tuesday:
        return 'سێشەممە';
      case DateTime.wednesday:
        return 'چوارشەممە';
      case DateTime.thursday:
        return 'پێنجشەممە';
      case DateTime.friday:
        return 'هەینی';
      default:
        return 'شەممە';
    }
  }

  String _translateDay(String kurdishDay, LanguageProvider lang) {
    const Map<String, Map<AppLanguage, String>> dayTranslations = {
      'شەممە': {
        AppLanguage.kurdish: 'شەممە',
        AppLanguage.kurdishBadini: 'شەمبی',
        AppLanguage.arabic: 'السبت',
        AppLanguage.english: 'Saturday',
      },
      'یەکشەممە': {
        AppLanguage.kurdish: 'یەکشەممە',
        AppLanguage.kurdishBadini: 'ئێکەشەمبی',
        AppLanguage.arabic: 'الأحد',
        AppLanguage.english: 'Sunday',
      },
      'دووشەممە': {
        AppLanguage.kurdish: 'دووشەممە',
        AppLanguage.kurdishBadini: 'دووشەمبی',
        AppLanguage.arabic: 'الإثنين',
        AppLanguage.english: 'Monday',
      },
      'سێشەممە': {
        AppLanguage.kurdish: 'سێشەممە',
        AppLanguage.kurdishBadini: 'سێشەمبی',
        AppLanguage.arabic: 'الثلاثاء',
        AppLanguage.english: 'Tuesday',
      },
      'چوارشەممە': {
        AppLanguage.kurdish: 'چوارشەممە',
        AppLanguage.kurdishBadini: 'چارشەمبی',
        AppLanguage.arabic: 'الأربعاء',
        AppLanguage.english: 'Wednesday',
      },
      'پێنجشەممە': {
        AppLanguage.kurdish: 'پێنجشەممە',
        AppLanguage.kurdishBadini: 'پێنجشەمبی',
        AppLanguage.arabic: 'الخميس',
        AppLanguage.english: 'Thursday',
      },
      'هەینی': {
        AppLanguage.kurdish: 'هەینی',
        AppLanguage.kurdishBadini: 'ئەینی',
        AppLanguage.arabic: 'الجمعة',
        AppLanguage.english: 'Friday',
      },
    };
    return dayTranslations[kurdishDay]?[lang.currentLanguage] ?? kurdishDay;
  }

  bool _isSameDay(String itemDay, String targetKurdishDay) {
    final cleanItem = itemDay.trim().toLowerCase();
    final cleanTarget = targetKurdishDay.trim();
    if (cleanItem == cleanTarget.toLowerCase()) return true;

    const kurdishToEnglish = {
      'شەممە': 'saturday',
      'یەکشەممە': 'sunday',
      'دووشەممە': 'monday',
      'سێشەممە': 'tuesday',
      'چوارشەممە': 'wednesday',
      'پێنجشەممە': 'thursday',
      'هەینی': 'friday',
    };
    if (kurdishToEnglish[cleanTarget] == cleanItem) return true;

    const kurdishToBadini = {
      'شەممە': 'شەمبی',
      'یەکشەممە': 'ئێکەشەمبی',
      'دووشەممە': 'دووشەمبی',
      'سێشەممە': 'سێشەمبی',
      'چوارشەممە': 'چارشەمبی',
      'پێنجشەممە': 'پێنجشەمبی',
      'هەینی': 'ئەینی',
    };
    if (kurdishToBadini[cleanTarget] == cleanItem) return true;

    const kurdishToArabic = {
      'شەممە': 'السبت',
      'یەکشەممە': 'الأحد',
      'دووشەممە': 'الإثنين',
      'سێشەممە': 'الثلاثاء',
      'چوارشەممە': 'الأربعاء',
      'پێنجشەممە': 'الخميس',
      'هەینی': 'الجمعة',
    };
    if (kurdishToArabic[cleanTarget] == cleanItem) return true;

    return false;
  }

  String _getFormattedDate(LanguageProvider lang) {
    final now = DateTime.now();
    final dayName = _translateDay(_getTodayKurdishDay(), lang);
    if (lang.currentLanguage == AppLanguage.english) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '$dayName, ${months[now.month - 1]} ${now.day}';
    } else {
      return '$dayName، ${now.day}/${now.month}';
    }
  }

  Color _getLectureColor(int index) {
    return _cardColors[index % _cardColors.length];
  }

  Future<void> _pickCustomTime(
    BuildContext context,
    StateSetter setModalState,
  ) async {
    HapticFeedback.lightImpact();
    final startTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 30),
      helpText: 'کاتی دەستپێکردن (Start Time)',
    );
    if (startTime == null || !context.mounted) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (startTime.hour + 1) % 24,
        minute: (startTime.minute + 30) % 60,
      ),
      helpText: 'کاتی کۆتایی (End Time)',
    );
    if (endTime == null || !context.mounted) return;

    final formattedStart =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final formattedEnd =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    setModalState(() {
      _timeController.text = '$formattedStart - $formattedEnd';
    });
  }

  void _openLectureSheet({ScheduleModel? lectureToEdit, String? defaultDay}) {
    HapticFeedback.lightImpact();
    final isEditing = lectureToEdit != null;
    _editingLectureId = lectureToEdit?.id;
    String sheetDay = lectureToEdit?.dayName ?? defaultDay ?? _selectedDay;

    if (isEditing) {
      _courseController.text = lectureToEdit.courseName;
      _timeController.text = lectureToEdit.time;
      _locationController.text = lectureToEdit.location;
      _teacherController.text = lectureToEdit.teacherName;
    } else {
      _courseController.clear();
      _timeController.text = '08:30 - 10:00';
      _locationController.clear();
      _teacherController.clear();
    }

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String t(String key) => lang.translate(key);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 12,
              ),
              child: Directionality(
                textDirection: lang.textDirection,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[700]
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ZankoColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isEditing
                                  ? CupertinoIcons.pencil_ellipsis_rectangle
                                  : CupertinoIcons.add_circled_solid,
                              color: ZankoColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEditing ? t('edit_lecture') : t('add_lecture'),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: isDark
                                    ? Colors.white
                                    : ZankoColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: isDark
                                  ? Colors.grey[500]
                                  : const Color(0xFF94A3B8),
                              size: 26,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Lecture / Course Name
                      _buildInputLabel(t('lecture_name'), isDark),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _courseController,
                        hint: t('lecture_name_hint'),
                        icon: CupertinoIcons.book_fill,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // Day Selector
                      _buildInputLabel(t('select_day'), isDark),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _kurdishDays.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final day = _kurdishDays[index];
                            final isSelected = _isSameDay(day, sheetDay);
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => sheetDay = day);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ZankoColors.primary
                                      : (isDark
                                            ? const Color(0xFF21262D)
                                            : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? ZankoColors.primary
                                        : (isDark
                                              ? Colors.white10
                                              : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _translateDay(day, lang),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.grey[300]
                                                : const Color(0xFF475569)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Lecture Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInputLabel(t('lecture_time'), isDark),
                          GestureDetector(
                            onTap: () => _pickCustomTime(ctx, setModalState),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.stopwatch,
                                  color: ZankoColors.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  t('custom_time'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: ZankoColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _timeController,
                        hint: '08:30 - 10:00',
                        icon: CupertinoIcons.clock_fill,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _timePresets.map((preset) {
                            final isSelected =
                                _timeController.text.trim() == preset;
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                label: Text(
                                  preset,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setModalState(
                                    () => _timeController.text = preset,
                                  );
                                },
                                selectedColor: ZankoColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                backgroundColor: isDark
                                    ? const Color(0xFF21262D)
                                    : const Color(0xFFF1F5F9),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? ZankoColors.primary
                                      : (isDark
                                            ? Colors.grey[300]
                                            : const Color(0xFF64748B)),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location
                      _buildInputLabel(t('lecture_location'), isDark),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _locationController,
                        hint: t('lecture_location_hint'),
                        icon: CupertinoIcons.location_solid,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // Instructor
                      _buildInputLabel(t('lecture_teacher'), isDark),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _teacherController,
                        hint: t('lecture_teacher_hint'),
                        icon: CupertinoIcons.person_crop_circle_fill,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton(
                              onPressed: () => _saveLecture(t, sheetDay),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ZankoColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 3,
                                shadowColor: ZankoColors.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isEditing
                                        ? CupertinoIcons
                                              .checkmark_alt_circle_fill
                                        : CupertinoIcons.add_circled_solid,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditing ? t('update_lecture') : t('save'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF30363D)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                t('close'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.grey[300] : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isDark ? Colors.white : ZankoColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: ZankoColors.primary, size: 19),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  void _saveLecture(String Function(String) t, String sheetDay) {
    final course = _courseController.text.trim();
    final time = _timeController.text.trim();
    final location = _locationController.text.trim();
    final teacher = _teacherController.text.trim();

    if (course.isEmpty || time.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('snackbar_fill_all_fields')),
          backgroundColor: ZankoColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final lectureId = _editingLectureId ?? const Uuid().v4();

    final lecture = ScheduleModel(
      id: lectureId,
      courseName: course,
      dayName: sheetDay,
      time: time,
      location: location.isNotEmpty ? location : t('not_specified'),
      teacherName: teacher.isNotEmpty ? teacher : t('default_teacher'),
    );

    if (_editingLectureId != null) {
      dbService.deleteScheduleItem(_editingLectureId!);
    }
    dbService.addScheduleItem(lecture);

    HapticFeedback.mediumImpact();
    setState(() {
      _selectedDay = sheetDay;
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              CupertinoIcons.checkmark_alt_circle_fill,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(t('lecture_save_success'))),
          ],
        ),
        backgroundColor: ZankoColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _deleteLecture(String id, String Function(String) t) {
    HapticFeedback.heavyImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t('delete_lecture_title')),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(t('delete_lecture_confirm')),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(t('cancel')),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              final dbService = Provider.of<DatabaseService>(
                context,
                listen: false,
              );
              dbService.deleteScheduleItem(id);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t('lecture_delete_success')),
                  backgroundColor: ZankoColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            },
            child: Text(t('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dbService = Provider.of<DatabaseService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    final todayKurdish = _getTodayKurdishDay();
    final todayLectures = dbService.schedule
        .where((item) => _isSameDay(item.dayName, todayKurdish))
        .toList();
    final activeDayLectures = dbService.schedule
        .where((item) => _isSameDay(item.dayName, _selectedDay))
        .toList();

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0D1117)
            : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark
              ? const Color(0xFF0D1117)
              : const Color(0xFFF8FAFC),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ZankoColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.calendar,
                  color: ZankoColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t('schedule_title'),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: IconButton(
                icon: Icon(
                  _viewAllDays
                      ? CupertinoIcons.square_grid_2x2_fill
                      : CupertinoIcons.calendar_today,
                  color: ZankoColors.primary,
                  size: 20,
                ),
                tooltip: _viewAllDays
                    ? t('schedule_view_daily')
                    : t('schedule_view_weekly'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _viewAllDays = !_viewAllDays);
                },
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Ad Banner for Schedule
              const AdBannerWidget(screenName: 'schedule'),

              // Apple-Style Hero Status Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: _buildHeroCard(
                  todayLectures,
                  todayKurdish,
                  langProvider,
                  isDark,
                  t,
                ),
              ),

              // Horizontal Day Selector (shown in Daily View)
              if (!_viewAllDays) ...[
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _kurdishDays.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final day = _kurdishDays[index];
                      final isSelected = _isSameDay(day, _selectedDay);
                      final isToday = _isSameDay(day, todayKurdish);
                      final lectureCount = dbService.schedule
                          .where((l) => _isSameDay(l.dayName, day))
                          .length;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedDay = day);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ZankoColors.primary
                                : (isDark
                                      ? const Color(0xFF161B22)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? ZankoColors.primary
                                  : (isToday
                                        ? ZankoColors.primary.withValues(
                                            alpha: 0.6,
                                          )
                                        : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : const Color(0xFFE2E8F0))),
                              width: isToday && !isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: ZankoColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.2 : 0.03,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _translateDay(day, langProvider),
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.bold,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white
                                            : ZankoColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (lectureCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : ZankoColors.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$lectureCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected
                                          ? Colors.white
                                          : ZankoColors.primary,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : const Color(0xFF10B981).withValues(
                                            alpha: 0.15,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '🎉 ${t('off_day')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Main Content: Daily or Weekly View
              Expanded(
                child: _viewAllDays
                    ? _buildAllDaysView(dbService, langProvider, isDark, t)
                    : _buildSingleDayView(
                        activeDayLectures,
                        langProvider,
                        isDark,
                        t,
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: (activeDayLectures.isEmpty && !_viewAllDays)
            ? null
            : FloatingActionButton.extended(
                heroTag: 'fab_schedule_unique',
                onPressed: () => _openLectureSheet(defaultDay: _selectedDay),
                backgroundColor: ZankoColors.primary,
                elevation: 6,
                icon: const Icon(
                  CupertinoIcons.plus_circle_fill,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  t('add_lecture'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeroCard(
    List<ScheduleModel> todayLectures,
    String todayKurdish,
    LanguageProvider lang,
    bool isDark,
    String Function(String) t,
  ) {
    final hasLectures = todayLectures.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF0F6CBD), const Color(0xFF024A9B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : ZankoColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getFormattedDate(lang),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasLectures
                      ? '${todayLectures.length} ${t('lectures_today_count')}'
                      : t('day_off_title'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasLectures
                      ? '${t('schedule_title')}: ${todayLectures.first.courseName} (${todayLectures.first.time})'
                      : t('day_off_sub'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: _pickAndScanScheduleImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.camera_viewfinder,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t('scan_schedule_ai'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showWeeklySummarySheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.sparkles,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t('schedule_summary_title'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasLectures) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${todayLectures.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    t('schedule_lectures_count'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(
                    t('off_day'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiDayInsightBanner(
    String dayName,
    List<ScheduleModel> lectures,
    LanguageProvider lang,
    bool isDark,
    String Function(String) t,
  ) {
    final summaryText = _getDaySummaryText(dayName, lectures, lang);
    final isSpeakingThis = _isPlayingVoice && _speakingText == summaryText;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ZankoColors.primary.withValues(alpha: isDark ? 0.25 : 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ZankoColors.primary.withValues(alpha: 0.2),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.sparkles,
              color: ZankoColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      t('ai_day_insight'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: ZankoColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${_translateDay(dayName, lang)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  summaryText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isSpeakingThis
                  ? CupertinoIcons.stop_circle_fill
                  : CupertinoIcons.speaker_2_fill,
              color: isSpeakingThis ? const Color(0xFFEF4444) : ZankoColors.primary,
              size: 22,
            ),
            tooltip: t('listen_schedule'),
            onPressed: () => _toggleSpeakText(summaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleDayView(
    List<ScheduleModel> lectures,
    LanguageProvider lang,
    bool isDark,
    String Function(String) t,
  ) {
    if (lectures.isEmpty) {
      final offDayVoiceText = _getDaySummaryText(_selectedDay, lectures, lang);
      final isSpeakingThis = _isPlayingVoice && _speakingText == offDayVoiceText;

      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Off Day Celebration Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF064E3B).withValues(alpha: 0.35),
                            const Color(0xFF0F172A),
                          ]
                        : [
                            const Color(0xFFECFDF5),
                            const Color(0xFFF0FDF4),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          ),
                        ),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          ),
                          child: const Icon(
                            CupertinoIcons.sun_max_fill,
                            color: Color(0xFF10B981),
                            size: 38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎉 ', style: TextStyle(fontSize: 12)),
                          Text(
                            t('off_day'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_translateDay(_selectedDay, lang)} • ${t('off_day')}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('day_off_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF047857),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('enjoy_day_off'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color(0xFF065F46).withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Kurdish TTS button
                    InkWell(
                      onTap: () => _toggleSpeakText(offDayVoiceText),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSpeakingThis
                                  ? CupertinoIcons.stop_circle_fill
                                  : CupertinoIcons.speaker_2_fill,
                              color: isSpeakingThis
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSpeakingThis
                                  ? t('stop_listening')
                                  : t('listen_schedule'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAndScanScheduleImage,
                    icon: const Icon(CupertinoIcons.camera_viewfinder, size: 18),
                    label: Text(t('scan_schedule_ai')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openLectureSheet(defaultDay: _selectedDay),
                    icon: const Icon(CupertinoIcons.add, size: 18),
                    label: Text(t('add_lecture')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : ZankoColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white24
                            : ZankoColors.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildAiDayInsightBanner(_selectedDay, lectures, lang, isDark, t),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            physics: const BouncingScrollPhysics(),
            itemCount: lectures.length,
            itemBuilder: (context, index) {
              final lecture = lectures[index];
              final cardColor = _getLectureColor(index);
              return _buildLectureCard(lecture, cardColor, index, isDark, t);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllDaysView(
    DatabaseService dbService,
    LanguageProvider lang,
    bool isDark,
    String Function(String) t,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      physics: const BouncingScrollPhysics(),
      itemCount: _kurdishDays.length,
      itemBuilder: (context, dayIndex) {
        final day = _kurdishDays[dayIndex];
        final dayLectures = dbService.schedule
            .where((item) => _isSameDay(item.dayName, day))
            .toList();
        final isToday = _isSameDay(day, _getTodayKurdishDay());

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isToday
                  ? ZankoColors.primary.withValues(alpha: 0.6)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0)),
              width: isToday ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: isToday || dayLectures.isNotEmpty,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (isToday
                              ? ZankoColors.primary
                              : _cardColors[dayIndex % _cardColors.length])
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isToday ? CupertinoIcons.star_fill : CupertinoIcons.calendar,
                  color: isToday
                      ? ZankoColors.primary
                      : _cardColors[dayIndex % _cardColors.length],
                  size: 20,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    _translateDay(day, lang),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isToday
                          ? ZankoColors.primary
                          : (isDark ? Colors.white : ZankoColors.textPrimary),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t('today'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: dayLectures.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🎉 ', style: TextStyle(fontSize: 10)),
                                Text(
                                  t('off_day'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      '${dayLectures.length} ${t('schedule_lectures_count')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                      ),
                    ),
              children: [
                if (dayLectures.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(
                          alpha: isDark ? 0.08 : 0.05,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.sun_max_fill,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_translateDay(day, lang)} • ${t('off_day')} 🎉',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t('day_off_desc'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _selectedDay = day);
                              _openLectureSheet(defaultDay: day);
                            },
                            icon: const Icon(CupertinoIcons.plus, size: 14),
                            label: Text(
                              t('add_lecture'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...dayLectures.map((lecture) {
                    final index = dayLectures.indexOf(lecture);
                    final cardColor = _getLectureColor(index);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: _buildLectureCard(
                        lecture,
                        cardColor,
                        index,
                        isDark,
                        t,
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLectureCard(
    ScheduleModel lecture,
    Color accentColor,
    int index,
    bool isDark,
    String Function(String) t,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.08 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coloured accent vertical indicator bar
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accentColor, accentColor.withValues(alpha: 0.4)],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Time Badge + Actions
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(
                                alpha: isDark ? 0.2 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedClock01,
                                  color: accentColor,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  lecture.time,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (lecture.stage.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(
                                  alpha: isDark ? 0.18 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                lecture.stage,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Edit Button
                          GestureDetector(
                            onTap: () =>
                                _openLectureSheet(lectureToEdit: lecture),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF21262D)
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedPencilEdit02,
                                  size: 15,
                                  color: isDark
                                      ? Colors.grey[300]!
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete Button
                          GestureDetector(
                            onTap: () => _deleteLecture(lecture.id, t),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedDelete02,
                                  size: 15,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Course Name
                      Text(
                        lecture.courseName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      if (lecture.location.isNotEmpty ||
                          lecture.teacherName.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (lecture.location.isNotEmpty)
                              _infoChip(
                                icon: HugeIcons.strokeRoundedLocation01,
                                label: lecture.location,
                                isDark: isDark,
                              ),
                            if (lecture.teacherName.isNotEmpty)
                              _infoChip(
                                icon: HugeIcons.strokeRoundedTeacher,
                                label: lecture.teacherName,
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip({
    required dynamic icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 12,
            color: isDark ? Colors.grey[400]! : const Color(0xFF64748B),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300]! : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
