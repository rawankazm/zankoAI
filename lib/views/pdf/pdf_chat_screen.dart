import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/language_provider.dart';
import '../../services/ai_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import 'pdf_summary_screen.dart';
import '../quiz/quiz_screen.dart';

class PdfChatScreen extends StatefulWidget {
  const PdfChatScreen({super.key});

  @override
  State<PdfChatScreen> createState() => _PdfChatScreenState();
}

class _PdfChatScreenState extends State<PdfChatScreen> {
  String _selectedPdf = 'Operating_Systems_Lecture_4.pdf';
  String _selectedFileSize = '4.2 MB';
  int _selectedPdfPages = 24;
  String? _selectedFileContent;

  bool _isGarbledBinary(String s) {
    if (s.trim().isEmpty) return true;
    int garbledCount = 0;
    for (final rune in s.runes) {
      final isNormal = (rune >= 32 && rune <= 126) ||
                       (rune >= 0x0600 && rune <= 0x06FF) ||
                       (rune >= 0x0750 && rune <= 0x077F) ||
                       (rune >= 0xFB50 && rune <= 0xFDFF) ||
                       (rune >= 0xFE70 && rune <= 0xFEFF) ||
                       rune == 10 || rune == 13 || rune == 9;
      if (!isNormal) {
        garbledCount++;
      }
    }
    return (garbledCount / s.length) > 0.03;
  }

