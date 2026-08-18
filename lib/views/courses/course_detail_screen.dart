import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/sample_pdf_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../pdf/pdf_chat_screen.dart';
import '../ai_teacher/ai_teacher_chat_screen.dart';

class PdfLectureItem {
  final String id;
  final String title;
  final String fileName;
  final String size;
  final String dateAdded;

  PdfLectureItem({
    required this.id,
    required this.title,
    required this.fileName,
    required this.size,
    required this.dateAdded,
  });
}

class CourseDetailScreen extends StatefulWidget {
  final String courseTitle;
  final String courseSubtitle;
  final double progress;
  final IconData icon;
  final Color themeColor;
  final DateTime? midtermDate;
  final DateTime? finalDate;
  final Function(DateTime? midterm, DateTime? finalDate)? onExamDatesChanged;

  const CourseDetailScreen({
    super.key,
    required this.courseTitle,
    required this.courseSubtitle,
    required this.progress,
    required this.icon,
    required this.themeColor,
    this.midtermDate,
    this.finalDate,
    this.onExamDatesChanged,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final List<PdfLectureItem> _pdfLectures = [];
  DateTime? _midtermDate;
  DateTime? _finalDate;

  @override
  void initState() {
    super.initState();
    _midtermDate = widget.midtermDate;
    _finalDate = widget.finalDate;
    _pdfLectures.addAll(_generateLecturesForCourse(widget.courseTitle));
  }

  List<PdfLectureItem> _generateLecturesForCourse(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('calculus') || lower.contains('math')) {
      return [
        PdfLectureItem(
          id: 'calc_1',
          title: 'Lecture 1: Limits & Continuity',
          fileName: 'Calculus_L01_Limits.pdf',
          size: '3.4 MB',
          dateAdded: '2 days ago',
        ),
        PdfLectureItem(
          id: 'calc_2',
          title: 'Lecture 2: Derivatives & Chain Rule',
          fileName: 'Calculus_L02_Derivatives.pdf',
          size: '4.1 MB',
          dateAdded: 'yesterday',
        ),
        PdfLectureItem(
          id: 'calc_3',
          title: 'Lecture 3: Integrals & Applications',
          fileName: 'Calculus_L03_Integrals.pdf',
          size: '5.2 MB',
          dateAdded: '3 hours ago',
        ),
        PdfLectureItem(
          id: 'calc_4',
          title: 'Lecture 4: Differential Equations',
          fileName: 'Calculus_L04_DiffEq.pdf',
          size: '2.8 MB',
          dateAdded: 'just_now',
        ),
      ];
    } else if (lower.contains('machine') || lower.contains('ai')) {
      return [
        PdfLectureItem(
          id: 'ml_1',
          title: 'Lecture 1: Intro to Supervised Learning',
          fileName: 'ML_L01_Supervised.pdf',
          size: '4.8 MB',
          dateAdded: '3 days ago',
        ),
        PdfLectureItem(
          id: 'ml_2',
          title: 'Lecture 2: Neural Networks & Backpropagation',
          fileName: 'ML_L02_NeuralNets.pdf',
          size: '6.3 MB',
          dateAdded: 'yesterday',
        ),
        PdfLectureItem(
          id: 'ml_3',
          title: 'Lecture 3: Transformers & LLMs',
          fileName: 'ML_L03_Transformers.pdf',
          size: '5.9 MB',
          dateAdded: '5 hours ago',
        ),
      ];
    } else if (lower.contains('operating') || lower.contains('system')) {
      return [
        PdfLectureItem(
          id: 'os_1',
          title: 'Lecture 1: Processes, Threads & Concurrency',
          fileName: 'OS_L01_Processes.pdf',
          size: '3.1 MB',
          dateAdded: '4 days ago',
        ),
        PdfLectureItem(
          id: 'os_2',
          title: 'Lecture 2: Virtual Memory & Page Tables',
          fileName: 'OS_L02_Memory.pdf',
          size: '4.5 MB',
          dateAdded: 'yesterday',
        ),
        PdfLectureItem(
          id: 'os_3',
          title: 'Lecture 3: File Systems & Storage Devices',
          fileName: 'OS_L03_FileSystems.pdf',
          size: '3.7 MB',
          dateAdded: '1 day ago',
        ),
      ];
    } else {
      return [
        PdfLectureItem(
          id: 'gen_1',
          title: 'Lecture 1: Course Syllabus & Overview',
          fileName: '${title.replaceAll(" ", "_")}_L01.pdf',
          size: '2.1 MB',
          dateAdded: '3 days ago',
        ),
        PdfLectureItem(
          id: 'gen_2',
          title: 'Lecture 2: Core Fundamentals & Exercises',
          fileName: '${title.replaceAll(" ", "_")}_L02.pdf',
          size: '3.9 MB',
          dateAdded: 'yesterday',
        ),
        PdfLectureItem(
          id: 'gen_3',
          title: 'Lecture 3: Advanced Topics & Exam Guide',
          fileName: '${title.replaceAll(" ", "_")}_L03.pdf',
          size: '4.2 MB',
          dateAdded: '2 hours ago',
        ),
      ];
    }
  }

  Future<void> _uploadPdfLecture() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.name.isNotEmpty) {
        final fileName = result.files.single.name;
        final sizeBytes = result.files.single.size;
        final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);

