import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
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

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isThinking = false;
  bool _isBannerExpanded = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialFileName != null && widget.initialFileName!.isNotEmpty) {
      _selectedPdf = widget.initialFileName!;
      _selectedFileContent = widget.initialFileContent ??
          SamplePdfService().getSampleLectureText(widget.initialFileName!, 'Academic Course');
    } else {
      _selectedFileContent =
          SamplePdfService().getSampleLectureText(_selectedPdf, 'Academic Course');
    }

    _initWelcomeMessage();
  }

  void _initWelcomeMessage() {
    _messages.add({
      'role': 'ai',
      'text':
          'سڵاو! من یاریدەدەری زیرەکی ZankoAIـم بۆ فایلی ($_selectedPdf).\n\nمن تەواوی دەق و زانیارییەکانی ئەم فایلەم خوێندووەتەوە. دەتوانیت هەر پرسیارێک دەربارەی وانەکە، یاساکان، کورتکردنەوە یان پێشبینی پرسیاری تاقیکردنەوە بپرسیت!',
      'time': _formatCurrentTime(),
    });
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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
          _messages.add({
            'role': 'system',
            'text': '📄 فایلی نوێ هەڵبژێردرا: ${parsed.fileName} (${parsed.formattedSize})',
            'time': _formatCurrentTime(),
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ هۆشداری: نه‌توانرا فایلەکە بخوێندرێتەوە: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _textController.text.trim();
    if (text.isEmpty || _isThinking) return;

    if (presetText == null) {
      _textController.clear();
    }

    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
        'time': _formatCurrentTime(),
      });
      _isThinking = true;
    });
    _scrollToBottom();

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
Here is the actual text content of the student's PDF lecture document ($_selectedPdf):
========================================
$pdfContext
========================================

Student's question regarding this document:
$text

Please provide a clear, accurate, and professional response ENTIRELY IN ENGLISH based strictly on the document above. Include key terms and bullet points if explaining concepts.
'''
          : '''
ئەمە ناوەرۆک و دەقی ڕاستەقینەی فایلی وانەی خوێندکارەکەیە ($_selectedPdf):
========================================
$pdfContext
========================================

پرسیاری خوێندکار لەسەر ناوەرۆکی ئەم فایلە:
$text

