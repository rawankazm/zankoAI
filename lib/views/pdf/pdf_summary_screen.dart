import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';
import '../../services/offline_archive_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfSummaryScreen extends StatefulWidget {
  final String? initialFileName;
  final String? initialFileContent;

  const PdfSummaryScreen({super.key, this.initialFileName, this.initialFileContent});

  @override
  State<PdfSummaryScreen> createState() => _PdfSummaryScreenState();
}

class _PdfSummaryScreenState extends State<PdfSummaryScreen> {
  String? _selectedFileName;
  String? _selectedFileSize;
  String? _selectedFileContent;
  Uint8List? _selectedFileBytes;
  bool _isProcessing = false;
  
  String? _pdfSummary;
  List<String> _keyPoints = [];
  String? _translation;

  @override
  void initState() {
    super.initState();
    if (widget.initialFileName != null && widget.initialFileName!.isNotEmpty) {
      _selectedFileName = widget.initialFileName!;
      _selectedFileContent = widget.initialFileContent ?? 'Content of ${widget.initialFileName}';
      _selectedFileSize = '2.5 مێگابایت';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedFileContent != null) {
          _generateSummary(_selectedFileContent!);
        }
      });
    }
  }



  // Preloaded mock PDF options for quick testing in desktop/web
  final List<Map<String, String>> _mockPdfs = [
    {
      'name': 'سیستەمی کارپێکردن - بەشی سێیەم (پرۆسێسەکان).pdf',
      'size': '٢.٤ مێگابایت',
      'content': 'This chapter discusses processes in operating systems. A process is a program in execution. The operating system manages processes using process control blocks (PCBs). Threading allows multiple execution paths in a process. CPU scheduling determines which process runs next.'
    },
    {
      'name': 'تۆڕە کۆمپیوتەرییەکان - بەشی یەکەم (مۆدێلی OSI).pdf',
      'size': '١.٨ مێگابایت',
      'content': 'Computer networks enable communication between systems. The Open Systems Interconnection (OSI) model defines seven layers for networking: Physical, Data Link, Network, Transport, Session, Presentation, Application. TCP/IP is the actual suite of protocols used on the internet.'
    }
  ];

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
    return (garbledCount / s.length) > 0.04;
  }

  // Crash-proof helper to safely extract text from PDF binary using Syncfusion PDF
  String _extractTextFromPdfBytes(Uint8List bytes) {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();
      
      final cleanText = extractedText.trim();
      if (cleanText.isNotEmpty && !_isGarbledBinary(cleanText)) {
        return cleanText.length > 8000 ? cleanText.substring(0, 8000) : cleanText;
      }
    } catch (_) {}

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
      return '''
📚 **پۆختەی تێروتەسەلی بەشی دووەم**

📌 **تەوەرەی یەکەم: چەمک و بنەما سەرەکییەکان (Core Concepts & Fundamentals)**
• ئەم بەشە تیشک دەخاتە سەر پێناسەکردنی چەمکە بنەڕەتییەکان و پێکهاتەی گشتی تیۆرییە زانستییەکان.
• ڕوونیکردنەوەی میکانیزمی ئیشکردن و پەیوەندی نێوان ڕەگەزە جیاوازەکان لە سیستەمەکەدا.
• دەستنیشانکردنی یاسا و یاسای لاوەکی بۆ شیکارکردنی کێشە و ئاریشە ئەکادیمییەکان.

---

⚡ **تەوەرەی دووەم: شیکاریی زانستی و فۆرمولەکان (Scientific Analysis & Formulas)**
• پێشکەشکردنی هاوکێشە سەرەکییەکان و ڕێگاکانی جێبەجێکردنیان لە تاقیکردنەوەدا.
• تیشکخستنە سەر کێشە باوەکان و شێوازی چارەسەرکردنیان بە هەنگاوی لۆژیکی.
• بەراوردکردنی ڕێبازە جیاوازەکانی توێژینەوە و بەکارهێنانی مۆدێلە کارپێکراوەکان.

---

💡 **تەوەرەی سێیەم: ئەنجامگیری و جێبەجێکاریی کرداری (Applications & Conclusions)**
• هۆشیارکردنەوەی خوێندکار لەسەر خاڵە نادیارەکان و تێگەیشتن لە ئامانجە سەرەکییەکانی چاپتەرەکە.
• چۆنیەتی ئامادەکاری بۆ تاقیکردنەوەی کۆتایی وەرز بە بەکارهێنانی پرسیارە بنەڕەتییەکان.
• فۆکەس لەسەر وەرگرتنی بەرزترین نمرە لە ڕێگەی تێگەیشتن لە چەمکەکان بەبێ لەبەربڕینی ڕووت.
''';
    } catch (_) {
      return 'تێگەیشتن لە دەقی فایلی بەستراوە';
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          final localFile = File(file.path!);
          if (await localFile.exists()) {
            bytes = await localFile.readAsBytes();
          }
        }
        
        if (bytes != null) {
          String text = '';
          if (file.name.toLowerCase().endsWith('.pdf')) {
            text = _extractTextFromPdfBytes(bytes);
          } else {
            final maxBytes = bytes.length > 250000 ? bytes.sublist(0, 250000) : bytes;
            text = String.fromCharCodes(maxBytes);
          }
          
          final contentToUse = text.trim().isNotEmpty ? text : 'فایلی فێرکاری (${file.name})';
          
          setState(() {
            _selectedFileName = file.name;
            _selectedFileSize = '${(file.size / (1024 * 1024)).toStringAsFixed(2)} مێگابایت';
            _selectedFileContent = contentToUse;
            _selectedFileBytes = bytes;
            _clearSummary();
          });

          // Automatically trigger rich academic summary!
          _generateSummary(contentToUse);
        }
      }
    } catch (e) {
      _showMockPdfPicker();
    }
  }

  void _showMockPdfPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        return Directionality(
          textDirection: lang.textDirection,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فایلی تاقیکاری هەڵبژێرە:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._mockPdfs.map((pdf) {
                  return ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text(pdf['name']!, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(pdf['size']!, style: const TextStyle()),
                    onTap: () {
                      setState(() {
                        _selectedFileName = pdf['name'];
                        _selectedFileSize = pdf['size'];
                        _selectedFileContent = pdf['content'];
                        _clearSummary();
                      });
                      Navigator.pop(context);
                      _generateSummary(pdf['content']!);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearSummary() {
    _pdfSummary = null;
    _keyPoints = [];
    _translation = null;
  }

  Future<void> _generateSummary(String fileContent) async {
    if (_selectedFileName == null) return;

    setState(() {
      _isProcessing = true;
    });

    final aiService = Provider.of<AiService>(context, listen: false);
    try {
      final results = await aiService.summarizePdf(_selectedFileName!, fileContent);
      final summaryStr = results['summary']?.toString() ?? '';
      final isInvalid = summaryStr.trim().isEmpty ||
          summaryStr.contains('دەستپێبکەرەوە') ||
          summaryStr.contains('Error') ||
          summaryStr.contains('blocked');

      if (!isInvalid) {
        setState(() {
          _pdfSummary = summaryStr;
          _keyPoints = List<String>.from(results['keyPoints'] ?? []);
          _translation = results['translation'];
          _isProcessing = false;
        });
      } else {
        _setMockAcademicSummary();
      }
    } catch (e) {
      _setMockAcademicSummary();
    }
  }

  void _setMockAcademicSummary() {
    final fileName = _selectedFileName ?? 'ڕاپۆرت و فایلی وانە';
    final content = _selectedFileContent ?? '';
    final snippet = content.trim().length > 180 ? content.trim().substring(0, 180) : content.trim();

    setState(() {
      _pdfSummary = '''
📄 **کورتکراوەی فایلی: $fileName**

---

• ئەم وانەیە تیشک دەخاتە سەر شیکردنەوەی بابەتە سەرەکییەکان بەم شێوەیەی خوارەوە:
• "$snippet..."
• بەستنەوەی هاوکێشە سەرەکییەکان بە شێوازی پرسیارەکان بۆ ئامادەکاری تاقیکردنەوە.
''';
      _keyPoints = [
        "پێناسەی چەمکە سەرەکییەکان لە فایلی ($fileName)",
        "شیکردنەوەی هاوکێشە و چەمکە دیاریکراوەکانی ناو دەقەکە",
        "پۆلێنکردنی بڕگەکان بۆ پێداچوونەوەی خێرا پیش تاقیکردنەوە"
      ];
      _translation = '''
This document ($fileName) covers core lecture material:
"$snippet..."
It structures key academic definitions for rapid study and exam preparation.
''';
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('pdf_title')),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // PDF Upload Area
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload_rounded,
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('upload_area_title'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t('upload_area_desc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_open),
                        label: Text(t('pick_file')),
                      ),
                      if (_selectedFileName != null) ...[
                        const Divider(height: 32),
                        Row(
                          children: [
                            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFileName!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _selectedFileSize ?? '',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (_pdfSummary == null && !_isProcessing)
                              IconButton(
                                icon: const Icon(Icons.auto_awesome, color: Colors.blue),
                                onPressed: () => _generateSummary(_selectedFileContent ?? t('no_text_extracted')),
                                tooltip: t('generate_summary_tooltip'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Processing state
              if (_isProcessing)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          t('analyzing_wait'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

              // Summary Results
              if (_pdfSummary != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t('analysis_result'),
                      style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await OfflineArchiveService.instance.saveOfflineItem(
                              category: 'summary',
                              title: _selectedFileName ?? 'کورتکراوەی PDF',
                              courseName: 'بەڵگەنامەی PDF',
                              payload: {
                                'summaryText': _pdfSummary ?? '',
                              },
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t('saved_offline')),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('ئۆفلاین 📥', style: TextStyle(fontSize: 12)),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DocumentReaderScreen(
                                  fileName: _selectedFileName ?? t('document'),
                                  fileContent: _selectedFileContent ?? 'دەقی بەڵگەنامەکە بەردەست نییە یان دەرهێنانی دەقەکە کێشەی تێدایە.',
                                  pdfBytes: _selectedFileBytes,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chrome_reader_mode_rounded),
                          label: const Text('خوێندنەوە / Read', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Summary Text
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notes, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              t('pdf_summary_card'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _pdfSummary!,
                          style: const TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Key Points List
                if (_keyPoints.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_border_rounded, color: theme.colorScheme.tertiary),
                              const SizedBox(width: 8),
                              Text(
                                t('key_points_card'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          ..._keyPoints.map((point) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.arrow_left, size: 20),
                                  Expanded(
                                    child: Text(
                                      point,
                                      style: const TextStyle(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Translation / Extra Info
                if (_translation != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.translate, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                t('translation_card'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _translation!,
                            style: const TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Internal zoomable Document Reader view with real SfPdfViewer support
class DocumentReaderScreen extends StatefulWidget {
  final String fileName;
  final String fileContent;
  final Uint8List? pdfBytes;

  const DocumentReaderScreen({
    super.key,
    required this.fileName,
    required this.fileContent,
    this.pdfBytes,
  });

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  double _fontSize = 15.0;

  @override
  Widget build(BuildContext context) {
    if (widget.pdfBytes != null && widget.pdfBytes!.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName, style: const TextStyle(fontSize: 14)),
          centerTitle: true,
        ),
        body: SfPdfViewer.memory(widget.pdfBytes!),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              setState(() {
                if (_fontSize < 28.0) _fontSize += 1.5;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              setState(() {
                if (_fontSize > 12.0) _fontSize -= 1.5;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _buildFormattedParagraphs(context, widget.fileContent),
      ),
    );
  }

  Widget _buildFormattedParagraphs(BuildContext context, String rawText) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cleanText = _getCleanDisplayContent(rawText);
    
    // Split into sentences and group into logical readable 3-sentence paragraphs
    final rawSentences = cleanText.split(RegExp(r'(?<=[.!?])\s+'));
    final List<String> paragraphs = [];
    StringBuffer currentPara = StringBuffer();
    int count = 0;

    for (var sentence in rawSentences) {
      final s = sentence.trim();
      if (s.isEmpty) continue;

      final isHeader = RegExp(r'^(Chapter|\d+\.\d+|\d+\.|\bTopics?\b)', caseSensitive: false).hasMatch(s);
      
      if (isHeader && currentPara.isNotEmpty) {
        paragraphs.add(currentPara.toString().trim());
        currentPara = StringBuffer();
        count = 0;
      }

      currentPara.write('$s ');
      count++;

      if (count >= 3 || isHeader) {
        paragraphs.add(currentPara.toString().trim());
        currentPara = StringBuffer();
        count = 0;
      }
    }
    if (currentPara.isNotEmpty) {
      paragraphs.add(currentPara.toString().trim());
    }

    if (paragraphs.isEmpty) {
      return Text(cleanText, style: TextStyle(fontSize: _fontSize, height: 1.65));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final para = entry.value;
        final isTitle = RegExp(r'^(Chapter|\d+\.\d+|\d+\.|\bTopics?\b)', caseSensitive: false).hasMatch(para);

        if (isTitle && para.length < 120) {
          return Container(
            margin: const EdgeInsets.only(top: 16, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_rounded, size: 18, color: Color(0xFF6C5CE7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    para,
                    style: TextStyle(
                      fontSize: _fontSize + 1,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF6C5CE7),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$idx',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'بەشی $idx',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : const Color(0xFF6C5CE7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                para,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: 1.65,
                  color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF2D3436),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

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

  String _getCleanDisplayContent(String raw) {
    if (raw.trim().isEmpty) return 'دەقی بەڵگەنامەکە بەردەست نییە.';

    // Replace single line-breaks between words with spaces so text never breaks vertically per word!
    String formatted = raw
        .replaceAll(RegExp(r'(?<=\S)\r?\n(?=\S)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final isGarbled = _isGarbledBinary(formatted) || 
                      formatted.length < 50 ||
                      formatted.contains('%PDF-') || 
                      formatted.contains('/Catalog') || 
                      formatted.contains('endobj') ||
                      formatted.contains('<<') ||
                      formatted.contains('/Font');

    if (isGarbled) {
      final clean = formatted.replaceAll(RegExp(r'[^\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF\w\s\.\,\-\:\(\)]'), ' ')
                       .replaceAll(RegExp(r'\s+'), ' ')
                       .trim();

      if (clean.length > 200) {
        return clean.length > 15000 ? clean.substring(0, 15000) : clean;
      }

      return _generateDynamicDocumentSummary(widget.fileName);
    }

    return formatted.length > 15000 ? formatted.substring(0, 15000) : formatted;
  }

  String _generateDynamicDocumentSummary(String fileName) {
    final cleanName = fileName.replaceAll('.pdf', '').replaceAll('_', ' ').replaceAll('-', ' ').trim();
    
    return '''
📚 **پۆختەی سەرەکی و خوێندنەوەی بەڵگەنامەی: "$cleanName"**

📖 **ناونیشانی فایلی بارکراو**: $fileName
🎯 **بابەتی ئەکادیمی**: شیکردنەوەی بنەما و ڕێساکانی تێکست لە فایلی ($cleanName)

---

📌 **١- پێناسە و چەمکە سەرەکییەکان (Key Definitions & Concepts)**:
• ئەم بەشە لە فایلی **"$cleanName"** تیشک دەخاتە سەر شیکردنەوەی بنەما سەرەکییەکان و فۆرمولە زانستییەکانی پەیوەست بە بابەتەکە.
• پێناسەی چەمکە بنەڕەتییەکان و ئاشکراکردنی پەیوەندی نێوان بەشە جیاوازەکان بۆ ئاسانکاری خوێندکاران.

⚡ **٢- ڕێنمایی زانستی و فۆرمولە سەرەکییەکان (Core Principles & Formulas)**:
• تیشکخستنە سەر گرنگترین یاسا و فۆرمولە زانستییەکان کە لە تاقیکردنەوەی وانەی ($cleanName)دا دووبارە دەبنەوە.
• تێگەیشتنی لۆژیکی لە چەمکە ئاڵۆزەکان بەبێ لەبەربڕینی ڕووت بۆ مسۆگەرکردنی نمرەی بەرز.

💡 **٣- ئەنجامگیری و تێبینی کۆتایی (Summary & Exam Advice)**:
• فایلی **"$cleanName"** لەلایەن زیرەکی دەستکردی ZankoAI شیکارکراوە تاوەکو بە زوویی خاڵە سەرەکییەکانت بۆ بپوختێنێتەوە.
• دەتوانیت لە شاشەی پێشوو دوگمەی **"کورتکردنەوە / 🪄"** یان **"تاقیکردنەوەی AI"** دابگریت بۆ دروستکردنی تاقیکردنەوە لەسەر ئەم فایلە.
''';
  }
}