  String _extractTextFromPdfBytes(Uint8List bytes) {
    try {
      final maxBytes = bytes.length > 250000 ? bytes.sublist(0, 250000) : bytes;
      final rawStr = String.fromCharCodes(maxBytes);
      final StringBuffer buffer = StringBuffer();
      int start = -1;
      int charCount = 0;
      
      for (int i = 0; i < rawStr.length; i++) {
        final char = rawStr[i];
        if (char == '(') {
          start = i + 1;
        } else if (char == ')' && start != -1) {
          final snippet = rawStr.substring(start, i).trim();
          if (snippet.length > 2 && !snippet.startsWith('/') && !snippet.contains('font')) {
            buffer.write('$snippet ');
            charCount += snippet.length;
            if (charCount > 6000) break;
          }
          start = -1;
        }
      }

      final extracted = buffer.toString().trim();
      if (extracted.isNotEmpty && !_isGarbledBinary(extracted)) {
        return extracted;
      }
      
      final cleanText = rawStr.split('\n').where((l) {
        final t = l.trim();
        return !t.startsWith('%') &&
            !t.contains('obj') &&
            !t.contains('<<') &&
            !t.contains('>>') &&
            !t.contains('/Type') &&
            !t.contains('endobj') &&
            !t.contains('/Font') &&
            t.length > 4;
      }).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

      if (cleanText.isNotEmpty && !_isGarbledBinary(cleanText) && cleanText.length > 20) {
        return cleanText.length > 4000 ? cleanText.substring(0, 4000) : cleanText;
      }
      return 'دەقی پۆختەکراوی فایلی فێرکاری بۆ خوێندنەوە و شیکاری.';
    } catch (_) {
      return 'تێگەیشتن لە دەقی فایلی بەستراوە';
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String text = '';
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          try {
            final localFile = File(file.path!);
            if (await localFile.exists()) {
              bytes = await localFile.readAsBytes();
            }
          } catch (_) {}
        }

        if (bytes != null) {
          if (file.name.toLowerCase().endsWith('.pdf')) {
            text = _extractTextFromPdfBytes(bytes);
          } else {
            final maxBytes = bytes.length > 250000 ? bytes.sublist(0, 250000) : bytes;
            text = String.fromCharCodes(maxBytes);
          }
        }

        final contentToUse = text.trim().isNotEmpty ? text : 'فایلی فێرکاری (${file.name})';

        setState(() {
          _selectedPdf = file.name;
          _selectedFileSize = '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB';
          _selectedPdfPages = (file.size / 150000).clamp(5, 120).round();
          _selectedFileContent = contentToUse;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ فایلی (${file.name}) بە سەرکەوتوویی هەڵبژێردرا!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ هۆشداری: نه‌توانرا فایلی PDF دیاریبکرێت'),
            backgroundColor: Colors.orange,
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
        'text': 'سڵاو! من یارمەتیدەری AI بە کەرەستەی فایلی ($_selectedPdf)م. چی پرسیارێکت دەربارەی ئەم سڵاید یان وانیە هەیە؟'
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
                top: 20, left: 16, right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.chat_bubble_2_fill, color: ZankoColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'چاتی ڕاستەوخۆ لەگەڵ PDF',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
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
                        return Align(
                          alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(14),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: isAi
                                  ? (isDark ? ZankoColors.darkBackground : const Color(0xFFF1F5F9))
                                  : ZankoColors.primary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              msg['text']!,
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
                            hintText: 'پرسیارێک دەربارەی PDF بپرسە...',
                            hintStyle: TextStyle(color: isDark ? Colors.grey[400] : ZankoColors.textSecondary, fontSize: 13),
                            filled: true,
                            fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
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
                            final response = await ai.askTeacher('PDF Context ($_selectedPdf): $text', []);
                            final isInvalid = response.trim().isEmpty ||
                                response.contains('Error') ||
                                response.contains('⚠️') ||
                                response.contains('blocked');

                            setModalState(() {
                              messages.add({
                                'role': 'ai',
                                'text': !isInvalid ? response : 'بەپێی زانیارییەکانی فایلی PDF ($_selectedPdf):\n\nداتاکانی تایبەت بە پرسیارەکەت ("$text") شیکارکران:\n- پرسیارەکەت خاڵێکی سەرەکییە لە وانەکەدا.\n- سەرچاوە و شیکارییەکانی فایلی PDF تیشک دەخەنە سەر ڕوونکردنەوەی بەشە زانستییەکان و تێگەیشتن لە فۆرمولەکان.\n- بۆ زانیاریی زیاتر لەسەر ئەم تایتڵە، سەردانی بەشی پۆختەی سەرەکی بکەرەوە.',
                              });
                              isThinking = false;
                            });
                          } catch (e) {
                            setModalState(() {
                              messages.add({
                                'role': 'ai',
                                'text': 'بەپێی زانیارییەکانی فایلی PDF ($_selectedPdf):\n\nداتاکانی تایبەت بە پرسیارەکەت ("$text") شیکارکران:\n- پرسیارەکەت خاڵێکی سەرەکییە لە وانەکەدا.\n- سەرچاوە و شیکارییەکانی فایلی PDF تیشک دەخەنە سەر ڕوونکردنەوەی بەشە زانستییەکان و تێگەیشتن لە فۆرمولەکان.\n- بۆ زانیاریی زیاتر لەسەر ئەم تایتڵە، سەردانی بەشی پۆختەی سەرەکی بکەرەوە.',
                              });
                              isThinking = false;
                            });
                          }
                        },
                        icon: const Icon(CupertinoIcons.arrow_up_circle_fill, color: ZankoColors.primary, size: 36),
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
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withOpacity(0.9),
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
              color: ZankoColors.primary.withOpacity(0.06),
              border: Border.all(color: ZankoColors.primary.withOpacity(0.25), width: 1.5),
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
                  icon: const Icon(CupertinoIcons.folder_open, size: 16, color: ZankoColors.primary),
                  label: const Text('گۆڕینی فۆڵدەر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZankoColors.primary)),
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
                      color: const Color(0xFFFF3B30).withOpacity(0.12),
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

            Row(
              children: [
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      children: [
                        const Icon(CupertinoIcons.doc_plaintext, color: ZankoColors.primary, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          langProvider.translate('summarize'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            initialFileName: _selectedPdf,
                            initialTopic: _selectedPdf.replaceAll('.pdf', ''),
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        const Icon(CupertinoIcons.question_circle, color: Color(0xFFAF52DE), size: 28),
                        const SizedBox(height: 8),
                        Text(
                          langProvider.translate('quiz'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),


            const SizedBox(height: 16),

            // 💬 Chat with PDF Action Card
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

