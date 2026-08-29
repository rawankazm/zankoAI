import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:zanko_ai/services/docx_generator_service.dart';
import 'package:zanko_ai/services/report_pdf_generator_service.dart';
import 'package:zanko_ai/utils/kurdish_arabic_reshaper.dart';

void main() {
  test('Compare PDF Rendering Approaches for Kurdish', () async {
    final fontBytes = File('assets/fonts/calibri.ttf').readAsBytesSync();
    final notoSansBytes = File('assets/fonts/NotoSansArabic-Regular.ttf').readAsBytesSync();

    final testPhrases = [
      'Ø­Ú©ÙˆÙ…Û•ØªÛŒ Ù‡Û•Ø±ÛŽÙ…ÛŒ Ú©ÙˆØ±Ø¯Ø³ØªØ§Ù† - Ø¹ÛŽØ±Ø§Ù‚',
      'ÙˆÛ•Ø²Ø§Ø±Û•ØªÛŒ Ø®ÙˆÛŽÙ†Ø¯Ù†ÛŒ Ø¨Ø§ÚµØ§ Ùˆ ØªÙˆÛŽÚ˜ÛŒÙ†Û•ÙˆÛ•ÛŒ Ø²Ø§Ù†Ø³ØªÛŒ',
      'Ú©Ø§Ø±ÛŒÚ¯Û•Ø±ÛŒÛŒ Ú˜ÛŒØ±ÛŒÛŒ Ø¯Û•Ø³ØªÚ©Ø±Ø¯ Ù„Û•Ø³Û•Ø± ØªÛ•Ú©Ù†Û†Ù„Û†Ú˜ÛŒØ§ÛŒ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒ',
      'Ø¦Ø§Ù…Ø§Ø¯Û•Ú©Ø±Ø¯Ù†ÛŒ: Ú•Ø§ÙˆØ§Ù† Ø¦Û•Ø­Ù…Û•Ø¯ØŒ Ø³Ø§Ø±Ø§ Ù…Ø­Û•Ù…Û•Ø¯ØŒ Ú©Ø§Ø±ÙˆØ§Ù† Ú•Û•Ø²Ø§',
      'Ø¨Û•Ø³Û•Ø±Ù¾Û•Ø±Ø´ØªÛŒÛŒ: Ù¾.ÛŒ.Ø¯. Ù†Û•Ø¨Û•Ø² Ø¹ÙˆÙ…Û•Ø± (2024 - 2025)',
      'Ù¡. Ù¾ÛŽØ´Û•Ú©ÛŒ Ùˆ Ú¯Ø±Ù†Ú¯ÛŒÛŒ Ø²Ø§Ù†Ø³ØªÛŒÛŒ Ø¨Ø§Ø¨Û•ØªÛ•Ú©Û• Ù„Û• Ø³Û•Ø±Ø¯Û•Ù…ÛŒ Ù…Û†Ø¯ÛŽØ±Ù†Ø¯Ø§',
      'Ú•Ø§Ù¾Û†Ø±ØªÛŒ Ø²Ø§Ù†Ø³ØªÛŒ Ù¾ÛŽØ´Ú©Û•Ø´ Ø¨Û• Ø¨Û•Ø´ÛŒ ØªÛ•Ú©Ù†Û†Ù„Û†Ú˜ÛŒØ§ÛŒ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒ Ú©Ø±Ø§ÙˆÛ•.',
    ];

    // Approach A: Calibri + KurdishArabicReshaper.shapeAndReorder (alignment: right)
    {
      final doc = PdfDocument();
      doc.pageSettings.size = PdfPageSize.a4;
      final page = doc.pages.add();
      final font = PdfTrueTypeFont(fontBytes, 14);

      double y = 40;
      for (var phrase in testPhrases) {
        final text = KurdishArabicReshaper.shapeAndReorder(phrase);
        page.graphics.drawString(
          text,
          font,
          brush: PdfSolidBrush(PdfColor(15, 23, 42)),
          bounds: Rect.fromLTWH(40, y, 500, 24),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        y += 35;
      }

      final bytes = await doc.save();
      doc.dispose();
      File('C:/Users/rawan/.gemini/antigravity/brain/c0a7c93f-d782-4611-b466-eee7f2d7974d/scratch/kurdish_calibri_bidi.pdf')
          .writeAsBytesSync(bytes);
      debugPrint('Saved kurdish_calibri_bidi.pdf (${bytes.length} bytes)');
    }

    // Approach B: NotoSans + KurdishArabicReshaper.shapeAndReorder
    {
      final doc = PdfDocument();
      doc.pageSettings.size = PdfPageSize.a4;
      final page = doc.pages.add();
      final font = PdfTrueTypeFont(notoSansBytes, 14);

      double y = 40;
      for (var phrase in testPhrases) {
        final text = KurdishArabicReshaper.shapeAndReorder(phrase);
        page.graphics.drawString(
          text,
          font,
          brush: PdfSolidBrush(PdfColor(15, 23, 42)),
          bounds: Rect.fromLTWH(40, y, 500, 24),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        y += 35;
      }

      final bytes = await doc.save();
      doc.dispose();
      File('C:/Users/rawan/.gemini/antigravity/brain/c0a7c93f-d782-4611-b466-eee7f2d7974d/scratch/kurdish_notosans_bidi.pdf')
          .writeAsBytesSync(bytes);
      debugPrint('Saved kurdish_notosans_bidi.pdf (${bytes.length} bytes)');
    }

    // Approach C: Full 8-Page Academic Report Generation (Kurdish)
    {
      final report = DocxGeneratorService.parseReportFromText(
        rawText: '',
        title: 'Ú©Ø§Ø±ÛŒÚ¯Û•Ø±ÛŒÛŒ Ú˜ÛŒØ±ÛŒÛŒ Ø¯Û•Ø³ØªÚ©Ø±Ø¯ Ù„Û•Ø³Û•Ø± ØªÛ•Ú©Ù†Û†Ù„Û†Ú˜ÛŒØ§ÛŒ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒ',
        studentName: 'Ú•Ø§ÙˆØ§Ù† Ø¦Û•Ø­Ù…Û•Ø¯\nØ³Ø§Ø±Ø§ Ù…Ø­Û•Ù…Û•Ø¯',
        supervisorName: 'Ù¾.ÛŒ.Ø¯. Ù†Û•Ø¨Û•Ø² Ø¹ÙˆÙ…Û•Ø±',
        universityName: 'Ø²Ø§Ù†Ú©Û†ÛŒ Ù¾Û†Ù„ÛŒØªÛ•Ú©Ù†ÛŒÚ©ÛŒ Ù‡Û•ÙˆÙ„ÛŽØ±',
        departmentName: 'Ø¨Û•Ø´ÛŒ ØªÛ•Ú©Ù†Û†Ù„Û†Ú˜ÛŒØ§ÛŒ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒ',
        academicYear: '2024 - 2025',
        languageCode: 'ku',
      );

      final pdfBytes = await ReportPdfGeneratorService.createPdfBytes(report);
      expect(pdfBytes.length > 50000, true);
      File('C:/Users/rawan/.gemini/antigravity/brain/c0a7c93f-d782-4611-b466-eee7f2d7974d/scratch/full_kurdish_report.pdf')
          .writeAsBytesSync(pdfBytes);
      debugPrint('Saved full_kurdish_report.pdf (${pdfBytes.length} bytes)');
    }

    // Approach D: Full 8-Page Academic Report Generation (Arabic)
    {
      final report = DocxGeneratorService.parseReportFromText(
        rawText: '',
        title: 'Ø£Ø«Ø± Ø§Ù„Ø°ÙƒØ§Ø¡ Ø§Ù„Ø§ØµØ·Ù†Ø§Ø¹ÙŠ ÙÙŠ Ù‡Ù†Ø¯Ø³Ø© Ø§Ù„Ø¨Ø±Ù…Ø¬ÙŠØ§Øª ÙˆØ§Ù„Ø£Ù†Ø¸Ù…Ø© Ø§Ù„Ø°ÙƒÙŠØ©',
        studentName: 'Ø£Ø­Ù…Ø¯ Ø¹Ù„ÙŠ\nØ³Ø§Ø±Ø© Ù…Ø­Ù…Ø¯',
        supervisorName: 'Ø£.Ø¯. Ø¹Ø¨Ø¯ Ø§Ù„Ù„Ù‡ Ø¹Ù…Ø±',
        universityName: 'Ø¬Ø§Ù…Ø¹Ø© Ø¨ØºØ¯Ø§Ø¯',
        departmentName: 'Ù‚Ø³Ù… Ø¹Ù„ÙˆÙ… Ø§Ù„Ø­Ø§Ø³ÙˆØ¨',
        academicYear: '2024 - 2025',
        languageCode: 'ar',
      );

      final pdfBytes = await ReportPdfGeneratorService.createPdfBytes(report);
      expect(pdfBytes.length > 50000, true);
      File('C:/Users/rawan/.gemini/antigravity/brain/c0a7c93f-d782-4611-b466-eee7f2d7974d/scratch/full_arabic_report.pdf')
          .writeAsBytesSync(pdfBytes);
      debugPrint('Saved full_arabic_report.pdf (${pdfBytes.length} bytes)');
    }
  });
}


