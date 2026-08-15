import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/kurdish_arabic_reshaper.dart';
import 'docx_generator_service.dart';

class ReportPdfGeneratorService {
  static List<int>? _cachedFontBytes;

  static Future<List<int>> _loadFontBytes() async {
    if (_cachedFontBytes != null && _cachedFontBytes!.isNotEmpty) {
      return _cachedFontBytes!;
    }
    try {
      final byteData = await rootBundle.load('assets/fonts/DroidKufi-Regular.ttf');
      _cachedFontBytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      return _cachedFontBytes!;
    } catch (_) {
      try {
        final file = File('assets/fonts/DroidKufi-Regular.ttf');
        if (file.existsSync()) {
          _cachedFontBytes = file.readAsBytesSync();
          return _cachedFontBytes!;
        }
      } catch (_) {}
    }
    return [];
  }

  /// Shapes and BiDi reorders text if language is Kurdish or Arabic
  static String _fixText(String text, bool isRtl) {
    if (!isRtl || text.trim().isEmpty) return text;
    return KurdishArabicReshaper.shapeAndReorder(text);
  }

  /// Wraps a long text into lines of maxChars and shapes each line
  static List<String> _wrapAndShapeLines(String text, int maxCharsPerLine, bool isRtl) {
    if (text.trim().isEmpty) return [];
    final rawLines = text.split('\n');
    final List<String> wrappedLines = [];

    for (var rawLine in rawLines) {
      final words = rawLine.trim().split(RegExp(r'\s+'));
      if (words.isEmpty || words.first.isEmpty) continue;

      final StringBuffer currentLine = StringBuffer();

      for (var word in words) {
        if (currentLine.length + word.length + 1 > maxCharsPerLine) {
          if (currentLine.isNotEmpty) {
            wrappedLines.add(_fixText(currentLine.toString().trim(), isRtl));
            currentLine.clear();
          }
        }
        if (currentLine.isNotEmpty) currentLine.write(' ');
        currentLine.write(word);
      }

      if (currentLine.isNotEmpty) {
        wrappedLines.add(_fixText(currentLine.toString().trim(), isRtl));
      }
    }

    return wrappedLines;
  }

  /// Generates a valid 12-page PDF document bytes from an AcademicReportModel
  static Future<List<int>> createPdfBytes(AcademicReportModel report) async {
    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 36;
    document.pageSettings.size = PdfPageSize.a4;

    final isRtl = report.languageCode != 'en';
    final fontBytes = await _loadFontBytes();

    // Fonts: Load DroidKufi TrueType font for Kurdish/Arabic Unicode support
    final PdfFont titleFont = fontBytes.isNotEmpty
        ? PdfTrueTypeFont(fontBytes, 16, style: PdfFontStyle.bold)
        : PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);

