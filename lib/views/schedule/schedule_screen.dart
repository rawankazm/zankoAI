import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
import '../../models/schedule_model.dart';

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
  
  final List<String> _kurdishDays = [
    'شەممە',
    'یەکشەممە',
    'دووشەممە',
    'سێشەممە',
    'چوارشەممە',
    'پێنجشەممە',
  ];

  @override
  void dispose() {
    _courseController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  String _translateDay(String kurdishDay, LanguageProvider lang) {
    final Map<String, Map<AppLanguage, String>> dayTranslations = {
      'شەممە': {AppLanguage.kurdish: 'شەممە', AppLanguage.arabic: 'السبت', AppLanguage.english: 'Saturday'},
      'یەکشەممە': {AppLanguage.kurdish: 'یەکشەممە', AppLanguage.arabic: 'الأحد', AppLanguage.english: 'Sunday'},
      'دووشەممە': {AppLanguage.kurdish: 'دووشەممە', AppLanguage.arabic: 'الإثنين', AppLanguage.english: 'Monday'},
      'سێشەممە': {AppLanguage.kurdish: 'سێشەممە', AppLanguage.arabic: 'الثلاثاء', AppLanguage.english: 'Tuesday'},
      'چوارشەممە': {AppLanguage.kurdish: 'چوارشەممە', AppLanguage.arabic: 'الأربعاء', AppLanguage.english: 'Wednesday'},
      'پێنجشەممە': {AppLanguage.kurdish: 'پێنجشەممە', AppLanguage.arabic: 'الخميس', AppLanguage.english: 'Thursday'},
    };
    return dayTranslations[kurdishDay]?[lang.currentLanguage] ?? kurdishDay;
  }

  void _openAddLectureSheet() {
    _courseController.clear();
    _timeController.text = '08:30 - 10:00';
    _locationController.clear();
    _teacherController.clear();

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String t(String key) => lang.translate(key);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: lang.textDirection,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t('add_lecture'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Noto Sans Arabic'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _courseController,
                        decoration: InputDecoration(
                          labelText: t('lecture_name'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedDay,
                        decoration: InputDecoration(labelText: t('lecture_day')),
                        items: _kurdishDays.map((day) {
                          return DropdownMenuItem(
                            value: day, 
                            child: Text(_translateDay(day, lang)),
                          );
                        }).toList(),
                        onChanged: (day) {
                          if (day != null) {
                            setModalState(() => _selectedDay = day);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _timeController,
                        decoration: InputDecoration(
                          labelText: t('lecture_time'),
                          hintText: 'e.g. 10:15 - 11:45',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: t('lecture_location'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _teacherController,
                        decoration: InputDecoration(
                          labelText: t('lecture_teacher'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _saveLecture(t),
                              child: Text(t('save')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(t('close')),
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
          },
        );
      },
    );
  }

  void _saveLecture(String Function(String) t) {
    final course = _courseController.text.trim();
    final time = _timeController.text.trim();
    final location = _locationController.text.trim();
    final teacher = _teacherController.text.trim();

    if (course.isEmpty || time.isEmpty || location.isEmpty || teacher.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە هەموو خانەکان پڕبکەرەوە', style: TextStyle(fontFamily: 'Noto Sans Arabic'))),
      );
      return;
    }

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final newLecture = ScheduleModel(
      id: const Uuid().v4(),
      courseName: course,
      dayName: _selectedDay,
      time: time,
      location: location,
      teacherName: teacher,
    );

    dbService.addScheduleItem(newLecture);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('lecture_save_success'), style: const TextStyle(fontFamily: 'Noto Sans Arabic'))),
    );
  }

  void _deleteLecture(String id, String Function(String) t) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    dbService.deleteScheduleItem(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('lecture_delete_success'), style: const TextStyle(fontFamily: 'Noto Sans Arabic'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dbService = Provider.of<DatabaseService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('schedule_title')),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _kurdishDays.length,
          itemBuilder: (context, index) {
            final day = _kurdishDays[index];
            final lectures = dbService.schedule.where((item) => item.dayName == day).toList();

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  _translateDay(day, langProvider),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic'),
                ),
                subtitle: Text(
                  '${lectures.length} ${langProvider.currentLanguage == AppLanguage.english ? 'lectures' : 'وانە'}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'Noto Sans Arabic'),
                ),
                children: [
                  if (lectures.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(t('no_lectures_day'), style: const TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 13)),
                    )
                  else
                    ...lectures.map((lecture) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.class_outlined, color: theme.colorScheme.primary),
                        ),
                        title: Text(
                          lecture.courseName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic', fontSize: 14),
                        ),
                        subtitle: Text(
                          '${lecture.time} • ${lecture.location} • ${lecture.teacherName}',
                          style: const TextStyle(fontSize: 12, fontFamily: 'Noto Sans Arabic'),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteLecture(lecture.id, t),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab_schedule_unique',
          onPressed: _openAddLectureSheet,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
