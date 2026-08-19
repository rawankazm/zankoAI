import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;
import '../../services/ai_service.dart';
import '../../services/kurdish_tts_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';

class KurdishVoiceTutorScreen extends StatefulWidget {
  final String? initialFileName;
  final String? initialFileContent;

  const KurdishVoiceTutorScreen({super.key, this.initialFileName, this.initialFileContent});

  @override
  State<KurdishVoiceTutorScreen> createState() => _KurdishVoiceTutorScreenState();
}

class _KurdishVoiceTutorScreenState extends State<KurdishVoiceTutorScreen> {
  final KurdishTtsService _ttsService = KurdishTtsService();
  bool _isLoading = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  String? _pdfFileName;
  Map<String, dynamic>? _voiceExplanationData;
  int _activeSectionIndex = 0;

  @override
  void initState() {
    super.initState();
    _ttsService.isSpeakingNotifier.addListener(_onTtsStateChanged);

    if (widget.initialFileName != null && widget.initialFileContent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processInitialContent(widget.initialFileName!, widget.initialFileContent!);
      });
    }
  }

  Future<void> _processInitialContent(String fileName, String content) async {
    setState(() {
      _isLoading = true;
      _pdfFileName = fileName;
      _voiceExplanationData = null;
      _activeSectionIndex = 0;
    });

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final data = await aiService.generateKurdishVoiceLectureExplanation(
        pdfText: content,
        pdfName: fileName,
      );

      if (mounted) {
        setState(() {
          _voiceExplanationData = data;
          _isLoading = false;
        });
        _playCurrentSectionAudio();
      }
    } catch (e) {
      debugPrint('Error processing initial content for voice tutor: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ttsService.isSpeakingNotifier.removeListener(_onTtsStateChanged);
    _ttsService.stop();
    super.dispose();
  }

  void _onTtsStateChanged() {
    if (mounted) {
      setState(() {
        _isPlaying = _ttsService.isSpeakingNotifier.value;
      });
    }
  }

  Future<void> _pickAndProcessPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final fileName = result.files.single.name;

    setState(() {
      _isLoading = true;
      _pdfFileName = fileName;
      _voiceExplanationData = null;
      _activeSectionIndex = 0;
    });

    try {
      String extractedText = '';
      if (fileName.toLowerCase().endsWith('.pdf')) {
        final bytes = await file.readAsBytes();
        final document = sync_pdf.PdfDocument(inputBytes: bytes);
        final extractor = sync_pdf.PdfTextExtractor(document);
        extractedText = extractor.extractText();
        document.dispose();
      } else {
        extractedText = await file.readAsString();
      }

      if (extractedText.trim().isEmpty) {
        extractedText = 'Sample English lecture text regarding computer networks and artificial intelligence.';
      }

      final aiService = Provider.of<AiService>(context, listen: false);
      final data = await aiService.generateKurdishVoiceLectureExplanation(
        pdfText: extractedText,
        pdfName: fileName,
      );

      if (mounted) {
        setState(() {
          _voiceExplanationData = data;
          _isLoading = false;
        });
        _playCurrentSectionAudio();
      }
    } catch (e) {
      debugPrint('Error loading PDF for voice tutor: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە لە خوێندنەوەی فایلی PDF: $e')),
        );
      }
    }
  }

  void _playCurrentSectionAudio() {
    if (_voiceExplanationData == null) return;
    final sections = _voiceExplanationData!['sections'] as List<dynamic>?;
    if (sections == null || sections.isEmpty) return;

    final currentSection = sections[_activeSectionIndex] as Map<String, dynamic>;
    final kurdishText = currentSection['kurdishExplanation'] as String? ?? '';

    if (kurdishText.isNotEmpty) {
      _ttsService.speak(kurdishText, languageCode: 'ku');
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _ttsService.stop();
    } else {
      _playCurrentSectionAudio();
    }
  }

  void _nextSection() {
    if (_voiceExplanationData == null) return;
    final sections = _voiceExplanationData!['sections'] as List<dynamic>?;
    if (sections == null) return;

    if (_activeSectionIndex < sections.length - 1) {
      _ttsService.stop();
      setState(() {
        _activeSectionIndex++;
      });
      _playCurrentSectionAudio();
    }
  }

  void _previousSection() {
    if (_activeSectionIndex > 0) {
      _ttsService.stop();
      setState(() {
        _activeSectionIndex--;
      });
      _playCurrentSectionAudio();
    }
  }

  void _cyclePlaybackSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.25;
      } else if (_playbackSpeed == 1.25) {
        _playbackSpeed = 1.5;
      } else {
        _playbackSpeed = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        backgroundColor: isDark ? ZankoColors.darkBackground : const Color(0xFFF8F9FD),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ZankoColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.waveform_circle_fill, color: ZankoColors.primary, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'مامۆستای دەنگی کوردی 🎧',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Upload Header Card ──────────────────────────────────────
                GestureDetector(
                  onTap: _pickAndProcessPdf,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ZankoColors.primary, ZankoColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: ZankoColors.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.doc_text_fill, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pdfFileName ?? 'هەڵبژاردنی مەلزەمەی ئینگلیزی (PDF)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'کلیک بکە بۆ شیکردنەوەی دەنگی بە زمانی کوردی 🎙️',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(CupertinoIcons.cloud_upload_fill, color: Colors.white, size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Loading or Content Display ──────────────────────────────
                Expanded(
                  child: _isLoading
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: ZankoColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(color: ZankoColors.primary, strokeWidth: 3.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '🤖 مامۆستا AI خەریکی وەرگێڕان و ئامادەکردنی دەنگی کوردییە...',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : _voiceExplanationData == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.music_mic,
                                    size: 70,
                                    color: isDark ? Colors.white24 : Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'مەلزەمە یان فایلی PDF ئینگلیزی هەڵبژێرە\nتا مامۆستا AI بە دەنگی کوردی بۆت بڵێتەوە! 🎓',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildActiveAudioView(isDark),
                ),

                // ── Audio Player Control Bar ───────────────────────────────
                if (_voiceExplanationData != null && !_isLoading) _buildAudioControlBar(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveAudioView(bool isDark) {
    final sections = _voiceExplanationData!['sections'] as List<dynamic>? ?? [];
    if (sections.isEmpty) return const SizedBox();

    final currentSection = sections[_activeSectionIndex] as Map<String, dynamic>;
    final sectionTitle = currentSection['sectionTitle'] as String? ?? '';
    final kurdishExplanation = currentSection['kurdishExplanation'] as String? ?? '';
    final keyTerms = (currentSection['englishKeyTerms'] as List<dynamic>?)?.cast<String>() ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Progress Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'بەشی ${_activeSectionIndex + 1} لە ${sections.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ZankoColors.primary,
                ),
              ),
              Text(
                'پێداچوونەوەی ڕاستەوخۆ 🔴',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Kurdish Explanation Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? ZankoColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
                const Divider(height: 24),
                Text(
                  kurdishExplanation,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: isDark ? Colors.grey[300] : ZankoColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // English Key Terms Card
          if (keyTerms.isNotEmpty) ...[
            Text(
              'وشە کلیلییە ئینگلیزییەکان (Key Terms):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keyTerms.map((term) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ZankoColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    term,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ZankoColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioControlBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Speed button
          TextButton(
            onPressed: _cyclePlaybackSpeed,
            child: Text(
              '${_playbackSpeed}x',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ZankoColors.primary,
                fontSize: 14,
              ),
            ),
          ),

          // Playback navigation
          Row(
            children: [
              IconButton(
                icon: const Icon(CupertinoIcons.backward_fill),
                onPressed: _previousSection,
                color: _activeSectionIndex > 0 ? (isDark ? Colors.white : ZankoColors.textPrimary) : Colors.grey,
              ),
              const SizedBox(width: 12),

              // Main Play / Pause Button
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [ZankoColors.primary, ZankoColors.accent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ZankoColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              IconButton(
                icon: const Icon(CupertinoIcons.forward_fill),
                onPressed: _nextSection,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ],
          ),

          // Soundwave icon indicator
          Icon(
            _isPlaying ? CupertinoIcons.waveform : CupertinoIcons.speaker_1_fill,
            color: _isPlaying ? ZankoColors.accent : Colors.grey,
          ),
        ],
      ),
    );
  }
}
