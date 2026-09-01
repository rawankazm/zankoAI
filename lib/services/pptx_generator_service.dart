import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'pptx_template_data.dart';

class SlideModel {
  final String title;
  final List<String> bulletPoints;
  final String? visualPrompt;
  final String? speakerNotes;
  final String? imageUrl;
  final String? categoryTag;

  SlideModel({
    required this.title,
    required this.bulletPoints,
    this.visualPrompt,
    this.speakerNotes,
    this.imageUrl,
    this.categoryTag,
  });
}

class PptxGeneratorService {
  /// Gets a distinct curated high-quality image URL for each slide based on topic and slide index
  static String getSlideSpecificImageUrl(String topic, int slideIndex) {
    final t = topic.toLowerCase();

    // 1. Medicine & Healthcare
    if (t.contains('پزیشک') || t.contains('med') || t.contains('health') || t.contains('دکتۆر') || t.contains('نەخۆش') || t.contains('طب') || t.contains('صحة')) {
      final images = [
        'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1532938911079-1b06ac7ceec7?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1581093458791-9f3c3900df4b?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1582750433449-648ed127bb54?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=800&auto=format&fit=crop&q=80',
      ];
      return images[(slideIndex - 1).clamp(0, images.length - 1)];
    }

    // 2. Cybersecurity & Networks
    if (t.contains('سایبەر') || t.contains('سکیوریتی') || t.contains('security') || t.contains('cyber') || t.contains('network') || t.contains('أمن')) {
      final images = [
        'https://images.unsplash.com/photo-1563986768609-322da13575f3?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1510511459019-5dda7724fd87?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=800&auto=format&fit=crop&q=80',
      ];
      return images[(slideIndex - 1).clamp(0, images.length - 1)];
    }

    // 3. AI & Computer Science
    if (t.contains('ژیری') || t.contains('ai') || t.contains('intelligence') || t.contains('کۆمپیوتەر') || t.contains('computer') || t.contains('ذكاء') || t.contains('تەکنەلۆجیا')) {
      final images = [
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1531482615713-2afd69097998?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=800&auto=format&fit=crop&q=80',
      ];
      return images[(slideIndex - 1).clamp(0, images.length - 1)];
    }

    // 4. Cloud & Big Data
    if (t.contains('کلاود') || t.contains('cloud') || t.contains('data') || t.contains('داتا') || t.contains('ئامار') || t.contains('بیانات')) {
      final images = [
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1504868584819-f8e8b4b6d7e3?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=800&auto=format&fit=crop&q=80',
      ];
      return images[(slideIndex - 1).clamp(0, images.length - 1)];
    }

    // 5. Law & Justice
    if (t.contains('یاسا') || t.contains('law') || t.contains('داد') || t.contains('justice') || t.contains('قانون') || t.contains('حقوق')) {
      final images = [
        'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1450133064473-71024230f91b?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1453728013993-6d66e9c9123a?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=800&auto=format&fit=crop&q=80',
      ];
      return images[(slideIndex - 1).clamp(0, images.length - 1)];
    }

    // 6. Engineering & Science
    if (t.contains('ئەندازیار') || t.contains('engineering') || t.contains('بیناسازی') || t.contains('هندسة')) {
      final images = [
        'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1581092335397-9583fe92d232?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1581092580497-e0d23cbdf1dc?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=800&auto=format&fit=crop&q=80',
      ];
      return images[(slideIndex - 1).clamp(0, images.length - 1)];
    }

    // 7. Business & Management
    if (t.contains('کارگێڕی') || t.contains('business') || t.contains('ئابووری') || t.contains('ژمێریاری') || t.contains('إدارة') || t.contains('اقتصاد')) {
      final images = [
        'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1531482615713-2afd69097998?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=800&auto=format&fit=crop&q=80',
      ];
      return images[(slideIndex - 1).clamp(0, images.length - 1)];
    }

    // General / Canva Academic Default
    final defaultImages = [
      'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=800&auto=format&fit=crop&q=80',
    ];
    return defaultImages[(slideIndex - 1).clamp(0, defaultImages.length - 1)];
  }

