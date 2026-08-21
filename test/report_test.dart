import 'dart:io';
import 'dart:ui';
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
      'حکومەتی هەرێمی کوردستان - عێراق',
      'وەزارەتی خوێندنی باڵا و توێژینەوەی زانستی',
      'کاریگەریی ژیریی دەستکرد لەسەر تەکنۆلۆژیای زانیاری',
      'ئامادەکردنی: ڕاوان ئەحمەد، سارا محەمەد، کاروان ڕەزا',
      'بەسەرپەرشتیی: پ.ی.د. نەبەز عومەر (2024 - 2025)',
      '١. پێشەکی و گرنگیی زانستیی بابەتەکە لە سەردەمی مۆدێرندا',
      'ڕاپۆرتی زانستی پێشکەش بە بەشی تەکنۆلۆژیای زانیاری کراوە.',
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
      print('Saved kurdish_calibri_bidi.pdf (${bytes.length} bytes)');
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
      print('Saved kurdish_notosans_bidi.pdf (${bytes.length} bytes)');
    }

    // Approach C: Full 8-Page Academic Report Generation (Kurdish)
    {
      final report = DocxGeneratorService.parseReportFromText(
        rawText: '',
        title: 'کاریگەریی ژیریی دەستکرد لەسەر تەکنۆلۆژیای زانیاری',
        studentName: 'ڕاوان ئەحمەد\nسارا محەمەد',
        supervisorName: 'پ.ی.د. نەبەز عومەر',
        universityName: 'زانکۆی پۆلیتەکنیکی هەولێر',
        departmentName: 'بەشی تەکنۆلۆژیای زانیاری',
        academicYear: '2024 - 2025',
        languageCode: 'ku',
      );

      final pdfBytes = await ReportPdfGeneratorService.createPdfBytes(report);
      expect(pdfBytes.length > 50000, true);
      File('C:/Users/rawan/.gemini/antigravity/brain/c0a7c93f-d782-4611-b466-eee7f2d7974d/scratch/full_kurdish_report.pdf')
          .writeAsBytesSync(pdfBytes);
      print('Saved full_kurdish_report.pdf (${pdfBytes.length} bytes)');
    }

    // Approach D: Full 8-Page Academic Report Generation (Arabic)
    {
      final report = DocxGeneratorService.parseReportFromText(
        rawText: '',
        title: 'أثر الذكاء الاصطناعي في هندسة البرمجيات والأنظمة الذكية',
        studentName: 'أحمد علي\nسارة محمد',
        supervisorName: 'أ.د. عبد الله عمر',
        universityName: 'جامعة بغداد',
        departmentName: 'قسم علوم الحاسوب',
        academicYear: '2024 - 2025',
        languageCode: 'ar',
      );

      final pdfBytes = await ReportPdfGeneratorService.createPdfBytes(report);
      expect(pdfBytes.length > 50000, true);
      File('C:/Users/rawan/.gemini/antigravity/brain/c0a7c93f-d782-4611-b466-eee7f2d7974d/scratch/full_arabic_report.pdf')
          .writeAsBytesSync(pdfBytes);
      print('Saved full_arabic_report.pdf (${pdfBytes.length} bytes)');
    }
  });
}


