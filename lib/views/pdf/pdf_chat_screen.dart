import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/ai_service.dart';
import '../../services/sample_pdf_service.dart';
import '../../services/document_parser_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import 'pdf_summary_screen.dart';

class PdfChatScreen extends StatefulWidget {
  final String? initialFileName;
  final String? initialFileContent;

  const PdfChatScreen({super.key, this.initialFileName, this.initialFileContent});

  @override
  State<PdfChatScreen> createState() => _PdfChatScreenState();
}

class _PdfChatScreenState extends State<PdfChatScreen> {
  String _selectedPdf = 'Operating_Systems_Lecture_4.pdf';
  String _selectedFileSize = '4.2 MB';
  int _selectedPdfPages = 24;
  String? _selectedFileContent;

  @override
  void initState() {
    super.initState();
    if (widget.initialFileName != null && widget.initialFileName!.isNotEmpty) {
      _selectedPdf = widget.initialFileName!;
      _selectedFileContent = widget.initialFileContent ??
          SamplePdfService().getSampleLectureText(widget.initialFileName!, 'Academic Course');
    } else {
      _selectedFileContent = SamplePdfService().getSampleLectureText(_selectedPdf, 'Academic Course');
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      final parsed = await DocumentParserService.pickAndExtractDocument();
      if (parsed != null) {
        setState(() {
          _selectedPdf = parsed.fileName;
          _selectedFileSize = parsed.formattedSize;
          _selectedPdfPages = parsed.estimatedPagesOrSlides;
          _selectedFileContent = parsed.content;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ فایلی (${parsed.fileName}) بە سەرکەوتوویی هەڵبژێردرا! [${parsed.typeDisplayName}]'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ هۆشداری: نه‌توانرا فایلەکە بخوێندرێتەوە: $e'),
          ),
        );
      }
    }
  }

  void _openPdfAiChatModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textController = TextEditingController();
    final List<Map<String, String>> messages = [
      {
        'role': 'ai',
        'text': 'سڵاو! من یارمەتیدەری AI بە کەرەستەی فایلی ($_selectedPdf)م. چی پرسیارێکت دەربارەی ئەم سڵاید یان وانەیە هەیە؟'
      }
    ];
    bool isThinking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(CupertinoIcons.chat_bubble_2_fill, color: ZankoColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'چاتی دەقی لەگەڵ PDF',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.clear_circled_solid,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Messages list
                  Expanded(
                    child: ListView.builder(
                      itemCount: messages.length,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isAi = msg['role'] == 'ai';
                        final msgText = msg['text'] ?? '';

                        return Align(
                          alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(14),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                            decoration: BoxDecoration(
                              color: isAi
                                  ? (isDark ? ZankoColors.darkBackground : const Color(0xFFF1F5F9))
                                  : ZankoColors.primary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              msgText,
                              style: TextStyle(
                                fontSize: 13,
                                color: isAi
                                    ? (isDark ? Colors.white : ZankoColors.textPrimary)
                                    : Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (isThinking)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(width: 10),
                          Text('مامۆستا AI لە حاڵەتی شیکاری PDFدایە...'),
                        ],
                      ),
                    ),

                  // Input box
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'پرسیارێک دەربارەی PDF بنووسە...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          final text = textController.text.trim();
                          if (text.isEmpty) return;

                          setModalState(() {
                            messages.add({'role': 'user', 'text': text});
                            textController.clear();
                            isThinking = true;
                          });

                          try {
                            final ai = Provider.of<AiService>(context, listen: false);
                            final String pdfContext =
                                (_selectedFileContent != null && _selectedFileContent!.trim().isNotEmpty)
                                    ? _selectedFileContent!
                                    : 'فایلی $_selectedPdf';

                            final englishCharCount = RegExp(r'[a-zA-Z]').allMatches(pdfContext).length;
                            final isEnglishDoc =
                                pdfContext.length > 30 && (englishCharCount / pdfContext.length) > 0.35;
                            final isEnglishQuestion =
                                RegExp(r'[a-zA-Z]').allMatches(text).length > (text.length * 0.5);

                            final fullPrompt = (isEnglishDoc || isEnglishQuestion)
                                ? '''
Here is the actual text content of the student's PDF file ($_selectedPdf):
========================================
$pdfContext
========================================

Student's question regarding this PDF document:
$text

Please provide a detailed, accurate, and professional answer ENTIRELY IN ENGLISH based strictly on the PDF document above.
'''
                                : '''
ئەمە ناوەرۆک و دەقی ڕاستەقینەی فایلی PDFی خوێندکارەکەیە:
========================================
$pdfContext
========================================

پرسیاری خوێندکار لەسەر ناوەرۆکی ئەم فایلی PDFە:
$text

تکایە بە ووردبیینییەوە تەنها لەسەر بنەمای ئەم دەقەی سه‌رەوە بە زمانی کوردی (سۆرانی) وەڵامی ڕاست و تێروتەسەل بنووسەوە.
''';
                            final response = await ai.askTeacher(fullPrompt, [], isVip: true);
                            final isInvalid = response.trim().isEmpty ||
                                response.contains('Error') ||
                                response.contains('⚠️') ||
                                response.contains('blocked');

                            setModalState(() {
                              messages.add({
                                'role': 'ai',
                                'text': !isInvalid
                                    ? response
                                    : (response.isNotEmpty
                                        ? response
                                        : '⚠️ ببورە، نەتوانرا وەڵام لە سێرڤەری AI وەربگیرێت. تکایە دووبارە هەوڵ بدەرەوە.'),
                              });
                              isThinking = false;
                            });
                          } catch (e) {
                            setModalState(() {
                              messages.add({
                                'role': 'ai',
                                'text': '⚠️ هەڵە لە پەیوەندی بە AI: $e',
                              });
                              isThinking = false;
                            });
                          }
                        },
                        icon: Icon(CupertinoIcons.arrow_up_circle_fill, color: ZankoColors.primary, size: 36),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          langProvider.translate('pdf_chat'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // PDF Upload Hero Container
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              color: ZankoColors.primary.withValues(alpha: 0.06),
              border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.25), width: 1.5),
              onTap: _pickPdfFile,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: ZankoColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: ZankoShadows.floating,
                    ),
                    child: const Icon(
                      CupertinoIcons.doc_fill,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    langProvider.translate('upload_pdf_title'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    langProvider.translate('upload_pdf_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: ZankoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Active PDF Document Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  langProvider.translate('active_document'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickPdfFile,
                  icon: Icon(CupertinoIcons.folder_open, size: 16, color: ZankoColors.primary),
                  label: Text(
                    'گۆڕینی فۆڵدەر',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZankoColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(16),
              onTap: _pickPdfFile,
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      CupertinoIcons.doc_fill,
                      color: Color(0xFFFF3B30),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPdf,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_selectedPdfPages Pages • $_selectedFileSize',
                          style: TextStyle(
                            fontSize: 12,
                            color: ZankoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.checkmark_alt_circle_fill,
                    color: ZankoColors.success,
                    size: 22,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // AI PDF Action Tools Header
            Text(
              langProvider.translate('ai_pdf_actions'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // 📄 Text Summarize Action Card
            AppCard(
              padding: const EdgeInsets.all(18),
              color: ZankoColors.primary.withValues(alpha: 0.1),
              border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.3)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfSummaryScreen(
                      initialFileName: _selectedPdf,
                      initialFileContent: _selectedFileContent,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ZankoColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(CupertinoIcons.doc_plaintext, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'کورتکردنەوەی تەواوی دەقی PDF',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'پوختەکردنی خاڵە سەرەکییەکان و وەرگێڕانی ئەکادیمی بە دەق',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_left, color: ZankoColors.primary, size: 20),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 💬 Direct Chat with PDF Action Card
            AppCard(
              padding: const EdgeInsets.all(18),
              color: ZankoColors.primary,
              onTap: () => _openPdfAiChatModal(context),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 30),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💬 چاتی ڕاستەوخۆ لەگەڵ PDF',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'پرسیار بپرسە و وەڵامی زیرەک لە فایلی سڵایدی PDFەکەت وەربگرە',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_left, color: Colors.white, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