  /// Parses markdown or plain text AI output into structured SlideModel items
  static List<SlideModel> parseSlidesFromText(String rawText, {String? defaultTitle}) {
    final List<SlideModel> slides = [];
    final lines = rawText.split('\n');

    String currentTitle = '';
    List<String> currentBullets = [];
    String currentVisual = '';
    String currentNotes = '';
    bool inSlide = false;
    int slideCounter = 1;

    void saveCurrentSlide() {
      if (currentTitle.isNotEmpty || currentBullets.isNotEmpty) {
        final assignedTitle = currentTitle.isNotEmpty ? currentTitle : (defaultTitle ?? 'سلايد');
        final assignedImg = getSlideSpecificImageUrl(defaultTitle ?? assignedTitle, slideCounter);
        slides.add(SlideModel(
          title: assignedTitle,
          bulletPoints: List.from(currentBullets),
          visualPrompt: currentVisual.isNotEmpty ? currentVisual : null,
          speakerNotes: currentNotes.isNotEmpty ? currentNotes : null,
          imageUrl: assignedImg,
          categoryTag: 'Canva / PPT Template',
        ));
        slideCounter++;
      }
      currentTitle = '';
      currentBullets = [];
      currentVisual = '';
      currentNotes = '';
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip top-level document headers like "# 💡 بابەتی سیمینار" or "# Presentation Title"
      if (trimmed.startsWith('# ') && !RegExp(r'(سلاید|سلايد|Slide|الشريحة)', caseSensitive: false).hasMatch(trimmed)) {
        continue;
      }

      // Detect explicit slide headers e.g. "### 🔹 سلایدی ١: ناساندن", "### Slide 1: Title", "1️⃣ سلایدی یەکەم:", "## Slide 1", "**سلایدی ١: ...**"
      final isExplicitSlideKeyword = RegExp(
        r'^(#{1,4}\s*)?(🔹|🔸|▪️|▫️|🔻|\d+️⃣)?\s*(\*\*)?(سلایدی|سلايد|Slide|الشريحة)\s*(\d+|[٠-٩]+|[١-٩]+|یەکەم|دووەم|سێیەم|چوارەم|پێنجەم|شەشەم|حەوتەم|هەشتەم|الأول|الثاني|الثالث|الرابع|الخامس|السادس|السابع|الثامن)?\s*[:\-–\.]?\s*',
        caseSensitive: false,
      ).hasMatch(trimmed);

      final isMarkdownSlideHeading = RegExp(r'^#{2,3}\s+', caseSensitive: false).hasMatch(trimmed) &&
          (trimmed.contains('سلاید') || trimmed.contains('Slide') || trimmed.contains('سلايد') || trimmed.contains('الشريحة') || trimmed.contains('🔹') || trimmed.contains('🔸') || RegExp(r'\b(Slide\s*\d+)\b', caseSensitive: false).hasMatch(trimmed));

      final isSlideHeader = isExplicitSlideKeyword || isMarkdownSlideHeading;

      if (isSlideHeader) {
        if (inSlide) {
          saveCurrentSlide();
        }
        inSlide = true;
        
        // Extract title
        String cleanTitle = trimmed
            .replaceAll(RegExp(r'^#+\s*'), '')
            .replaceAll(RegExp(r'^(🔹|🔸|▪️|▫️|🔻|\d+️⃣)\s*'), '')
            .replaceAll(RegExp(r'^(سلایدی|سلايد|Slide|الشريحة)\s*(\d+|[٠-٩]+|[١-٩]+|یەکەم|دووەم|سێیەم|چوارەم|پێنجەم|شەشەم|حەوتەم|هەشتەم)?[:\-–\.]?\s*', caseSensitive: false), '')
            .replaceAll('**', '')
            .replaceAll('*', '')
            .trim();

        currentTitle = cleanTitle.isNotEmpty ? cleanTitle : 'سلاید';
        continue;
      }

      // Detect slide title explicit line
      if (trimmed.startsWith('- **ناونیشان') || trimmed.startsWith('- **ناونیشانی سەرەکی**:') || trimmed.startsWith('- **Title**:') || trimmed.startsWith('- **العنوان**:')) {
        final titleVal = trimmed.split(':').sublist(1).join(':').replaceAll('**', '').replaceAll('*', '').trim();
        if (titleVal.isNotEmpty) {
          currentTitle = titleVal;
        }
        continue;
      }

      // Detect Visual / Diagram / Image suggestion
      if (trimmed.contains('🖼️') || trimmed.contains('وێنە') || trimmed.contains('دایەگرام') || trimmed.contains('Diagram') || trimmed.contains('Visual') || trimmed.contains('صورة') || trimmed.contains('مخطط')) {
        final visualVal = trimmed
            .replaceAll(RegExp(r'^[-*]\s*'), '')
            .replaceAll(RegExp(r'.*وێنە.*?:', caseSensitive: false), '')
            .replaceAll(RegExp(r'.*Visual.*?:', caseSensitive: false), '')
            .replaceAll(RegExp(r'.*صورة.*?:', caseSensitive: false), '')
            .replaceAll('🖼️', '')
            .replaceAll('**', '')
            .trim();
        if (visualVal.isNotEmpty) {
          currentVisual = visualVal;
        }
        continue;
      }

      // Detect speaker notes
      if (trimmed.contains('تێبینی پێشکەشکار') || trimmed.contains('Speaker Note') || trimmed.contains('ملاحظات المتحدث') || trimmed.contains('🎙️')) {
        final noteVal = trimmed
            .replaceAll(RegExp(r'^[-*]\s*'), '')
            .replaceAll(RegExp(r'.*تێبینی پێشکەشکار.*?:', caseSensitive: false), '')
            .replaceAll(RegExp(r'.*Speaker Note.*?:', caseSensitive: false), '')
            .replaceAll(RegExp(r'.*ملاحظات المتحدث.*?:', caseSensitive: false), '')
            .replaceAll('🎙️', '')
            .replaceAll('"', '')
            .replaceAll('**', '')
            .trim();
        if (noteVal.isNotEmpty) {
          currentNotes = noteVal;
        }
        continue;
      }

      // Detect bullet points & sentences
      if (trimmed.startsWith('-') || trimmed.startsWith('*') || trimmed.startsWith('•') || RegExp(r'^\d+\.').hasMatch(trimmed)) {
        final bulletText = trimmed
            .replaceAll(RegExp(r'^[-*•]\s*'), '')
            .replaceAll(RegExp(r'^\d+\.\s*'), '')
            .replaceAll('**', '')
            .replaceAll('*', '')
            .trim();

        if (bulletText.isNotEmpty &&
            !bulletText.startsWith('خاڵە سەرەکییەکان') &&
            !bulletText.startsWith('پێشنیاری دیزاین') &&
            !bulletText.startsWith('Design Suggestion')) {
          currentBullets.add(bulletText);
        }
        continue;
      }
    }

    if (inSlide) {
      saveCurrentSlide();
    }

    // Fallback if parsing didn't catch separate slides
    if (slides.isEmpty) {
      final safeTitle = defaultTitle ?? 'پرێزێنتەیشنی سیمینار';
      slides.add(SlideModel(
        title: safeTitle,
        bulletPoints: [
          'پێناسەی سەرەکی و گرنگیی زانستی بابەتەکە',
          'ئامانجەکان و شیکاریی داتای توێژینەوە',
          'دەرئەنجامەکان و پێشنیار بۆ ئاییندە',
        ],
        visualPrompt: 'وێنەی بەرگی سەرەکی و هێڵکاریی چەمکەکان',
        speakerNotes: 'تێبینی دەستپێکی سیمینار بۆ پێشکەشکار',
        imageUrl: getSlideSpecificImageUrl(safeTitle, 1),
      ));
    }

    return slides;
  }