تکایە بە ووردبینییەوە و بە شێوازێکی زانستی و ڕوون تەنها لەسەر بنەمای ئەم دەقەی سەرەوە بە زمانی کوردی (سۆرانی) وەڵامی تەواو و تێروتەسەل بنووسەوە. ئەگەر یاسا یان خاڵی گرنگ هەیە بە خاڵ ڕیزبکە.
''';

      final response = await ai.askTeacher(fullPrompt, [], isVip: true);
      final isInvalid = response.trim().isEmpty ||
          response.contains('Error') ||
          response.contains('⚠️') ||
          response.contains('blocked');

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text': !isInvalid
                ? response
                : (response.isNotEmpty
                    ? response
                    : '⚠️ ببورە، نەتوانرا وەڵام لە سێرڤەری AI وەربگیرێت. تکایە دووبارە هەوڵ بدەرەوە.'),
            'time': _formatCurrentTime(),
          });
          _isThinking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text': '⚠️ هەڵە لە پەیوەندی بە AI: $e',
            'time': _formatCurrentTime(),
          });
          _isThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _showDocumentTextModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final content = _selectedFileContent ?? 'ناوەرۆکی فایل بەردەست نییە';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedFile02,
                      color: Color(0xFFFF3B30),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.translate('document_preview'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$_selectedPdf • ${content.length} پیت',
                          style: TextStyle(
                            fontSize: 11,
                            color: ZankoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCopy01,
                      size: 20,
                      color: ZankoColors.primary,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(lang.translate('response_copied')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: isDark ? Colors.grey[300] : ZankoColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestedPromptChip(String title, String prompt, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _sendMessage(prompt),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: ZankoColors.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDark) {
    final role = message['role'] as String;
    final text = message['text'] as String;
    final time = message['time'] as String? ?? '';
    final isAi = role == 'ai';
    final isSystem = role == 'system';

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : ZankoColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        child: Column(
          crossAxisAlignment:
              isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isAi
                    ? null
                    : LinearGradient(
                        colors: [
                          ZankoColors.primary,
                          ZankoColors.primary.withValues(alpha: 0.85),
                        ],
                      ),
                color: isAi
                    ? (isDark ? ZankoColors.darkCard : Colors.white)
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isAi ? 4 : 20),
                  bottomRight: Radius.circular(isAi ? 20 : 4),
                ),
                border: isAi
                    ? Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF1F5F9),
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAi)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: ZankoColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedAiBrain01,
                            size: 14,
                            color: ZankoColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ZankoAI Document Assistant',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ZankoColors.primary,
                          ),
                        ),
                      ],
                    ),
                  if (isAi) const SizedBox(height: 8),
                  SelectableText(
                    text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: isAi
                          ? (isDark ? Colors.white : ZankoColors.textPrimary)
                          : Colors.white,
                      fontWeight: isAi ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
                if (isAi) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            Provider.of<LanguageProvider>(context, listen: false)
                                .translate('response_copied'),
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCopy01,
                        size: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
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
        child: Column(
          children: [
            // Top Navigation & Document Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
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
                      // PDF Icon & Document Info
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isBannerExpanded = !_isBannerExpanded;
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedFile02,
                                    color: Color(0xFFFF3B30),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedPdf,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_selectedPdfPages Pages • $_selectedFileSize',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ZankoColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Document Text Preview Modal Icon
                      IconButton(
                        tooltip: lang.translate('view_document_text'),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedDocumentCode,
                          size: 20,
                          color: isDark ? Colors.white70 : ZankoColors.textPrimary,
                        ),
                        onPressed: _showDocumentTextModal,
                      ),
                      // Full Summary Screen Navigation Button
                      IconButton(
                        tooltip: lang.translate('ai_summary'),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedSparkles,
                          size: 20,
                          color: Color(0xFFAF52DE),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => PdfSummaryScreen(
                                initialFileName: _selectedPdf,
                                initialFileContent: _selectedFileContent,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Collapsible Quick Action Pill Strip
                  if (_isBannerExpanded) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                                color: Color(0xFF10B981),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                lang.translate('active_document'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _pickPdfFile,
                            child: Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedFolder01,
                                  size: 14,
                                  color: ZankoColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  lang.translate('change_document'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: ZankoColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Suggested Prompt Chips
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildSuggestedPromptChip(
                    lang.translate('summarize_doc'),
                    'تکایە کورتەیەکی پوخت و زانستی لە ناوەڕۆکی ئەم فایلە بە زمانی کوردی بخەرەڕوو.',
                    CupertinoIcons.doc_text_fill,
                  ),
                  _buildSuggestedPromptChip(
                    lang.translate('key_exam_questions'),
                    'تکایە ٥ لە گرنگترین پرسیارەکانی تاقیکردنەوە لەم فایلە دەربهێنە لەگەڵ وەڵامەکانیان.',
                    CupertinoIcons.question_circle_fill,
                  ),
                  _buildSuggestedPromptChip(
                    lang.translate('key_formulas'),
                    'سەرجەم یاسا، هاوکێشە یان پێناسە سەرەکییەکانی ئەم بابەتە بە خاڵ بنووسەوە.',
                    CupertinoIcons.function,
                  ),
                  _buildSuggestedPromptChip(
                    lang.translate('quick_quiz_doc'),
                    'کویزێکی ٥ پرسیاری لەسەر ئەم فایلە بە هەڵبژاردن دروست بکە.',
                    CupertinoIcons.bolt_fill,
                  ),
                ],
              ),
            ),

            // Chat Messages Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index], isDark);
                },
              ),
            ),

            // Thinking Progress Indicator
            if (_isThinking)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(4),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(ZankoColors.primaryBlue),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ZankoAI سەرقاڵی شیکاریی دەقی پەڕەکانی PDFەکەیە...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pick File Quick Button
                  GestureDetector(
                    onTap: _pickPdfFile,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? ZankoColors.darkBackground : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedAttachment01,
                        color: isDark ? Colors.white70 : ZankoColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Input TextField
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: lang.translate('ask_pdf_hint'),
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : ZankoColors.textSecondary,
                          fontSize: 12.5,
                        ),
                        filled: true,
                        fillColor:
                            isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send Button
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ZankoColors.primary,
                            ZankoColors.primary.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: ZankoColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: isRtl
                              ? HugeIcons.strokeRoundedArrowLeft01
                              : HugeIcons.strokeRoundedArrowRight01,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
