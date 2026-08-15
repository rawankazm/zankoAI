import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

      // Detect slide headers e.g. "### 🔹 سلایدی ١: ناساندن", "### Slide 1: Title", "1️⃣ بابەتی یەکەم:"
      final isSlideHeader = RegExp(r'^(#+\s*)?(🔹|🔸|▪️|▫️|🔻|\d+️⃣|\d+\.|\d+\))\s*(سلایدی|سلايد|Slide|بابەت|بابەتی|الشريحة)\s*\d*[:\-–]', caseSensitive: false).hasMatch(trimmed) ||
          RegExp(r'^###\s+.*(سلاید|Slide|بابەت|الشريحة)', caseSensitive: false).hasMatch(trimmed);

      if (isSlideHeader) {
        if (inSlide) {
          saveCurrentSlide();
        }
        inSlide = true;
        
        // Extract title
        String cleanTitle = trimmed
            .replaceAll(RegExp(r'^#+\s*'), '')
            .replaceAll(RegExp(r'^(🔹|🔸|▪️|▫️|🔻|\d+️⃣)\s*'), '')
            .replaceAll(RegExp(r'^(سلایدی|سلايد|Slide|بابەت|بابەتی|الشريحة)\s*\d*[:\-–]\s*', caseSensitive: false), '')
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

  /// Generates a valid OpenXML PowerPoint (.pptx) file with real embedded images and Kurdish/Arabic app fonts
  static Future<List<int>> createPptxBytes(
    List<SlideModel> slides, {
    String presentationTitle = 'ZankoAI Seminar',
    String languageCode = 'ku',
  }) async {
    final archive = Archive();

    // 1. [Content_Types].xml (including image extensions)
    final contentTypesXml = _buildContentTypesXml(slides.length);
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    final rootRelsXml = _buildRootRelsXml();
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)));

    // 3. ppt/_rels/presentation.xml.rels
    final presRelsXml = _buildPresentationRelsXml(slides.length);
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsXml.length, utf8.encode(presRelsXml)));

    // 4. ppt/presentation.xml
    final presXml = _buildPresentationXml(slides.length);
    archive.addFile(ArchiveFile('ppt/presentation.xml', presXml.length, utf8.encode(presXml)));

    // 5. ppt/slideMasters/slideMaster1.xml & rels
    final slideMasterXml = _buildSlideMasterXml();
    archive.addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', slideMasterXml.length, utf8.encode(slideMasterXml)));

    final slideMasterRelsXml = _buildSlideMasterRelsXml();
    archive.addFile(ArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', slideMasterRelsXml.length, utf8.encode(slideMasterRelsXml)));

    // 6. ppt/slideLayouts/slideLayout1.xml & slideLayout2.xml & rels
    final layout1Xml = _buildSlideLayoutXml('Title Slide');
    archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout1.xml', layout1Xml.length, utf8.encode(layout1Xml)));

    final layout2Xml = _buildSlideLayoutXml('Title and Content');
    archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout2.xml', layout2Xml.length, utf8.encode(layout2Xml)));

    final layoutRelsXml = _buildSlideLayoutRelsXml();
    archive.addFile(ArchiveFile('ppt/slideLayouts/_rels/slideLayout1.xml.rels', layoutRelsXml.length, utf8.encode(layoutRelsXml)));
    archive.addFile(ArchiveFile('ppt/slideLayouts/_rels/slideLayout2.xml.rels', layoutRelsXml.length, utf8.encode(layoutRelsXml)));

    // 7. ppt/theme/theme1.xml with Droid Arabic Kufi & Segoe UI fontScheme
    final themeXml = _buildThemeXml();
    archive.addFile(ArchiveFile('ppt/theme/theme1.xml', themeXml.length, utf8.encode(themeXml)));

    // 8. Fetch real images asynchronously and embed into PPTX media/ + slides/
    for (int i = 0; i < slides.length; i++) {
      final slideNum = i + 1;
      final slide = slides[i];
      final imgUrl = slide.imageUrl ?? getSlideSpecificImageUrl(presentationTitle, slideNum);

      // Download real image bytes from web
      final imageBytes = await _fetchOrGenerateImageBytes(imgUrl);
      archive.addFile(ArchiveFile('ppt/media/image$slideNum.jpeg', imageBytes.length, imageBytes));

      // Build slide XML with DrawingML <p:pic> image frame and Kurdish/Arabic typography
      final slideXml = _buildSlideXml(
        slide,
        slideNum,
        slides.length,
        isFirstSlide: i == 0,
        hasImage: true,
        languageCode: languageCode,
      );
      archive.addFile(ArchiveFile('ppt/slides/slide$slideNum.xml', slideXml.length, utf8.encode(slideXml)));

      // Build relationship linking slide to layout and embedded image
      final slideRelXml = _buildSlideRelsXml(i == 0 ? 1 : 2, hasImage: true, imageIndex: slideNum);
      archive.addFile(ArchiveFile('ppt/slides/_rels/slide$slideNum.xml.rels', slideRelXml.length, utf8.encode(slideRelXml)));
    }

    final zipEncoder = ZipEncoder();
    return zipEncoder.encode(archive);
  }

  /// Exports PPTX bytes to a temporary file and triggers the system Share / Open With sheet
  static Future<void> exportAndSharePptx({
    required String rawContent,
    required String title,
    String languageCode = 'ku',
  }) async {
    final slides = parseSlidesFromText(rawContent, defaultTitle: title);
    final bytes = await createPptxBytes(slides, presentationTitle: title, languageCode: languageCode);

    final tempDir = await getTemporaryDirectory();
    final cleanFileName = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_')
        .trim();
    final fileName = '${cleanFileName.isEmpty ? 'Seminar_Presentation' : cleanFileName}.pptx';
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
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _buildContentTypesXml(int slideCount) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n');
    buffer.write('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n');
    buffer.write('  <Default Extension="xml" ContentType="application/xml"/>\n');
    buffer.write('  <Default Extension="jpeg" ContentType="image/jpeg"/>\n');
    buffer.write('  <Default Extension="jpg" ContentType="image/jpeg"/>\n');
    buffer.write('  <Default Extension="png" ContentType="image/png"/>\n');
    buffer.write('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>\n');
    buffer.write('  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>\n');
    buffer.write('  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>\n');
    buffer.write('  <Override PartName="/ppt/slideLayouts/slideLayout2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>\n');
    buffer.write('  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\n');

    for (int i = 1; i <= slideCount; i++) {
      buffer.write('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>\n');
    }

    buffer.write('</Types>');
    return buffer.toString();
  }

  static String _buildRootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\n'
        '</Relationships>';
  }

  static String _buildPresentationRelsXml(int slideCount) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    buffer.write('  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>\n');
    buffer.write('  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>\n');

    for (int i = 1; i <= slideCount; i++) {
      buffer.write('  <Relationship Id="rId${i + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>\n');
    }

    buffer.write('</Relationships>');
    return buffer.toString();
  }

  static String _buildPresentationXml(int slideCount) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n');
    buffer.write('  <p:sldMasterIdLst>\n');
    buffer.write('    <p:sldMasterId id="2147483648" r:id="rId1"/>\n');
    buffer.write('  </p:sldMasterIdLst>\n');
    buffer.write('  <p:sldIdLst>\n');

    for (int i = 1; i <= slideCount; i++) {
      buffer.write('    <p:sldId id="${255 + i}" r:id="rId${i + 2}"/>\n');
    }

    buffer.write('  </p:sldIdLst>\n');
    buffer.write('  <p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>\n');
    buffer.write('  <p:notesSz cx="6858000" cy="9144000"/>\n');
    buffer.write('</p:presentation>');
    return buffer.toString();
  }

  static String _buildSlideMasterXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n'
        '  <p:cSld>\n'
        '    <p:spTree>\n'
        '      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\n'
        '      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\n'
        '    </p:spTree>\n'
        '  </p:cSld>\n'
        '  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>\n'
        '  <p:sldLayoutIdLst>\n'
        '    <p:sldLayoutId id="2147483649" r:id="rId1"/>\n'
        '    <p:sldLayoutId id="2147483650" r:id="rId2"/>\n'
        '  </p:sldLayoutIdLst>\n'
        '</p:sldMaster>';
  }

  static String _buildSlideMasterRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\n'
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout2.xml"/>\n'
        '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>\n'
        '</Relationships>';
  }

  static String _buildSlideLayoutXml(String layoutName) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="cust" preserve="1">\n'
        '  <p:cSld name="$layoutName">\n'
        '    <p:spTree>\n'
        '      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\n'
        '      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\n'
        '    </p:spTree>\n'
        '  </p:cSld>\n'
        '</p:sldLayout>';
  }

  static String _buildSlideLayoutRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>\n'
        '</Relationships>';
  }

  static String _buildThemeXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="ZankoCanvaModern">\n'
        '  <a:themeElements>\n'
        '    <a:clrScheme name="ZankoCanva">\n'
        '      <a:dk1><a:srgbClr val="0F172A"/></a:dk1>\n'
        '      <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>\n'
        '      <a:dk2><a:srgbClr val="334155"/></a:dk2>\n'
        '      <a:lt2><a:srgbClr val="F8FAFC"/></a:lt2>\n'
        '      <a:accent1><a:srgbClr val="7D2AE8"/></a:accent1>\n'
        '      <a:accent2><a:srgbClr val="00C4CC"/></a:accent2>\n'
        '      <a:accent3><a:srgbClr val="6366F1"/></a:accent3>\n'
        '      <a:accent4><a:srgbClr val="10B981"/></a:accent4>\n'
        '      <a:accent5><a:srgbClr val="F59E0B"/></a:accent5>\n'
        '      <a:accent6><a:srgbClr val="EF4444"/></a:accent6>\n'
        '      <a:hlink><a:srgbClr val="7D2AE8"/></a:hlink>\n'
        '      <a:folHlink><a:srgbClr val="00C4CC"/></a:folHlink>\n'
        '    </a:clrScheme>\n'
        '    <a:fontScheme name="ZankoAppFonts">\n'
        '      <a:majorFont><a:latin typeface="Segoe UI"/><a:ea typeface=""/><a:cs typeface="Droid Arabic Kufi"/></a:majorFont>\n'
        '      <a:minorFont><a:latin typeface="Segoe UI"/><a:ea typeface=""/><a:cs typeface="Droid Arabic Kufi"/></a:minorFont>\n'
        '    </a:fontScheme>\n'
        '    <a:fmtScheme name="Office">\n'
        '      <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>\n'
        '      <a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>\n'
        '      <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>\n'
        '      <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>\n'
        '    </a:fmtScheme>\n'
        '  </a:themeElements>\n'
        '</a:theme>';
  }

  static String _buildSlideRelsXml(int layoutIndex, {bool hasImage = false, int? imageIndex}) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    buffer.write('  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout$layoutIndex.xml"/>\n');
    if (hasImage && imageIndex != null) {
      buffer.write('  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$imageIndex.jpeg"/>\n');
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
    String languageCode = 'ku',
  }) {
    final isEnglish = languageCode == 'en';
    final isArabic = languageCode == 'ar';
    final isRtl = !isEnglish;

    final langAttr = isEnglish ? 'en-US' : (isArabic ? 'ar-SA' : 'ar-IQ');
    final latinFont = 'Segoe UI';
    final csFont = isEnglish ? 'Segoe UI' : 'Droid Arabic Kufi'; // App Font!
    final algn = isRtl ? 'r' : 'l';
    final rtlColVal = isRtl ? '1' : '0';
    final rtlAttr = isRtl ? 'rtl="1"' : 'rtl="0"';

    final subTitleText = isEnglish
        ? 'Comprehensive Academic Presentation | Canva &amp; PowerPoint Format'
        : (isArabic
            ? 'عرض تقديمي أكاديمي متكامل | Canva &amp; PowerPoint Presentation'
            : 'سیمیناری ئەکادیمی ئامادەکراو | Canva &amp; PowerPoint Presentation');

    final footerText = isEnglish
        ? 'ZankoAI 🎓 | Canva &amp; PPT Template | Slide $slideIndex of $totalSlides'
        : (isArabic
            ? 'ZankoAI 🎓 | Canva &amp; PPT Template | الشريحة $slideIndex من $totalSlides'
            : 'ZankoAI 🎓 | Canva &amp; PPT Template | سلایدی $slideIndex لە $totalSlides');

    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n');
    buffer.write('  <p:cSld>\n');
    buffer.write('    <p:spTree>\n');
    buffer.write('      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\n');
    buffer.write('      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\n');

    if (isFirstSlide) {
      // ── Canva Title Slide Layout ──
      // Background Accent Gradient Card
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="2" name="BackCard"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr>\n');
      buffer.write('          <a:xfrm><a:off x="600000" y="600000"/><a:ext cx="10992000" cy="5658000"/></a:xfrm>\n');
      buffer.write('          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 2000"/></a:avLst></a:prstGeom>\n');
      buffer.write('          <a:solidFill><a:srgbClr val="0F172A"/></a:solidFill>\n');
      buffer.write('        </p:spPr>\n');
      buffer.write('      </p:sp>\n');

      // Main Title
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="3" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr><a:xfrm><a:off x="1000000" y="1200000"/><a:ext cx="10192000" cy="2400000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="ctr" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write('              <a:rPr lang="$langAttr" sz="3400" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:ea typeface=""/><a:cs typeface="$csFont"/></a:rPr>\n');
      buffer.write('              <a:t>${_escapeXml(slide.title)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="ctr" $rtlAttr spaceBefore="180000"/>\n');
      buffer.write('            <a:r>\n');
      buffer.write('              <a:rPr lang="$langAttr" sz="1800"><a:solidFill><a:srgbClr val="00C4CC"/></a:solidFill><a:latin typeface="$latinFont"/><a:ea typeface=""/><a:cs typeface="$csFont"/></a:rPr>\n');
      buffer.write('              <a:t>$subTitleText</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // First Slide Points / Author Info Box
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="4" name="Info"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr><a:xfrm><a:off x="1000000" y="3700000"/><a:ext cx="10192000" cy="1900000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="t" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');

      for (var bullet in slide.bulletPoints) {
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="ctr" $rtlAttr spaceBefore="80000"/>\n');
        buffer.write('            <a:r>\n');
        buffer.write('              <a:rPr lang="$langAttr" sz="1600"><a:solidFill><a:srgbClr val="CBD5E1"/></a:solidFill><a:latin typeface="$latinFont"/><a:ea typeface=""/><a:cs typeface="$csFont"/></a:rPr>\n');
        buffer.write('              <a:t>${_escapeXml(bullet)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
      }

      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

    } else {
      // ── Canva Split-Screen Slide Layout (Image + Text Card) ──
      // Top Gradient Accent Bar
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="2" name="TopAccent"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="12192000" cy="180000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="7D2AE8"/></a:solidFill></p:spPr>\n');
      buffer.write('      </p:sp>\n');

      // Slide Title Box (Top)
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="3" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr><a:xfrm><a:off x="600000" y="380000"/><a:ext cx="10992000" cy="850000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write('              <a:rPr lang="$langAttr" sz="2500" b="1"><a:solidFill><a:srgbClr val="0F172A"/></a:solidFill><a:latin typeface="$latinFont"/><a:ea typeface=""/><a:cs typeface="$csFont"/></a:rPr>\n');
      buffer.write('              <a:t>${_escapeXml(slide.title)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // Picture Frame Positions (Left side for RTL, Right side for LTR)
      final picX = isRtl ? '7200000' : '7200000';
      final textX = '600000';
      final textWidth = hasImage ? '6400000' : '10992000';

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
        buffer.write('          <a:xfrm><a:off x="$picX" y="1350000"/><a:ext cx="4400000" cy="4850000"/></a:xfrm>\n');
        buffer.write('          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 1500"/></a:avLst></a:prstGeom>\n');
        buffer.write('          <a:ln w="19050"><a:solidFill><a:srgbClr val="CBD5E1"/></a:solidFill></a:ln>\n');
        buffer.write('        </p:spPr>\n');
        buffer.write('      </p:pic>\n');
      }

      // Content Card / Text & Points Box
      buffer.write('      <p:sp>\n');
      buffer.write('        <p:nvSpPr><p:cNvPr id="4" name="ContentBox"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
      buffer.write('        <p:spPr>\n');
      buffer.write('          <a:xfrm><a:off x="$textX" y="1350000"/><a:ext cx="$textWidth" cy="4850000"/></a:xfrm>\n');
      buffer.write('          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 1500"/></a:avLst></a:prstGeom>\n');
      buffer.write('          <a:solidFill><a:srgbClr val="F8FAFC"/></a:solidFill>\n');
      buffer.write('          <a:ln w="12700"><a:solidFill><a:srgbClr val="E2E8F0"/></a:solidFill></a:ln>\n');
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="t" rtlCol="$rtlColVal" lIns="300000" tIns="300000" rIns="300000" bIns="300000"/>\n');
      buffer.write('          <a:lstStyle/>\n');

      if (slide.visualPrompt != null && slide.visualPrompt!.isNotEmpty) {
        final visualPrefix = isEnglish ? '🖼️ Visual Focus:' : (isArabic ? '🖼️ التركيز البصري:' : '🖼️ وێنەی پەیوەندیدار:');
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="$algn" $rtlAttr spaceBefore="40000"/>\n');
        buffer.write('            <a:r>\n');
        buffer.write('              <a:rPr lang="$langAttr" sz="1200" b="1"><a:solidFill><a:srgbClr val="7D2AE8"/></a:solidFill><a:latin typeface="$latinFont"/><a:ea typeface=""/><a:cs typeface="$csFont"/></a:rPr>\n');
        buffer.write('              <a:t>$visualPrefix ${_escapeXml(slide.visualPrompt!)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
      }

      for (var bullet in slide.bulletPoints) {
        final indentTag = isRtl ? 'marR="240000" indent="-240000"' : 'marL="240000" indent="-240000"';
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="$algn" $rtlAttr $indentTag spaceBefore="120000">\n');
        buffer.write('              <a:buChar char="🔹"/>\n');
        buffer.write('            </a:pPr>\n');
        buffer.write('            <a:r>\n');
        buffer.write('              <a:rPr lang="$langAttr" sz="1600"><a:solidFill><a:srgbClr val="1E293B"/></a:solidFill><a:latin typeface="$latinFont"/><a:ea typeface=""/><a:cs typeface="$csFont"/></a:rPr>\n');
        buffer.write('              <a:t>${_escapeXml(bullet)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
      }

      if (slide.speakerNotes != null && slide.speakerNotes!.isNotEmpty) {
        final notesPrefix = isEnglish ? '🎙️ Speaker Note:' : (isArabic ? '🎙️ ملاحظات المتحدث:' : '🎙️ تێبینی قسەکردن:');
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="$algn" $rtlAttr spaceBefore="200000"/>\n');
        buffer.write('            <a:r>\n');
        buffer.write('              <a:rPr lang="$langAttr" sz="1300" i="1"><a:solidFill><a:srgbClr val="64748B"/></a:solidFill><a:latin typeface="$latinFont"/><a:ea typeface=""/><a:cs typeface="$csFont"/></a:rPr>\n');
        buffer.write('              <a:t>$notesPrefix ${_escapeXml(slide.speakerNotes!)}</a:t>\n');
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
      buffer.write('            <a:r><a:rPr lang="$langAttr" sz="1200"><a:solidFill><a:srgbClr val="94A3B8"/></a:solidFill><a:latin typeface="$latinFont"/><a:ea typeface=""/><a:cs typeface="$csFont"/></a:rPr><a:t>$footerText</a:t></a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');
    }

    buffer.write('    </p:spTree>\n');
    buffer.write('  </p:cSld>\n');
    buffer.write('</p:sld>');
    return buffer.toString();
  }
}
