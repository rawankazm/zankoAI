import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/database_service.dart';
import '../../models/lecture_model.dart';

class TeacherLecturesScreen extends StatefulWidget {
  const TeacherLecturesScreen({super.key});

  @override
  State<TeacherLecturesScreen> createState() => _TeacherLecturesScreenState();
}

class _TeacherLecturesScreenState extends State<TeacherLecturesScreen> {
  final List<LectureModel> _initialLectures = [
    LectureModel(
      id: 'lec_1',
      title: 'وانەی ١: بەشەکانی ڕەقەکاڵا و سیستەم',
      courseName: 'سیستەمی کارپێکردن',
      type: LectureType.pdf,
      fileUrl: 'https://example.com/lecture1.pdf',
      description: 'سەرجەم لایەنە سەرەکییەکانی پڕۆسێسەر و یادگە.',
      uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
      fileSize: '4.2 MB',
    ),
    LectureModel(
      id: 'lec_2',
      title: 'وانەی ٢: دروستکردنی پەیوەندی و خشتەکان',
      courseName: 'داتابەیس',
      type: LectureType.ppt,
      fileUrl: 'https://example.com/lecture2.pptx',
      description: 'پڕیزێنتەیشنی تەملیاتی ER Diagrams.',
      uploadedAt: DateTime.now().subtract(const Duration(days: 3)),
      fileSize: '12.8 MB',
    ),
    LectureModel(
      id: 'lec_3',
      title: 'وانەی پراکتیکی: بەستنەوەی فایەربەیس',
      courseName: 'تۆڕەکان',
      type: LectureType.video,
      fileUrl: 'https://example.com/lecture3.mp4',
      description: 'کۆرسێکی فێرکاری ڤیدیۆیی ٢٠ خولەکی.',
      uploadedAt: DateTime.now().subtract(const Duration(days: 5)),
      fileSize: '85 MB',
    ),
  ];

  void _openUploadDialog(BuildContext context, DatabaseService db, String Function(String) t) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final fileUrlController = TextEditingController(text: 'https://zanko.edu/materials/');
    String selectedCourse = 'سیستەمی کارپێکردن';
    LectureType selectedType = LectureType.pdf;

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
                    const Icon(Icons.cloud_upload_rounded, color: Color(0xFF059669), size: 28),
                    const SizedBox(width: 10),
                    Text(
                      t('upload_lecture'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: t('lecture_title'),
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
                    DropdownMenuItem(value: 'سیستەمی کارپێکردن', child: Text('سیستەمی کارپێکردن')),
                    DropdownMenuItem(value: 'داتابەیس', child: Text('داتابەیس')),
                    DropdownMenuItem(value: 'تۆڕەکان', child: Text('تۆڕەکان')),
                    DropdownMenuItem(value: 'ئەمنیەتی سایبەر', child: Text('ئەمنیەتی سایبەر')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedCourse = v);
                  },
                ),
                const SizedBox(height: 14),

                // Type selector (PDF, PPT, Video)
                Text(
                  t('lecture_type'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TypeChip(
                      label: 'PDF',
                      icon: Icons.picture_as_pdf_rounded,
                      color: Colors.red,
                      isSelected: selectedType == LectureType.pdf,
                      onTap: () => setModalState(() => selectedType = LectureType.pdf),
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(
                      label: 'PPT',
                      icon: Icons.slideshow_rounded,
                      color: Colors.orange,
                      isSelected: selectedType == LectureType.ppt,
                      onTap: () => setModalState(() => selectedType = LectureType.ppt),
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(
                      label: 'Video',
                      icon: Icons.video_library_rounded,
                      color: Colors.blue,
                      isSelected: selectedType == LectureType.video,
                      onTap: () => setModalState(() => selectedType = LectureType.video),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'ڕوونکردنەوەی وانەکە',
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
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(t('upload_lecture'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) return;

                      final newLec = LectureModel(
                        id: 'lec_${DateTime.now().millisecondsSinceEpoch}',
                        title: titleController.text.trim(),
                        courseName: selectedCourse,
                        type: selectedType,
                        fileUrl: fileUrlController.text,
                        description: descriptionController.text.trim(),
                        uploadedAt: DateTime.now(),
                        fileSize: selectedType == LectureType.video ? '45 MB' : '5.8 MB',
                      );

                      db.addLecture(newLec);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('وانەکە بە سەرکەوتوویی بارکرا! ✅')),
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
    String t(String key) => lang.translate(key);
    const green = Color(0xFF059669);

    final allLectures = [..._initialLectures, ...db.lectures];

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('teacher_lectures_title')),
          centerTitle: true,
          backgroundColor: green,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(t('upload_lecture')),
          onPressed: () => _openUploadDialog(context, db, t),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allLectures.length,
          itemBuilder: (context, i) {
            final lec = allLectures[i];
            IconData iconData;
            Color typeColor;
            String typeBadge;

            switch (lec.type) {
              case LectureType.pdf:
                iconData = Icons.picture_as_pdf_rounded;
                typeColor = const Color(0xFFDC2626);
                typeBadge = 'PDF';
                break;
              case LectureType.ppt:
                iconData = Icons.slideshow_rounded;
                typeColor = const Color(0xFFD97706);
                typeBadge = 'PPT';
                break;
              case LectureType.video:
                iconData = Icons.video_library_rounded;
                typeColor = const Color(0xFF0284C7);
                typeBadge = 'Video';
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: typeColor.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(iconData, color: typeColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                typeBadge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lec.courseName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lec.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (lec.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            lec.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.attachment_rounded, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text(
                              lec.fileSize,
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () {
                      db.deleteLecture(lec.id);
                    },
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

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