        setState(() {
          _pdfLectures.insert(
            0,
            PdfLectureItem(
              id: 'pdf_${DateTime.now().millisecondsSinceEpoch}',
              title: fileName.replaceAll('.pdf', ''),
              fileName: fileName,
              size: '$sizeMb MB',
              dateAdded: 'just_now',
            ),
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploaded "$fileName" to ${widget.courseTitle}'),
              backgroundColor: ZankoColors.success,
            ),
          );
        }
      }
    } catch (e) {
      // Fallback: Add mock PDF lecture if picker is cancelled or unsupported on web
      _showAddPdfModal();
    }
  }

  void _showAddPdfModal() {
    final titleController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text('${Provider.of<LanguageProvider>(context, listen: false).translate('add_pdf')} ${widget.courseTitle}'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: CupertinoTextField(
              controller: titleController,
              placeholder: 'Enter Lecture Title (e.g. Chapter 3 Notes)',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('cancel')),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('add_pdf')),
              onPressed: () {
                final text = titleController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _pdfLectures.insert(
                      0,
                      PdfLectureItem(
                        id: 'pdf_${DateTime.now().millisecondsSinceEpoch}',
                        title: text,
                        fileName: '${text.replaceAll(" ", "_")}.pdf',
                        size: '3.2 MB',
                        dateAdded: 'just_now',
                      ),
                    );
                  });
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _deletePdf(String id) {
    setState(() {
      _pdfLectures.removeWhere((item) => item.id == id);
    });
  }

  void _showExamDateEditModal({
    required BuildContext context,
    required String examTitle,
    required DateTime? currentDate,
    required Color accentColor,
    required ValueChanged<DateTime?> onSaved,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    DateTime selectedDate = currentDate ?? now.add(const Duration(days: 7));
    int daysOffset = selectedDate.difference(todayStart).inDays;
    if (daysOffset < 0) daysOffset = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final targetDate = todayStart.add(Duration(days: daysOffset));
            final formattedTarget = '${targetDate.year}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.day.toString().padLeft(2, '0')}';

            return Container(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(CupertinoIcons.timer, color: accentColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'دیاریکردنی ماوەی $examTitle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Days Counter & Live Preview
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ماوەی ماوە بە ڕۆژ (Countdown in Days):',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: daysOffset > 0
                                  ? () => setModalState(() => daysOffset--)
                                  : null,
                              icon: const Icon(CupertinoIcons.minus_circle, size: 32),
                              color: accentColor,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '$daysOffset ڕۆژ',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setModalState(() => daysOffset++),
                              icon: const Icon(CupertinoIcons.add_circled_solid, size: 32),
                              color: accentColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ڕێکەوتی تاقیکردنەوە: $formattedTarget',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Quick Presets
                  const Text(
                    'دیاریکردنی خێرا (Quick Presets):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [3, 7, 10, 14, 21, 30, 45].map((presetDays) {
                      final isSelected = daysOffset == presetDays;
                      return ChoiceChip(
                        label: Text('+$presetDays ڕۆژ'),
                        selected: isSelected,
                        selectedColor: accentColor.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? accentColor : (isDark ? Colors.white : Colors.black87),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              daysOffset = presetDays;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Custom Calendar DatePicker Button
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setModalState(() {
                          final diff = picked.difference(todayStart).inDays;
                          daysOffset = diff < 0 ? 0 : diff;
                        });
                      }
                    },
                    icon: const Icon(CupertinoIcons.calendar, size: 18),
                    label: const Text('هەڵبژاردنی لە ڕۆژژمێرەوە (Calendar)'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Save / Clear Buttons
                  Row(
                    children: [
                      if (currentDate != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              onSaved(null);
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('سڕینەوە', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (currentDate != null) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final resultDate = todayStart.add(Duration(days: daysOffset));
                            onSaved(resultDate);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'پاشەکەوتکردن',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExamDetailTile({
    required BuildContext context,
    required String title,
    required DateTime? date,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onPickDate,
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    String statusText = 'دیاری نەکراوە';
    String dateFormatted = 'دیاری نەکراوە';
    Color badgeBg = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    Color badgeFg = Colors.grey;

    if (date != null) {
      dateFormatted = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      final targetStart = DateTime(date.year, date.month, date.day);
      final diff = targetStart.difference(todayStart).inDays;

      if (diff < 0) {
        statusText = 'تەواوبوو';
        badgeBg = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
        badgeFg = Colors.grey;
      } else if (diff == 0) {
        statusText = 'ئەمڕۆیە! ⚠️';
        badgeBg = const Color(0xFFFF3B30).withValues(alpha: 0.18);
        badgeFg = const Color(0xFFFF3B30);
      } else if (diff <= 3) {
        statusText = '$diff ڕۆژی ماوە 🔥';
        badgeBg = const Color(0xFFFF9500).withValues(alpha: 0.18);
        badgeFg = const Color(0xFFFF9500);
      } else {
        statusText = '$diff ڕۆژی ماوە';
        badgeBg = accentColor.withValues(alpha: 0.15);
        badgeFg = accentColor;
      }
    }

    return GestureDetector(
      onTap: onPickDate,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0F0F6),
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
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(
                    CupertinoIcons.pencil_circle_fill,
                    size: 20,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dateFormatted,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GlassButton(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        CupertinoIcons.back,
                        size: 20,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.courseTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Hero Card Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.themeColor,
                                  widget.themeColor.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.courseTitle,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.courseSubtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: ZankoColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Progress Bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: widget.progress,
                                minHeight: 8,
                                backgroundColor: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : const Color(0xFFEFEFF7),
                                valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(widget.progress * 100).toInt()}% Done',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: widget.themeColor,
                          ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Exam Countdown Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.timer, size: 18, color: ZankoColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'ژێرمێژووی تاقیکردنەوەکان (Exam Countdown)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildExamDetailTile(
                            context: context,
                            title: 'تاقیکردنەوەی میدترم',
                            date: _midtermDate,
                            icon: CupertinoIcons.timer,
                            accentColor: const Color(0xFF007AFF),
                            isDark: isDark,
                            onPickDate: () {
                              _showExamDateEditModal(
                                context: context,
                                examTitle: 'تاقیکردنەوەی میدترم',
                                currentDate: _midtermDate,
                                accentColor: const Color(0xFF007AFF),
                                onSaved: (newDate) {
                                  setState(() {
                                    _midtermDate = newDate;
                                  });
                                  widget.onExamDatesChanged?.call(_midtermDate, _finalDate);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildExamDetailTile(
                            context: context,
                            title: 'تاقیکردنەوەی فایناڵ',
                            date: _finalDate,
                            icon: CupertinoIcons.flag_fill,
                            accentColor: const Color(0xFFAF52DE),
                            isDark: isDark,
                            onPickDate: () {
                              _showExamDateEditModal(
                                context: context,
                                examTitle: 'تاقیکردنەوەی فایناڵ',
                                currentDate: _finalDate,
                                accentColor: const Color(0xFFAF52DE),
                                onSaved: (newDate) {
                                  setState(() {
                                    _finalDate = newDate;
                                  });
                                  widget.onExamDatesChanged?.call(_midtermDate, _finalDate);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // PDF Lectures Header & Add Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.doc_fill,
                            color: Color(0xFFFF3B30),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'سڵاید و فایلی PDF (${_pdfLectures.length})',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _uploadPdfLecture,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.themeColor,
                              widget.themeColor.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.cloud_upload_fill,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '+ ئاپڵۆد',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // PDF Lectures List
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _pdfLectures.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark ? ZankoColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(ZankoRadius.card),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFEFEFF5),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              CupertinoIcons.doc_on_clipboard_fill,
                              size: 48,
                              color: ZankoColors.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t('no_pdf_uploaded'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t('upload_pdf_desc'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: ZankoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: _pdfLectures.map((pdf) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      final realContent = SamplePdfService().getSampleLectureText(pdf.fileName, widget.courseTitle);
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (context) => PdfChatScreen(
                                            initialFileName: pdf.title,
                                            initialFileContent: realContent,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        // PDF Red Icon
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF3B30).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.doc_text_fill,
                                            color: Color(0xFFFF3B30),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                pdf.title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? Colors.white
                                                      : ZankoColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    pdf.size,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: ZankoColors.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '• ${t(pdf.dateAdded)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: ZankoColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Delete button
                                        IconButton(
                                          icon: const Icon(
                                            CupertinoIcons.trash,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () => _deletePdf(pdf.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            final realContent = SamplePdfService().getSampleLectureText(pdf.fileName, widget.courseTitle);
                                            Navigator.push(
                                              context,
                                              CupertinoPageRoute(
                                                builder: (context) => PdfChatScreen(
                                                  initialFileName: pdf.title,
                                                  initialFileContent: realContent,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: ZankoColors.primary.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  CupertinoIcons.chat_bubble_2_fill,
                                                  size: 14,
                                                  color: ZankoColors.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  t('chat_with_ai'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: ZankoColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            final realContent = SamplePdfService().getSampleLectureText(pdf.fileName, widget.courseTitle);
                                            Navigator.push(
                                              context,
                                              CupertinoPageRoute(
                                                builder: (context) => AiTeacherChatScreen(
                                                  initialPrompt:
                                                      'تکایە ئەم فایلی وانەیە (${pdf.title}) کورت بکەرەوە و خاڵە گرنگەکانی شیکار بکە:\n\n$realContent',
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFAF52DE).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  CupertinoIcons.sparkles,
                                                  size: 14,
                                                  color: Color(0xFFAF52DE),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  t('ai_summary'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFFAF52DE),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
