import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/announcement_model.dart';

class TeacherAnnouncementsScreen extends StatefulWidget {
  const TeacherAnnouncementsScreen({super.key});

  @override
  State<TeacherAnnouncementsScreen> createState() => _TeacherAnnouncementsScreenState();
}

class _TeacherAnnouncementsScreenState extends State<TeacherAnnouncementsScreen> {
  final List<AnnouncementModel> _initialAnnouncements = [
    AnnouncementModel(
      id: 'ann_1',
      title: 'گۆڕینی کاتی هۆڵی تاقیکردنەوەی میدترم',
      content: 'ئاگاداری سەرجەم قوتابییان دەکەینەوە تاقیکردنەوەی ناوەڕاستی وەرز بۆ هۆڵی ٥ گواسترایەوە.',
      courseName: 'سیستەمی کارپێکردن',
      teacherName: 'د. سارا محمد',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      priority: AnnouncementPriority.urgent,
    ),
    AnnouncementModel(
      id: 'ann_2',
      title: 'ڕادەستکردنی پڕۆژەی دووەمی داتابەیس',
      content: 'کۆتا مۆڵەت بۆ ڕادەستکردنی فایلی SQL رۆژی پێنجشەممەیە لەڕێگەی سیستەمەکەوە.',
      courseName: 'داتابەیس',
      teacherName: 'د. سارا محمد',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      priority: AnnouncementPriority.important,
    ),
  ];

  void _openAnnouncementDialog(BuildContext context, DatabaseService db, AuthService auth, String Function(String) t) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCourse = 'سیستەمی کارپێکردن';
    AnnouncementPriority selectedPriority = AnnouncementPriority.normal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign_rounded, color: Color(0xFFE11D48), size: 28),
                    const SizedBox(width: 10),
                    Text(
                      t('send_announcement'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: t('announcement_title'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Course Dropdown
                DropdownButtonFormField<String>(
                  value: selectedCourse,
                  decoration: InputDecoration(
                    labelText: t('select_course'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'سەرجەم وانەکان', child: Text('سەرجەم وانەکان')),
                    DropdownMenuItem(value: 'سیستەمی کارپێکردن', child: Text('سیستەمی کارپێکردن')),
                    DropdownMenuItem(value: 'داتابەیس', child: Text('داتابەیس')),
                    DropdownMenuItem(value: 'تۆڕەکان', child: Text('تۆڕەکان')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedCourse = v);
                  },
                ),
                const SizedBox(height: 14),

                // Priority selector
                Text(
                  'ئاستی گرنگی (Priority)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PriorityChip(
                      label: t('priority_normal'),
                      color: const Color(0xFF0284C7),
                      isSelected: selectedPriority == AnnouncementPriority.normal,
                      onTap: () => setModalState(() => selectedPriority = AnnouncementPriority.normal),
                    ),
                    const SizedBox(width: 8),
                    _PriorityChip(
                      label: t('priority_important'),
                      color: const Color(0xFFD97706),
                      isSelected: selectedPriority == AnnouncementPriority.important,
                      onTap: () => setModalState(() => selectedPriority = AnnouncementPriority.important),
                    ),
                    const SizedBox(width: 8),
                    _PriorityChip(
                      label: t('priority_urgent'),
                      color: const Color(0xFFDC2626),
                      isSelected: selectedPriority == AnnouncementPriority.urgent,
                      onTap: () => setModalState(() => selectedPriority = AnnouncementPriority.urgent),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Content
                TextField(
                  controller: contentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: t('announcement_content'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: Text(t('send_announcement'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) return;

                      final newAnn = AnnouncementModel(
                        id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
                        title: titleController.text.trim(),
                        content: contentController.text.trim(),
                        courseName: selectedCourse,
                        teacherName: auth.currentUser?.name ?? 'مامۆستا',
                        createdAt: DateTime.now(),
                        priority: selectedPriority,
                      );

                      db.addAnnouncement(newAnn);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ئاگادارییەکە بۆ سەرجەم قوتابییان نێردرا! 📢')),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Provider.of<LanguageProvider>(context);
    final db = Provider.of<DatabaseService>(context);
    final auth = Provider.of<AuthService>(context);
    String t(String key) => lang.translate(key);
    const red = Color(0xFFE11D48);

    final allAnnouncements = [..._initialAnnouncements, ...db.announcements];

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('teacher_announcements_title')),
          centerTitle: true,
          backgroundColor: red,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: red,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.campaign_rounded),
          label: Text(t('send_announcement')),
          onPressed: () => _openAnnouncementDialog(context, db, auth, t),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allAnnouncements.length,
          itemBuilder: (context, i) {
            final ann = allAnnouncements[i];
            Color priorityColor;
            String priorityText;

            switch (ann.priority) {
              case AnnouncementPriority.normal:
                priorityColor = const Color(0xFF0284C7);
                priorityText = t('priority_normal');
                break;
              case AnnouncementPriority.important:
                priorityColor = const Color(0xFFD97706);
                priorityText = t('priority_important');
                break;
              case AnnouncementPriority.urgent:
                priorityColor = const Color(0xFFDC2626);
                priorityText = t('priority_urgent');
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: priorityColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: priorityColor, size: 8),
                            const SizedBox(width: 6),
                            Text(
                              priorityText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: priorityColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        ann.courseName,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ann.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ann.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ann.teacherName,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          db.deleteAnnouncement(ann.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
