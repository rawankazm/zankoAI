import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Represents the parsed result of any uploaded academic document
class DocumentParseResult {
  final String fileName;
  final String extension;
  final String content;
  final int estimatedPagesOrSlides;
  final int byteSize;
  final String formattedSize;
  final bool isWord;
  final bool isPowerPoint;
  final bool isPdf;
  final bool isPlainText;

  DocumentParseResult({
    required this.fileName,
    required this.extension,
    required this.content,
    required this.estimatedPagesOrSlides,
    required this.byteSize,
    required this.formattedSize,
    this.isWord = false,
    this.isPowerPoint = false,
    this.isPdf = false,
    this.isPlainText = false,
  });

  String get typeDisplayName {
    if (isWord) return 'Word (.$extension)';
    if (isPowerPoint) return 'PowerPoint (.$extension)';
    if (isPdf) return 'PDF';
    return 'Text (${extension.toUpperCase()})';
  }
}

/// Comprehensive parser supporting ALL versions of Word (.docx, .doc),
/// PowerPoint (.pptx, .ppt), PDF (.pdf), and text documents (.txt, .md, .rtf, .csv).
class DocumentParserService {
  /// All supported file extensions for file pickers
  static const List<String> allowedExtensions = [
    'pdf',
    'docx',
    'doc',
    'pptx',
    'ppt',
    'txt',
    'md',
    'rtf',
    'csv',
  ];

