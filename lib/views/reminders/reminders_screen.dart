import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
import '../../services/notification_service.dart';
import '../../models/reminder_model.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _taskController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
      }
    }
  }

  void _addReminder(DatabaseService dbService, String Function(String) t) {
    final title = _taskController.text.trim();
    final course = _courseController.text.trim();

    if (title.isEmpty || course.isEmpty || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('snackbar_fill_all_fields'), style: const TextStyle())),
      );
      return;
    }

    final deadline = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final newReminder = ReminderModel(
      id: const Uuid().v4(),
      title: title,
      deadline: deadline,
      courseName: course,
    );

    dbService.addReminder(newReminder);

    // Schedule a push notification 10 minutes before the deadline
    NotificationService().scheduleReminder(
      id: newReminder.id.hashCode,
      title: '⏰ $title',
      body: course,
      scheduledTime: deadline,
    );

    _taskController.clear();
    _courseController.clear();
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
    });
    
    Navigator.pop(context);
  }

  void _showAddTaskSheet(BuildContext context, DatabaseService dbService, String Function(String) t, LanguageProvider lang) {
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
                        t('reminders_add_title'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _taskController,
                        decoration: InputDecoration(labelText: Provider.of<LanguageProvider>(context, listen: false).translate('task_subject_label')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _courseController,
                        decoration: InputDecoration(labelText: Provider.of<LanguageProvider>(context, listen: false).translate('course_name_label')),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDate == null 
                                ? t('reminders_no_deadline') 
                                : '${t('add')}: ${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}  ${_selectedTime?.format(context) ?? ""}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await _selectDeadline(context);
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(t('ok')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _addReminder(dbService, t),
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

  String _formatCountdown(DateTime deadline, LanguageProvider lang) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) {
      return lang.translate('reminders_passed');
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;

    return lang.translate('reminders_time_left')
        .replaceAll('{days}', days.toString())
        .replaceAll('{hours}', hours.toString());
  }

  Color _getCountdownColor(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return Colors.grey;
    if (diff.inDays < 1) return Colors.red.shade400;
    if (diff.inDays < 3) return Colors.orange.shade400;
    return Colors.green.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dbService = Provider.of<DatabaseService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    // Filter active and completed
    final activeTasks = dbService.reminders.where((r) => !r.isCompleted).toList();
    final completedTasks = dbService.reminders.where((r) => r.isCompleted).toList();

    // Translations
    final String title = t('reminders_title');
    final String activeLabel = t('reminders_active');
    final String completedLabel = t('reminders_completed');
    final String noTasks = t('reminders_no_tasks');

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Tasks Header
              Text(
                activeLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (activeTasks.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(noTasks, style: const TextStyle()),
                  ),
                )
              else
                ...activeTasks.map((reminder) {
                  final countdown = _formatCountdown(reminder.deadline, langProvider);
                  final color = _getCountdownColor(reminder.deadline);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Checkbox(
                        value: reminder.isCompleted,
                        onChanged: (val) {
                          dbService.toggleReminder(reminder.id);
                        },
                      ),
                      title: Text(
                        reminder.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reminder.courseName,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              countdown,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.brightness == Brightness.dark ? color : color.withRed(150),
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          dbService.deleteReminder(reminder.id);
                        },
                      ),
                    ),
                  );
                }),
              
              const SizedBox(height: 24),

              // Completed Tasks Header
              if (completedTasks.isNotEmpty) ...[
                Text(
                  completedLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...completedTasks.map((reminder) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Checkbox(
                        value: reminder.isCompleted,
                        onChanged: (val) {
                          dbService.toggleReminder(reminder.id);
                        },
                      ),
                      title: Text(
                        reminder.title,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        reminder.courseName,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          dbService.deleteReminder(reminder.id);
                        },
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab_reminders_unique',
          onPressed: () => _showAddTaskSheet(context, dbService, t, langProvider),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
