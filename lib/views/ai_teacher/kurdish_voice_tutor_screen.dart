import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../services/document_parser_service.dart';
import '../../services/kurdish_tts_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';

class KurdishVoiceTutorScreen extends StatefulWidget {
  final String? initialFileName;
  final String? initialFileContent;

  const KurdishVoiceTutorScreen({super.key, this.initialFileName, this.initialFileContent});

  @override
  State<KurdishVoiceTutorScreen> createState() => _KurdishVoiceTutorScreenState();
}

class _KurdishVoiceTutorScreenState extends State<KurdishVoiceTutorScreen> {
  final KurdishTtsService _ttsService = KurdishTtsService();
  final ScrollController _chipsScrollController = ScrollController();
  bool _isLoading = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  String? _pdfFileName;
  Map<String, dynamic>? _voiceExplanationData;
  int _activeSectionIndex = 0;
  String _selectedVoiceLang = 'ku';
  String? _lastContent;

  @override
  void initState() {
    super.initState();
    _ttsService.isSpeakingNotifier.addListener(_onTtsStateChanged);

    if (widget.initialFileName != null && widget.initialFileContent != null) {
      _lastContent = widget.initialFileContent!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptLanguageAndGenerate(widget.initialFileName!, widget.initialFileContent!);
      });
    }
  }

  void _promptLanguageAndGenerate(String fileName, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZankoColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.globe, size: 36, color: ZankoColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'هەڵبژاردنی زمانی ڕوونکردنەوەی دەنگی 🎙️',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'دەتەوێت مامۆستا AI بە چ زمانێک فایلی ($fileName) بە دەنگ لێکبداتەوە؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _generateAudioExplanation(fileName, content, lang: 'ku');
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZankoColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Text('☀️', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'زمانی کوردی (سۆرانی)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                          ),
                          const Text('ڕوونکردنەوەی ڕێکخراو و تێروتەسەلی مامۆستایانە بە کوردی', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_left, color: ZankoColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _generateAudioExplanation(fileName, content, lang: 'en');
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZankoColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ZankoColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Text('🇬🇧', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'English (ئینگلیزی)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                          ),
                          const Text('HD Neural Academic AI Voice Explanation in English', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_left, color: ZankoColors.accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAudioExplanation(String fileName, String content, {required String lang}) async {
    setState(() {
      _isLoading = true;
      _pdfFileName = fileName;
      _selectedVoiceLang = lang;
      _lastContent = content;
      _voiceExplanationData = null;
      _activeSectionIndex = 0;
    });

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      final data = await aiService.generateKurdishVoiceLectureExplanation(
        pdfText: content,
        pdfName: fileName,
        targetLanguage: lang,
      );

      if (mounted) {
        setState(() {
          _voiceExplanationData = data;
          _isLoading = false;
        });
        _playCurrentSectionAudio();
      }
    } catch (e) {
      debugPrint('Error generating audio explanation: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('نەتوانرا ڕوونکردنەوەی دەنگی دروستبکرێت: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _chipsScrollController.dispose();
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
    final parsed = await DocumentParserService.pickAndExtractDocument();

    if (parsed == null) return;

    final fileName = parsed.fileName;

    try {
      String extractedText = parsed.content;

      if (extractedText.trim().isEmpty) {
        extractedText = 'Sample English lecture text regarding computer networks and artificial intelligence.';
      }

      _lastContent = extractedText;
      if (mounted) {
        _promptLanguageAndGenerate(fileName, extractedText);
      }
    } catch (e) {
      debugPrint('Error loading document for voice tutor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە لە خوێندنەوەی فایل: $e')),
        );
      }
    }
  }

  void _playCurrentSectionAudio() {
    _playSectionAt(_activeSectionIndex);
  }

  void _playSectionAt(int index) {
    if (_voiceExplanationData == null) return;
    final sections = _voiceExplanationData!['sections'] as List<dynamic>?;
    if (sections == null || sections.isEmpty || index >= sections.length) return;

    // Smoothly scroll active chip into view
    if (_chipsScrollController.hasClients) {
      final targetScroll = (index * 130.0).clamp(0.0, _chipsScrollController.position.maxScrollExtent);
      _chipsScrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    final section = sections[index] as Map<String, dynamic>;
    final textToSpeak = section['kurdishExplanation'] as String? ?? '';
    final aiService = Provider.of<AiService>(context, listen: false);

    if (textToSpeak.isNotEmpty) {
      _ttsService.speak(
        textToSpeak,
        languageCode: _selectedVoiceLang,
        apiKey: aiService.apiKey,
        speed: _playbackSpeed,
        onDone: () {
          // Auto-advance to next section when current finishes
          if (mounted && index < sections.length - 1) {
            setState(() => _activeSectionIndex = index + 1);
            _playSectionAt(index + 1);
          }
        },
      );
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
      setState(() => _activeSectionIndex++);
      _playSectionAt(_activeSectionIndex);
    }
  }

  void _previousSection() {
    if (_activeSectionIndex > 0) {
      _ttsService.stop();
      setState(() => _activeSectionIndex--);
      _playSectionAt(_activeSectionIndex);
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

    if (_isPlaying) {
      _playCurrentSectionAudio();
    }
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
          actions: [
            if (_pdfFileName != null && _lastContent != null)
              IconButton(
                icon: Icon(CupertinoIcons.globe, color: ZankoColors.primary),
                tooltip: 'گۆڕینی زمانی دەنگ 🎙️',
                onPressed: () {
                  _promptLanguageAndGenerate(_pdfFileName!, _lastContent!);
                },
              ),
          ],
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

    final summary = _voiceExplanationData!['summary'] as String? ?? '';
    final title = _voiceExplanationData!['title'] as String? ?? '';
    final currentSection = sections[_activeSectionIndex] as Map<String, dynamic>;
    final sectionTitle = currentSection['sectionTitle'] as String? ?? '';
    final kurdishExplanation = currentSection['kurdishExplanation'] as String? ?? '';
    final keyTerms = (currentSection['englishKeyTerms'] as List<dynamic>?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary card ──────────────────────────────────────────────
        if (summary.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ZankoColors.primary.withValues(alpha: 0.12), ZankoColors.accent.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZankoColors.primary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  summary,
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: isDark ? Colors.grey[300] : ZankoColors.textSecondary),
                ),
              ],
            ),
          ),

        // ── Section cards list (horizontal scroll) ────────────────────
        SizedBox(
          height: 52,
          child: ListView.separated(
            controller: _chipsScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final sec = sections[i] as Map<String, dynamic>;
              final secTitle = sec['sectionTitle'] as String? ?? 'بەشی ${i + 1}';
              final isActive = i == _activeSectionIndex;
              return GestureDetector(
                onTap: () {
                  if (_activeSectionIndex != i) {
                    _ttsService.stop();
                    setState(() => _activeSectionIndex = i);
                  }
                  _playSectionAt(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(colors: [ZankoColors.primary, ZankoColors.accent])
                        : null,
                    color: isActive ? null : (isDark ? ZankoColors.darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? ZankoColors.primary : (isDark ? Colors.white12 : Colors.grey[200]!),
                    ),
                    boxShadow: isActive
                        ? [BoxShadow(color: ZankoColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive && _isPlaying)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(CupertinoIcons.waveform, size: 14, color: Colors.white),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        '${i + 1}. ${secTitle.length > 28 ? '${secTitle.substring(0, 28)}…' : secTitle}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // ── Active section detail ─────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header + play indicator
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sectionTitle,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : ZankoColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ZankoColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                          size: 18,
                          color: ZankoColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Voice Waveform Visualizer
                VoiceWaveformWidget(isPlaying: _isPlaying),
                const SizedBox(height: 14),

                // Explanation text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? ZankoColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isPlaying
                          ? ZankoColors.primary.withValues(alpha: 0.4)
                          : (isDark ? Colors.white10 : Colors.grey[200]!),
                      width: _isPlaying ? 1.5 : 1,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Text(
                    kurdishExplanation,
                    style: TextStyle(fontSize: 14.5, height: 1.7, color: isDark ? Colors.grey[300] : ZankoColors.textPrimary),
                    textDirection: _selectedVoiceLang == 'en' ? TextDirection.ltr : TextDirection.rtl,
                  ),
                ),
                const SizedBox(height: 16),

                // Key Terms
                if (keyTerms.isNotEmpty) ...[
                  Text(
                    'وشە کلیلییەکان (Key Terms):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : ZankoColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: keyTerms.map((term) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: ZankoColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Text(term, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ZankoColors.primary)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 80),
                ],
              ],
            ),
          ),
        ),
      ],
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

// ─── Animated Voice Waveform Visualizer ──────────────────────────────────────
class VoiceWaveformWidget extends StatefulWidget {
  final bool isPlaying;
  final Color primaryColor;
  final Color accentColor;

  const VoiceWaveformWidget({
    super.key,
    required this.isPlaying,
    this.primaryColor = const Color(0xFF10B981),
    this.accentColor = const Color(0xFF06B6D4),
  });

  @override
  State<VoiceWaveformWidget> createState() => _VoiceWaveformWidgetState();
}

class _VoiceWaveformWidgetState extends State<VoiceWaveformWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<double> _baseHeights = [
    0.3, 0.6, 0.9, 0.4, 0.8, 1.0, 0.5, 0.7, 0.3, 0.8, 0.6, 1.0,
    0.7, 0.4, 0.9, 0.5, 0.8, 0.3, 0.6, 0.9, 0.4, 0.7, 0.5, 0.3
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.primaryColor.withValues(alpha: widget.isPlaying ? 0.25 : 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_baseHeights.length, (i) {
              final phase = (i / _baseHeights.length) * 3.14;
              final wave = widget.isPlaying
                  ? math.sin(_animController.value * 2 * 3.14 + phase).abs()
                  : 0.15;
              final heightFactor = (0.2 + wave * _baseHeights[i] * 0.8).clamp(0.15, 1.0);

              return Container(
                width: 3.5,
                height: 32 * heightFactor,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, widget.accentColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: widget.isPlaying
                      ? [
                          BoxShadow(
                            color: widget.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