  /// Downloads image bytes from URL with fallback to generated valid PNG bytes
  static Future<List<int>> _fetchOrGenerateImageBytes(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (prev, element) => prev..addAll(element));
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {}
    return _getFallbackImageBytes();
  }

  /// Generates a valid 1x1 colored PNG pixel byte buffer as fallback
  static List<int> _getFallbackImageBytes() {
    return [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ];
  }

  /// Generates a valid OpenXML PowerPoint (.pptx) file with real embedded images and Kurdish/Arabic Calibri fonts
  static Future<List<int>> createPptxBytes(
    List<SlideModel> slides, {
    required String presentationTitle,
    String languageCode = 'ku',
    String? studentName,
    String? supervisorName,
    String? university,
    String? department,
    List<int>? logoBytes,
  }) async {
    final archive = Archive();

    List<int> toUtf8(String str) => utf8.encode(str);

    // 1. [Content_Types].xml (including core/app/presProps/viewProps/tableStyles/slideLayouts 1..11)
    final contentTypesXml = _buildContentTypesXml(slides.length);
    final contentTypesBytes = toUtf8(contentTypesXml);
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesBytes.length, contentTypesBytes));

    // 2. _rels/.rels (with core-properties and extended-properties)
    final rootRelsXml = _buildRootRelsXml();
    final rootRelsBytes = toUtf8(rootRelsXml);
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes));

    // 3. docProps/core.xml & docProps/app.xml (Required for Protected View)
    final coreXml = _buildDocPropsCoreXml(presentationTitle);
    final coreBytes = toUtf8(coreXml);
    archive.addFile(ArchiveFile('docProps/core.xml', coreBytes.length, coreBytes));

    final appXml = _buildDocPropsAppXml(slides.length);
    final appBytes = toUtf8(appXml);
    archive.addFile(ArchiveFile('docProps/app.xml', appBytes.length, appBytes));

    // 4. ppt/_rels/presentation.xml.rels
    final presRelsXml = _buildPresentationRelsXml(slides.length);
    final presRelsBytes = toUtf8(presRelsXml);
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsBytes.length, presRelsBytes));

    // 5. ppt/presentation.xml
    final presXml = _buildPresentationXml(slides.length);
    final presBytes = toUtf8(presXml);
    archive.addFile(ArchiveFile('ppt/presentation.xml', presBytes.length, presBytes));

    // 6. Native Templates: presProps.xml, viewProps.xml, tableStyles.xml, theme1.xml
    final presPropsBytes = toUtf8(PptxTemplateData.ppt_presProps_xml);
    archive.addFile(ArchiveFile('ppt/presProps.xml', presPropsBytes.length, presPropsBytes));

    final viewPropsBytes = toUtf8(PptxTemplateData.ppt_viewProps_xml);
    archive.addFile(ArchiveFile('ppt/viewProps.xml', viewPropsBytes.length, viewPropsBytes));

    final tableStylesBytes = toUtf8(PptxTemplateData.ppt_tableStyles_xml);
    archive.addFile(ArchiveFile('ppt/tableStyles.xml', tableStylesBytes.length, tableStylesBytes));

    final themeBytes = toUtf8(PptxTemplateData.ppt_theme_theme1_xml);
    archive.addFile(ArchiveFile('ppt/theme/theme1.xml', themeBytes.length, themeBytes));

    // 7. SlideMaster and its rels
    final slideMasterBytes = toUtf8(PptxTemplateData.ppt_slideMasters_slideMaster1_xml);
    archive.addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', slideMasterBytes.length, slideMasterBytes));

    final slideMasterRelsBytes = toUtf8(PptxTemplateData.ppt_slideMasters__rels_slideMaster1_xml_rels);
    archive.addFile(ArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', slideMasterRelsBytes.length, slideMasterRelsBytes));

    // 8. SlideLayouts 1..11 and their rels
    final layouts = [
      (PptxTemplateData.ppt_slideLayouts_slideLayout1_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout1_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout2_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout2_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout3_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout3_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout4_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout4_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout5_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout5_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout6_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout6_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout7_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout7_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout8_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout8_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout9_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout9_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout10_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout10_xml_rels),
      (PptxTemplateData.ppt_slideLayouts_slideLayout11_xml, PptxTemplateData.ppt_slideLayouts__rels_slideLayout11_xml_rels),
    ];

    for (int i = 0; i < layouts.length; i++) {
      final layoutNum = i + 1;
      final layoutXmlBytes = toUtf8(layouts[i].$1);
      final layoutRelsBytes = toUtf8(layouts[i].$2);
      archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout$layoutNum.xml', layoutXmlBytes.length, layoutXmlBytes));
      archive.addFile(ArchiveFile('ppt/slideLayouts/_rels/slideLayout$layoutNum.xml.rels', layoutRelsBytes.length, layoutRelsBytes));
    }

    final hasCustomLogo = logoBytes != null && logoBytes.isNotEmpty;
    if (hasCustomLogo) {
      archive.addFile(ArchiveFile('ppt/media/logo.png', logoBytes.length, logoBytes));
    }

    // 9. Fetch real images in parallel asynchronously and embed into PPTX media/ + slides/
    final imageFutures = slides.asMap().entries.map((entry) {
      final slideNum = entry.key + 1;
      final slide = entry.value;
      final imgUrl = slide.imageUrl ?? getSlideSpecificImageUrl(presentationTitle, slideNum);
      return _fetchOrGenerateImageBytes(imgUrl);
    }).toList();

    final allImageBytes = await Future.wait(imageFutures);

    for (int i = 0; i < slides.length; i++) {
      final slideNum = i + 1;
      final slide = slides[i];
      final imageBytes = allImageBytes[i];
      final isFirst = i == 0;

      // Detect real MIME type by checking magic bytes
      final isPng = imageBytes.length >= 8 &&
          imageBytes[0] == 0x89 &&
          imageBytes[1] == 0x50 &&
          imageBytes[2] == 0x4E &&
          imageBytes[3] == 0x47;
      final imageExt = isPng ? 'png' : 'jpeg';

      archive.addFile(ArchiveFile('ppt/media/image$slideNum.$imageExt', imageBytes.length, imageBytes));

      // Build slide XML
      final slideXml = _buildSlideXml(
        slide,
        slideNum,
        slides.length,
        isFirstSlide: isFirst,
        hasImage: !isFirst,
        hasLogo: isFirst && hasCustomLogo,
        languageCode: languageCode,
        studentName: studentName,
        supervisorName: supervisorName,
        university: university,
        department: department,
      );
      final slideBytes = toUtf8(slideXml);
      archive.addFile(ArchiveFile('ppt/slides/slide$slideNum.xml', slideBytes.length, slideBytes));

      // Build relationship linking slide to layout and embedded image
      final slideRelXml = _buildSlideRelsXml(
        isFirst ? 1 : 2,
        hasImage: !isFirst,
        imageIndex: slideNum,
        imageExt: imageExt,
        hasLogo: isFirst && hasCustomLogo,
      );
      final slideRelBytes = toUtf8(slideRelXml);
      archive.addFile(ArchiveFile('ppt/slides/_rels/slide$slideNum.xml.rels', slideRelBytes.length, slideRelBytes));
    }

    final zipEncoder = ZipEncoder();
    return zipEncoder.encode(archive);
  }

  /// Exports PPTX bytes to a temporary file and triggers the system Share / Open With sheet
  static Future<void> exportAndSharePptx({
    List<SlideModel>? slides,
    String? rawContent,
    required String title,
    String languageCode = 'ku',
    String? studentName,
    String? supervisorName,
    String? university,
    String? department,
    List<int>? logoBytes,
  }) async {
    final effectiveSlides = (slides != null && slides.isNotEmpty)
        ? slides
        : (rawContent != null ? parseSlidesFromText(rawContent, defaultTitle: title) : <SlideModel>[]);

    final bytes = await createPptxBytes(
      effectiveSlides,
      presentationTitle: title,
      languageCode: languageCode,
      studentName: studentName,
      supervisorName: supervisorName,
      university: university,
      department: department,
      logoBytes: logoBytes,
    );

    final tempDir = await getTemporaryDirectory();
    final cleanFileName = title
        .replaceAll(RegExp(r'[\\/:*?"<>|«»“”‘’،,;!?.#%&{}$+=@^~`\(\)\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    final truncated = cleanFileName.length > 35
        ? cleanFileName.substring(0, 35).replaceAll(RegExp(r'_+$'), '')
        : cleanFileName;
    final fileName = '${truncated.isEmpty ? 'Seminar_Presentation' : truncated}.pptx';
    final filePath = '${tempDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation')],
      subject: title,
      text: 'فایلی پاوەرپۆینت بۆ سیمیناری: $title',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // XML Builders for OpenXML Presentation Standard
  // ─────────────────────────────────────────────────────────────────────────

  static String _escapeXml(String text) {
    final cleaned = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\uD800-\uDFFF]'), '');
    return cleaned
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _buildDocPropsCoreXml(String title) {
    final now = DateTime.now().toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n'
        '  <dc:title>${_escapeXml(title)}</dc:title>\n'
        '  <dc:creator>ZankoAI</dc:creator>\n'
        '  <cp:lastModifiedBy>ZankoAI Academic Suite</cp:lastModifiedBy>\n'
        '  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>\n'
        '  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>\n'
        '</cp:coreProperties>';
  }

  static String _buildDocPropsAppXml(int slideCount) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">\n'
        '  <TotalTime>0</TotalTime>\n'
        '  <Words>0</Words>\n'
        '  <Application>Microsoft Office PowerPoint</Application>\n'
        '  <PresentationFormat>On-screen Show (16:9)</PresentationFormat>\n'
        '  <Paragraphs>0</Paragraphs>\n'
        '  <Slides>$slideCount</Slides>\n'
        '  <Notes>0</Notes>\n'
        '  <HiddenSlides>0</HiddenSlides>\n'
        '  <MMClips>0</MMClips>\n'
        '  <ScaleCrop>false</ScaleCrop>\n'
        '  <HeadingPairs>\n'
        '    <vt:vector size="2" baseType="variant">\n'
        '      <vt:variant><vt:lpstr>Theme</vt:lpstr></vt:variant>\n'
        '      <vt:variant><vt:i4>1</vt:i4></vt:variant>\n'
        '    </vt:vector>\n'
        '  </HeadingPairs>\n'
        '  <TitlesOfParts>\n'
        '    <vt:vector size="1" baseType="lpstr">\n'
        '      <vt:lpstr>ZankoAcademic</vt:lpstr>\n'
        '    </vt:vector>\n'
        '  </TitlesOfParts>\n'
        '  <Company>ZankoAI</Company>\n'
        '  <LinksUpToDate>false</LinksUpToDate>\n'
        '  <SharedDoc>false</SharedDoc>\n'
        '  <HyperlinksChanged>false</HyperlinksChanged>\n'
        '  <AppVersion>16.0000</AppVersion>\n'
        '</Properties>';
  }



  static String _buildContentTypesXml(int slideCount) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n');
    buffer.write('  <Default Extension="jpeg" ContentType="image/jpeg"/>\n');
    buffer.write('  <Default Extension="jpg" ContentType="image/jpeg"/>\n');
    buffer.write('  <Default Extension="png" ContentType="image/png"/>\n');
    buffer.write('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n');
    buffer.write('  <Default Extension="xml" ContentType="application/xml"/>\n');
    buffer.write('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>\n');
    buffer.write('  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>\n');
    buffer.write('  <Override PartName="/ppt/presProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"/>\n');
    buffer.write('  <Override PartName="/ppt/viewProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml"/>\n');
    buffer.write('  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\n');
    buffer.write('  <Override PartName="/ppt/tableStyles.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml"/>\n');

    for (int i = 1; i <= 11; i++) {
      buffer.write('  <Override PartName="/ppt/slideLayouts/slideLayout$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>\n');
    }

    for (int i = 1; i <= slideCount; i++) {
      buffer.write('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>\n');
    }

    buffer.write('  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>\n');
    buffer.write('  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>\n');
    buffer.write('</Types>');
    return buffer.toString();
  }

  static String _buildRootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\n'
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>\n'
        '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>\n'
        '</Relationships>';
  }

  static String _buildPresentationRelsXml(int slideCount) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    buffer.write('  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>\n');
    buffer.write('  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>\n');
    buffer.write('  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps" Target="presProps.xml"/>\n');
    buffer.write('  <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/viewProps" Target="viewProps.xml"/>\n');
    buffer.write('  <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles" Target="tableStyles.xml"/>\n');

    for (int i = 1; i <= slideCount; i++) {
      buffer.write('  <Relationship Id="rId${i + 5}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>\n');
    }

    buffer.write('</Relationships>');
    return buffer.toString();
  }

  static String _buildPresentationXml(int slideCount) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" saveSubsetFonts="1">\n');
    buffer.write('  <p:sldMasterIdLst>\n');
    buffer.write('    <p:sldMasterId id="2147483648" r:id="rId1"/>\n');
    buffer.write('  </p:sldMasterIdLst>\n');
    buffer.write('  <p:sldIdLst>\n');

    for (int i = 1; i <= slideCount; i++) {
      buffer.write('    <p:sldId id="${255 + i}" r:id="rId${i + 5}"/>\n');
    }

    buffer.write('  </p:sldIdLst>\n');
    buffer.write('  <p:sldSz cx="12192000" cy="6858000"/>\n');
    buffer.write('  <p:notesSz cx="6858000" cy="9144000"/>\n');
    buffer.write('  <p:defaultTextStyle><a:defPPr><a:defRPr lang="en-US"/></a:defPPr><a:lvl1pPr marL="0" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl1pPr><a:lvl2pPr marL="457200" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl2pPr><a:lvl3pPr marL="914400" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl3pPr><a:lvl4pPr marL="1371600" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl4pPr><a:lvl5pPr marL="1828800" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl5pPr><a:lvl6pPr marL="2286000" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl6pPr><a:lvl7pPr marL="2743200" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl7pPr><a:lvl8pPr marL="3200400" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl8pPr><a:lvl9pPr marL="3657600" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl9pPr></p:defaultTextStyle>\n');
    buffer.write('</p:presentation>');
    return buffer.toString();
  }



  static String _buildSlideRelsXml(int layoutIndex, {bool hasImage = false, int? imageIndex, String imageExt = 'jpeg', bool hasLogo = false}) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    buffer.write('  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout$layoutIndex.xml"/>\n');
    if (hasImage && imageIndex != null) {
      buffer.write('  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$imageIndex.$imageExt"/>\n');
    }
    if (hasLogo) {
      buffer.write('  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/logo.png"/>\n');
    }
    buffer.write('</Relationships>');
    return buffer.toString();
  }

  static String _buildSlideXml(
    SlideModel slide,
    int slideIndex,
    int totalSlides, {
    bool isFirstSlide = false,
    bool hasImage = false,
    bool hasLogo = false,
    String languageCode = 'ku',
    String? studentName,
    String? supervisorName,
    String? university,
    String? department,
  }) {
    final isEnglish = languageCode == 'en';
    final isArabic = languageCode == 'ar';
    final isBad = languageCode == 'ku_badini' || languageCode == 'badini';
    final isRtl = !isEnglish;

    final langAttr = isEnglish ? 'en-US' : (isArabic ? 'ar-SA' : 'ar-IQ');
    const latinFont = 'Calibri';
    const csFont = 'Calibri';
    final algn = isRtl ? 'r' : 'l';
    final rtlColVal = isRtl ? '1' : '0';
    final rtlAttr = isRtl ? 'rtl="1"' : 'rtl="0"';

    final effectiveUniv = (university != null && university.trim().isNotEmpty)
        ? university.trim()
        : (isEnglish ? 'Salahaddin University - Erbil' : 'زانکۆی سەڵاحەدین - هەولێر');
    final effectiveDept = (department != null && department.trim().isNotEmpty) ? department.trim() : '';

    final footerText = isEnglish
        ? 'ZankoAI Academic Presentation • Slide $slideIndex of $totalSlides'
        : (isArabic
            ? 'ZankoAI العرض الأكاديمي • الشريحة $slideIndex من $totalSlides'
            : 'ZankoAI پرێزێنتەیشنی ئەکادیمی • سلایدی $slideIndex لە $totalSlides');

    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n');
    buffer.write('  <p:cSld>\n');
    buffer.write('    <p:spTree>\n');
    buffer.write('      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\n');
    buffer.write('      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\n');

    if (isFirstSlide) {
      // ═════════════════════════════════════════════════════════════════════════
      // SLIDE 1: PURE ACADEMIC COVER SLIDE (TITLE, SUPERVISOR, STUDENT, LOGO ONLY)
      // ═════════════════════════════════════════════════════════════════════════
      // Background Canvas Card
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="2" name="TitleBackground"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr>\n');
      buffer.write('          <a:xfrm><a:off x="400000" y="400000"/><a:ext cx="11392000" cy="6058000"/></a:xfrm>\n');
      buffer.write('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n');
      buffer.write('          <a:solidFill><a:srgbClr val="0F172A"/></a:solidFill>\n');
      buffer.write('          <a:ln w="19050"><a:solidFill><a:srgbClr val="1E293B"/></a:solidFill></a:ln>\n');
      buffer.write('        </p:spPr>\n');
      buffer.write('      </p:sp>\n');

      // Top Radiant Line
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="3" name="TopGlow"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr>\n');
      buffer.write('          <a:xfrm><a:off x="400000" y="400000"/><a:ext cx="11392000" cy="90000"/></a:xfrm>\n');
      buffer.write('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n');
      buffer.write('          <a:solidFill><a:srgbClr val="2563EB"/></a:solidFill>\n');
      buffer.write('        </p:spPr>\n');
      buffer.write('      </p:sp>\n');

      // 1. UNIVERSITY LOGO / EMBLEM (Top Center)
      if (hasLogo) {
        buffer.write('      <p:pic>\n');
        buffer.write('        <p:nvPicPr><p:cNvPr id="4" name="UniversityLogo"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>\n');
        buffer.write('        <p:blipFill><a:blip r:embed="rId3"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\n');
        buffer.write('        <p:spPr><a:xfrm><a:off x="5496000" y="600000"/><a:ext cx="1200000" cy="1200000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
        buffer.write('      </p:pic>\n');

        // University Name under Logo
        buffer.write('      <p:sp>\n');
        buffer.write('        <p:nvSpPr><p:cNvPr id="5" name="UnivName"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
        buffer.write('        <p:spPr>\n');
        buffer.write('          <a:xfrm><a:off x="2500000" y="1900000"/><a:ext cx="7192000" cy="380000"/></a:xfrm>\n');
        buffer.write('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n');
        buffer.write('          <a:solidFill><a:srgbClr val="1E293B"/></a:solidFill>\n');
        buffer.write('          <a:ln w="12700"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln>\n');
        buffer.write('        </p:spPr>\n');
        buffer.write('        <p:txBody>\n');
        buffer.write('          <a:bodyPr anchor="ctr" rtlCol="0"/>\n');
        buffer.write('          <a:lstStyle/>\n');
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="ctr"/>\n');
        buffer.write('            <a:r>\n');
        buffer.write('              <a:rPr lang="$langAttr" sz="1300" b="1"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
        buffer.write('              <a:t>${_escapeXml(effectiveUniv)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
        buffer.write('        </p:txBody>\n');
        buffer.write('      </p:sp>\n');
      } else {
        // University Emblem Badge Pill (Top Center)
        buffer.write('      <p:sp>\n');
        buffer.write('        <p:nvSpPr><p:cNvPr id="4" name="UnivBadge"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
        buffer.write('        <p:spPr>\n');
        buffer.write('          <a:xfrm><a:off x="3100000" y="800000"/><a:ext cx="5992000" cy="450000"/></a:xfrm>\n');
        buffer.write('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n');
        buffer.write('          <a:solidFill><a:srgbClr val="1E293B"/></a:solidFill>\n');
        buffer.write('          <a:ln w="12700"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln>\n');
        buffer.write('        </p:spPr>\n');
        buffer.write('        <p:txBody>\n');
        buffer.write('          <a:bodyPr anchor="ctr" rtlCol="0"/>\n');
        buffer.write('          <a:lstStyle/>\n');
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="ctr"/>\n');
        buffer.write('            <a:r>\n');
        buffer.write('              <a:rPr lang="$langAttr" sz="1350" b="1"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
        buffer.write('              <a:t>${_escapeXml(effectiveUniv)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
        buffer.write('        </p:txBody>\n');
        buffer.write('      </p:sp>\n');
      }

      // 2. MAIN PRESENTATION TOPIC TITLE (Center)
      final titleY = hasLogo ? '2380000' : '1500000';
      final titleHeight = hasLogo ? '1600000' : '2200000';
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="6" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr><a:xfrm><a:off x="900000" y="$titleY"/><a:ext cx="10392000" cy="$titleHeight"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="ctr" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write('              <a:rPr lang="$langAttr" sz="3400" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
      buffer.write('              <a:t>${_escapeXml(slide.title)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      if (effectiveDept.isNotEmpty) {
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="ctr" $rtlAttr><a:spcBef><a:spcPts val="1200"/></a:spcBef></a:pPr>\n');
        buffer.write('            <a:r>\n');
        buffer.write('              <a:rPr lang="$langAttr" sz="1500"><a:solidFill><a:srgbClr val="94A3B8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
        buffer.write('              <a:t>${_escapeXml(effectiveDept)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
      }
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // 3. STUDENT & 4. SUPERVISOR CARDS (Bottom)
      final effectiveStudent = (studentName != null && studentName.trim().isNotEmpty)
          ? studentName.trim()
          : (isEnglish ? 'Student / Research Team' : (isBad ? 'قوتابیێن بەشێ زانستی' : 'قوتابیانی بەش'));
      final effectiveSupervisor = (supervisorName != null && supervisorName.trim().isNotEmpty)
          ? supervisorName.trim()
          : (isEnglish ? 'Academic Supervisor' : (isBad ? 'مامۆستایێ سەرپەرشتیار' : 'مامۆستای سەرپەرشتیار'));

      final studentLabel = isEnglish ? 'Prepared By:' : (isArabic ? 'إعداد الطالب / الفريق:' : (isBad ? 'ئامادەکرن ژ لایێ:' : 'ئامادەکردنی:'));
      final supervisorLabel = isEnglish ? 'Supervised By:' : (isArabic ? 'إشراف الأستاذ المشرف:' : (isBad ? 'سەرپەرشتیار:' : 'مامۆستای سەرپەرشتیار:'));

      // Card 1: Student (Left in LTR, Right in RTL)
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="7" name="StudentCard"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr>\n');
      buffer.write('          <a:xfrm><a:off x="1000000" y="4200000"/><a:ext cx="4900000" cy="1800000"/></a:xfrm>\n');
      buffer.write('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n');
      buffer.write('          <a:solidFill><a:srgbClr val="111827"/></a:solidFill>\n');
      buffer.write('          <a:ln w="15875"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln>\n');
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal" lIns="200000" tIns="160000" rIns="200000" bIns="160000"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="ctr" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write('              <a:rPr lang="$langAttr" sz="1300" b="1"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
      buffer.write('              <a:t>$studentLabel</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="ctr" $rtlAttr><a:spcBef><a:spcPts val="800"/></a:spcBef></a:pPr>\n');
      buffer.write('            <a:r>\n');
      buffer.write('              <a:rPr lang="$langAttr" sz="1800" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
      buffer.write('              <a:t>${_escapeXml(effectiveStudent)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // Card 2: Supervisor (Right in LTR, Left in RTL)
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="8" name="SupervisorCard"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr>\n');
      buffer.write('          <a:xfrm><a:off x="6292000" y="4200000"/><a:ext cx="4900000" cy="1800000"/></a:xfrm>\n');
      buffer.write('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n');
      buffer.write('          <a:solidFill><a:srgbClr val="111827"/></a:solidFill>\n');
      buffer.write('          <a:ln w="15875"><a:solidFill><a:srgbClr val="10B981"/></a:solidFill></a:ln>\n');
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal" lIns="200000" tIns="160000" rIns="200000" bIns="160000"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="ctr" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write('              <a:rPr lang="$langAttr" sz="1300" b="1"><a:solidFill><a:srgbClr val="34D399"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
      buffer.write('              <a:t>$supervisorLabel</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="ctr" $rtlAttr><a:spcBef><a:spcPts val="800"/></a:spcBef></a:pPr>\n');
      buffer.write('            <a:r>\n');
      buffer.write('              <a:rPr lang="$langAttr" sz="1800" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
      buffer.write('              <a:t>${_escapeXml(effectiveSupervisor)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

    } else {
      // ═════════════════════════════════════════════════════════════════════════
      // SLIDES 2..N: ACADEMIC CONTENT SLIDES (TOP TITLE + SPLIT IMAGE & CONTENT)
      // ═════════════════════════════════════════════════════════════════════════
      // Top Gradient Accent Bar
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="2" name="TopAccent"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="12192000" cy="120000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></p:spPr>\n');
      buffer.write('      </p:sp>\n');

      // Slide Title Box (Top)
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="3" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr><a:xfrm><a:off x="600000" y="300000"/><a:ext cx="10992000" cy="850000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write('              <a:rPr lang="$langAttr" sz="2400" b="1"><a:solidFill><a:srgbClr val="0F172A"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
      buffer.write('              <a:t>${_escapeXml(slide.title)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // Picture Frame Positions (Left side for RTL, Right side for LTR)
      final picX = isRtl ? '600000' : '6992000';
      final textX = isRtl ? '5400000' : '600000';
      final textWidth = hasImage ? '6192000' : '10992000';

      if (hasImage) {
        buffer.write('      <p:pic>\n');
        buffer.write('        <p:nvPicPr>\n');
        buffer.write('          <p:cNvPr id="6" name="SlideImage$slideIndex"/>\n');
        buffer.write('          <p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>\n');
        buffer.write('          <p:nvPr/>\n');
        buffer.write('        </p:nvPicPr>\n');
        buffer.write('        <p:blipFill>\n');
        buffer.write('          <a:blip r:embed="rId2"/>\n');
        buffer.write('          <a:stretch><a:fillRect/></a:stretch>\n');
        buffer.write('        </p:blipFill>\n');
        buffer.write('        <p:spPr>\n');
        buffer.write('          <a:xfrm><a:off x="$picX" y="1300000"/><a:ext cx="4600000" cy="4900000"/></a:xfrm>\n');
        buffer.write('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n');
        buffer.write('          <a:ln w="19050"><a:solidFill><a:srgbClr val="CBD5E1"/></a:solidFill></a:ln>\n');
        buffer.write('        </p:spPr>\n');
        buffer.write('      </p:pic>\n');
      }

      // Content Card / Text & Points Box
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="4" name="ContentBox"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr>\n');
      buffer.write('          <a:xfrm><a:off x="$textX" y="1300000"/><a:ext cx="$textWidth" cy="4900000"/></a:xfrm>\n');
      buffer.write('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n');
      buffer.write('          <a:solidFill><a:srgbClr val="F8FAFC"/></a:solidFill>\n');
      buffer.write('          <a:ln w="12700"><a:solidFill><a:srgbClr val="E2E8F0"/></a:solidFill></a:ln>\n');
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="t" rtlCol="$rtlColVal" lIns="250000" tIns="250000" rIns="250000" bIns="250000"/>\n');
      buffer.write('          <a:lstStyle/>\n');

      for (var bullet in slide.bulletPoints) {
        final cleanBullet = bullet.trim();
        final displayBullet = cleanBullet.startsWith('•') ? cleanBullet : '• $cleanBullet';
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="$algn" $rtlAttr><a:spcBef><a:spcPts val="600"/></a:spcBef></a:pPr>\n');
        buffer.write('            <a:r>\n');
        buffer.write('              <a:rPr lang="$langAttr" sz="1600"><a:solidFill><a:srgbClr val="1E293B"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n');
        buffer.write('              <a:t>${_escapeXml(displayBullet)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
      }

      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // Slide Footer (Page Number & ZankoAI branding)
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="5" name="Footer"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr><a:xfrm><a:off x="600000" y="6350000"/><a:ext cx="10992000" cy="350000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="b" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write('            <a:r><a:rPr lang="$langAttr" sz="1100"><a:solidFill><a:srgbClr val="94A3B8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr><a:t>$footerText</a:t></a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');
    }

    buffer.write('    </p:spTree>\n');
    buffer.write('  </p:cSld>\n');
    buffer.write('  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>\n');
    buffer.write('</p:sld>');
    return buffer.toString();
  }
}
