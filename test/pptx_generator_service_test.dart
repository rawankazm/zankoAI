import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/services/pptx_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PptxGeneratorService Tests', () {
    test('getSlideSpecificImageUrl matches AI category for LLM topics', () {
      const topic = 'پێشەکی و چوارچێوەی گشتیی بەکارهێنانی مۆدێلە زمانە گەورەکان لە خوێندنی باڵادا';
      final imgUrlSlide1 = PptxGeneratorService.getSlideSpecificImageUrl(topic, 1);
      final imgUrlSlide2 = PptxGeneratorService.getSlideSpecificImageUrl(topic, 2);

      // Should match AI neural / robotics / deep learning, NOT antique book library
      expect(imgUrlSlide1, contains('photo-1618005182384-a83a8bd57fbe'));
      expect(imgUrlSlide2, contains('photo-1485827404703-89b55fcc595e'));
    });

    test('createPptxBytes produces valid OpenXML PPTX with full-bleed cover and content slides', () async {
      final slides = List.generate(
        8,
        (i) => SlideModel(
          title: i == 0
              ? 'پێشەکی و چوارچێوەی گشتیی بەکارهێنانی مۆدێلە زمانە گەورەکان لە خوێندنی باڵادا'
              : 'تەوەری $i: پێناسە و تایبەتمەندییە زانستییەکان',
          bulletPoints: [
            'پێناسەی گشتی: مۆدێلە زمانە گەورەکان بە شێوەیەکی بنەڕەتی کار دەکەن لەسەر تێگەیشتن لە دەقی سروشتی.',
            'کارایی لە توێژینەوەدا: کەمکردنەوەی ماوەی شیکردنەوەی زانیارییە ئاڵۆزەکان بە ڕێژەی ٨٥٪.',
            'ئاستەنگە ئەکادیمییەکان: ڕەچاوکردنی ئیتیکی زانستی و پاراستنی مافی خاوەندارێتی هزری.',
            'دەرئەنجام: پێویستیی ناوەندە زانستییەکان بە داڕشتنی چوارچێوەیەکی ڕێنمایی گشتگیر.',
          ],
          speakerNotes: 'تێبینی پێشکەشکار بۆ سلایدی $i',
          categoryTag: 'تەکنەلۆژیا',
        ),
      );

      final pptxBytes = await PptxGeneratorService.createPptxBytes(
        slides,
        presentationTitle: 'مۆدێلە زمانە گەورەکان',
        languageCode: 'ku',
        studentName: 'Rawan kurdi',
        supervisorName: 'چنار',
        university: 'کۆلێژی تەکنیکی شەقڵاوە',
        department: 'Management Information Systems (MIS)',
        academicYear: '٢٠٢٥ - ٢٠٢٦',
      );

      expect(pptxBytes, isNotEmpty);

      // Verify ZIP / OpenXML structure
      final archive = ZipDecoder().decodeBytes(pptxBytes);
      final fileNames = archive.files.map((f) => f.name).toSet();

      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('_rels/.rels'));
      expect(fileNames, contains('ppt/presentation.xml'));
      expect(fileNames, contains('ppt/slideMasters/slideMaster1.xml'));

      for (int i = 1; i <= 8; i++) {
        expect(fileNames, contains('ppt/slides/slide$i.xml'));
        expect(fileNames, contains('ppt/slides/_rels/slide$i.xml.rels'));
      }

      // Verify Slide 1 XML
      final slide1File = archive.findFile('ppt/slides/slide1.xml');
      expect(slide1File, isNotNull);
      final slide1Xml = utf8.decode(slide1File!.content as List<int>);

      // Full bleed cover background (no 400,000 margin)
      expect(slide1Xml, contains('name="CoverBackground"'));
      expect(slide1Xml, contains('<a:off x="0" y="0"/><a:ext cx="12192000" cy="6858000"/>'));
      expect(slide1Xml, contains('0A0F1D')); // Midnight Navy Background

      // Top royal ribbon & cyan glow
      expect(slide1Xml, contains('name="TopRoyalRibbon"'));
      expect(slide1Xml, contains('name="TopCyanGlow"'));

      // Student and Supervisor cards
      expect(slide1Xml, contains('name="StudentCard"'));
      expect(slide1Xml, contains('Rawan kurdi'));
      expect(slide1Xml, contains('name="SupervisorCard"'));
      expect(slide1Xml, contains('چنار'));

      // Academic Year footer
      expect(slide1Xml, contains('name="YearFooter"'));
      expect(slide1Xml, contains('٢٠٢٥ - ٢٠٢٦'));

      // Verify Content Slide (Slide 2) XML
      final slide2File = archive.findFile('ppt/slides/slide2.xml');
      expect(slide2File, isNotNull);
      final slide2Xml = utf8.decode(slide2File!.content as List<int>);

      expect(slide2Xml, contains('name="TopAccent"'));
      expect(slide2Xml, contains('name="ContentBox"'));
      expect(slide2Xml, contains('name="SlideImage2"'));
      expect(slide2Xml, contains('پێناسەی گشتی:'));
      expect(slide2Xml, contains('b="1"')); // Bold leading term
    });

    test('getSlideSpecificImageUrl correctly categorizes all diverse academic departments', () {
      // Dentistry
      final dentalImg = PptxGeneratorService.getSlideSpecificImageUrl(
        'نەخۆشییەکانی پووک و چاندنی ددان',
        1,
        department: 'کۆلێژی پزیشکی ددان',
      );
      expect(dentalImg, contains('photo-1588776814546-1ffcf47267a5'));

      // Civil Engineering / Architecture
      final civilImg = PptxGeneratorService.getSlideSpecificImageUrl(
        'شیکاریی چەمانەوەی کۆنکرێتی چەکدار',
        1,
        department: 'ئەندازیاری شارستانی',
      );
      expect(civilImg, contains('photo-1486406146926-c627a92ad1ab'));

      // Law / Judiciary
      final lawImg = PptxGeneratorService.getSlideSpecificImageUrl(
        'مافی مرۆڤ لە یاسای نێودەوڵەتیدا',
        1,
        department: 'یاسا و پەیوەندییە نێودەوڵەتییەکان',
      );
      expect(lawImg, contains('photo-1589829545856-d10d557cf95f'));

      // Sports Science
      final sportImg = PptxGeneratorService.getSlideSpecificImageUrl(
        'فیسیۆلۆجیای مەشق و ڕاهێنانی وەرزشی',
        1,
        department: 'کۆلێژی پەروەردەی وەرزش',
      );
      expect(sportImg, contains('photo-1517649763962-0c623266ddc0'));

      // Veterinary
      final vetImg = PptxGeneratorService.getSlideSpecificImageUrl(
        'ڤایرۆسناسی لە پەلەوەر و ئاژەڵدا',
        1,
        department: 'پزیشکی ڤێتێرنەری',
      );
      expect(vetImg, contains('photo-1576201836106-db1758fd1c97'));

      // Kurdish Studies & History
      final kurdImg = PptxGeneratorService.getSlideSpecificImageUrl(
        'دەستنووسە مێژووییەکانی میرنشینی بابان',
        1,
        department: 'مێژوو و کەلتووری کورد',
      );
      expect(kurdImg, contains('photo-1461360370896-922624d12aa1'));
    });
  });
}
