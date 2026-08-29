import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  String _selectedDay = 'شەممە';
  bool _viewAllDays = false;
  String? _editingLectureId;

  final List<String> _kurdishDays = [
    'شەممە',
    'یەکشەممە',
    'دووشەممە',
    'سێشەممە',
    'چوارشەممە',
    'پێنجشەممە',
  ];

  final List<Color> _cardColors = [
    const Color(0xFF6366F1), // Indigo
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEC4899), // Pink
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFF97316), // Orange
  ];

  final List<String> _timePresets = [
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
      default:
        return 'شەممە';
    }
  }

  String _translateDay(String kurdishDay, LanguageProvider lang) {
    final Map<String, Map<AppLanguage, String>> dayTranslations = {
      'شەممە': {AppLanguage.kurdish: 'شەممە', AppLanguage.kurdishBadini: 'شەمبی', AppLanguage.arabic: 'السبت', AppLanguage.english: 'Saturday'},
      'یەکشەممە': {AppLanguage.kurdish: 'یەکشەممە', AppLanguage.kurdishBadini: 'ئێکەشەمبی', AppLanguage.arabic: 'الأحد', AppLanguage.english: 'Sunday'},
      'دووشەممە': {AppLanguage.kurdish: 'دووشەممە', AppLanguage.kurdishBadini: 'دووشەمبی', AppLanguage.arabic: 'الإثنين', AppLanguage.english: 'Monday'},
      'سێشەممە': {AppLanguage.kurdish: 'سێشەممە', AppLanguage.kurdishBadini: 'سێشەمبی', AppLanguage.arabic: 'الثلاثاء', AppLanguage.english: 'Tuesday'},
      'چوارشەممە': {AppLanguage.kurdish: 'چوارشەممە', AppLanguage.kurdishBadini: 'چارشەمبی', AppLanguage.arabic: 'الأربعاء', AppLanguage.english: 'Wednesday'},
      'پێنجشەممە': {AppLanguage.kurdish: 'پێنجشەممە', AppLanguage.kurdishBadini: 'پێنجشەمبی', AppLanguage.arabic: 'الخميس', AppLanguage.english: 'Thursday'},
    };
    return dayTranslations[kurdishDay]?[lang.currentLanguage] ?? kurdishDay;
  }

  Color _getLectureColor(int index) {
    return _cardColors[index % _cardColors.length];
  }

  void _openLectureSheet({ScheduleModel? lectureToEdit}) {
    final isEditing = lectureToEdit != null;
    _editingLectureId = lectureToEdit?.id;

    if (isEditing) {
      _courseController.text = lectureToEdit.courseName;
      _timeController.text = lectureToEdit.time;
      _locationController.text = lectureToEdit.location;
      _teacherController.text = lectureToEdit.teacherName;
      _selectedDay = lectureToEdit.dayName;
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
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 25,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 14,
              ),
              child: Directionality(
                textDirection: lang.textDirection,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ZankoColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isEditing ? CupertinoIcons.pencil_circle_fill : CupertinoIcons.add_circled_solid,
                              color: ZankoColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEditing ? 'دەستکاریکردنی وانە ✏️' : t('add_lecture'),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey, size: 24),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildTextField(
                        controller: _courseController,
                        label: t('lecture_name'),
                        hint: 'بۆ نموونە: بیرکاری، داتابەیس، تۆڕەکان...',
                        icon: CupertinoIcons.book_fill,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.calendar, color: ZankoColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedDay,
                                  isExpanded: true,
                                  dropdownColor: isDark ? ZankoColors.darkCard : Colors.white,
                                  items: _kurdishDays.map((day) {
                                    return DropdownMenuItem(
                                      value: day,
                                      child: Text(
                                        _translateDay(day, lang),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (day) {
                                    if (day != null) {
                                      setModalState(() => _selectedDay = day);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _timeController,
                        label: t('lecture_time'),
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
                                label: Text(preset, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                selected: isSelected,
                                onSelected: (_) {
                                  setModalState(() {
                                    _timeController.text = preset;
                                  });
                                },
                                selectedColor: ZankoColors.primary.withValues(alpha: 0.2),
                                backgroundColor: isDark ? ZankoColors.darkBackground : const Color(0xFFF1F5F9),
                                labelStyle: TextStyle(
                                  color: isSelected ? ZankoColors.primary : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _locationController,
                        label: t('lecture_location'),
                        hint: 'بۆ نموونە: هۆڵی ٣، تاقیگەی ٥...',
                        icon: CupertinoIcons.location_solid,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _teacherController,
                        label: t('lecture_teacher'),
                        hint: 'ناوی مامۆستای وانەکە...',
                        icon: CupertinoIcons.person_crop_circle_fill,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () => _saveLecture(t),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ZankoColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 4,
                                shadowColor: ZankoColors.primary.withValues(alpha: 0.4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isEditing ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.add_circled_solid, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditing ? 'نوێکردنەوەی وانە' : t('save'),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: isDark ? Colors.grey[700]! : const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                t('close'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
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
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 13,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[600] : Colors.grey[400],
            fontSize: 12,
          ),
          prefixIcon: Icon(icon, color: ZankoColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  void _saveLecture(String Function(String) t) {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final lectureId = _editingLectureId ?? const Uuid().v4();

    final lecture = ScheduleModel(
      id: lectureId,
      courseName: course,
      dayName: _selectedDay,
      time: time,
      location: location.isNotEmpty ? location : 'دیارینەکراوە',
      teacherName: teacher.isNotEmpty ? teacher : 'مامۆستای وانە',
    );

    if (_editingLectureId != null) {
      dbService.deleteScheduleItem(_editingLectureId!);
    }
    dbService.addScheduleItem(lecture);

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
        backgroundColor: ZankoColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _deleteLecture(String id, String Function(String) t) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('سڕینەوەی وانە'),
        content: const Text('ئایا دڵنیایت لە سڕینەوەی ئەم وانەیە لە خشتەکەتدا؟'),
        actions: [
          CupertinoDialogAction(
            child: const Text('نەخێر'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              final dbService = Provider.of<DatabaseService>(context, listen: false);
              dbService.deleteScheduleItem(id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t('lecture_delete_success')),
                  backgroundColor: ZankoColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text('سڕینەوە'),
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
    final todayLectures = dbService.schedule.where((item) => item.dayName == todayKurdish).toList();
    final activeDayLectures = dbService.schedule.where((item) => item.dayName == _selectedDay).toList();

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        backgroundColor: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: (isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC)).withValues(alpha: 0.95),
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
                child: Icon(CupertinoIcons.calendar_today, color: ZankoColors.primary, size: 18),
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
            IconButton(
              icon: Icon(
                _viewAllDays ? CupertinoIcons.calendar_circle_fill : CupertinoIcons.square_grid_2x2_fill,
                color: ZankoColors.primary,
              ),
              tooltip: _viewAllDays ? 'بینینی ڕۆژانە' : 'بینینی تەواوی هەفتە',
              onPressed: () => setState(() => _viewAllDays = !_viewAllDays),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ZankoColors.primary, ZankoColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: ZankoColors.primary.withValues(alpha: 0.3),
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
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.clock_fill, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ئەمڕۆ ${_translateDay(todayKurdish, langProvider)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              todayLectures.isEmpty
                                  ? 'پشووە و هیچ وانەیەکت نییە 🎉'
                                  : '${todayLectures.length} وانەت هەیە بۆ ئەمڕۆ 📚',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _openLectureSheet(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: ZankoColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.add, size: 16),
                            SizedBox(width: 4),
                            Text('وانە', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_viewAllDays) ...[
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _kurdishDays.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final day = _kurdishDays[index];
                      final isSelected = day == _selectedDay;
                      final isToday = day == todayKurdish;
                      final lectureCount = dbService.schedule.where((l) => l.dayName == day).length;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedDay = day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ZankoColors.primary
                                : (isDark ? ZankoColors.darkCard : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? ZankoColors.primary
                                  : (isToday
                                      ? ZankoColors.primary.withValues(alpha: 0.5)
                                      : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))),
                              width: isToday && !isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: ZankoColors.primary.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
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
                                      fontSize: 10,
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
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _viewAllDays
                    ? _buildAllDaysView(dbService, langProvider, isDark, t)
                    : _buildSingleDayView(activeDayLectures, langProvider, isDark, t),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_schedule_unique',
          onPressed: () => _openLectureSheet(),
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

  Widget _buildSingleDayView(
    List<ScheduleModel> lectures,
    LanguageProvider lang,
    bool isDark,
    String Function(String) t,
  ) {
    if (lectures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: ZankoColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.calendar_badge_plus, color: ZankoColors.primary, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                'هیچ وانەیەک بۆ ${_translateDay(_selectedDay, lang)} تۆمار نەکراوە',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'کلیک لە دوگمەی خوارەوە بکە بۆ زیادکردنی وانەکانی ئەم ڕۆژە',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _openLectureSheet(),
                icon: const Icon(CupertinoIcons.plus, size: 16),
                label: Text(t('add_lecture')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ZankoColors.primary,
                  side: BorderSide(color: ZankoColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        final dayLectures = dbService.schedule.where((item) => item.dayName == day).toList();
        final isToday = day == _getTodayKurdishDay();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
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
          child: ExpansionTile(
            initiallyExpanded: isToday || dayLectures.isNotEmpty,
            shape: const Border(),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ZankoColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ئەمڕۆ',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _selectedDay = day);
                          _openLectureSheet();
                        },
                        icon: const Icon(CupertinoIcons.plus, size: 14),
                        label: const Text('زیادکردن', style: TextStyle(fontSize: 12)),
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
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 14,
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
              Container(
                width: 6,
                color: accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.clock_fill, color: accentColor, size: 13),
                                const SizedBox(width: 6),
                                Text(
                                  lecture.time,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(CupertinoIcons.pencil_circle, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'دەستکاریکردن',
                                onPressed: () => _openLectureSheet(lectureToEdit: lecture),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(CupertinoIcons.trash, color: Color(0xFFEF4444), size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'سڕینەوە',
                                onPressed: () => _deleteLecture(lecture.id, t),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        lecture.courseName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (lecture.location.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? ZankoColors.darkBackground : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.location_solid, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    lecture.location,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (lecture.teacherName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? ZankoColors.darkBackground : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.person_crop_circle_fill, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    lecture.teacherName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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
}
