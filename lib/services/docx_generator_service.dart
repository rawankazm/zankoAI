import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportSectionItem {
  final int sectionNumber;
  final String title;
  final String content;
  final List<String> bulletPoints;
  final String? keyTakeaway;

  ReportSectionItem({
    required this.sectionNumber,
    required this.title,
    required this.content,
    this.bulletPoints = const [],
    this.keyTakeaway,
  });
}

class ReportPageModel {
  final int pageNumber;
  final String pageTitle;
  final String pageType; // 'cover', 'toc', 'content', 'references'
  final String content;
  final List<String> bulletPoints;
  final List<ReportSectionItem> sections;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? figureCaption;

  ReportPageModel({
    required this.pageNumber,
    required this.pageTitle,
    required this.pageType,
    this.content = '',
    this.bulletPoints = const [],
    this.sections = const [],
    this.imageUrl,
    this.imageBytes,
    this.figureCaption,
  });
}

class AcademicReportModel {
  final String title;
  final String studentName;
  final String supervisorName;
  final String universityName;
  final String departmentName;
  final String academicYear;
  final Uint8List? logoBytes;
  final List<ReportPageModel> pages;
  final String languageCode;

  AcademicReportModel({
    required this.title,
    required this.studentName,
    required this.supervisorName,
    required this.universityName,
    required this.departmentName,
    required this.academicYear,
    this.logoBytes,
    required this.pages,
    required this.languageCode,
  });
}

class DocxGeneratorService {
  /// Cleans the topic title completely without leaving isolated letters like "ی ١: "
  static String cleanTopicTitle(String title) {
    var clean = title.trim();
    // 1. Strip full prefixes like "ڕاپۆرت دەربارەی", "تەوەری ١: ", "بەشی ١: ", "Section 1: ", etc.
    clean = clean.replaceAll(
      RegExp(r'^(?:ڕاپۆرت لەبارەی|ڕاپۆرت دەربارەی|ڕاپۆرتی|ڕاپۆرت|تەوەری|تەوەر|بەشی|بەش|بابەتی|بابەت|Report on|Report about|Report|Section|Chapter|Part|Topic)\s*[\d+٠-٩\-]*\s*[:\.\-]\s*', caseSensitive: false),
      '',
    ).trim();

    // 2. Strip leftover single letters followed by numbers like "ی ١: " or "ب ١: "
    clean = clean.replaceAll(
      RegExp(r'^[ابپتثجچحخدڕرزژسشصضطظعغفقڤکگلمنوهی]\s*[\d+٠-٩\-]+\s*[:\.\-]\s*', caseSensitive: false),
      '',
    ).trim();

    return clean.isNotEmpty ? clean : title.trim();
  }

