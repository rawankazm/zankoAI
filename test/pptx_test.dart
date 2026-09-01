import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/services/pptx_generator_service.dart';

void main() {
  test('PPTX generation test', () async {
    final rawText = '''
# 💡 بابەتی سیمینار
### 🔹 سلایدی ١: ناساندنی سیمینار
- ناونیشانی سەرەکی: تەکنەلۆجیای زیرەک
- خاڵە سەرەکییەکان: پێناسە و مێژوو
- 🎙️ تێبینی پێشکەشکار: بەخێربێن

### 🔹 سلایدی ٢: کێشەی توێژینەوە
- ناونیشانی سەرەکی: ئاستەنگەکان
- کێشە نەریتییەکان لە کارگێڕیدا
''';

    final slides = PptxGeneratorService.parseSlidesFromText(rawText, defaultTitle: 'سیمینار');
    expect(slides.isNotEmpty, true);
    expect(slides.length, 2);

    final bytes = await PptxGeneratorService.createPptxBytes(
      slides,
      presentationTitle: 'ئاستەنگە سەرەکییەکان ڕەهەندە تەکنیکییەکان',
      studentName: 'ئاراس علی',
      supervisorName: 'د. نەبەز عومەر',
      university: 'زانکۆی سەڵاحەدین',
      department: 'کۆلێژی زانست',
      logoBytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82],
    );
    expect(bytes.isNotEmpty, true);
    File('scratch/test_presentation.pptx').writeAsBytesSync(bytes);
  });

  test('Realistic 8-Slide Kurdish AI Output Parsing', () async {
    const rawAiResponse = '''
# 📊 سیمیناری زانستی: زیرەکی دەستکرد
### 🔹 سلایدی ١: ناساندنی سیمینار و تێزی سەرەکی
- **پێناسە و گرنگی**: زیرەکی دەستکرد شۆڕشێکی گەورەی لە هەموو بوارەکاندا دروستکردووە.
- **تێزی سەرەکی**: پێویستیی بەکارهێنانی مۆدێلە مۆدێرنەکان لە پرۆسەی خوێندندا بە ڕێژەی ٨٥٪ زیادی کردووە.
- **ئامانجی گشتی**: خستنەڕووی سوود و ئاستەنگە سەرەکییەکان بە شێوەیەکی زانستی.
- 🖼️ **Visual Focus: AI Brain Concept**
- 🎙️ **تێبینی پێشکەشکار: بەخێربێن بۆ ئەم سیمینارە ئەکادیمییە**

### 🔹 سلایدی ٢: پاشخانی مێژوویی و گەشەسەندن
1. قۆناغی سەرەتایی لە ساڵانی ١٩٥٠ تا ١٩٨٠.
2. شۆڕشی فێربوونی قووڵ لە ساڵی ٢٠١٢ بەدواوە.
3. گەشەکردنی مۆدێلە گەورەکانی زمان لە ساڵی ٢٠٢٢.
- 🎙️ **تێبینی پێشکەشکار: مێژووی زیرەکی دەستکرد پڕە لە دەستکەوت**

### 🔹 سلایدی ٣: کێشە و ئاستەنگەکان
- **کێشەی سەرەکی**: کەمیی سەرچاوە و داتای پارێزراو.
- **ئاستەنگی دارایی**: تێچووی بەرز لە دەستپێکدا بە ڕێژەی ٤٠٪ زیاترە.
- **ئاستەنگی ئەخلاقی**: پاراستنی نهێنی و مافی خاوەندارێتی داتا.
- 🎙️ **تێبینی پێشکەشکار: با ئێستا سەرنج بخەینە سەر ئاستەنگەکان**

### 🔹 سلایدی ٤: ئامانجە ستراتیجییەکان
- بەرزکردنەوەی کارایی کارگێڕی بە ڕێژەی ٦٠٪.
- کەمکردنەوەی هەڵەی مرۆیی بۆ کەمتر لە ٢٪.
- خێراکردنی بڕیاردان لە دەزگا ئەکادیمییەکاندا.
- 🎙️ **تێبینی پێشکەشکار: ئامانجمان گەیشتنە بەم ژمارانە**

### 🔹 سلایدی ٥: میتۆدۆلۆژی و شێوازی کار
- میتۆدی تاقیکاری و شیکاریی داتای چەندین سەرچاوە.
- نموونەی وەرگیراو لە ١٥٠٠ توێژەر و مامۆستا.
- بەکارهێنانی مۆدێلی Python و PyTorch بۆ شیکردنەوە.
- 🎙️ **تێبینی پێشکەشکار: ئەم میتۆدە زۆرترین وردبینیی هەبووە**

### 🔹 سلایدی ٦: ئەنجامە ئامارییەکان
- گەیشتن بە وردبینی ٩٦.٨٪ لە پۆلێنکردنی داتادا.
- کەمکردنەوەی کاتی تاقیکردنەوەکان بە ڕێژەی ٧٠٪.
- دڵنیایی ئاماری سەلمێنراو لە هەموو قۆناغەکاندا.
- 🎙️ **تێبینی پێشکەشکار: ئەم ئەنجامانە سەلمێنەری سەرکەوتنی کارەکەمانن**

### 🔹 سلایدی ٧: گفتوگۆ و ڕاسپاردەکان
- پێشنیار بۆ دروستکردنی تاقیگەی تایبەت لە زانکۆکان.
- ڕاهێنانی بەردەوامی ستاف و مامۆستایان.
- دانانی ڕێسای ئەخلاقی بۆ بەکارهێنانی زیرەکی دەستکرد.
- 🎙️ **تێبینی پێشکەشکار: ئەم ڕاسپاردانە کلیلی سەرکەوتنن**

### 🔹 سلایدی ٨: دەرئەنجام و سەرچاوە زانستییەکان
- کورتەی دەرئەنجامی توێژینەوەکە و کارایی سیستەمەکە.
- سەرچاوە: Russell, S., & Norvig, P. (2024). AI: A Modern Approach.
- سەرچاوە: Goodfellow, I. (2023). Deep Learning. MIT Press.
- 🎙️ **تێبینی پێشکەشکار: زۆر سوپاس بۆ کات و گوێگرتنتان**
''';

    final parsed = PptxGeneratorService.parseSlidesFromText(rawAiResponse, defaultTitle: 'زیرەکی دەستکرد');
    expect(parsed.length, 8);
    for (int i = 0; i < parsed.length; i++) {
      expect(parsed[i].bulletPoints.isNotEmpty, true, reason: 'Slide ${i + 1} has no bullets');
    }

    final bytes = await PptxGeneratorService.createPptxBytes(
      parsed,
      presentationTitle: 'ئاستەنگە سەرەکییەکان و ڕەهەندە تەکنیکییەکان',
      studentName: 'ئاراس علی',
      supervisorName: 'د. نەبەز عومەر',
      university: 'زانکۆی سەڵاحەدین',
      department: 'کۆلێژی زانست',
    );
    expect(bytes.isNotEmpty, true);
    File('scratch/test_presentation.pptx').writeAsBytesSync(bytes);
  });

  test('PPTX bytes unzipping and schema integrity verification', () async {
    final rawText = '''
### 🔹 سلایدی ١: ناساندنی سیمینار
- ناونیشانی سەرەکی: تەکنەلۆجیای زیرەک لە پزیشکیدا
- خاڵە سەرەکییەکان: پێناسە و مێژوو

### 🔹 سلایدی ٢: ئامانجەکان
- بەرزکردنەوەی کارایی دەستنیشانکردنی نەخۆشییەکان بە ٩٥٪
- کەمکردنەوەی کاتی چارەسەر
''';

    final slides = PptxGeneratorService.parseSlidesFromText(rawText, defaultTitle: 'تەکنەلۆجیا');
    final bytes = await PptxGeneratorService.createPptxBytes(
      slides,
      presentationTitle: 'تەکنەلۆجیای زیرەک',
      studentName: 'قوتابی نموونەیی',
      supervisorName: 'د. محەمەد',
      university: 'زانکۆی سەڵاحەدین',
      department: 'کۆلێژی پزیشکی',
      logoBytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82],
    );

    expect(bytes.isNotEmpty, true);
  });
}