    final PdfFont headingFont = fontBytes.isNotEmpty
        ? PdfTrueTypeFont(fontBytes, 13, style: PdfFontStyle.bold)
        : PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);

    final PdfFont subHeadingFont = fontBytes.isNotEmpty
        ? PdfTrueTypeFont(fontBytes, 11, style: PdfFontStyle.bold)
        : PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);

    final PdfFont bodyFont = fontBytes.isNotEmpty
        ? PdfTrueTypeFont(fontBytes, 10)
        : PdfStandardFont(PdfFontFamily.helvetica, 10);

    final PdfFont smallFont = fontBytes.isNotEmpty
        ? PdfTrueTypeFont(fontBytes, 8)
        : PdfStandardFont(PdfFontFamily.helvetica, 8);

    final PdfBrush primaryBrush = PdfSolidBrush(PdfColor(14, 165, 233));
    final PdfBrush darkBrush = PdfSolidBrush(PdfColor(15, 23, 42));
    final PdfBrush textBrush = PdfSolidBrush(PdfColor(30, 41, 59));
    final PdfBrush grayBrush = PdfSolidBrush(PdfColor(100, 116, 139));
    final PdfBrush lightGrayBrush = PdfSolidBrush(PdfColor(148, 163, 184));

    for (int i = 0; i < report.pages.length; i++) {
      final pageModel = report.pages[i];
      final PdfPage page = document.pages.add();
      final PdfGraphics g = page.graphics;
      final Size pageSize = page.getClientSize();

      if (i == 0) {
        // ── PAGE 1: COVER PAGE ──
        // Outer decorative border
        g.drawRectangle(
          pen: PdfPen(PdfColor(14, 165, 233), width: 2),
          bounds: Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
        );
        g.drawRectangle(
          pen: PdfPen(PdfColor(226, 232, 240), width: 1),
          bounds: Rect.fromLTWH(6, 6, pageSize.width - 12, pageSize.height - 12),
        );

        // Top University Name (Shaped & Centered)
        final uniText = _fixText(report.universityName, isRtl);
        g.drawString(
          uniText,
          titleFont,
          brush: darkBrush,
          bounds: Rect.fromLTWH(20, 30, pageSize.width - 40, 26),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );

        // Department Name
        final deptText = _fixText(report.departmentName, isRtl);
        g.drawString(
          deptText,
          subHeadingFont,
          brush: grayBrush,
          bounds: Rect.fromLTWH(20, 60, pageSize.width - 40, 22),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );

        // University Logo or Emblem Badge
        if (report.logoBytes != null && report.logoBytes!.isNotEmpty) {
          try {
            final PdfBitmap logoBitmap = PdfBitmap(report.logoBytes!);
            g.drawImage(logoBitmap, Rect.fromLTWH(pageSize.width / 2 - 40, 95, 80, 80));
          } catch (_) {
            _drawEmblemPlaceholder(g, pageSize.width / 2 - 40, 95, 80, 80);
          }
        } else {
          _drawEmblemPlaceholder(g, pageSize.width / 2 - 40, 95, 80, 80);
        }

        // Horizontal Accent Line
        g.drawLine(
          PdfPen(PdfColor(14, 165, 233), width: 2),
          Offset(40, 195),
          Offset(pageSize.width - 40, 195),
        );

        // Main Report Title (Wrapped & Shaped)
        final titleLines = _wrapAndShapeLines(report.title, 45, isRtl);
        double titleY = 220;
        for (var tLine in titleLines) {
          g.drawString(
            tLine,
            titleFont,
            brush: darkBrush,
            bounds: Rect.fromLTWH(20, titleY, pageSize.width - 40, 26),
            format: PdfStringFormat(alignment: PdfTextAlignment.center),
          );
          titleY += 28;
        }

        // Subtitle
        final rawSubTitle = report.languageCode == 'en'
            ? 'Academic Research Paper & Thesis Report (12 Pages)'
            : (report.languageCode == 'ar' ? 'تقرير وبحث أكاديمي متكامل (١٢ صفحة)' : 'ڕاپۆرت و توێژینەوەی ئەکادیمیی وەرزی (١٢ پەڕە)');
        final subTitle = _fixText(rawSubTitle, isRtl);
        g.drawString(
          subTitle,
          subHeadingFont,
          brush: primaryBrush,
          bounds: Rect.fromLTWH(20, titleY + 10, pageSize.width - 40, 22),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );

        // Student Info Card
        final studentBoxY = 370.0;
        g.drawRectangle(
          brush: PdfSolidBrush(PdfColor(248, 250, 252)),
          pen: PdfPen(PdfColor(203, 213, 225), width: 1),
          bounds: Rect.fromLTWH(40, studentBoxY, pageSize.width - 80, 120),
        );

        final rawStudent = report.languageCode == 'en'
            ? 'Prepared by: ${report.studentName}'
            : (report.languageCode == 'ar' ? 'إعداد الطالب: ${report.studentName}' : 'ئامادەکردنی قوتابی: ${report.studentName}');
        final studentText = _fixText(rawStudent, isRtl);
        g.drawString(
          studentText,
          headingFont,
          brush: darkBrush,
          bounds: Rect.fromLTWH(60, studentBoxY + 20, pageSize.width - 120, 24),
          format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
        );

        final rawSupervisor = report.languageCode == 'en'
            ? 'Supervised by: ${report.supervisorName}'
            : (report.languageCode == 'ar' ? 'إشراف الأستاذ: ${report.supervisorName}' : 'سەرپەرشتیاری ئەکادیمی: ${report.supervisorName}');
        final supervisorText = _fixText(rawSupervisor, isRtl);
        g.drawString(
          supervisorText,
          subHeadingFont,
          brush: grayBrush,
          bounds: Rect.fromLTWH(60, studentBoxY + 52, pageSize.width - 120, 22),
          format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
        );

        final rawYear = 'Academic Year: ${report.academicYear}';
        final yearText = _fixText(rawYear, isRtl);
        g.drawString(
          yearText,
          bodyFont,
          brush: lightGrayBrush,
          bounds: Rect.fromLTWH(60, studentBoxY + 82, pageSize.width - 120, 20),
          format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
        );

      } else {
        // ── PAGES 2 to 12 ──
        // Top Header Bar
        g.drawLine(
          PdfPen(PdfColor(226, 232, 240), width: 1),
          Offset(0, 20),
          Offset(pageSize.width, 20),
        );

        final rawHeader = isRtl
            ? 'ZankoAI 🎓 | پەڕەی ${pageModel.pageNumber} لە ١٢'
            : 'ZankoAI 🎓 | Page ${pageModel.pageNumber} of 12';
        final headerText = _fixText(rawHeader, isRtl);
        g.drawString(
          headerText,
          smallFont,
          brush: lightGrayBrush,
          bounds: Rect.fromLTWH(0, 4, pageSize.width, 14),
          format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.left : PdfTextAlignment.right),
        );

        // Section Title (Heading 1)
        final rawTitle = '${pageModel.pageNumber}. ${pageModel.pageTitle}';
        final titleText = _fixText(rawTitle, isRtl);
        g.drawString(
          titleText,
          headingFont,
          brush: primaryBrush,
          bounds: Rect.fromLTWH(0, 32, pageSize.width, 26),
          format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
        );

        g.drawLine(
          PdfPen(PdfColor(14, 165, 233), width: 1.5),
          Offset(isRtl ? pageSize.width - 140 : 0, 60),
          Offset(isRtl ? pageSize.width : 140, 60),
        );

        // Body Content (Line by Line with Shaping)
        double currentY = 75;

        if (pageModel.content.isNotEmpty) {
          final contentLines = _wrapAndShapeLines(pageModel.content, 65, isRtl);
          for (var line in contentLines) {
            if (currentY + 20 > pageSize.height - 40) break;
            g.drawString(
              line,
              bodyFont,
              brush: textBrush,
              bounds: Rect.fromLTWH(0, currentY, pageSize.width, 18),
              format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
            );
            currentY += 20;
          }
          currentY += 10;
        }

        // Bullet Points (Line by Line with Shaping & Bullet Icon)
        for (var bullet in pageModel.bulletPoints) {
          if (currentY + 24 > pageSize.height - 40) break;

          final bulletLines = _wrapAndShapeLines(bullet, 60, isRtl);
          for (int bIdx = 0; bIdx < bulletLines.length; bIdx++) {
            if (currentY + 20 > pageSize.height - 40) break;

            if (bIdx == 0) {
              // Draw bullet indicator dot
              final dotX = isRtl ? pageSize.width - 6 : 0.0;
              g.drawRectangle(
                brush: primaryBrush,
                bounds: Rect.fromLTWH(dotX, currentY + 4, 5, 5),
              );
            }

            final textX = isRtl ? 0.0 : 14.0;
            final textW = pageSize.width - 16;
            g.drawString(
              bulletLines[bIdx],
              bodyFont,
              brush: textBrush,
              bounds: Rect.fromLTWH(textX, currentY, textW, 18),
              format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
            );
            currentY += 20;
          }
          currentY += 6;
        }

        // Footer
        g.drawLine(
          PdfPen(PdfColor(226, 232, 240), width: 1),
          Offset(0, pageSize.height - 20),
          Offset(pageSize.width, pageSize.height - 20),
        );

        final footerTitle = _fixText(report.title, isRtl);
        g.drawString(
          footerTitle,
          smallFont,
          brush: lightGrayBrush,
          bounds: Rect.fromLTWH(0, pageSize.height - 15, pageSize.width, 14),
          format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
        );
      }
    }

    final List<int> bytes = await document.save();
    document.dispose();
    return bytes;
  }

  static void _drawEmblemPlaceholder(PdfGraphics g, double x, double y, double w, double h) {
    g.drawRectangle(
      brush: PdfSolidBrush(PdfColor(240, 249, 255)),
      pen: PdfPen(PdfColor(14, 165, 233), width: 1.5),
      bounds: Rect.fromLTWH(x, y, w, h),
    );
  }

  /// Exports PDF bytes to a temporary file and triggers the system Share / Open With sheet
  static Future<void> exportAndSharePdf(AcademicReportModel report) async {
    final bytes = await createPdfBytes(report);
    final tempDir = await getTemporaryDirectory();
    final cleanFileName = report.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_')
        .trim();
    final fileName = '${cleanFileName.isEmpty ? 'Academic_Report' : cleanFileName}.pdf';
    final filePath = '${tempDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/pdf')],
      subject: report.title,
      text: 'فایلی PDF بۆ ڕاپۆرتی: ${report.title}',
    );
  }
}