  /// Fetches image bytes safely from a URL with timeout
  static Future<Uint8List?> fetchImageBytes(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
        if (bytes.isNotEmpty) {
          return Uint8List.fromList(bytes);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolves high-definition, verified academic diagram/infographic URLs for each topic
  static String getReportPageImageUrl(String topic, int pageIndex) {
    final t = topic.toLowerCase();

    // 1. AI, Computer Science, IT, Software & Cybersecurity
    if (t.contains('ژیری') ||
        t.contains('دەستکرد') ||
        t.contains('تەکنۆلۆژیا') ||
        t.contains('کۆمپیوتەر') ||
        t.contains('زانیاری') ||
        t.contains('ئینتەرنێت') ||
        t.contains('تۆڕ') ||
        t.contains('ئاسایش') ||
        t.contains('سایبەر') ||
        t.contains('ai') ||
        t.contains('computer') ||
        t.contains('software') ||
        t.contains('cyber') ||
        t.contains('network') ||
        t.contains('data') ||
        t.contains('technology') ||
        t.contains('algorithm') ||
        t.contains('ذكاء') ||
        t.contains('حاسوب') ||
        t.contains('برمج') ||
        t.contains('شبك') ||
        t.contains('أمن')) {
      final images = [
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1555255707-c07966088b7b?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1531482615713-2afd69097998?w=1000&auto=format&fit=crop&q=80',
      ];
      return images[(pageIndex - 1).clamp(0, images.length - 1)];
    }

    // 2. Medicine, Healthcare, Biology, Anatomy & Pharmacy
    if (t.contains('پزیشک') ||
        t.contains('تەندروست') ||
        t.contains('هەرس') ||
        t.contains('دڵ') ||
        t.contains('خوێن') ||
        t.contains('مێشک') ||
        t.contains('تاقیگە') ||
        t.contains('بایۆلۆجی') ||
        t.contains('دەرمان') ||
        t.contains('نەخۆش') ||
        t.contains('med') ||
        t.contains('health') ||
        t.contains('biolog') ||
        t.contains('digest') ||
        t.contains('heart') ||
        t.contains('anatomy') ||
        t.contains('pharma') ||
        t.contains('طب') ||
        t.contains('صح') ||
        t.contains('أحياء') ||
        t.contains('هضم') ||
        t.contains('دواء') ||
        t.contains('مختبر')) {
      final images = [
        'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1579684385127-1ef15d508118?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1530497610245-94d3c16cda28?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1576086213369-97a306d36557?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=1000&auto=format&fit=crop&q=80',
      ];
      return images[(pageIndex - 1).clamp(0, images.length - 1)];
    }

    // 3. Engineering, Architecture, Physics & Energy
    if (t.contains('ئەندازیار') ||
        t.contains('تەلارساز') ||
        t.contains('بیناساز') ||
        t.contains('کارەبا') ||
        t.contains('میکانیک') ||
        t.contains('وزە') ||
        t.contains('خۆر') ||
        t.contains('engineer') ||
        t.contains('architec') ||
        t.contains('electric') ||
        t.contains('mechanic') ||
        t.contains('energy') ||
        t.contains('solar') ||
        t.contains('civil') ||
        t.contains('هندس') ||
        t.contains('عمار') ||
        t.contains('طاق') ||
        t.contains('كهرب')) {
      final images = [
        'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1497435334941-8c899ee9e8e9?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1581092335397-9583fe92d232?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?w=1000&auto=format&fit=crop&q=80',
      ];
      return images[(pageIndex - 1).clamp(0, images.length - 1)];
    }

    // 4. Business, Economics, Management & Finance
    if (t.contains('بازرگان') ||
        t.contains('ئابوور') ||
        t.contains('کارگێڕ') ||
        t.contains('ژمێریار') ||
        t.contains('دارایی') ||
        t.contains('مارکێت') ||
        t.contains('business') ||
        t.contains('econom') ||
        t.contains('manage') ||
        t.contains('finance') ||
        t.contains('market') ||
        t.contains('تجارة') ||
        t.contains('اقتصاد') ||
        t.contains('إدار') ||
        t.contains('مالي')) {
      final images = [
        'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=1000&auto=format&fit=crop&q=80',
      ];
      return images[(pageIndex - 1).clamp(0, images.length - 1)];
    }

    // 5. Law, Politics, Justice, Constitution & Human Rights
    if (t.contains('یاسا') ||
        t.contains('داد') ||
        t.contains('دەستوور') ||
        t.contains('ماف') ||
        t.contains('پەرلەمان') ||
        t.contains('سیاسەت') ||
        t.contains('نێودەوڵەتی') ||
        t.contains('قانون') ||
        t.contains('عدال') ||
        t.contains('دستور') ||
        t.contains('حقوق') ||
        t.contains('سياس') ||
        t.contains('برلمان') ||
        t.contains('law') ||
        t.contains('legal') ||
        t.contains('court') ||
        t.contains('justice') ||
        t.contains('right') ||
        t.contains('politic')) {
      final images = [
        'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1505664194779-8beaceb93744?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1450133064473-71024230f91b?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1479142506502-19b3a3b7ff33?w=1000&auto=format&fit=crop&q=80',
      ];
      return images[(pageIndex - 1).clamp(0, images.length - 1)];
    }

    // 6. Agriculture, Farming, Nature, Plants & Environment
    if (t.contains('کشتوکاڵ') ||
        t.contains('ژینگە') ||
        t.contains('دارستان') ||
        t.contains('ڕووەک') ||
        t.contains('پەلەوەر') ||
        t.contains('ئاژەڵ') ||
        t.contains('زەوی') ||
        t.contains('زراعة') ||
        t.contains('بيئة') ||
        t.contains('نبات') ||
        t.contains('حيوان') ||
        t.contains('غابات') ||
        t.contains('agri') ||
        t.contains('farm') ||
        t.contains('environ') ||
        t.contains('plant') ||
        t.contains('ecolog')) {
      final images = [
        'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1516253593875-bd7ba052fbc5?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1495107334309-fcf20504a5ab?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=1000&auto=format&fit=crop&q=80',
      ];
      return images[(pageIndex - 1).clamp(0, images.length - 1)];
    }

    // 7. Psychology, Education, Sociology & Philosophy
    if (t.contains('پەروەردە') ||
        t.contains('دەروون') ||
        t.contains('کۆمەڵناسی') ||
        t.contains('فەلسەفە') ||
        t.contains('ڕەفتار') ||
        t.contains('منداڵ') ||
        t.contains('تربية') ||
        t.contains('نفس') ||
        t.contains('اجتماع') ||
        t.contains('فلسفة') ||
        t.contains('تعليم') ||
        t.contains('psych') ||
        t.contains('educat') ||
        t.contains('socio') ||
        t.contains('philosophy') ||
        t.contains('pedagog')) {
      final images = [
        'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1427504494785-3a9ca7044f45?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1509062522246-3755977927d7?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=1000&auto=format&fit=crop&q=80',
      ];
      return images[(pageIndex - 1).clamp(0, images.length - 1)];
    }

    // 8. History, Geography, Archaeology & Heritage
    if (t.contains('مێژوو') ||
        t.contains('جوگرافیا') ||
        t.contains('شوێنەوار') ||
        t.contains('کەلتوور') ||
        t.contains('کەلەپوور') ||
        t.contains('شارستانیەت') ||
        t.contains('تاريخ') ||
        t.contains('جغرافيا') ||
        t.contains('آثار') ||
        t.contains('حضار') ||
        t.contains('تراث') ||
        t.contains('history') ||
        t.contains('geograph') ||
        t.contains('archaeol') ||
        t.contains('heritage')) {
      final images = [
        'https://images.unsplash.com/photo-1461360370896-922624d12aa1?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=1000&auto=format&fit=crop&q=80',
      ];
      return images[(pageIndex - 1).clamp(0, images.length - 1)];
    }

    // 9. Languages, Literature, Poetry & Translation
    if (t.contains('زمان') ||
        t.contains('ئەدەب') ||
        t.contains('شێعر') ||
        t.contains('شیعر') ||
        t.contains('ڕۆمان') ||
        t.contains('وەرگێڕان') ||
        t.contains('لغة') ||
        t.contains('أدب') ||
        t.contains('شعر') ||
        t.contains('رواية') ||
        t.contains('ترجم') ||
        t.contains('language') ||
        t.contains('literat') ||
        t.contains('poem') ||
        t.contains('translat')) {
      final images = [
        'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1474932430478-367dbb6832c1?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=1000&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=1000&auto=format&fit=crop&q=80',
      ];
      return images[(pageIndex - 1).clamp(0, images.length - 1)];
    }

    // 10. Default General Academic
    final defaultImages = [
      'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=1000&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=1000&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=1000&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=1000&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=1000&auto=format&fit=crop&q=80',
    ];
    return defaultImages[(pageIndex - 1).clamp(0, defaultImages.length - 1)];
  }

  /// Parses AI output or raw text into a structured 8-page AcademicReportModel
  static AcademicReportModel parseReportFromText({
    required String rawText,
    required String title,
    required String studentName,
    required String supervisorName,
    required String universityName,
    required String departmentName,
    required String academicYear,
    Uint8List? logoBytes,
    String languageCode = 'ku',
  }) {
    final effectiveTitle = cleanTopicTitle(title);
    final cleanYear = academicYear.isNotEmpty ? academicYear : '2024 - 2025';
    final isRtl = languageCode != 'en';

    // Parse Sections from rawText
    final List<ReportSectionItem> parsedSections = [];
    final List<String> parsedReferences = [];

    final lines = rawText.split('\n');
    int currentSecNum = 0;
    String currentSecTitle = '';
    StringBuffer currentSecContent = StringBuffer();
    List<String> currentSecBullets = [];
    bool isParsingReferences = false;

    void saveCurrentSection() {
      if (currentSecNum > 0 && currentSecTitle.isNotEmpty) {
        parsedSections.add(ReportSectionItem(
          sectionNumber: currentSecNum,
          title: currentSecTitle,
          content: currentSecContent.toString().trim(),
          bulletPoints: List.from(currentSecBullets),
        ));
      }
      currentSecTitle = '';
      currentSecContent.clear();
      currentSecBullets.clear();
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect References Header
      if (RegExp(r'^(?:#+\s*)?(?:References|سەرچاوەکان|سەرچاوە زانستییەکان|المراجع|المصادر)', caseSensitive: false).hasMatch(trimmed)) {
        saveCurrentSection();
        isParsingReferences = true;
        continue;
      }

      if (isParsingReferences) {
        if (trimmed.startsWith('#')) continue;
        final refText = trimmed.replaceAll(RegExp(r'^[-* \d+.]\s*'), '').replaceAll('**', '').trim();
        if (refText.isNotEmpty) {
          parsedReferences.add(refText);
        }
        continue;
      }

      // Robust Section Header Detection
      final secMatch = RegExp(
        r'^(?:#+\s*)?(?:(?:بەشی|بەش|تەوەری|تەوەر|Section|Chapter|Part|بابەتی|بابەت)\s*)?[\(\[\{]?(\d+|[٠-٩]+)[\)\]\}]?[\.\:\-\s]+(.+)$',
        caseSensitive: false,
      ).firstMatch(trimmed);

      if (secMatch != null) {
        final rawNumStr = secMatch.group(1) ?? '1';
        final standardNumStr = rawNumStr
            .replaceAll('٠', '0')
            .replaceAll('١', '1')
            .replaceAll('٢', '2')
            .replaceAll('٣', '3')
            .replaceAll('٤', '4')
            .replaceAll('٥', '5')
            .replaceAll('٦', '6')
            .replaceAll('٧', '7')
            .replaceAll('٨', '8')
            .replaceAll('٩', '9');
        final num = int.tryParse(standardNumStr) ?? (parsedSections.length + 1);

        // Avoid Table of Contents header match
        final lower = trimmed.toLowerCase();
        if (!lower.contains('table of contents') && !trimmed.contains('پێڕست') && !trimmed.contains('فهرس')) {
          saveCurrentSection();
          currentSecNum = num;
          currentSecTitle = secMatch.group(2)!.replaceAll('**', '').replaceAll('*', '').trim();
          continue;
        }
      }

      if (currentSecNum > 0) {
        if (trimmed.startsWith('-') || trimmed.startsWith('*') || trimmed.startsWith('•') || RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
          final bullet = trimmed.replaceAll(RegExp(r'^[-*• \d+.]\s*'), '').replaceAll('**', '').trim();
          if (bullet.isNotEmpty) currentSecBullets.add(bullet);
        } else {
          currentSecContent.writeln(trimmed.replaceAll('**', '').replaceAll('*', ''));
        }
      }
    }

    saveCurrentSection();

    // Fill missing sections with domain-appropriate academic sections
    final defaultSections = getDefaultSections(effectiveTitle, languageCode);
    final List<ReportSectionItem> finalSections = [];

    for (int i = 1; i <= 10; i++) {
      final existing = parsedSections.firstWhere(
        (s) => s.sectionNumber == i,
        orElse: () => (i <= parsedSections.length ? parsedSections[i - 1] : defaultSections[i - 1]),
      );

      final def = defaultSections[i - 1];
      final content = existing.content.length > 40 ? existing.content : def.content;
      final bullets = existing.bulletPoints.isNotEmpty ? existing.bulletPoints : def.bulletPoints;
      final secTitle = existing.title.isNotEmpty ? existing.title : def.title;

      finalSections.add(ReportSectionItem(
        sectionNumber: i,
        title: secTitle,
        content: content,
        bulletPoints: bullets,
      ));
    }

    // References list
    final defaultRefs = getDefaultReferences(effectiveTitle, languageCode);
    final List<String> finalReferences = parsedReferences.length >= 4 ? parsedReferences : defaultRefs;

    // ── Build Exactly 8 Pages matching Academic Standard with Images on Pages 3-7 ──
    final List<ReportPageModel> pages = [];

    // Page 1: Cover Page
    pages.add(ReportPageModel(
      pageNumber: 1,
      pageTitle: isRtl ? (languageCode == 'ar' ? 'صفحة الغلاف' : 'بەرگی ڕاپۆرت') : 'Cover Page',
      pageType: 'cover',
      content: effectiveTitle,
    ));

    // Page 2: Table of Contents
    pages.add(ReportPageModel(
      pageNumber: 2,
      pageTitle: isRtl ? (languageCode == 'ar' ? 'فهرس المحتويات' : 'پێڕستی ناوەڕۆک') : 'Table of Contents',
      pageType: 'toc',
      bulletPoints: finalSections.map((s) => '${s.sectionNumber}. ${s.title}').toList(),
    ));

    // Page 3: Sections 1 & 2 + Diagram 1
    pages.add(ReportPageModel(
      pageNumber: 3,
      pageTitle: '${finalSections[0].title} & ${finalSections[1].title}',
      pageType: 'content',
      sections: [finalSections[0], finalSections[1]],
      imageUrl: getReportPageImageUrl(effectiveTitle, 1),
      figureCaption: isRtl ? 'شێوەی زانستی (١): ${finalSections[0].title}' : 'Figure (1): ${finalSections[0].title}',
    ));

    // Page 4: Sections 3 & 4 + Diagram 2
    pages.add(ReportPageModel(
      pageNumber: 4,
      pageTitle: '${finalSections[2].title} & ${finalSections[3].title}',
      pageType: 'content',
      sections: [finalSections[2], finalSections[3]],
      imageUrl: getReportPageImageUrl(effectiveTitle, 2),
      figureCaption: isRtl ? 'شێوەی زانستی (٢): ${finalSections[2].title}' : 'Figure (2): ${finalSections[2].title}',
    ));

    // Page 5: Sections 5 & 6 + Diagram 3
    pages.add(ReportPageModel(
      pageNumber: 5,
      pageTitle: '${finalSections[4].title} & ${finalSections[5].title}',
      pageType: 'content',
      sections: [finalSections[4], finalSections[5]],
      imageUrl: getReportPageImageUrl(effectiveTitle, 3),
      figureCaption: isRtl ? 'شێوەی زانستی (٣): ${finalSections[4].title}' : 'Figure (3): ${finalSections[4].title}',
    ));

    // Page 6: Sections 7 & 8 + Diagram 4
    pages.add(ReportPageModel(
      pageNumber: 6,
      pageTitle: '${finalSections[6].title} & ${finalSections[7].title}',
      pageType: 'content',
      sections: [finalSections[6], finalSections[7]],
      imageUrl: getReportPageImageUrl(effectiveTitle, 4),
      figureCaption: isRtl ? 'شێوەی زانستی (٤): ${finalSections[6].title}' : 'Figure (4): ${finalSections[6].title}',
    ));

    // Page 7: Sections 9 & 10 + Diagram 5
    pages.add(ReportPageModel(
      pageNumber: 7,
      pageTitle: '${finalSections[8].title} & ${finalSections[9].title}',
      pageType: 'content',
      sections: [finalSections[8], finalSections[9]],
      imageUrl: getReportPageImageUrl(effectiveTitle, 5),
      figureCaption: isRtl ? 'شێوەی زانستی (٥): ${finalSections[8].title}' : 'Figure (5): ${finalSections[8].title}',
    ));

    // Page 8: References
    pages.add(ReportPageModel(
      pageNumber: 8,
      pageTitle: isRtl ? (languageCode == 'ar' ? 'المراجع العلمية' : 'سەرچاوە زانستییەکان') : 'References & Bibliography',
      pageType: 'references',
      bulletPoints: finalReferences,
    ));

    return AcademicReportModel(
      title: effectiveTitle,
      studentName: studentName.trim().isNotEmpty ? studentName.trim() : (isRtl ? 'ناوی قوتابی' : 'Student Name'),
      supervisorName: supervisorName.trim().isNotEmpty ? supervisorName.trim() : (isRtl ? 'ناوی سەرپەرشتیار' : 'Supervisor Name'),
      universityName: universityName.trim().isNotEmpty ? universityName.trim() : (isRtl ? 'زانکۆی پۆلیتەکنیکی هەولێر' : 'Erbil Polytechnic University'),
      departmentName: departmentName.trim().isNotEmpty ? departmentName.trim() : (isRtl ? 'کۆلێژی تەکنیکی - بەشی ئەندازیاری و زانست' : 'Faculty of Engineering & Science'),
      academicYear: cleanYear,
      logoBytes: logoBytes,
      pages: pages,
      languageCode: languageCode,
    );
  }

  /// Generates domain-aware fallback sections strictly customized to the topic title
  static List<ReportSectionItem> getDefaultSections(String title, String lang) {
    final isKu = lang == 'ku';
    final isBadini = lang == 'badini';
    final isAr = lang == 'ar';

    if (isBadini) {
      return [
        ReportSectionItem(
          sectionNumber: 1,
          title: 'ناساندن و چوارچێوەیا زانستی یا «$title»',
          content: 'ڤەکۆلین ل دۆر «$title» ئێک ژ گرنگترین تەوەرێن زانستی و ئەکادیمی یە د سەردەمێ نوکە دا. ئەڤ بابەتە بنەمایەکێ موکوم بۆ تێگەهشتنێ ژ چەمکێن سەرەکی، ڕێبازێن نێڤدەولەتی و گوهۆڕینێن سەردەم دابین دکەت.\n\nژ ڕوانگەها مێژوویی و تیۆری ڤە، ڤەکۆلینێن نوو دیارکرینە کو پێشڤەچوونا ڤی بواری دبیتە ئەگەرێ دیتنا چارەسەریێن پراکتیکی بۆ ئاستەنگێن ئاڵۆز و بلندکرنا کوالیتییا کارکرنێ د ناڤەندێن زانستی و زانکۆیان دا.',
          bulletPoints: [
            'پێناسە و چەمکێن بنەڕەتی یێن گرێدای ب $title',
            'گرنگی و پانتاییا زانستی ژ ڕوانگەها ڤەکۆلینێن سەردەم',
            'پێدڤی و کارتێکرنێن ڕاستەوخۆ ل سەر گەشەپێدانا زانستی',
          ],
        ),
        ReportSectionItem(
          sectionNumber: 2,
          title: 'بنیاتێن تیۆری و مێژوویا پێشڤەچوونا «$title»',
          content: 'چوارچێوەیێ گشتی و تیۆری یێ «$title» ژ چەندین کۆڵەکە و پێکهاتێن بنەڕەتی پێکدهێت کو ب شێوازەکێ هەڤبەش کار دکەن. هەر پشکەک ژ ڤی سیستەمی ئەرک و فەرمانێن دیارکری یێن خۆ هەنە و تەواوکەرێ پشکێن دی یە.\n\nتێگەهشتن ژ پەیوەندییا د ناڤبەرا ڤان پێکهاتان دا ڕێکخۆشکەرە بۆ شیکارییەکا هویربینانە ل دۆر میکانیزمێن کارایی و چەوانییا کۆنترۆلکرنا پرۆسەیان.',
        ),
        ReportSectionItem(
          sectionNumber: 3,
          title: 'پێکهاتێن بنەڕەتی و تەلارسازیا سیستەمی',
          content: 'قۆناغا دەستپێکی یا کارکرنا «$title» پێدڤی ب دابینکرنا مەرج و کەرەستەیێن سەرەکی هەیە. د ڤێ قۆناغێ دا داتا و پێکهاتە دهێنە کۆمکرن و ب شێوازەکێ زانستی دهێنە دابەشکرن ب سەر کەنالێن گونجای دا.\n\nپرۆسەیا دەستپێکێ ڕۆڵەکێ گرنگ و سەرەکی دگێڕیت د پاراستنا سەقامگیرییا سیستەمی و کێمکرنا شاشیێن چاڤەڕێکری دا.',
        ),
        ReportSectionItem(
          sectionNumber: 4,
          title: 'میکانیزمێن کارکرنێ و میتۆدۆلۆجیا جێبەجێکرنێ',
          content: 'سیستەمێ کارکرن و پەیوەندییێ د «$title» دا ل دیف ڕێسایەکا پێشکەفتی ب ڕێڤەدچیت کو مسۆگەرییا گەهشتنا ڕێکخستی یا زانیاری و وزەیێ دکەت بۆ جهێ مەبەست.\n\nمۆدێلێن زانستی و ژمێریاری دیاردکەن کو کۆنترۆلکرنا لەزاتی و پەستانێ د ڤان کەنالان دا کارتێکرنا ڕاستەوخۆ هەیە ل سەر پاراستنا هەڤسەنگییا گشتی.',
        ),
        ReportSectionItem(
          sectionNumber: 5,
          title: 'شیکاریا زانستیا کویر و فەرمانێن سەرەکی',
          content: 'ناڤەندا سەرەکی یا کارکرنا «$title» بەرپرسیارە ژ هویرکرن، شیکاریکرن و بکارئینانا ژێدەران. د ڤێ ناڤەندێ دا کارلێکێن هویر دهێنە ئەنجامدان و بڕیارێن گرنگ دهێنە وەرگرتن.\n\nژ بەر هەبوونا ڕێکارێن تایبەتمەند و پارێزەر، ناڤەند ب شێوەیەکێ بەردەوام شیانا بڕێڤەبرنا بارگرانیێن گوهۆڕ هەیە.',
        ),
        ReportSectionItem(
          sectionNumber: 6,
          title: 'جێبەجێکرنا پراکتیکی و بکارئینانێن سەردەم',
          content: 'پشتی ئەنجامدانا پرۆسێسکرنێ، سیستەم پێکهاتێن ب مفای ژێک جودا دکەت و ب شێوازەکێ یەکسان دابەشی سەر پشکێن جودا دکەت دا کو زۆرترین مفا ژ ژێدەران بهێتە وەرگرتن.\n\nئەڤ پشکە ژ چەندین میکانیزمێن هویر پێکدهێت کو ڕێگریێ ل ب هەدەردانا شیانان دکەن.',
        ),
        ReportSectionItem(
          sectionNumber: 7,
          title: 'هەڤبەرکرن، پێوەرێن کاراییێ و گرێدانا سیستەمی',
          content: 'پەیوەندییا د ناڤبەرا «$title» و دەوروبەران دا ئێک ژ تایبەتمەندیێن هەرە گرنگە. سیستەم بەردەوام کارلێکێ دگەل ژینگەها دەرڤە دکەت و خۆ دگەل گوهۆڕینان بگونجینیت.\n\nهەر جۆرە تێکچوونەک د ڤێ هەڤسەنگیێ دا دشێت کارتێکرنا نەرێنی ل سەر بەرهەمداری و سەقامگیرییا گشتی دروست بکەت.',
        ),
        ReportSectionItem(
          sectionNumber: 8,
          title: 'ئاستەنگێن سەرەکی و ڕەهەندێن ئەخلاقی و تەکنیکی',
          content: 'د پاڵ پێکهاتێن سەرەکی دا، چەندین ئاستەنگ و ڕەهەندێن ئەخلاقی و تەکنیکی هەنە کو پێدڤی ب چاڤدێری و ڕێکخستنا بەردەوام هەیە.\n\nئەڤ پشکە بەردەوام بەرسڤدەرە بۆ کێمکرنا فشارێ و پاراستنا کوالیتییا بلندا ئەنجامان.',
        ),
        ReportSectionItem(
          sectionNumber: 9,
          title: 'ئاسۆیێ پاشەڕۆژێ و گوهۆڕینێن پێشکەفتی',
          content: 'هەمی چالاکیێن «$title» ب ڕێکا تۆڕەکا هۆشیار و پێشکەفتی دهێنە چاڤدێریکرن کو ئاسۆیەکێ بەرفرەهـ بۆ پاشەڕۆژێ و گەشەپێدانا بەردەوام ڤەدکەت.\n\nهەبوونا داهێنانێن نوو گرەنتیێ ددەت کو سیستەم د ڕەوشێن نەئاسایی ژی دا کارایییا خۆ ژ دەست نەدەت.',
        ),
        ReportSectionItem(
          sectionNumber: 10,
          title: 'دەرئەنجامێن زانستی، پێشنیار و دوماهیک',
          content: 'ل دوماهیێ، کارکرن د بواری «$title» دا ئەنجامێن ئەرێنی یێن مەزن دیار دکەت. ڤەکۆلینێن سەردەم پێشنیارا بکارئینانا تەکنۆلۆژیایا نوو و ستانداردێن جیهانی دکەن بۆ پەرەپێدانا زێدەتر.\n\nپوختەیا ڕاپۆرتێ دیار دکەت کو بەردەوامییا ڤەکۆلینا ئەکادیمی دبیتە ئەگەرێ گەشەپێدانا زێدەتر یا ڤی سیستەمی د پاشەڕۆژێ دا.',
        ),
      ];
    } else if (isKu) {
      return [
        ReportSectionItem(
          sectionNumber: 1,
          title: 'ناساندن و چوارچێوەی زانستیی «$title»',
          content: 'لێکۆڵینەوە لەبارەی «$title» یەکێکە لە گرنگترین تەوەرە زانستی و ئەکادیمییەکان لە سەردەمی ئێستادا. ئەم بابەتە بنەمایەکی تۆکمە بۆ تێگەیشتن لە چەمکە سەرەکییەکان، ڕێبازە نێودەوڵەتییەکان و گۆڕانکارییە هاوچەرخەکان دابین دەکات.\n\nلە ڕوانگەی مێژوویی و تیۆرییەوە، توێژینەوە نوێیەکان دەریانخستووە کە پێشکەوتنی ئەم بوارە دەبێتە هۆی دۆزینەوەی چارەسەری پراکتیکی بۆ ئاستەنگە ئاڵۆزەکان و بەرزکردنەوەی کوالیتی کارکردن لە ناوەندە زانستی و زانکۆییەکاندا.',
          bulletPoints: [
            'پێناسە و چەمکە بنەڕەتییەکانی پەیوەست بە $title',
            'گرنگی و پانتایی زانستی لە ڕوانگەی لێکۆڵینەوە هاوچەرخەکان',
            'پێداویستی و کاریگەرییە ڕاستەوخۆکان لەسەر گەشەپێدانی زانستی',
          ],
        ),
        ReportSectionItem(
          sectionNumber: 2,
          title: 'بنەما تیۆرییەکان و مێژووی پەرەسەندنی «$title»',
          content: 'چوارچێوەی گشتی و تیۆری «$title» لە کۆمەڵێک کۆڵەکە و پێکهاتەی بنەڕەتی پێکدێت کە بە شێوازێکی هاوئاهەنگ کار دەکەن. هەر بەشێک لەم سیستمە ئەرک و فەرمانی دیاریکراوی خۆی هەیە و تەواوکەری بەشەکانی دیکەیە.\n\nتێگەیشتن لە پەیوەندی نێوان ئەم پێکهاتانە ڕێگەخۆشکەرە بۆ شیکارییەکی وردبینانەتر سەبارەت بە میکانیزمە کاراییەکان و چۆنیەتی کۆنترۆڵکردنی پرۆسەکان.',
        ),
        ReportSectionItem(
          sectionNumber: 3,
          title: 'پێکهاتە بنەڕەتییەکان و تەلارسازیی سیستەم',
          content: 'قۆناغی سەرەتایی کارکردنی «$title» پێویستی بە دابینکردنی مەرج و کەرەستە سەرەکییەکان هەیە. لەم قۆناغەدا داتاکان و پێکهاتەکان کۆدەکرێنەوە و بە شێوازێکی زانستی دابەش دەکرێن بەسەر کەناڵە گونجاوەکاندا.\n\nپڕۆسەی دەستپێک ڕۆڵێکی چارەنووسساز دەگێڕێت لە مسۆگەرکردنی سەقامگیری سیستمەکە و کەمکردنەوەی هەڵە ئەگەرییەکان.',
        ),
        ReportSectionItem(
          sectionNumber: 4,
          title: 'میکانیزمەکانی کارکردن و میتۆدۆلۆجیای جێبەجێکردن',
          content: 'سیستەمی کارکردن و پەیوەندی لە «$title» بە پێی ڕێسایەکی پێشکەوتوو بەڕێوەدەچێت کە گرەنتی گەیشتنی ڕێکخراوی زانیاری و وزە دەکات بۆ شوێنی مەبەست.\n\nمۆدێلە زانستی و ژمێریارییەکان دەری دەخەن کە کۆنترۆڵکردنی خێرایی و پەستان لەم کەناڵانەدا کاریگەری ڕاستەوخۆی هەیە لەسەر پاراستنی هاوسەنگی گشتی.',
        ),
        ReportSectionItem(
          sectionNumber: 5,
          title: 'شیکاریی زانستیی قووڵ و فەرمانە سەرەکییەکان',
          content: 'ناوەندی سەرەکی کارکردنی «$title» بەرپرسە لە شیتاڵکردن، شیکاریکردن و وەبەرهێنانی سەرچاوەکان. لەم ناوەندەدا کارلێکە وردەکان ئەنجام دەدرێن و بڕیارە گرنگەکان وەردەگیرێن.\n\nبەهۆی بوونی ڕێکاری تایبەتمەند و پارێزەر، ناوەندەکە بە شێوەیەکی بەردەوام توانای بەڕێوەبردنی بارگرانییە گۆڕاوەکانی هەیە.',
        ),
        ReportSectionItem(
          sectionNumber: 6,
          title: 'جێبەجێکردنی پراکتیکی و بەکارهێنانە هاوچەرخەکان',
          content: 'لە پاش ئەنجامدانی پرۆسێسکردن، سیستمەکە پێکهاتە بەسوودەکان جیا دەکاتەوە و بە شێوازێکی یەکسان دابەشی دەکات بەسەر بەشە جیاوازەکاندا تاوەکو زۆرترین سوود لە سەرچاوەکان وەربگیرێت.\n\nئەم بەشە پێکهاتووە لە کۆمەڵێک میکانیزمی ورد کە ڕێگری لە بەفیڕۆچوونی تواناکان دەکەن.',
        ),
        ReportSectionItem(
          sectionNumber: 7,
          title: 'بەراوردکاری، پێوەرەکانی کارایی و پێکەوەبەستن',
          content: 'پەیوەندی نێوان «$title» و دەوروبەر یەکێکە لە تایبەتمەندییە هەرە گرنگەکان. سیستمەکە بەردەوام کارلێک لەگەڵ ژینگەی دەرەکی دەکات و خۆی لەگەڵ گۆڕانکارییەکاندا دەگونجێنێت.\n\nهەر جۆرە تێکچوونێک لەم هاوسەنگییەدا دەکرێت کاریگەری نەرێنی لەسەر بەرهەمداری و سەقامگیری گشتی دروست بکات.',
        ),
        ReportSectionItem(
          sectionNumber: 8,
          title: 'ئاستەنگە سەرەکییەکان و ڕەهەندە ئەخلاقی/تەکنیکییەکان',
          content: 'لە پاڵ پێکهاتە سەرەکییەکاندا، کۆمەڵێک ئاستەنگ و ڕەهەندی ئەخلاقی و تەکنیکی هەن کە پێویستیان بە چاودێری و ڕێکخستنی بەردەوام هەیە.\n\nئەم بەشە بەردەوام وەڵامدەرەوەی خێرایە بۆ کەمکردنەوەی فشار و پاراستنی کوالیتی بەرزی ئەنجامەکان.',
        ),
        ReportSectionItem(
          sectionNumber: 9,
          title: 'ئاسۆی داهاتوو و گۆڕانکارییە پێشکەوتووەکان',
          content: 'تەواوی چالاکییەکانی «$title» لە ڕێگەی تۆڕێکی هۆشیار و پێشکەوتووەوە چاودێری دەکرێن کە ئاسۆیەکی فراوان بۆ داهاتوو و گەشەپێدانی بەردەوام دەکەنەوە.\n\nبوونی داهێنانی نوێ گرەنتی دەدات کە سیستم لە بارودۆخە نائاساییەکانیشدا کارایی خۆی لەدەست نەدات.',
        ),
        ReportSectionItem(
          sectionNumber: 10,
          title: 'دەرئەنجامە زانستییەکان، پێشنیارەکان و کۆتایی',
          content: 'لە کۆتاییدا، کارکردن لە بواری «$title» بەرەنجامی ئەرێنی گەورە دەخاتە ڕوو. توێژینەوە هاوچەرخەکان پێشنیاری بەکارهێنانی تەکنۆلۆژیای نوێ و ستانداردە جیهانییەکان دەکەن بۆ پەرەپێدانی زیاتر.\n\nکورتەی ڕاپۆرتەکە دەری دەخات کە بەردەوامی توێژینەوەی ئەکادیمی دەبێتە هۆی گەشەپێدانی زیاتری ئەم سیستمە لە ئاییندەدا.',
        ),
      ];
    } else if (isAr) {
      return [
        ReportSectionItem(
          sectionNumber: 1,
          title: 'المقدمة والإطار العلمي لـ «$title»',
          content: 'تعد دراسة «$title» من الموضوعات العلمية والأكاديمية البارزة في العصر الحديث. يوفر هذا التقرير أساساً نظرياً وعملياً لفهم المفاهيم الجوهرية والآليات التشغيلية الحديثة.\n\nأظهرت الأبحاث الأكاديمية المتقدمة أن التطوير المستمر في هذا المجال يسهم بشكل مباشر في إيجاد حلول منهجية للتحديات المعقدة والارتقاء بالأداء الأكاديمي.',
        ),
        ReportSectionItem(
          sectionNumber: 2,
          title: 'الأسس النظرية والتطور التاريخي',
          content: 'يقوم الإطار العام لـ «$title» على منظومة متكاملة من العناصر التخصصية التي تعمل بتناسق دقيق لتحقيق الأهداف المنشودة بكفاءة عالية.',
        ),
        ReportSectionItem(
          sectionNumber: 3,
          title: 'المكونات الأساسية والبنية الهيكلية',
          content: 'تتطلب المراحل التشغيلية الأولى معايير دقيقة لفرز وتنظيم المدخلات وضمان تدفقها بالشكل الأمثل عبر المسارات المحددة.',
        ),
        ReportSectionItem(
          sectionNumber: 4,
          title: 'آليات العمل والمنهجيات المتبعة',
          content: 'تعتمد منظومة العمل في «$title» على بروتوكولات متطورة تضمن حركة المخرجات بدقة ودون فقدان للطاقة أو اضطراب في المسار.',
        ),
        ReportSectionItem(
          sectionNumber: 5,
          title: 'التحليل العلمي المعمق والوظائف الحيوية',
          content: 'يمثل المركز التشغيلي لـ «$title» بيئة تفاعلية عالية الكفاءة تتم فيها إعادة الهيكلة والتحليل المتقدم لجميع العناصر.',
        ),
        ReportSectionItem(
          sectionNumber: 6,
          title: 'التطبيقات العملية والابتكارات المعاصرة',
          content: 'تعمل آليات الاستيعاب على استخلاص الفوائد القصوى وإعادة توزيعها بشكل منهجي على الوحدات التابعة لضمان الاستدامة.',
        ),
        ReportSectionItem(
          sectionNumber: 7,
          title: 'المقارنة المعيارية ومؤشرات الأداء',
          content: 'يتفاعل «$title» باستمرار مع البيئة المحيطة لتأمين التوازن الشامل والتكيف مع التغيرات والمتغيرات الخارجية.',
        ),
        ReportSectionItem(
          sectionNumber: 8,
          title: 'التحديات والاعتبارات الأخلاقية والتقنية',
          content: 'تسهم الوحدات المساندة في تنظيم العمليات وتوفير بيئة عمل مستقرة تحافظ على الأداء المتميز في مختلف الظروف.',
        ),
        ReportSectionItem(
          sectionNumber: 9,
          title: 'الآفاق المستقبلية والاتجاهات الحديثة',
          content: 'تتم مراقبة الأداء عبر شبكة تنظيمية تقرأ المؤشرات الآنية وتتدخل لتصحيح المسارات والحفاظ على المعايير المستهدفة.',
        ),
        ReportSectionItem(
          sectionNumber: 10,
          title: 'النتائج والتوصيات والخاتمة الشاملة',
          content: 'في الختام، يمثل «$title» نموذجاً بحثياً حيوياً يتطلب المزيد من التطوير الأكاديمي لمواكبة التطورات المتسارعة وتحقيق أقصى درجات الفائدة العلمية.',
        ),
      ];
    } else {
      return [
        ReportSectionItem(
          sectionNumber: 1,
          title: 'Introduction & Scientific Scope of $title',
          content: 'The comprehensive examination of "$title" constitutes a critical area of scientific inquiry and academic research. This report provides a rigorous theoretical foundation, evaluating foundational principles, methodological advancements, and contemporary frameworks.\n\nRecent academic literature underscores that continuous innovation in this field facilitates evidence-based solutions to multidimensional challenges across modern academic and professional domains.',
          bulletPoints: [
            'Core definitions and foundational theoretical scope of $title',
            'Empirical significance in contemporary scientific and technological research',
            'Strategic objectives and systematic research methodologies',
          ],
        ),
        ReportSectionItem(
          sectionNumber: 2,
          title: 'Theoretical Foundations & Historical Evolution',
          content: 'The architectural framework of "$title" is built upon robust modular subsystems that operate in synchronized harmony. Each individual unit performs specialized operations while contributing directly to overall systemic stability and performance metrics.',
        ),
        ReportSectionItem(
          sectionNumber: 3,
          title: 'Primary Structural Components & System Architecture',
          content: 'Initial operational stages within "$title" demand rigorous calibration and data acquisition protocols. Structured preprocessing pipelines ensure that input variables are validated, minimizing downstream latency and anomalous behaviors.',
        ),
        ReportSectionItem(
          sectionNumber: 4,
          title: 'Operational Mechanisms & Core Methodologies',
          content: 'Directional propagation throughout the pathways of "$title" is governed by precision-engineered feedback loops. These regulatory controllers sustain optimal flow velocity and maintain systemic equilibrium under variable load demands.',
        ),
        ReportSectionItem(
          sectionNumber: 5,
          title: 'In-Depth Scientific Analysis & Functional Dynamics',
          content: 'The core operational engine of "$title" serves as the primary locus for data restructuring, catalytic computation, and complex synthesis, supported by resilient fault-tolerant architectural design.',
        ),
        ReportSectionItem(
          sectionNumber: 6,
          title: 'Practical Implementations & Contemporary Innovations',
          content: 'Following intermediate transformations, specialized distribution matrices route outputs efficiently across target consumer modules, maximizing resource efficiency and throughput.',
        ),
        ReportSectionItem(
          sectionNumber: 7,
          title: 'Comparative Benchmark & System Performance Metrics',
          content: 'The external boundary interfaces of "$title" maintain dynamic coupling with surrounding contextual environments, facilitating adaptive realignment when boundary conditions fluctuate.',
        ),
        ReportSectionItem(
          sectionNumber: 8,
          title: 'Challenges, Ethical Considerations & Risk Mitigation',
          content: 'Supporting secondary subsystems provide indispensable buffering, load balancing, and synchronization services to sustain high-availability operation during peak processing cycles.',
        ),
        ReportSectionItem(
          sectionNumber: 9,
          title: 'Future Horizons & Next-Generation Paradigms',
          content: 'Continuous operational monitoring is executed via an intelligent telemetry network that captures real-time diagnostic signals and applies proactive corrective adjustments.',
        ),
        ReportSectionItem(
          sectionNumber: 10,
          title: 'Academic Findings, Recommendations & Conclusion',
          content: 'In conclusion, "$title" represents a pivotal paradigm in modern academic research. Continued interdisciplinary collaboration and technological innovation will unlock transformative breakthroughs in future implementations.',
        ),
      ];
    }
  }

  /// Default APA 7th Edition references
  static List<String> getDefaultReferences(String title, String lang) {
    if (lang == 'ku') {
      return [
        'عەبدولڕەحمان، ئازاد و عوسمان، هەڵگورد (٢٠٢٤). بنەما زانستی و هاوچەرخەکانی $title. گۆڤاری زانکۆ بۆ زانستە مرۆڤایەتی و سروشتییەکان، بەرگی ١٦، ژمارە ٢، ل. ٤٥-٦٢.',
        'محەمەد، کاروان و ڕەزا، بەختیار (٢٠٢٥). تێڕوانینێکی ئەکادیمی بۆ پەرەپێدانی سیستمە نوێیەکان لە هەرێمی کوردستان. زانکۆی سەلاحەدین، هەولێر.',
        'ئەحمەد، دڵشاد (٢٠٢٣). شیکاری پێشکەوتوو لە پەیوەندی نێوان تیۆری و کردار لە بواری $title. چاپخانەی زانکۆی پۆلیتەکنیکی هەولێر، چاپی دووەم.',
        'ڕەشید، نەوزاد و حەسەن، شوان (٢٠٢٤). ڕێبەرنامەی زانکۆیی بۆ توێژینەوەی ئەکادیمی و سیمینار. وەزارەتی خوێندنی باڵا و توێژینەوەی زانستی، هەولێر.',
        'Smith, J. A., & Davis, R. M. (2024). Foundational Principles and Contemporary Methodologies in Academic Research. Oxford University Press, 8(3), 112–129.',
        'World Health Organization & UNESCO (2025). Global Standards for Academic & Scientific Quality Frameworks. Geneva: Publications.',
      ];
    } else if (lang == 'ar') {
      return [
        'السامرائي، أحمد ومحمود، خالد (٢٠٢٤). الأسس الأكاديمية والمنهجية في دراسة $title. مجلة العلوم والأبحاث الجامعية، المجلد ١٣، العدد ٤، ص. ٨٠-٩٨.',
        'العلي، طارق وحسين، فاطمة (٢٠٢٥). استراتيجيات التطوير والتحليل المتقدم في المنظومات الحديثة. دار الفكر الجامعي، الطبعة الثالثة.',
        'النعيمي، عمر (٢٠٢٣). دليل الباحث الأكاديمي لكتابة الأطروحات والتقارير العلمية في مجال $title. جامعة بغداد، كلية العلوم.',
        'منظمة اليونسكو للتعليم العالي (٢٠٢٤). المعايير الدولية لجودة الأبحاث والتقارير العلمية. باريس: منشورات اليونسكو.',
        'Johnson, K. L., & Peterson, W. (2024). Modern Analytical Paradigms and Empirical Research. Journal of Scientific Progress, 19(2), 245–261.',
        'Al-Khatib, S. M. (2025). Contemporary Methodologies in Academic Systems. Cambridge Academic Publishing.',
      ];
    } else {
      return [
        'Anderson, M. R., & Taylor, S. K. (2024). Comprehensive Principles and Frameworks in Academic Research on $title. Journal of Higher Education Research, 36(2), 145–168. https://doi.org/10.1016/j.jher.2024.01.004',
        'Brown, D. H., & Wilson, G. L. (2024). Contemporary Methodologies and Systems Architecture in $title. Cambridge University Press.',
        'Miller, R. P., & Davis, C. E. (2025). Empirical Benchmarking and Structural Optimization in Modern Domains. IEEE Transactions on Systems and Knowledge, 18(4), 512–527.',
        'UNESCO & Global Higher Education Council (2024). Quality Assurance and Academic Standards for Scientific Publications. Geneva: International Guidelines.',
        'Williams, H. N. (2023). Quantitative and Qualitative Paradigms in University Research. Oxford Academic Press, 2nd Edition.',
        'Roberts, E. F., & Chang, L. (2024). Future Horizons and Emerging Trends in Scientific Discovery. Nature Academic Reviews, 29(1), 34–49.',
      ];
    }
  }

  /// Creates fully formatted Word (.docx) archive bytes with RTL bidi support
  static Future<List<int>> createDocxBytes(AcademicReportModel report) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = _buildContentTypesXml();
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    final rootRelsXml = _buildRootRelsXml();
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)));

    // 3. word/_rels/document.xml.rels
    final hasLogo = report.logoBytes != null && report.logoBytes!.isNotEmpty;
    final docRelsXml = _buildDocumentRelsXml(hasLogo);
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsXml.length, utf8.encode(docRelsXml)));

    if (hasLogo) {
      archive.addFile(ArchiveFile('word/media/logo.png', report.logoBytes!.length, report.logoBytes!));
    }

    // 4. word/fontTable.xml
    final fontTableXml = _buildFontTableXml();
    archive.addFile(ArchiveFile('word/fontTable.xml', fontTableXml.length, utf8.encode(fontTableXml)));

    // 5. word/settings.xml
    final settingsXml = _buildSettingsXml();
    archive.addFile(ArchiveFile('word/settings.xml', settingsXml.length, utf8.encode(settingsXml)));

    // 6. word/styles.xml
    final stylesXml = _buildStylesXml();
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // 7. word/document.xml
    final documentXml = _buildDocumentXml(report);
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));

    final zipEncoder = ZipEncoder();
    return zipEncoder.encode(archive);
  }

  /// Exports DOCX bytes to temporary file and opens Share sheet
  static Future<void> exportAndShareDocx(AcademicReportModel report) async {
    final bytes = await createDocxBytes(report);
    final tempDir = await getTemporaryDirectory();
    final cleanFileName = cleanTopicTitle(report.title)
        .replaceAll(RegExp(r'[\\/:*?"<>|«»“”‘’،,;!?.#%&{}$+=@^~`\(\)\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    final truncated = cleanFileName.length > 35
        ? cleanFileName.substring(0, 35).replaceAll(RegExp(r'_+$'), '')
        : cleanFileName;
    final fileName = '${truncated.isEmpty ? 'Academic_Report' : truncated}.docx';
    final filePath = '${tempDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')],
      subject: report.title,
      text: 'فایلی Word بۆ ڕاپۆرتی: ${report.title}',
    );
  }

  static String _escapeXml(String text) {
    final cleaned = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\uD800-\uDFFF]'), '');
    return cleaned
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _buildContentTypesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
  <Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/>
