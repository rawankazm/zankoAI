import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
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

  const CourseDetailScreen({
    super.key,
    required this.courseTitle,
    required this.courseSubtitle,
    required this.progress,
    required this.icon,
    required this.themeColor,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final List<PdfLectureItem> _pdfLectures = [];

  @override
  void initState() {
    super.initState();
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

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // PDF Lectures Header & Add Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.doc_fill,
                          color: Color(0xFFFF3B30),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PDF Lectures (${_pdfLectures.length})',
                          style: TextStyle(
                            fontSize: 17,
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
                              widget.themeColor,
                              widget.themeColor.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.cloud_upload_fill,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+ Add PDF',
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
                                  Row(
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
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  // Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              CupertinoPageRoute(
                                                builder: (context) => const PdfChatScreen(),
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
                                            Navigator.push(
                                              context,
                                              CupertinoPageRoute(
                                                builder: (context) => AiTeacherChatScreen(
                                                  initialPrompt:
                                                      'Generate a summary and study quiz for ${pdf.title}.',
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