  /// Convenient method to launch FilePicker and parse any selected document
  static Future<DocumentParseResult?> pickAndExtractDocument({
    List<String>? customExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: customExtensions ?? allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      if (bytes == null && file.path != null) {
        try {
          final localFile = File(file.path!);
          if (await localFile.exists()) {
            bytes = await localFile.readAsBytes();
          }
        } catch (_) {}
      }

      if (bytes == null || bytes.isEmpty) return null;

      return parseDocumentBytes(
        fileName: file.name,
        bytes: bytes,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Parses bytes for any document format and extracts high-quality text
  static DocumentParseResult parseDocumentBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    final lowerName = fileName.toLowerCase();
    final dotIndex = lowerName.lastIndexOf('.');
    final ext = dotIndex != -1 ? lowerName.substring(dotIndex + 1) : '';

    String content = '';
    int pageOrSlideCount = 1;
    bool isWord = false;
    bool isPpt = false;
    bool isPdf = false;
    bool isPlain = false;

    if (ext == 'pdf' || _isPdfBytes(bytes)) {
      isPdf = true;
      final pdfResult = _extractTextFromPdf(bytes);
      content = pdfResult.text;
      pageOrSlideCount = pdfResult.pageCount;
    } else if (ext == 'docx') {
      isWord = true;
      final docxResult = _extractTextFromDocx(bytes);
      content = docxResult.text;
      pageOrSlideCount = docxResult.estimatedPages;
    } else if (ext == 'doc') {
      isWord = true;
      final docResult = _extractTextFromDoc(bytes);
      content = docResult.text;
      pageOrSlideCount = docResult.estimatedPages;
    } else if (ext == 'pptx') {
      isPpt = true;
      final pptxResult = _extractTextFromPptx(bytes);
      content = pptxResult.text;
      pageOrSlideCount = pptxResult.slideCount;
    } else if (ext == 'ppt') {
      isPpt = true;
      final pptResult = _extractTextFromPpt(bytes);
      content = pptResult.text;
      pageOrSlideCount = pptResult.slideCount;
    } else {
      isPlain = true;
      content = _extractTextFromPlainBytes(bytes);
      pageOrSlideCount = (content.length / 1800).ceil().clamp(1, 999);
    }

    if (content.trim().isEmpty) {
      content = 'فایلی فێرکاری: $fileName';
    }

    final mbSize = (bytes.length / (1024 * 1024));
    final formattedSize = mbSize >= 1.0
        ? '${mbSize.toStringAsFixed(1)} MB'
        : '${(bytes.length / 1024).toStringAsFixed(0)} KB';

    return DocumentParseResult(
      fileName: fileName,
      extension: ext.isNotEmpty ? ext : 'dat',
      content: content,
      estimatedPagesOrSlides: pageOrSlideCount > 0 ? pageOrSlideCount : 1,
      byteSize: bytes.length,
      formattedSize: formattedSize,
      isWord: isWord,
      isPowerPoint: isPpt,
      isPdf: isPdf,
      isPlainText: isPlain,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. PDF Extractor (.pdf)
  // ──────────────────────────────────────────────────────────────────────────
  static ({String text, int pageCount}) _extractTextFromPdf(Uint8List bytes) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      return (text: text.trim(), pageCount: pageCount);
    } catch (_) {
      final rawText = _extractAsciiAndUtf16Strings(bytes);
      return (text: rawText.trim(), pageCount: 1);
    } finally {
      try {
        document?.dispose();
      } catch (_) {}
    }
  }

  static bool _isPdfBytes(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Modern Word Extractor (.docx - OpenXML 2007 through 2024 / 365)
  // ──────────────────────────────────────────────────────────────────────────
  static ({String text, int estimatedPages}) _extractTextFromDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final buffer = StringBuffer();

      // Priority 1: word/document.xml (Main Body)
      for (final file in archive.files) {
        if (file.name == 'word/document.xml' || file.name == 'word/document2.xml') {
          final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
          final parsed = _extractTextFromWordXml(xmlStr);
          if (parsed.isNotEmpty) {
            buffer.writeln(parsed);
          }
        }
      }

      // Priority 2: Headers, Footers, Footnotes, Comments
      for (final file in archive.files) {
        final name = file.name.toLowerCase();
        if ((name.startsWith('word/header') ||
                name.startsWith('word/footer') ||
                name.startsWith('word/footnotes') ||
                name.startsWith('word/comments')) &&
            name.endsWith('.xml')) {
          final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
          final parsed = _extractTextFromWordXml(xmlStr);
          if (parsed.isNotEmpty) {
            buffer.writeln(parsed);
          }
        }
      }

      final fullText = buffer.toString().trim();
      final pageEstimate = (fullText.length / 2200).ceil().clamp(1, 500);
      return (text: fullText, estimatedPages: pageEstimate);
    } catch (_) {
      final fallback = _extractAsciiAndUtf16Strings(bytes);
      return (text: fallback.trim(), estimatedPages: 1);
    }
  }

  static String _extractTextFromWordXml(String xml) {
    final buffer = StringBuffer();
    // Parse paragraphs <w:p>
    final paragraphRegex = RegExp(r'<w:p(?:\s+[^>]*)?>(.*?)</w:p>', dotAll: true);
    final textRegex = RegExp(r'<w:t(?:\s+[^>]*)?>(.*?)</w:t>', dotAll: true);
    final tabRegex = RegExp(r'<w:tab/>');
    final brRegex = RegExp(r'<w:br/>');

    final paragraphs = paragraphRegex.allMatches(xml);
    if (paragraphs.isNotEmpty) {
      for (final pMatch in paragraphs) {
        final pContent = pMatch.group(1) ?? '';
        final lineBuffer = StringBuffer();

        var processed = pContent.replaceAll(tabRegex, '\t').replaceAll(brRegex, '\n');
        for (final tMatch in textRegex.allMatches(processed)) {
          final text = tMatch.group(1) ?? '';
          lineBuffer.write(_decodeXmlEntities(text));
        }

        final line = lineBuffer.toString().trim();
        if (line.isNotEmpty) {
          buffer.writeln(line);
        }
      }
    } else {
      // Fallback: extract all <w:t> directly
      for (final tMatch in textRegex.allMatches(xml)) {
        final text = tMatch.group(1) ?? '';
        buffer.write('${_decodeXmlEntities(text)} ');
      }
    }

    return buffer.toString().trim();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Legacy Word Extractor (.doc - Word 97-2003 / RTF / OLE Compound File)
  // ──────────────────────────────────────────────────────────────────────────
  static ({String text, int estimatedPages}) _extractTextFromDoc(Uint8List bytes) {
    // 1. Check if file is actually an RTF file saved as .doc
    final isRtf = bytes.length > 5 &&
        bytes[0] == 0x7B && // {
        bytes[1] == 0x5C && // \
        bytes[2] == 0x72 && // r
        bytes[3] == 0x74 && // t
        bytes[4] == 0x66; // f

    if (isRtf) {
      final rawRtf = utf8.decode(bytes, allowMalformed: true);
      final rtfText = _stripRtf(rawRtf);
      final pageEstimate = (rtfText.length / 2200).ceil().clamp(1, 500);
      return (text: rtfText, estimatedPages: pageEstimate);
    }

    // 2. Extract text from binary Word OLE stream
    final extracted = _extractAsciiAndUtf16Strings(bytes);
    final pageEstimate = (extracted.length / 2200).ceil().clamp(1, 500);
    return (text: extracted.trim(), estimatedPages: pageEstimate);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Modern PowerPoint Extractor (.pptx - OpenXML 2007 through 2024 / 365)
  // ──────────────────────────────────────────────────────────────────────────
  static ({String text, int slideCount}) _extractTextFromPptx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final slideMap = <int, String>{};
      final notesMap = <int, String>{};

      for (final file in archive.files) {
        final name = file.name;
        // Slide XML matching: ppt/slides/slide1.xml, ppt/slides/slide2.xml, etc.
        final slideMatch = RegExp(r'ppt/slides/slide(\d+)\.xml', caseSensitive: false).firstMatch(name);
        if (slideMatch != null) {
          final slideIndex = int.tryParse(slideMatch.group(1) ?? '1') ?? 1;
          final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
          final slideText = _extractTextFromPptxSlideXml(xmlStr);
          slideMap[slideIndex] = slideText;
        }

        // Notes XML matching: ppt/notesSlides/notesSlide1.xml
        final notesMatch = RegExp(r'ppt/notesSlides/notesSlide(\d+)\.xml', caseSensitive: false).firstMatch(name);
        if (notesMatch != null) {
          final noteIndex = int.tryParse(notesMatch.group(1) ?? '1') ?? 1;
          final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
          final noteText = _extractTextFromPptxSlideXml(xmlStr);
          notesMap[noteIndex] = noteText;
        }
      }

      final sortedIndices = slideMap.keys.toList()..sort();
      final buffer = StringBuffer();

      for (final index in sortedIndices) {
        final slideContent = slideMap[index] ?? '';
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        buffer.writeln('📊 سڵایدی $index (Slide $index)');
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        if (slideContent.trim().isNotEmpty) {
          buffer.writeln(slideContent.trim());
        } else {
          buffer.writeln('[سڵایدی وێنەیی یان بێ دەق]');
        }

        final note = notesMap[index];
        if (note != null && note.trim().isNotEmpty) {
          buffer.writeln('\n📝 تێبینییەکانی پێشکەشکار (Speaker Notes):');
          buffer.writeln(note.trim());
        }
        buffer.writeln();
      }

      final fullText = buffer.toString().trim();
      final totalSlides = sortedIndices.isNotEmpty ? sortedIndices.length : 1;
      return (text: fullText, slideCount: totalSlides);
    } catch (_) {
      final fallback = _extractAsciiAndUtf16Strings(bytes);
      return (text: fallback.trim(), slideCount: 1);
    }
  }

  static String _extractTextFromPptxSlideXml(String xml) {
    final buffer = StringBuffer();
    // In PowerPoint OpenXML, text runs are in <a:p> (paragraphs) with <a:r><a:t>text</a:t></a:r>
    final paragraphRegex = RegExp(r'<a:p(?:\s+[^>]*)?>(.*?)</a:p>', dotAll: true);
    final textRegex = RegExp(r'<a:t(?:\s+[^>]*)?>(.*?)</a:t>', dotAll: true);

    final paragraphs = paragraphRegex.allMatches(xml);
    if (paragraphs.isNotEmpty) {
      for (final pMatch in paragraphs) {
        final pContent = pMatch.group(1) ?? '';
        final lineBuffer = StringBuffer();

        for (final tMatch in textRegex.allMatches(pContent)) {
          final text = tMatch.group(1) ?? '';
          lineBuffer.write(_decodeXmlEntities(text));
        }

        final line = lineBuffer.toString().trim();
        if (line.isNotEmpty) {
          buffer.writeln(line);
        }
      }
    } else {
      for (final tMatch in textRegex.allMatches(xml)) {
        final text = tMatch.group(1) ?? '';
        buffer.writeln(_decodeXmlEntities(text));
      }
    }

    return buffer.toString().trim();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Legacy PowerPoint Extractor (.ppt - PowerPoint 97-2003 binary)
  // ──────────────────────────────────────────────────────────────────────────
  static ({String text, int slideCount}) _extractTextFromPpt(Uint8List bytes) {
    final extracted = _extractAsciiAndUtf16Strings(bytes);
    final paragraphs = extracted.split('\n').where((p) => p.trim().isNotEmpty).toList();

    final buffer = StringBuffer();
    int currentSlide = 1;
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📊 سڵایدی $currentSlide (Slide $currentSlide)');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    int lineInSlide = 0;
    for (final p in paragraphs) {
      buffer.writeln(p);
      lineInSlide++;
      // Divide into slides every 6-8 distinct lines
      if (lineInSlide >= 7) {
        currentSlide++;
        lineInSlide = 0;
        buffer.writeln('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        buffer.writeln('📊 سڵایدی $currentSlide (Slide $currentSlide)');
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
    }

    return (text: buffer.toString().trim(), slideCount: currentSlide);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 6. Plain text / Markdown / CSV / JSON
  // ──────────────────────────────────────────────────────────────────────────
  static String _extractTextFromPlainBytes(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      try {
        return latin1.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Binary Heuristic Cleaner (Extracts Kurdish, Arabic, English text streams)
  // ──────────────────────────────────────────────────────────────────────────
  static String _extractAsciiAndUtf16Strings(Uint8List bytes) {
    final buffer = StringBuffer();

    // 1. Try UTF-16LE scanning (Standard for Microsoft Office OLE streams)
    final utf16Buffer = StringBuffer();
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);
      // Printable ASCII, Arabic/Kurdish (0x0600 - 0x06FF), Extended Arabic (0x0750-0x077F, 0x08A0-0x08FF)
      if ((codeUnit >= 32 && codeUnit <= 126) ||
          (codeUnit >= 0x0600 && codeUnit <= 0x06FF) ||
          (codeUnit >= 0x0750 && codeUnit <= 0x077F) ||
          (codeUnit >= 0xFB50 && codeUnit <= 0xFDFF) ||
          (codeUnit >= 0xFE70 && codeUnit <= 0xFEFF) ||
          codeUnit == 10 ||
          codeUnit == 13 ||
          codeUnit == 9) {
        utf16Buffer.writeCharCode(codeUnit);
      } else {
        if (utf16Buffer.length >= 6) {
          final str = utf16Buffer.toString().trim();
          if (_isMeaningfulText(str)) {
            buffer.writeln(str);
          }
        }
        utf16Buffer.clear();
      }
    }

    if (utf16Buffer.length >= 6) {
      final str = utf16Buffer.toString().trim();
      if (_isMeaningfulText(str)) {
        buffer.writeln(str);
      }
    }

    // 2. If UTF-16 didn't yield enough, scan for UTF-8 / ASCII chunks
    if (buffer.length < 50) {
      final asciiBuffer = StringBuffer();
      for (int i = 0; i < bytes.length; i++) {
        final byte = bytes[i];
        if ((byte >= 32 && byte <= 126) || byte == 10 || byte == 13 || byte == 9 || byte >= 128) {
          asciiBuffer.writeCharCode(byte);
        } else {
          if (asciiBuffer.length >= 6) {
            final str = asciiBuffer.toString().trim();
            if (_isMeaningfulText(str)) {
              buffer.writeln(str);
            }
          }
          asciiBuffer.clear();
        }
      }
      if (asciiBuffer.length >= 6) {
        final str = asciiBuffer.toString().trim();
        if (_isMeaningfulText(str)) {
          buffer.writeln(str);
        }
      }
    }

    return buffer.toString().trim();
  }

  static bool _isMeaningfulText(String str) {
    if (str.length < 3) return false;
    // Filter out common binary header keywords
    if (str.startsWith('Root Entry') ||
        str.startsWith('WordDocument') ||
        str.startsWith('SummaryInformation') ||
        str.startsWith('DocumentSummaryInformation') ||
        str.startsWith('CompObj') ||
        str.startsWith('Current User')) {
      return false;
    }
    // Must contain letters
    return RegExp(r'[\w\u0600-\u06FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(str);
  }

  static String _stripRtf(String rtf) {
    var text = rtf;
    // Remove headers and fonts definitions
    text = text.replaceAll(RegExp(r'\{\\\*?\\[^{}]+?\}'), '');
    // Replace newlines and paragraph marks
    text = text.replaceAll(RegExp(r'\\par\b|\\line\b'), '\n');
    text = text.replaceAll(RegExp(r'\\tab\b'), '\t');
    // Replace hex characters \'xx
    text = text.replaceAllMapped(RegExp(r"\\'([0-9a-fA-F]{2})"), (m) {
      final hex = m.group(1);
      if (hex != null) {
        final val = int.tryParse(hex, radix: 16);
        if (val != null) return String.fromCharCode(val);
      }
      return '';
    });
    // Remove all remaining control words
    text = text.replaceAll(RegExp(r'\\[a-zA-Z0-9\-]+ ?'), '');
    // Remove remaining braces
    text = text.replaceAll(RegExp(r'[{}]'), '');
    return text.trim();
  }

  static String _decodeXmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1) ?? '');
          return code != null ? String.fromCharCode(code) : '';
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final code = int.tryParse(m.group(1) ?? '', radix: 16);
          return code != null ? String.fromCharCode(code) : '';
        });
  }
}