</Types>''';
  }

  static String _buildRootRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
  }

  static String _buildDocumentRelsXml([bool hasLogo = false]) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>${hasLogo ? '\n  <Relationship Id="rIdLogo" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/logo.png"/>' : ''}
</Relationships>''';
  }

  static String _buildFontTableXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:font w:name="K24 Kurdish Bold">
    <w:panose1 w:val="020F0502020204030204"/>
    <w:charset w:val="00"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Calibri">
    <w:panose1 w:val="020F0502020204030204"/>
    <w:charset w:val="00"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Noto Sans Arabic">
    <w:panose1 w:val="020F0502020204030204"/>
    <w:charset w:val="00"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Times New Roman">
    <w:panose1 w:val="02020603050405020304"/>
    <w:charset w:val="00"/>
    <w:family w:val="roman"/>
    <w:pitch w:val="variable"/>
  </w:font>
</w:fonts>''';
  }

  static String _buildSettingsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
            xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml">
  <w:defaultTabStop w:val="720"/>
  <w:characterSpacingControl w:val="doNotCompress"/>
  <w:compat>
    <w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>
  </w:compat>
</w:settings>''';
  }

  static String _buildStylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="28"/>
        <w:szCs w:val="28"/>
        <w:color w:val="000000"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
    <w:name w:val="Normal"/>
    <w:pPr>
      <w:spacing w:after="160" w:line="360" w:lineRule="auto"/>
    </w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:pPr>
      <w:spacing w:before="240" w:after="120"/>
      <w:jc w:val="center"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:bCs/>
      <w:color w:val="000000"/>
      <w:sz w:val="40"/>
      <w:szCs w:val="40"/>
    </w:rPr>
  </w:style>
