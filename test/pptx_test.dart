import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
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

    final slides = PptxGeneratorService.parseSlidesFromText(
      rawText,
      defaultTitle: 'سیمینار',
    );
    expect(slides.isNotEmpty, true);
    expect(slides.length, 2);

    final bytes = await PptxGeneratorService.createPptxBytes(
      slides,
      presentationTitle: 'ئاستەنگە سەرەکییەکان ڕەهەندە تەکنیکییەکان',
      studentName: 'ئاراس علی',
      supervisorName: 'د. نەبەز عومەر',
      university: 'زانکۆی سەڵاحەدین',
      department: 'کۆلێژی زانست',
      logoBytes: [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ],
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

    final parsed = PptxGeneratorService.parseSlidesFromText(
      rawAiResponse,
      defaultTitle: 'زیرەکی دەستکرد',
    );
    expect(parsed.length, 8);
    for (int i = 0; i < parsed.length; i++) {
      expect(
        parsed[i].bulletPoints.isNotEmpty,
        true,
        reason: 'Slide ${i + 1} has no bullets',
      );
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

    final slides = PptxGeneratorService.parseSlidesFromText(
      rawText,
      defaultTitle: 'تەکنەلۆجیا',
    );
    final bytes = await PptxGeneratorService.createPptxBytes(
      slides,
      presentationTitle: 'تەکنەلۆجیای زیرەک',
      studentName: 'قوتابی نموونەیی',
      supervisorName: 'د. محەمەد',
      university: 'زانکۆی سەڵاحەدین',
      department: 'کۆلێژی پزیشکی',
      logoBytes: [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ],
    );

    expect(bytes.isNotEmpty, true);
    final archive = ZipDecoder().decodeBytes(bytes);
    final slide1Xml = utf8.decode(
      archive.findFile('ppt/slides/slide1.xml')!.content as List<int>,
    );
    expect(
      slide1Xml.contains('p14:morph'),
      true,
      reason: 'Slide XML must contain morph transition',
    );
  });

  test('Diverse Kurdish and Arabic Slide Header Parsing Resilience', () async {
    const variedOutput = '''
# ناونیشانی سەرەکیی پرێزێنتەیشن
### سڵاید ١: پێناسە و دەستپێک
- خاڵی یەکەم لەسەر شیکاری
- خاڵی دووەم دەربارەی گرنگی

### 2. Theoretical Background
- Literature review findings
- Historical context

### سلایدی ٣: کێشەی سەرەکی
- ئاستەنگی داتا و پاراستن
- تێچووی دارایی

### تەوەرەی ٤: ئامانجەکان
- بەدەستهێنانی کارایی ٩٠٪
- کەمکردنەوەی هەڵە

### 5. Methodology
- Statistical analysis
- Neural network model
''';

    final slides = PptxGeneratorService.parseSlidesFromText(
      variedOutput,
      defaultTitle: 'تاقیکردنەوە',
    );
    expect(slides.length, 5);
    expect(slides[0].title.contains('پێناسە'), true);
    expect(slides[1].title.contains('Theoretical Background'), true);
    expect(slides[2].title.contains('کێشەی سەرەکی'), true);
    expect(slides[3].title.contains('ئامانجەکان'), true);
    expect(slides[4].title.contains('Methodology'), true);
  });

  test(
    'Seminar final slide Thank You message translates across all languages',
    () {
      expect(
        PptxGeneratorService.getThankYouMessage('ku'),
        'سوپاس بۆ ئامادەبوونتان',
      );
      expect(
        PptxGeneratorService.getThankYouMessage('ku_badini'),
        'سوپاس بۆ ئامادەبوونا هەوە',
      );
      expect(
        PptxGeneratorService.getThankYouMessage('badini'),
        'سوپاس بۆ ئامادەبوونا هەوە',
      );
      expect(PptxGeneratorService.getThankYouMessage('ar'), 'شكراً لحضوركم');
      expect(
        PptxGeneratorService.getThankYouMessage('en'),
        'Thank You for Your Attendance',
      );
    },
  );

  test(
    'Zero duplicate images guaranteed across all slides in any presentation',
    () {
      final topics = [
        ('پزیشکی ددان', 'Dentistry'),
        ('کۆمپیوتەر و زیرەکی دەستکرد', 'Computer Science'),
        ('یاسا و مافەکانی مرۆڤ', 'Law'),
        ('ئەندازیاری شارستانی', 'Civil Engineering'),
        ('ئابووری و دارایی نێودەوڵەتی', 'Business & Economics'),
        ('بایۆلۆجی و بۆماوەزانی', 'Biology'),
        ('ڕاگەیاندن و میدیا', 'Media'),
      ];

      for (final t in topics) {
        final used = <String>{};
        final urls = <String>[];
        for (int i = 1; i <= 8; i++) {
          final url = PptxGeneratorService.getSlideSpecificImageUrl(
            t.$1,
            i,
            department: t.$2,
            usedUrls: used,
          );
          urls.add(url);
        }
        expect(urls.length, 8);
        expect(
          urls.toSet().length,
          8,
          reason: 'Found duplicate images in presentation for ${t.$1}',
        );
      }
    },
  );

  test(
    'All slides including Slide 1 and Slide 9 contain images and dedicated closing slide layout',
    () async {
      final slides = [
        SlideModel(
          title: 'تەکنەلۆجیای زیرەک',
          bulletPoints: ['پێناسە', 'گرنگی'],
        ),
        SlideModel(
          title: 'پاشخانی زانستی',
          bulletPoints: ['مێژوو', 'چەمکەکان'],
        ),
        SlideModel(title: 'ئاستەنگەکان', bulletPoints: ['تێچوو', 'کات']),
        SlideModel(title: 'ئامانجەکان', bulletPoints: ['کارایی', 'وردبینی']),
        SlideModel(
          title: 'میتۆدۆلۆجی',
          bulletPoints: ['شیکاری', 'تاقیکردنەوە'],
        ),
        SlideModel(
          title: 'دەرئەنجامەکان',
          bulletPoints: ['سەرکەوتن ٨٩٪', 'خێرایی'],
        ),
        SlideModel(title: 'ڕاسپاردەکان', bulletPoints: ['پێشنیار', 'داهاتوو']),
        SlideModel(
          title: 'دەرئەنجام و سەرچاوەکان',
          bulletPoints: ['پوختە', 'سەرچاوەکان'],
        ),
        SlideModel(
          title: 'سوپاس بۆ ئامادەبوونتان',
          bulletPoints: [
            'سوپاس بۆ ئامادەبوونتان و بەشداریتان',
            'کاتی پرسیار و گفتوگۆی زانستی',
          ],
        ),
      ];

      final bytes = await PptxGeneratorService.createPptxBytes(
        slides,
        presentationTitle: 'تەکنەلۆجیای زیرەک',
        languageCode: 'ku',
        studentName: 'ڕەوەند کامەران',
        supervisorName: 'د. ئاراس ئەحمەد',
        university: 'زانکۆی سەڵاحەدین - هەولێر',
        department: 'کۆلێژی ئەندازیاری',
      );

      expect(bytes.isNotEmpty, true);
      final archive = ZipDecoder().decodeBytes(bytes);

      // Verify each of the 9 slides has an image in rels and pic in slide xml
      for (int i = 1; i <= 9; i++) {
        final relsFile = archive.findFile('ppt/slides/_rels/slide$i.xml.rels');
        expect(relsFile, isNotNull, reason: 'slide$i.xml.rels must exist');
        final relsXml = utf8.decode(relsFile!.content as List<int>);
        expect(
          relsXml.contains('Id="rId2"'),
          true,
          reason: 'slide$i rels must contain rId2 image relation',
        );
        expect(
          relsXml.contains('Target="../media/image$i.jpeg"'),
          true,
          reason: 'slide$i rels must point to media/image$i.jpeg',
        );

        final slideFile = archive.findFile('ppt/slides/slide$i.xml');
        expect(slideFile, isNotNull, reason: 'slide$i.xml must exist');
        final slideXml = utf8.decode(slideFile!.content as List<int>);
        expect(
          slideXml.contains('r:embed="rId2"'),
          true,
          reason: 'slide$i XML must embed rId2',
        );
        expect(
          slideXml.contains('<p14:morph/>'),
          true,
          reason: 'slide$i XML must have morph transition',
        );

        if (i == 1) {
          expect(
            slideXml.contains('HeroImage'),
            true,
            reason: 'Slide 1 must have HeroImage frame',
          );
          expect(
            slideXml.contains('زانکۆی سەڵاحەدین'),
            true,
            reason: 'Slide 1 must have university badge',
          );
        } else if (i == 9) {
          expect(
            slideXml.contains('ClosingPhoto'),
            true,
            reason: 'Slide 9 must have ClosingPhoto frame',
          );
          expect(
            slideXml.contains('سوپاس بۆ ئامادەبوونتان'),
            true,
            reason: 'Slide 9 must have gratitude headline',
          );
          expect(
            slideXml.contains('کاتی پرسیار و گفتوگۆ'),
            true,
            reason: 'Slide 9 must have Q&A discussion card',
          );
        }
      }
    },
  );
}
