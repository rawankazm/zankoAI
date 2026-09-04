import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../services/document_parser_service.dart';
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
  final dynamic icon;
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
        allowedExtensions: DocumentParserService.allowedExtensions,
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
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      _showAddPdfModal();
    }
  }

  void _showAddPdfModal() {
    final titleController = TextEditingController();
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text('${lang.translate('add_pdf')} - ${widget.courseTitle}'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: CupertinoTextField(
              controller: titleController,
              placeholder: 'Enter Lecture Title (e.g. Chapter 3 Notes)',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(lang.translate('cancel')),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text(lang.translate('add_pdf')),
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
    final lang = Provider.of<LanguageProvider>(context, listen: false);
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
            final formattedTarget =
                '${targetDate.year}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.day.toString().padLeft(2, '0')}';

            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedClock01,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${lang.translate('set_exam_date')}: $examTitle',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Counter Container
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          lang.translate('days_left'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: daysOffset > 0
                                  ? () => setModalState(() => daysOffset--)
                                  : null,
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedMinusSignCircle,
                                size: 34,
                              ),
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '$daysOffset',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => setModalState(() => daysOffset++),
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedAddCircleHalfDot,
                                size: 34,
                              ),
                              color: accentColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendar01,
                              size: 15,
                              color: accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formattedTarget,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Presets
                  Text(
                    lang.translate('quick_presets'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [3, 7, 10, 14, 21, 30, 45].map((presetDays) {
                      final isSelected = daysOffset == presetDays;
                      return ChoiceChip(
                        label: Text('+$presetDays'),
                        selected: isSelected,
                        selectedColor: accentColor.withValues(alpha: 0.25),
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? accentColor
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? accentColor : Colors.transparent,
                          ),
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

                  // Pick from calendar button
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
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendar01,
                      size: 18,
                      color: isDark ? Colors.white70 : ZankoColors.textPrimary,
                    ),
                    label: Text(
                      lang.translate('pick_from_calendar'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : ZankoColors.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Actions
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              lang.translate('delete'),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            lang.translate('save'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
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
    required dynamic icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onPickDate,
  }) {
    final lang = Provider.of<LanguageProvider>(context);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    String statusText = lang.translate('not_set');
    String dateFormatted = lang.translate('not_set');
    Color badgeBg = isDark ? Colors.white10 : Colors.grey.shade100;
    Color badgeFg = isDark ? Colors.grey[400]! : Colors.grey.shade600;

    if (date != null) {
      dateFormatted =
          '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      final targetStart = DateTime(date.year, date.month, date.day);
      final diff = targetStart.difference(todayStart).inDays;

      if (diff < 0) {
        statusText = lang.translate('exam_ended');
        badgeBg = isDark ? Colors.white10 : Colors.grey.shade200;
        badgeFg = Colors.grey;
      } else if (diff == 0) {
        statusText = lang.translate('today_exam');
        badgeBg = const Color(0xFFFF3B30).withValues(alpha: 0.15);
        badgeFg = const Color(0xFFFF3B30);
      } else if (diff <= 3) {
        statusText = '$diff ${lang.translate('days_left')} 🔥';
        badgeBg = const Color(0xFFFF9500).withValues(alpha: 0.15);
        badgeFg = const Color(0xFFFF9500);
      } else {
        statusText = '$diff ${lang.translate('days_left')}';
        badgeBg = accentColor.withValues(alpha: 0.15);
        badgeFg = accentColor;
      }
    }

    return GestureDetector(
      onTap: onPickDate,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: appIcon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedPencilEdit02,
                  size: 16,
                  color: accentColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dateFormatted,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[300] : ZankoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiToolCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required dynamic icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: appIcon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: ZankoColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);
    final isRtl = lang.isRtl;

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    GlassButton(
                      onTap: () => Navigator.pop(context),
                      child: HugeIcon(
                        icon: isRtl
                            ? HugeIcons.strokeRoundedArrowRight01
                            : HugeIcons.strokeRoundedArrowLeft01,
                        size: 20,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.translate('course_details'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.themeColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.courseTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Action: AI Tutor Chat
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => AiTeacherChatScreen(
                              initialPrompt:
                                  'سڵاو! من خوێندکارم و دەمەوێت لە بابەتی (${widget.courseTitle}) یارمەتیم بدەیت و بەشێوازێکی سادە و زانستی بۆم ڕوون بکەیتەوە.',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: widget.themeColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedAiBrain01,
                          color: widget.themeColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modern Hero Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              widget.themeColor.withValues(alpha: 0.25),
                              ZankoColors.darkCard,
                            ]
                          : [
                              widget.themeColor.withValues(alpha: 0.12),
                              Colors.white,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.themeColor.withValues(alpha: isDark ? 0.3 : 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.themeColor.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                  widget.themeColor.withValues(alpha: 0.75),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.themeColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: appIcon(
                                widget.icon,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.courseTitle,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.courseSubtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: ZankoColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Metric Badges
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: widget.themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedFile02,
                                  size: 13,
                                  color: widget.themeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_pdfLectures.length} ${lang.translate('lectures_count')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: widget.themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: ZankoColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                                  size: 13,
                                  color: ZankoColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(widget.progress * 100).toInt()}% ${lang.translate('course_progress')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: ZankoColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: widget.progress,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // Exam Countdown Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedClock01,
                          size: 18,
                          color: ZankoColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang.translate('exam_countdown_title'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
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
                            title: lang.translate('midterm_exam'),
                            date: _midtermDate,
                            icon: HugeIcons.strokeRoundedClock01,
                            accentColor: const Color(0xFF0284C7),
                            isDark: isDark,
                            onPickDate: () {
                              _showExamDateEditModal(
                                context: context,
                                examTitle: lang.translate('midterm_exam'),
                                currentDate: _midtermDate,
                                accentColor: const Color(0xFF0284C7),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildExamDetailTile(
                            context: context,
                            title: lang.translate('final_exam'),
                            date: _finalDate,
                            icon: HugeIcons.strokeRoundedFlag01,
                            accentColor: const Color(0xFFAF52DE),
                            isDark: isDark,
                            onPickDate: () {
                              _showExamDateEditModal(
                                context: context,
                                examTitle: lang.translate('final_exam'),
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

            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // AI Study Superpowers Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAiMagic,
                          size: 18,
                          color: const Color(0xFFAF52DE),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang.translate('ai_study_tools'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildAiToolCard(
                          context: context,
                          title: lang.translate('ai_explain_course'),
                          subtitle: 'وانەبێژی AI',
                          icon: HugeIcons.strokeRoundedTeacher,
                          color: ZankoColors.primary,
                          isDark: isDark,
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => AiTeacherChatScreen(
                                  initialPrompt:
                                      'تکایە بە شێوازێکی زانستی و ڕوون سەرجەم چەمکە سەرەکییەکانی وانەی (${widget.courseTitle})م بۆ شیبکەرەوە بە کوردی.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildAiToolCard(
                          context: context,
                          title: lang.translate('generate_quiz_btn'),
                          subtitle: 'تاقیکردنەوە',
                          icon: HugeIcons.strokeRoundedNote01,
                          color: ZankoColors.success,
                          isDark: isDark,
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => AiTeacherChatScreen(
                                  initialPrompt:
                                      'تکایە ٥ پرسیاری هەڵبژاردن (Multiple Choice Quiz) لەسەر وانەی (${widget.courseTitle}) دابنێ لەگەڵ وەڵامە راستەکان و ڕوونکردنەوەی کورت بە کوردی.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildAiToolCard(
                          context: context,
                          title: lang.translate('key_concepts_btn'),
                          subtitle: 'کورتەی یاسا',
                          icon: HugeIcons.strokeRoundedSparkles,
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => AiTeacherChatScreen(
                                  initialPrompt:
                                      'گرنگترین فۆرمولا، یاسا و پێناسە سەرەکییەکانی وانەی (${widget.courseTitle}) لە شێوازی پوختەی کورت بە خاڵ بۆم ڕیزبکە.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Lectures & PDF Documents Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedFile02,
                          color: Color(0xFFFF3B30),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${lang.translate('lecture_materials')} (${_pdfLectures.length})',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _uploadPdfLecture,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ZankoColors.primary,
                              ZankoColors.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: ZankoColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedCloudUpload,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+ ${lang.translate('upload_lecture_btn')}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
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

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Lectures List / Empty State
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _pdfLectures.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark ? ZankoColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedFile02,
                                size: 40,
                                color: Color(0xFFFF3B30),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              lang.translate('no_pdf_uploaded'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lang.translate('upload_pdf_desc'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: ZankoColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _uploadPdfLecture,
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCloudUpload,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                lang.translate('upload_lecture_btn'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ZankoColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: _pdfLectures.map((pdf) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? ZankoColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFF1F5F9),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black26
                                        : Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      final realContent = SamplePdfService()
                                          .getSampleLectureText(
                                              pdf.fileName, widget.courseTitle);
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
                                        // PDF Squircle Icon
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF3B30)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Center(
                                            child: HugeIcon(
                                              icon: HugeIcons.strokeRoundedFile02,
                                              color: Color(0xFFFF3B30),
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                pdf.title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
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
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFFFF3B30),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '•',
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? Colors.grey[500]
                                                          : Colors.grey[400],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      lang.translate(pdf.dateAdded),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: ZankoColors.textSecondary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Delete Button
                                        IconButton(
                                          icon: const HugeIcon(
                                            icon: HugeIcons.strokeRoundedDelete02,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () => _deletePdf(pdf.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Quick Action Pills
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            final realContent = SamplePdfService()
                                                .getSampleLectureText(
                                                    pdf.fileName, widget.courseTitle);
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
                                            padding:
                                                const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: ZankoColors.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedChatting01,
                                                  size: 14,
                                                  color: ZankoColors.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  lang.translate('chat_with_lecture'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: ZankoColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            final realContent = SamplePdfService()
                                                .getSampleLectureText(
                                                    pdf.fileName, widget.courseTitle);
                                            Navigator.push(
                                              context,
                                              CupertinoPageRoute(
                                                builder: (context) =>
                                                    AiTeacherChatScreen(
                                                  initialPrompt:
                                                      'تکایە ئەم فایلی وانەیە (${pdf.title}) بەشێوەیەکی پوخت کورت بکەرەوە و خاڵە هەرە گرنگەکانی شیکار بکە:\n\n$realContent',
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFAF52DE)
                                                  .withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedAiMagic,
                                                  size: 14,
                                                  color: Color(0xFFAF52DE),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  lang.translate('summarize_lecture'),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFAF52DE),
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

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }
}
