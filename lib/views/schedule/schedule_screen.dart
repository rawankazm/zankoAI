import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/schedule_model.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';

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
    super.dispose();
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
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '$dayName, ${months[now.month - 1]} ${now.day}';
    } else {
      return '$dayName، ${now.day}/${now.month}';
    }
  }

  Color _getLectureColor(int index) {
    return _cardColors[index % _cardColors.length];
  }

  Future<void> _pickCustomTime(BuildContext context, StateSetter setModalState) async {
    HapticFeedback.lightImpact();
    final startTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 30),
      helpText: 'کاتی دەستپێکردن (Start Time)',
    );
    if (startTime == null || !context.mounted) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (startTime.hour + 1) % 24, minute: (startTime.minute + 30) % 60),
      helpText: 'کاتی کۆتایی (End Time)',
    );
    if (endTime == null || !context.mounted) return;

    final formattedStart = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final formattedEnd = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                            color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
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
                              color: ZankoColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isEditing ? CupertinoIcons.pencil_ellipsis_rectangle : CupertinoIcons.add_circled_solid,
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
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
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
                          separatorBuilder: (_, index) => const SizedBox(width: 8),
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
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ZankoColors.primary
                                      : (isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? ZankoColors.primary
                                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _translateDay(day, lang),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
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
                                Icon(CupertinoIcons.stopwatch, color: ZankoColors.primary, size: 14),
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
                            final isSelected = _timeController.text.trim() == preset;
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                label: Text(
                                  preset,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setModalState(() => _timeController.text = preset);
                                },
                                selectedColor: ZankoColors.primary.withValues(alpha: 0.2),
                                backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? ZankoColors.primary
                                      : (isDark ? Colors.grey[300] : const Color(0xFF64748B)),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 3,
                                shadowColor: ZankoColors.primary.withValues(alpha: 0.4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isEditing ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.add_circled_solid,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditing ? t('update_lecture') : t('save'),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                t('close'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF475569),
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
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
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
              final dbService = Provider.of<DatabaseService>(context, listen: false);
              dbService.deleteScheduleItem(id);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t('lecture_delete_success')),
                  backgroundColor: ZankoColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    final todayLectures = dbService.schedule.where((item) => _isSameDay(item.dayName, todayKurdish)).toList();
    final activeDayLectures = dbService.schedule.where((item) => _isSameDay(item.dayName, _selectedDay)).toList();

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
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
                child: Icon(CupertinoIcons.calendar, color: ZankoColors.primary, size: 18),
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
                  _viewAllDays ? CupertinoIcons.square_grid_2x2_fill : CupertinoIcons.calendar_today,
                  color: ZankoColors.primary,
                  size: 20,
                ),
                tooltip: _viewAllDays ? t('schedule_view_daily') : t('schedule_view_weekly'),
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
              // Apple-Style Hero Status Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: _buildHeroCard(todayLectures, todayKurdish, langProvider, isDark, t),
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
                      final lectureCount = dbService.schedule.where((l) => _isSameDay(l.dayName, day)).length;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedDay = day);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ZankoColors.primary
                                : (isDark ? const Color(0xFF161B22) : Colors.white),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? ZankoColors.primary
                                  : (isToday
                                      ? ZankoColors.primary.withValues(alpha: 0.6)
                                      : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))),
                              width: isToday && !isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: ZankoColors.primary.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white : ZankoColors.textPrimary),
                                ),
                              ),
                              if (lectureCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : ZankoColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$lectureCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected ? Colors.white : ZankoColors.primary,
                                    ),
                                  ),
                                ),
                              ],
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
                    : _buildSingleDayView(activeDayLectures, langProvider, isDark, t),
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
                icon: const Icon(CupertinoIcons.plus_circle_fill, color: Colors.white, size: 20),
                label: Text(
                  t('add_lecture'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.4) : ZankoColors.primary.withValues(alpha: 0.25),
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
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
          ],
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: ZankoColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ZankoColors.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(CupertinoIcons.calendar_badge_plus, color: ZankoColors.primary, size: 42),
              ),
              const SizedBox(height: 18),
              Text(
                '${t('no_lectures_for_day')} ${_translateDay(_selectedDay, lang)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t('tap_to_add_lecture_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => _openLectureSheet(defaultDay: _selectedDay),
                icon: const Icon(CupertinoIcons.add, size: 18),
                label: Text(t('add_lecture')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZankoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      physics: const BouncingScrollPhysics(),
      itemCount: lectures.length,
      itemBuilder: (context, index) {
        final lecture = lectures[index];
        final cardColor = _getLectureColor(index);
        return _buildLectureCard(lecture, cardColor, index, isDark, t);
      },
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
        final dayLectures = dbService.schedule.where((item) => _isSameDay(item.dayName, day)).toList();
        final isToday = _isSameDay(day, _getTodayKurdishDay());

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isToday
                  ? ZankoColors.primary.withValues(alpha: 0.6)
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
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
                  color: (isToday ? ZankoColors.primary : _cardColors[dayIndex % _cardColors.length]).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isToday ? CupertinoIcons.star_fill : CupertinoIcons.calendar,
                  color: isToday ? ZankoColors.primary : _cardColors[dayIndex % _cardColors.length],
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
                      color: isToday ? ZankoColors.primary : (isDark ? Colors.white : ZankoColors.textPrimary),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t('today'),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                '${dayLectures.length} ${t('schedule_lectures_count')}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                ),
              ),
              children: [
                if (dayLectures.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('no_lectures_day'),
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _selectedDay = day);
                            _openLectureSheet(defaultDay: day);
                          },
                          icon: const Icon(CupertinoIcons.plus, size: 14),
                          label: Text(t('add_lecture'), style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  )
                else
                  ...dayLectures.map((lecture) {
                    final index = dayLectures.indexOf(lecture);
                    final cardColor = _getLectureColor(index);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: _buildLectureCard(lecture, cardColor, index, isDark, t),
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
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
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
                          const Spacer(),
                          // Edit Button
                          GestureDetector(
                            onTap: () => _openLectureSheet(lectureToEdit: lecture),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedPencilEdit02,
                                  size: 15,
                                  color: isDark ? Colors.grey[300]! : const Color(0xFF475569),
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
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
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
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (lecture.location.isNotEmpty || lecture.teacherName.isNotEmpty) ...[
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

  Widget _infoChip({required dynamic icon, required String label, required bool isDark}) {
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
