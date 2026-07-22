import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';

class PdfSummaryScreen extends StatefulWidget {
  const PdfSummaryScreen({super.key});

  @override
  State<PdfSummaryScreen> createState() => _PdfSummaryScreenState();
}

class _PdfSummaryScreenState extends State<PdfSummaryScreen> {
  String? _selectedFileName;
  String? _selectedFileSize;
  String? _selectedFileContent;
  bool _isProcessing = false;
  
  String? _pdfSummary;
  List<String> _keyPoints = [];
  String? _translation;

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

  // Helper to extract text from PDF binary
  String _extractTextFromPdfBytes(Uint8List bytes) {
    final pdfString = String.fromCharCodes(bytes);
    final regex = RegExp(r'\((.*?)\)\s*Tj|\((.*?)\)\s*TJ');
    final matches = regex.allMatches(pdfString);
    
    StringBuffer buffer = StringBuffer();
    for (var match in matches) {
      final text = match.group(1) ?? match.group(2) ?? '';
      if (text.isNotEmpty) {
        buffer.write(text);
        buffer.write(' ');
      }
    }
    
    if (buffer.isEmpty) {
      final fallbackRegex = RegExp(r'\(([^)]+)\)');
      final fallbackMatches = fallbackRegex.allMatches(pdfString);
      for (var match in fallbackMatches) {
        final text = match.group(1) ?? '';
        if (text.length > 3 && !text.startsWith('/') && !text.contains(RegExp(r'[0-9]{4}'))) {
          buffer.write(text);
          buffer.write(' ');
        }
      }
    }
    
    return buffer.toString().trim();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md'],
      );

      if (result != null) {
        final file = result.files.single;
        
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        
        if (bytes != null) {
          String text = '';
          if (file.name.toLowerCase().endsWith('.pdf')) {
            text = _extractTextFromPdfBytes(bytes);
          } else {
            text = String.fromCharCodes(bytes);
          }
          
          setState(() {
            _selectedFileName = file.name;
            _selectedFileSize = '${(file.size / (1024 * 1024)).toStringAsFixed(2)} مێگابایت';
            _selectedFileContent = text.isNotEmpty ? text : 'No text could be extracted from this file.';
            _clearSummary();
          });
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
      setState(() {
        _pdfSummary = results['summary'];
        _keyPoints = List<String>.from(results['keyPoints'] ?? []);
        _translation = results['translation'];
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _pdfSummary = 'خەتایەک ڕوویدا لە کاتی شیکردنەوەی پەڕگەکەدا.';
        _isProcessing = false;
      });
    }
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
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DocumentReaderScreen(
                              fileName: _selectedFileName ?? t('document'),
                              fileContent: _selectedFileContent ?? 'دەقی بەڵگەنامەکە بەردەست نییە یان دەرهێنانی دەقەکە کێشەی تێدایە.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chrome_reader_mode_rounded),
                      label: const Text('خوێندنەوە / Read', style: TextStyle(fontSize: 12)),
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
                          const SizedBox(height: 8),
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

// Internal zoomable Document Reader view
class DocumentReaderScreen extends StatefulWidget {
  final String fileName;
  final String fileContent;

  const DocumentReaderScreen({super.key, required this.fileName, required this.fileContent});

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  double _fontSize = 15.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark 
                ? Colors.white10 
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.brightness == Brightness.dark ? Colors.white24 : Colors.black12),
          ),
          child: Text(
            widget.fileContent,
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
