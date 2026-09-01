import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/kurdish_arabic_reshaper.dart';
import 'docx_generator_service.dart';

class ReportPdfGeneratorService {
  static List<int>? _cachedNotoRegular;
  static List<int>? _cachedNotoBold;
  static List<int>? _cachedTimesRegular;
  static List<int>? _cachedTimesBold;

  static Future<List<int>> _loadFontFromPaths(List<String> paths) async {
    for (var path in paths) {
      try {
        final byteData = await rootBundle.load(path);
        final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            if (bytes.isNotEmpty) return bytes;
          }
        } catch (_) {}
      }
    }
    return [];
  }

  static Future<void> _initFonts() async {
    if (_cachedNotoRegular == null || _cachedNotoRegular!.isEmpty) {
      _cachedNotoRegular = await _loadFontFromPaths([
        'assets/fonts/NotoNaskhArabic-Regular.ttf',
        'assets/fonts/NotoSansArabic-Regular.ttf',
        'assets/fonts/DroidKufi-Regular.ttf',
        'assets/fonts/calibri.ttf',
        'C:/Windows/Fonts/calibri.ttf',
        'assets/fonts/arial.ttf',
        'C:/Windows/Fonts/arial.ttf',
      ]);
    }
    if (_cachedNotoBold == null || _cachedNotoBold!.isEmpty) {
      _cachedNotoBold = await _loadFontFromPaths([
        'assets/fonts/NotoNaskhArabic-Bold.ttf',
        'assets/fonts/NotoSansArabic-Bold.ttf',
        'assets/fonts/calibrib.ttf',
        'C:/Windows/Fonts/calibrib.ttf',
        'assets/fonts/arialbd.ttf',
        'C:/Windows/Fonts/arialbd.ttf',
      ]);
    }
    if (_cachedTimesRegular == null || _cachedTimesRegular!.isEmpty) {
      _cachedTimesRegular = await _loadFontFromPaths([
        'assets/fonts/times.ttf',
        'C:/Windows/Fonts/times.ttf',
        'assets/fonts/calibri.ttf',
      ]);
    }
    if (_cachedTimesBold == null || _cachedTimesBold!.isEmpty) {
      _cachedTimesBold = await _loadFontFromPaths([
        'assets/fonts/timesbd.ttf',
        'C:/Windows/Fonts/timesbd.ttf',
        'assets/fonts/calibrib.ttf',
      ]);
    }
  }

  static PdfStringFormat _fmt(PdfTextAlignment alignment, bool isRtl) {
    return PdfStringFormat(
      alignment: alignment,
    );
  }

  /// Shapes and reorders Kurdish/Arabic characters cleanly for TrueType font rendering
  static String _fixText(String text, bool isRtl) {
    if (!isRtl || text.trim().isEmpty) return text;
    return KurdishArabicReshaper.shapeAndReorder(text);
  }

  /// Dynamically wraps RTL/LTR text based on font metrics with a safety buffer
  static List<String> _wrapRtlTextDynamic(String text, PdfFont font, double maxWidth, bool isRtl) {
    if (text.trim().isEmpty) return [];
    final rawLines = text.split('\n');
    final List<String> result = [];

    // Safe width with 16pt buffer to guarantee no clipping or unwanted wrapping
    final double safeWidth = maxWidth - 16;

    for (var rawLine in rawLines) {
      final words = rawLine.trim().split(RegExp(r'\s+'));
      if (words.isEmpty || words.first.isEmpty) continue;

      final StringBuffer currentLine = StringBuffer();
      for (var word in words) {
        final testLine = currentLine.isEmpty ? word : '${currentLine.toString()} $word';
        final measuredWidth = font.measureString(_fixText(testLine, isRtl)).width;

        if (measuredWidth > safeWidth && currentLine.isNotEmpty) {
          result.add(_fixText(currentLine.toString().trim(), isRtl));
          currentLine.clear();
          currentLine.write(word);
        } else {
          if (currentLine.isNotEmpty) currentLine.write(' ');
          currentLine.write(word);
        }
      }
      if (currentLine.isNotEmpty) {
        result.add(_fixText(currentLine.toString().trim(), isRtl));
      }
    }
    return result;
  }

  /// Generates a pristine 8-page academic PDF document bytes
  static Future<List<int>> createPdfBytes(AcademicReportModel report) async {
    _cachedNotoRegular = null;
    _cachedNotoBold = null;
    _cachedTimesRegular = null;
    await _initFonts();

    // ── Pre-fetch images asynchronously for content pages ──
    final Map<int, Uint8List> fetchedImages = {};
    for (int i = 0; i < report.pages.length; i++) {
      final page = report.pages[i];
      if (page.imageBytes != null && page.imageBytes!.isNotEmpty) {
        fetchedImages[i] = page.imageBytes!;
      } else if (page.imageUrl != null && page.imageUrl!.isNotEmpty) {
        try {
          final bytes = await DocxGeneratorService.fetchImageBytes(page.imageUrl!);
          if (bytes != null && bytes.isNotEmpty) {
            fetchedImages[i] = bytes;
          }
        } catch (_) {}
      }
    }

    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 40;
    document.pageSettings.size = PdfPageSize.a4;

    final isRtl = report.languageCode != 'en';
    final regularFontBytes = isRtl ? _cachedNotoRegular : _cachedTimesRegular;
    final boldFontBytes = isRtl ? _cachedNotoBold : _cachedTimesBold;

    // Academic Typography
    final PdfFont bigTitleFont = (boldFontBytes != null && boldFontBytes.isNotEmpty)
        ? PdfTrueTypeFont(boldFontBytes, isRtl ? 22 : 24, style: PdfFontStyle.bold)
        : PdfStandardFont(PdfFontFamily.timesRoman, isRtl ? 22 : 24, style: PdfFontStyle.bold);

    final PdfFont sectionTitleFont = (boldFontBytes != null && boldFontBytes.isNotEmpty)
        ? PdfTrueTypeFont(boldFontBytes, 20, style: PdfFontStyle.bold)
        : PdfStandardFont(PdfFontFamily.timesRoman, 20, style: PdfFontStyle.bold);

    final PdfFont midTitleFont = (boldFontBytes != null && boldFontBytes.isNotEmpty)
        ? PdfTrueTypeFont(boldFontBytes, 18, style: PdfFontStyle.bold)
        : PdfStandardFont(PdfFontFamily.timesRoman, 18, style: PdfFontStyle.bold);

    final PdfFont boldBodyFont = (boldFontBytes != null && boldFontBytes.isNotEmpty)
        ? PdfTrueTypeFont(boldFontBytes, 14, style: PdfFontStyle.bold)
        : PdfStandardFont(PdfFontFamily.timesRoman, 14, style: PdfFontStyle.bold);

    final PdfFont bodyFont = (regularFontBytes != null && regularFontBytes.isNotEmpty)
        ? PdfTrueTypeFont(regularFontBytes, 14)
        : PdfStandardFont(PdfFontFamily.timesRoman, 14);

    final PdfFont smallMutedFont = (regularFontBytes != null && regularFontBytes.isNotEmpty)
        ? PdfTrueTypeFont(regularFontBytes, 12)
        : PdfStandardFont(PdfFontFamily.timesRoman, 12);

    // Academic Color Palette
    final PdfBrush primaryNavy = PdfSolidBrush(PdfColor(15, 23, 42));     // #0F172A
    final PdfBrush academicMaroon = PdfSolidBrush(PdfColor(136, 19, 55)); // #881337
    final PdfBrush bodyBrush = PdfSolidBrush(PdfColor(0, 0, 0));          // #000000 Solid Black
    final PdfBrush mutedBrush = PdfSolidBrush(PdfColor(71, 85, 105));     // #475569
    final PdfBrush solidBlack = PdfSolidBrush(PdfColor(0, 0, 0));         // #000000 Solid Black
    final PdfPen subtleBorder = PdfPen(PdfColor(226, 232, 240), width: 0.8);

    final cleanMainTitle = DocxGeneratorService.cleanTopicTitle(report.title);

    for (int pIndex = 0; pIndex < report.pages.length; pIndex++) {
      final pageModel = report.pages[pIndex];
      final PdfPage page = document.pages.add();
      final PdfGraphics g = page.graphics;
      final Size pageSize = page.getClientSize();

      // ── RUNNING FOOTER ONLY (PAGES 2 TO 8) ──
      // Requirement 6: No header at all, in footer only page numbers
      if (pIndex > 0) {
        final double footerY = pageSize.height - 18;
        final pageNumKurdish = (pIndex + 1).toString().replaceAll('1', '١').replaceAll('2', '٢').replaceAll('3', '٣').replaceAll('4', '٤').replaceAll('5', '٥').replaceAll('6', '٦').replaceAll('7', '٧').replaceAll('8', '٨');
        final pageNumText = isRtl ? pageNumKurdish : '${pIndex + 1}';

        g.drawString(
          _fixText(pageNumText, isRtl),
          smallMutedFont,
          brush: solidBlack,
          bounds: Rect.fromLTWH(0, footerY, pageSize.width, 16),
          format: _fmt(PdfTextAlignment.center, isRtl),
        );
      }

      // ── PAGE 1: OFFICIAL ACADEMIC COVER PAGE ──────────────────────────────
      if (pageModel.pageType == 'cover') {
        final ministryLine1 = report.languageCode == 'en'
            ? 'Kurdistan Regional Government - Iraq'
            : (report.languageCode == 'ar'
                ? 'حكومة إقليم كوردستان - العراق'
                : (report.languageCode == 'badini'
                    ? 'حکومەتا هەرێما کوردستانێ - عیراق'
                    : 'حکومەتی هەرێمی کوردستان - عێراق'));
        final ministryLine2 = report.languageCode == 'en'
            ? 'Ministry of Higher Education & Scientific Research'
            : (report.languageCode == 'ar'
                ? 'وزارة التعليم العالي والبحث العلمي'
                : (report.languageCode == 'badini'
                    ? 'وەزارەتا خوێندنا باڵا و ڤەکۆلینێن زانستی'
                    : 'وەزارەتی خوێندنی باڵا و توێژینەوەی زانستی'));

        final preparedLabel = report.languageCode == 'en'
            ? 'Prepared by:'
            : (report.languageCode == 'ar'
                ? 'إعداد الطالب:'
                : (report.languageCode == 'badini'
                    ? 'ئامادەکرن ژ لایێ قوتابی:'
                    : 'ئامادەکردنی خوێندکار:'));

        final supervisorLabel = report.languageCode == 'en'
            ? 'Supervised by:'
            : (report.languageCode == 'ar'
                ? 'بإشراف الأستاذ:'
                : (report.languageCode == 'badini'
                    ? 'ب سەرپەرشتیا مامۆستای:'
                    : 'بەسەرپەرشتیی مامۆستا:'));

        final stageLabel = report.languageCode == 'en'
            ? 'Academic Year:'
            : (report.languageCode == 'ar'
                ? 'العام الدراسي:'
                : (report.languageCode == 'badini'
                    ? 'ساڵا خوێندنا ئەکادیمی:'
                    : 'ساڵی خوێندنی ئەکادیمی:'));

        // ── 1. Official University Header (سەردێڕی فەرمی زانکۆ) ──
        final double logoSize = 64;
        final double logoX = (pageSize.width - logoSize) / 2;
        double headerY = 30;

        if (report.logoBytes != null && report.logoBytes!.isNotEmpty) {
          try {
            final PdfBitmap logoBitmap = PdfBitmap(report.logoBytes!);
            g.drawImage(logoBitmap, Rect.fromLTWH(logoX, headerY, logoSize, logoSize));
          } catch (_) {
            _drawOfficialEmblem(g, logoX, headerY, logoSize, logoSize);
          }
        } else {
          _drawOfficialEmblem(g, logoX, headerY, logoSize, logoSize);
        }

        headerY += logoSize + 14;

        // Ministry Line 1
        g.drawString(
          _fixText(ministryLine1, isRtl),
          boldBodyFont,
          brush: solidBlack,
          bounds: Rect.fromLTWH(20, headerY, pageSize.width - 40, 18),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        headerY += 18;

        // Ministry Line 2
        g.drawString(
          _fixText(ministryLine2, isRtl),
          boldBodyFont,
          brush: solidBlack,
          bounds: Rect.fromLTWH(20, headerY, pageSize.width - 40, 18),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        headerY += 20;

        // University Name (Bold & Large Solid Black)
        g.drawString(
          _fixText(report.universityName, isRtl),
          sectionTitleFont,
          brush: solidBlack,
          bounds: Rect.fromLTWH(20, headerY, pageSize.width - 40, 24),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        headerY += 24;

        // Department Name (Bold Solid Black)
        if (report.departmentName.isNotEmpty) {
          g.drawString(
            _fixText(report.departmentName, isRtl),
            boldBodyFont,
            brush: solidBlack,
            bounds: Rect.fromLTWH(20, headerY, pageSize.width - 40, 18),
            format: PdfStringFormat(alignment: PdfTextAlignment.center),
          );
          headerY += 22;
        }

        // Header Divider Line
        headerY += 6;
        final double divW = pageSize.width - 120;
        final double divX = 60;
        g.drawLine(PdfPen(PdfColor(15, 23, 42), width: 1.2), Offset(divX, headerY), Offset(divX + divW, headerY));

        // ── 2. Main Report Title (ناونیشانی سەرەکی ڕاپۆرت - ڕاستەوخۆ بە قەبارەی گەورە و تۆخ) ──
        double titleCardY = headerY + 45;
        final titleLines = _wrapRtlTextDynamic(cleanMainTitle, bigTitleFont, pageSize.width - 40, isRtl);

        for (var tLine in titleLines) {
          g.drawString(
            tLine,
            bigTitleFont,
            brush: solidBlack,
            bounds: Rect.fromLTWH(20, titleCardY, pageSize.width - 40, 30),
            format: PdfStringFormat(alignment: PdfTextAlignment.center),
          );
          titleCardY += 32;
        }

        // ── 3. Prepared by & Supervisor (زانیاریی قوتابی و سەرپەرشتیار لە خوارترەوە) ──
        final double infoY = pageSize.height - 180;
        final double colWidth = (pageSize.width - 60) / 2;
        final double colRightX = isRtl ? (pageSize.width / 2) + 10 : 30;
        final double colLeftX = isRtl ? 30 : (pageSize.width / 2) + 10;

        // Right Box: Prepared by (ئامادەکردنی خوێندکار)
        double cRightY = infoY;
        g.drawString(
          _fixText(preparedLabel, isRtl),
          boldBodyFont,
          brush: solidBlack,
          bounds: Rect.fromLTWH(colRightX, cRightY, colWidth, 18),
          format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
        );
        cRightY += 20;

        final studentList = report.studentName
            .split(RegExp(r'[\n\r,?]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        for (var st in studentList) {
          g.drawString(
            _fixText(st, isRtl),
            boldBodyFont,
            brush: solidBlack,
            bounds: Rect.fromLTWH(colRightX, cRightY, colWidth, 18),
            format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
          );
          cRightY += 18;
        }

        // Left Box: Supervised by (بەسەرپەرشتیی مامۆستا)
        double cLeftY = infoY;
        g.drawString(
          _fixText(supervisorLabel, isRtl),
          boldBodyFont,
          brush: solidBlack,
          bounds: Rect.fromLTWH(colLeftX, cLeftY, colWidth, 18),
          format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
        );
        cLeftY += 20;

        g.drawString(
          _fixText(report.supervisorName, isRtl),
          boldBodyFont,
          brush: solidBlack,
          bounds: Rect.fromLTWH(colLeftX, cLeftY, colWidth, 18),
          format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
        );

        // ── 4. Academic Year at Bottom (ساڵی خوێندن) ──
        final double bottomY = pageSize.height - 35;
        final yearDisplay = report.academicYear.isNotEmpty ? report.academicYear : '2025 - 2026';
        final yearText = isRtl ? '$stageLabel $yearDisplay' : 'Academic Year: $yearDisplay';

        g.drawString(
          _fixText(yearText, isRtl),
          boldBodyFont,
          brush: solidBlack,
          bounds: Rect.fromLTWH(20, bottomY, pageSize.width - 40, 20),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
      } else if (pageModel.pageType == 'toc') {
        // ── PAGE 2: TABLE OF CONTENTS (پێڕستی ناوەڕۆک) ──
        double currY = 40;

        // Title Badge
        g.drawString(
          _fixText(pageModel.pageTitle, isRtl),
          midTitleFont,
          brush: academicMaroon,
          bounds: Rect.fromLTWH(0, currY, pageSize.width, 24),
          format: _fmt(PdfTextAlignment.center, isRtl),
        );
        currY += 26;

        // Accent Underline
        final double barW = 80;
        g.drawRectangle(
          brush: academicMaroon,
          bounds: Rect.fromLTWH((pageSize.width - barW) / 2, currY, barW, 2),
        );
        currY += 28;

        // List of 10 Sections + References with Dotted Leader Lines
        final bullets = pageModel.bulletPoints;
        for (int bIdx = 0; bIdx < bullets.length; bIdx++) {
          final item = bullets[bIdx];
          final cleanItem = item.startsWith(RegExp(r'^\d+\.')) ? item : '${bIdx + 1}. $item';

          // Target Page calculation: Content pages start at Page 3 (2 sections per page)
          final targetPageNum = bIdx < 10 ? (3 + (bIdx ~/ 2)) : 8;
          final pageStr = isRtl
              ? targetPageNum.toString().replaceAll('3', '٣').replaceAll('4', '٤').replaceAll('5', '٥').replaceAll('6', '٦').replaceAll('7', '٧').replaceAll('8', '٨')
              : targetPageNum.toString();

          final double itemH = 25;

          // Shaded row background on alternate items
          if (bIdx % 2 == 0) {
            g.drawRectangle(
              brush: PdfSolidBrush(PdfColor(248, 250, 252)),
              bounds: Rect.fromLTWH(0, currY - 2, pageSize.width, itemH),
            );
          }

          if (isRtl) {
            // Page Number Badge on Left
            g.drawRectangle(
              brush: PdfSolidBrush(PdfColor(241, 245, 249)),
              pen: subtleBorder,
              bounds: Rect.fromLTWH(5, currY, 28, 19),
            );
            g.drawString(
              pageStr,
              boldBodyFont,
              brush: academicMaroon,
              bounds: Rect.fromLTWH(5, currY + 2, 28, 15),
              format: _fmt(PdfTextAlignment.center, isRtl),
            );

            // Title on Right
            final shapedTitle = _fixText(cleanItem, true);
            g.drawString(
              shapedTitle,
              boldBodyFont,
              brush: primaryNavy,
              bounds: Rect.fromLTWH(40, currY + 2, pageSize.width - 45, 18),
              format: _fmt(PdfTextAlignment.right, isRtl),
            );

            // Dotted Leader line
            final titleWidth = boldBodyFont.measureString(shapedTitle).width;
            final double dotStartX = 42;
            final double dotEndX = pageSize.width - titleWidth - 55;
            if (dotEndX > dotStartX + 30) {
              g.drawString(
                '. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .',
                smallMutedFont,
                brush: mutedBrush,
                bounds: Rect.fromLTWH(dotStartX, currY + 2, dotEndX - dotStartX, 15),
                format: _fmt(PdfTextAlignment.center, isRtl),
              );
            }
          } else {
            // Title on Left
            g.drawString(
              cleanItem,
              boldBodyFont,
              brush: primaryNavy,
              bounds: Rect.fromLTWH(5, currY + 2, pageSize.width - 45, 18),
              format: _fmt(PdfTextAlignment.left, isRtl),
            );

            // Page Number Badge on Right
            g.drawRectangle(
              brush: PdfSolidBrush(PdfColor(241, 245, 249)),
              pen: subtleBorder,
              bounds: Rect.fromLTWH(pageSize.width - 35, currY, 28, 19),
            );
            g.drawString(
              pageStr,
              boldBodyFont,
              brush: academicMaroon,
              bounds: Rect.fromLTWH(pageSize.width - 35, currY + 2, 28, 15),
              format: _fmt(PdfTextAlignment.center, isRtl),
            );

            // Dotted Leader line
            final titleWidth = boldBodyFont.measureString(cleanItem).width;
            final double dotStartX = titleWidth + 15;
            final double dotEndX = pageSize.width - 45;
            if (dotEndX > dotStartX + 30) {
              g.drawString(
                '. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .',
                smallMutedFont,
                brush: mutedBrush,
                bounds: Rect.fromLTWH(dotStartX, currY + 2, dotEndX - dotStartX, 15),
                format: _fmt(PdfTextAlignment.center, isRtl),
              );
            }
          }

          currY += itemH;
        }

      } else if (pageModel.pageType == 'references') {
        // ── PAGE 8: REFERENCES (سەرچاوە زانستییەکان) ──
        double currY = 40;

        // Title Badge
        g.drawString(
          _fixText(pageModel.pageTitle, isRtl),
          midTitleFont,
          brush: academicMaroon,
          bounds: Rect.fromLTWH(0, currY, pageSize.width, 24),
          format: _fmt(PdfTextAlignment.center, isRtl),
        );
        currY += 26;

        // Accent Underline
        final double barW = 80;
        g.drawRectangle(
          brush: academicMaroon,
          bounds: Rect.fromLTWH((pageSize.width - barW) / 2, currY, barW, 2),
        );
        currY += 28;

        // Render APA Citations
        for (int rIdx = 0; rIdx < pageModel.bulletPoints.length; rIdx++) {
          final ref = pageModel.bulletPoints[rIdx];
          final refNum = '[${rIdx + 1}]';

          final wrappedLines = _wrapRtlTextDynamic(ref, bodyFont, pageSize.width - 44, isRtl);
          final double blockH = (wrappedLines.length * 15.5) + 14;

          // Reference Item Card
          g.drawRectangle(
            brush: PdfSolidBrush(PdfColor(248, 250, 252)),
            pen: subtleBorder,
            bounds: Rect.fromLTWH(0, currY, pageSize.width, blockH),
          );

          // Number Badge
          final double badgeX = isRtl ? pageSize.width - 30 : 6;
          g.drawString(
            refNum,
            boldBodyFont,
            brush: academicMaroon,
            bounds: Rect.fromLTWH(badgeX, currY + 6, 24, 16),
            format: _fmt(isRtl ? PdfTextAlignment.right : PdfTextAlignment.left, isRtl),
          );

          // Citation Text
          final double textX = isRtl ? 10 : 34;
          final double textW = pageSize.width - 44;
          double lineY = currY + 6;

          for (var line in wrappedLines) {
            g.drawString(
              line,
              bodyFont,
              brush: bodyBrush,
              bounds: Rect.fromLTWH(textX, lineY, textW, 16),
              format: _fmt(isRtl ? PdfTextAlignment.right : PdfTextAlignment.left, isRtl),
            );
            lineY += 15.5;
          }

          currY += blockH + 8;
        }

      } else {
        // ── PAGES 3 TO 7: CONTENT PAGES (2 SECTIONS + SCIENTIFIC FIGURE) ──
        final sections = pageModel.sections;
        double currentY = 32;

        for (int sIdx = 0; sIdx < sections.length && sIdx < 2; sIdx++) {
          final sec = sections[sIdx];

          // 1. Section Header Badge (Size 20 Bold)
          final secHeader = '${sec.sectionNumber}. ${sec.title}';
          final double headerBoxH = 28;

          g.drawRectangle(
            brush: PdfSolidBrush(PdfColor(241, 245, 249)),
            pen: subtleBorder,
            bounds: Rect.fromLTWH(0, currentY, pageSize.width, headerBoxH),
          );

          // Left/Right Accent Indicator Bar
          final double indX = isRtl ? pageSize.width - 4 : 0;
          g.drawRectangle(
            brush: academicMaroon,
            bounds: Rect.fromLTWH(indX, currentY, 4, headerBoxH),
          );

          g.drawString(
            _fixText(secHeader, isRtl),
            sectionTitleFont,
            brush: solidBlack,
            bounds: Rect.fromLTWH(10, currentY + 2.0, pageSize.width - 20, 24),
            format: _fmt(isRtl ? PdfTextAlignment.right : PdfTextAlignment.left, isRtl),
          );
          currentY += headerBoxH + 10;

          // 2. Section Paragraphs (Size 14 Regular)
          final paragraphs = sec.content.split('\n');
          for (var p in paragraphs) {
            final trimmedP = p.trim();
            if (trimmedP.isEmpty) continue;

            final wrappedLines = _wrapRtlTextDynamic(trimmedP, bodyFont, pageSize.width - 24, isRtl);
            for (var line in wrappedLines) {
              g.drawString(
                line,
                bodyFont,
                brush: bodyBrush,
                bounds: Rect.fromLTWH(6, currentY, pageSize.width - 12, 19),
                format: _fmt(isRtl ? PdfTextAlignment.right : PdfTextAlignment.left, isRtl),
              );
              currentY += 19.5;
            }
            currentY += 6; // Paragraph gap
          }

          // 3. Section Bullet Points (Size 14)
          for (var bullet in sec.bulletPoints) {
            final bulletWrapped = _wrapRtlTextDynamic(bullet, bodyFont, pageSize.width - 32, isRtl);

            // Draw bullet dot
            final double bulletX = isRtl ? pageSize.width - 14 : 6;
            g.drawString(
              '•',
              boldBodyFont,
              brush: solidBlack,
              bounds: Rect.fromLTWH(bulletX, currentY, 12, 19),
              format: _fmt(isRtl ? PdfTextAlignment.right : PdfTextAlignment.left, isRtl),
            );

            final double bTextX = isRtl ? 4 : 20;
            for (var bLine in bulletWrapped) {
              g.drawString(
                bLine,
                bodyFont,
                brush: bodyBrush,
                bounds: Rect.fromLTWH(bTextX, currentY, pageSize.width - 26, 19),
                format: _fmt(isRtl ? PdfTextAlignment.right : PdfTextAlignment.left, isRtl),
              );
              currentY += 19.5;
            }
            currentY += 3;
          }

          currentY += 10; // Gap between sections
        }

        // 4. SCIENTIFIC FIGURE / DIAGRAM CARD (Fills the lower half of the page)
        final double figTopY = currentY + 6;
        final double maxBottomY = pageSize.height - 26;
        final double availFigH = maxBottomY - figTopY;

        if (availFigH >= 110) {
          final double figW = pageSize.width;
          final double figH = availFigH.clamp(130.0, 310.0);
          final double captionHeight = 22;
          final double imgAreaH = figH - captionHeight;

          // Outer Card Frame
          g.drawRectangle(
            brush: PdfSolidBrush(PdfColor(255, 255, 255)),
            pen: subtleBorder,
            bounds: Rect.fromLTWH(0, figTopY, figW, figH),
          );

          // Draw Image / Illustration
          final pageImgBytes = fetchedImages[pIndex];
          if (pageImgBytes != null && pageImgBytes.isNotEmpty) {
            try {
              final PdfBitmap bitmap = PdfBitmap(pageImgBytes);
              g.drawImage(
                bitmap,
                Rect.fromLTWH(2, figTopY + 2, figW - 4, imgAreaH - 4),
              );
            } catch (_) {
              _drawAcademicFallbackVector(g, 0, figTopY, figW, imgAreaH, isRtl, pageModel, boldBodyFont, smallMutedFont, academicMaroon, primaryNavy, subtleBorder);
            }
          } else {
            _drawAcademicFallbackVector(g, 0, figTopY, figW, imgAreaH, isRtl, pageModel, boldBodyFont, smallMutedFont, academicMaroon, primaryNavy, subtleBorder);
          }

          // Caption Banner at the bottom of the card
          g.drawRectangle(
            brush: PdfSolidBrush(PdfColor(248, 250, 252)),
            pen: subtleBorder,
            bounds: Rect.fromLTWH(0, figTopY + imgAreaH, figW, captionHeight),
          );

          final figureNum = pIndex - 1;
          final figNumKurdish = figureNum.toString().replaceAll('1', '١').replaceAll('2', '٢').replaceAll('3', '٣').replaceAll('4', '٤').replaceAll('5', '٥');
          final firstSecTitle = sections.isNotEmpty ? sections.first.title : cleanMainTitle;

          final captionText = isRtl
              ? (report.languageCode == 'ar' ? 'الشكل العلمي ($figNumKurdish): شیکاریی پڕۆسەی $firstSecTitle' : 'شێوەی زانستی ($figNumKurdish): شیکاری و دایەگرامی $firstSecTitle')
              : 'Figure ($figureNum): Architectural and operational workflow of $firstSecTitle';

          g.drawString(
            _fixText(captionText, isRtl),
            boldBodyFont,
            brush: academicMaroon,
            bounds: Rect.fromLTWH(8, figTopY + imgAreaH + 4, figW - 16, 16),
            format: PdfStringFormat(alignment: PdfTextAlignment.center),
          );
        }
      }
    }

    final List<int> bytes = await document.save();
    document.dispose();
    return bytes;
  }

  /// Draws official university emblem on Cover page
  static void _drawOfficialEmblem(PdfGraphics g, double x, double y, double w, double h) {
    // Circle background
    g.drawEllipse(
      Rect.fromLTWH(x, y, w, h),
      brush: PdfSolidBrush(PdfColor(241, 245, 249)),
      pen: PdfPen(PdfColor(15, 23, 42), width: 1.5),
    );
    // Inner accent ring
    g.drawEllipse(
      Rect.fromLTWH(x + 4, y + 4, w - 8, h - 8),
      pen: PdfPen(PdfColor(15, 23, 42), width: 0.8),
    );
    // Center Academic Icon representation
    final PdfFont capFont = PdfStandardFont(PdfFontFamily.timesRoman, 18, style: PdfFontStyle.bold);
    g.drawString(
      'Z',
      capFont,
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
      bounds: Rect.fromLTWH(x, y + (h * 0.28), w, 24),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
  }

  /// Draws a high-grade academic vector matrix when offline
  static void _drawAcademicFallbackVector(
    PdfGraphics g,
    double x,
    double y,
    double w,
    double h,
    bool isRtl,
    ReportPageModel page,
    PdfFont boldFont,
    PdfFont smallFont,
    PdfBrush maroon,
    PdfBrush navy,
    PdfPen border,
  ) {
    g.drawRectangle(
      brush: PdfSolidBrush(PdfColor(248, 250, 252)),
      bounds: Rect.fromLTWH(x, y, w, h),
    );

    final title = isRtl ? 'هەنگاوەکانی کارکردن و پێکهاتەی پەیوەستکراو' : 'Operational Workflow & Architecture';
    g.drawString(
      _fixText(title, isRtl),
      boldFont,
      brush: maroon,
      bounds: Rect.fromLTWH(x + 10, y + 10, w - 20, 16),
      format: PdfStringFormat(alignment: isRtl ? PdfTextAlignment.right : PdfTextAlignment.left),
    );

    // 3 Workflow Steps Boxes
    final double boxW = (w - 40) / 3;
    final double boxH = (h - 50).clamp(40.0, 90.0);
    final double boxY = y + 32;

    final steps = isRtl
        ? ['١. وەرگرتن و پشکنین', '٢. پڕۆسێسکردنی سەرەکی', '٣. بەرهەم و دەرئەنجام']
        : ['1. Ingestion & Validation', '2. Core Processing', '3. Synthesis & Output'];

    for (int i = 0; i < 3; i++) {
      final idx = isRtl ? (2 - i) : i;
      final bx = x + 10 + (i * (boxW + 10));

      g.drawRectangle(
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        pen: border,
        bounds: Rect.fromLTWH(bx, boxY, boxW, boxH),
      );

      g.drawString(
        _fixText(steps[idx], isRtl),
        boldFont,
        brush: navy,
        bounds: Rect.fromLTWH(bx + 4, boxY + (boxH * 0.35), boxW - 8, 16),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }
  }

  /// Exports PDF bytes to temporary/download file and triggers system Share sheet or opens on Windows
  static Future<void> exportAndSharePdf(AcademicReportModel report) async {
    final bytes = await createPdfBytes(report);
    Directory? targetDir;
    if (!kIsWeb && Platform.isWindows) {
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
    }
    targetDir ??= await getTemporaryDirectory();

    final cleanFileName = DocxGeneratorService.cleanTopicTitle(report.title)
        .replaceAll(RegExp(r'[\\/:*?"<>|«»“”‘’،,;!?.#%&{}$+=@^~`\(\)\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    final fileName = '${cleanFileName.isEmpty ? 'Academic_Report' : cleanFileName}.pdf';
    final filePath = '${targetDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // On Windows, auto-open the PDF document in the default PDF viewer / browser
    if (!kIsWeb && Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '""', filePath], runInShell: true);
      } catch (e) {
        debugPrint('Windows auto-launch info: $e');
      }
    }

    // On Mobile & Desktop, trigger the system Share/Open sheet
    try {
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        subject: report.title,
        text: 'فایلی PDF بۆ ڕاپۆرتی: ${report.title}',
      );
    } catch (e) {
      debugPrint('Share sheet info: $e');
    }
  }
}