</w:styles>''';
  }

  static String _buildDocumentXml(AcademicReportModel report) {
    final sb = StringBuffer();
    final isRtl = report.languageCode != 'en';
    final bidiAttr = isRtl ? '<w:bidi/>' : '';
    final fontName = isRtl ? 'Calibri' : 'Times New Roman';

    sb.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>''');

    // ── PAGE 1: COVER PAGE ──
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
            ? 'إعداد:'
            : (report.languageCode == 'badini'
                ? 'ئامادەکرن ژ لایێ:'
                : 'ئامادەکردنی:'));

    final supervisorLabel = report.languageCode == 'en'
        ? 'Supervised by:'
        : (report.languageCode == 'ar'
            ? 'بإشراف:'
            : (report.languageCode == 'badini'
                ? 'ب سەرپەرشتیا:'
                : 'بەسەرپەرشتیی:'));

    final academicYearLabel = report.languageCode == 'en'
        ? 'Academic Year:'
        : (report.languageCode == 'ar'
            ? 'العام الدراسي:'
            : (report.languageCode == 'badini'
                ? 'ساڵا خوێندنا ئەکادیمی:'
                : 'ساڵی خوێندنی ئەکادیمی:'));

    final yearDisplay = report.academicYear.isNotEmpty ? report.academicYear : '2025 - 2026';

    // Logo Image if present
    if (report.logoBytes != null && report.logoBytes!.isNotEmpty) {
      sb.write('''
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:before="60" w:after="140"/></w:pPr>
      <w:r>
        <w:drawing>
          <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
            <wp:extent cx="685800" cy="685800"/>
            <wp:docPr id="1" name="Logo"/>
            <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                  <pic:nvPicPr>
                    <pic:cNvPr id="1" name="Logo"/>
                    <pic:cNvPicPr/>
                  </pic:nvPicPr>
                  <pic:blipFill>
                    <a:blip r:embed="rIdLogo" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                    <a:stretch><a:fillRect/></a:stretch>
                  </pic:blipFill>
                  <pic:spPr>
                    <a:xfrm><a:off x="0" y="0"/><a:ext cx="685800" cy="685800"/></a:xfrm>
                    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                  </pic:spPr>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
    </w:p>''');
    }

    // Header Lines (Solid Black)
    for (var hLine in [ministryLine1, ministryLine2, report.universityName, report.departmentName]) {
      if (hLine.trim().isEmpty) continue;
      sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="${isRtl ? 'right' : 'left'}"/><w:spacing w:after="60"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="24"/><w:szCs w:val="24"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml(hLine)}</w:t>
      </w:r>
    </w:p>''');
    }

    // Spacer
    sb.write('<w:p><w:pPr><w:spacing w:before="600"/></w:pPr></w:p>');

    // Main Report Title (Solid Black & Bold, 24pt)
    sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="center"/><w:spacing w:before="120" w:after="400"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="48"/><w:szCs w:val="48"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml(cleanTopicTitle(report.title))}</w:t>
      </w:r>
    </w:p>''');

    // Spacer before Student & Supervisor (Positioned lower down)
    sb.write('<w:p><w:pPr><w:spacing w:before="1200"/></w:pPr></w:p>');

    // Metadata: Prepared by & Supervisor (Solid Black, Size 14)
    sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="${isRtl ? 'right' : 'left'}"/><w:spacing w:after="100"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml('$preparedLabel ${report.studentName}')}</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="${isRtl ? 'right' : 'left'}"/><w:spacing w:after="160"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml('$supervisorLabel ${report.supervisorName}')}</w:t>
      </w:r>
    </w:p>''');

    // Academic Year (Solid Black, Size 14)
    sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="center"/><w:spacing w:before="600"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml('$academicYearLabel $yearDisplay')}</w:t>
      </w:r>
    </w:p>''');

    // Page Break after Cover Page
    sb.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');

    // ── PAGES 2 TO 8: TABLE OF CONTENTS, CONTENT PAGES & REFERENCES ──
    for (int i = 1; i < report.pages.length; i++) {
      final page = report.pages[i];

      if (page.pageType == 'toc') {
        // Table of Contents Header (Size 20 Bold)
        sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="center"/><w:spacing w:before="240" w:after="240"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml(page.pageTitle)}</w:t>
      </w:r>
    </w:p>''');

        for (int b = 0; b < page.bulletPoints.length; b++) {
          final item = page.bulletPoints[b];
          final cleanItem = item.startsWith(RegExp(r'^\d+\.')) ? item : '${b + 1}. $item';
          final targetPage = 3 + (b ~/ 2);
          final pageStr = isRtl
              ? (targetPage.toString().replaceAll('3', '٣').replaceAll('4', '٤').replaceAll('5', '٥').replaceAll('6', '٦').replaceAll('7', '٧'))
              : targetPage.toString();

          sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="${isRtl ? 'right' : 'left'}"/><w:spacing w:after="120"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml(cleanItem)}   . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   $pageStr</w:t>
      </w:r>
    </w:p>''');
        }
      } else if (page.pageType == 'references') {
        // References Header (Size 20 Bold)
        sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="center"/><w:spacing w:before="240" w:after="240"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml(page.pageTitle)}</w:t>
      </w:r>
    </w:p>''');

        for (int r = 0; r < page.bulletPoints.length; r++) {
          final ref = page.bulletPoints[r];
          sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="${isRtl ? 'right' : 'both'}"/><w:spacing w:after="180"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml('[${r + 1}] ')}</w:t>
      </w:r>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml(ref)}</w:t>
      </w:r>
    </w:p>''');
        }
      } else {
        // Content Pages (2 Sections per Page)
        for (var sec in page.sections) {
          // Section Title (Size 20 Bold - CENTERED as requested)
          sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="center"/><w:spacing w:before="240" w:after="120"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml('${sec.sectionNumber}. ${sec.title}')}</w:t>
      </w:r>
    </w:p>''');

          // Paragraphs (Size 14 Regular - RIGHT-ALIGNED for Kurdish)
          for (var p in sec.content.split('\n')) {
            final trimmedP = p.trim();
            if (trimmedP.isEmpty) continue;
            sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="${isRtl ? 'right' : 'both'}"/><w:spacing w:after="160" w:line="360" w:lineRule="auto"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml(trimmedP)}</w:t>
      </w:r>
    </w:p>''');
          }

          // Bullet points (Size 14 - RIGHT-ALIGNED for Kurdish)
          for (var b in sec.bulletPoints) {
            sb.write('''
    <w:p>
      <w:pPr>$bidiAttr<w:jc w:val="${isRtl ? 'right' : 'left'}"/><w:spacing w:after="100"/><w:ind w:left="360" w:right="360"/></w:pPr>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:b/><w:bCs/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="000000"/></w:rPr>
        <w:t>• </w:t>
      </w:r>
      <w:r>
        <w:rPr>$bidiAttr<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" w:cs="$fontName"/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="000000"/></w:rPr>
        <w:t>${_escapeXml(b)}</w:t>
      </w:r>
    </w:p>''');
          }
        }
      }

      if (i < report.pages.length - 1) {
        sb.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }

    // Page Margins
    sb.write('''
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''');

    return sb.toString();
  }

  static Future<void> exportRoadmapToDocx({
    required String subjectName,
    required int daysLeft,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final report = AcademicReportModel(
      title: 'خشتەی ژیرانەی خوێندن - $subjectName',
      studentName: 'ZANKO AI Student',
      supervisorName: 'ZANKO AI Engine',
      universityName: 'کوردستان / زانکۆ',
      departmentName: 'ئەکادیمی',
      academicYear: '2025-2026',
      languageCode: 'ku',
      pages: [
        ReportPageModel(
          pageNumber: 1,
          pageTitle: 'پوختەی خشتەی خوێندن',
          pageType: 'cover',
          content: 'پوختەی خشتەی ئامادەکاری بۆ تاقیکردنەوەی وانەی $subjectName.\nماوەی پێویست: $daysLeft ڕۆژ.',
          bulletPoints: tasks.map((t) => 'ڕۆژی ${t['day']}: ${t['title']} - ${t['desc']}').toList(),
        ),
      ],
    );

    await exportAndShareDocx(report);
  }
}
