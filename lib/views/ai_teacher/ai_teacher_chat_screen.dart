import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/language_provider.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/document_parser_service.dart';
import '../../services/kurdish_tts_service.dart';
import '../../models/note_model.dart';
import '../../theme.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../widgets/apple_ui_components.dart';
import '../payment/vip_upgrade_sheet.dart';


class AiTeacherChatScreen extends StatefulWidget {
  final String? initialPrompt;

  const AiTeacherChatScreen({super.key, this.initialPrompt});

  @override
  State<AiTeacherChatScreen> createState() => _AiTeacherChatScreenState();
}

class _AiTeacherChatScreenState extends State<AiTeacherChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  // Active Teaching Mode
  int _selectedModeIndex = 0;
  final List<Map<String, dynamic>> _modes = [
    {'title': 'گشتی 🧑‍🏫', 'tag': 'General Academic'},
    {'title': 'هاوکێشە و یاساکان 📐', 'tag': 'Step-by-Step Math & Formula Solver'},
    {'title': 'کۆد و IT 💻', 'tag': 'Coding & Computer Science'},
    {'title': 'پزیشکی و دەرمان 🏥', 'tag': 'Medicine & Health'},
    {'title': 'کورتکردنەوە 📝', 'tag': 'Summarize & Simplify'},
    {'title': 'تاقیکردنەوە ⚡', 'tag': 'Exam Preparation & Prediction'},
  ];

  // Quick Math & Formula Symbols
  static const List<String> _mathSymbols = [
    'x²', 'xⁿ', '√', '∛', '∫', 'dy/dx', 'lim', 'π', '±', '÷', '×',
    'Δ', 'θ', '∞', 'log', 'ln', 'sin', 'cos', 'tan', '∑', '≠', '≤', '≥', '≈', 'f(x)', 'λ'
  ];
  bool _showMathToolbar = false;

  void _insertMathSymbol(String symbol) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, symbol);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );
    setState(() {});
  }

  // Real Audio Recording & Speech-to-Text State
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedVoiceFilePath;
  bool _isRecording = false;
  bool _isTranscribingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _currentlySpeakingMsg;

  List<String> get _currentSuggestions {
    switch (_selectedModeIndex) {
      case 1:
        return [
          'شیکارکردنی هاوکێشەی دووجا (ax² + bx + c = 0)',
          'دۆزینەوەی داتاشراو (Derivatives dy/dx)',
          'تەواوکاری دیاریکراو و نادیار (Integrals ∫)',
          'یاساکانی نیوتن و هێز لە فیزیا (Physics)',
          'ماتریس و لیمیت (Limits & Matrices)',
          'هاوکێشەی کیمیایی و باڵانس کردن (Chemistry)',
          'شیکاری نەخشەی سێگۆشەزانی (Trigonometry)',
        ];
      case 2:
        return [
          'پێناسەی OOP و چەمکەکانی',
          'جیاوازی نێوان SQL و NoSQL',
          'چۆن فلاتەر کار دەکات؟',
          'شیکاری ئەم هەڵەی کۆدە',
        ];
      case 3:
        return [
          'ئەناتۆمی و فرمانی دڵ',
          'جیاوازی بەکتریا و ڤایرۆس',
          'چەمکی Pharmacokinetics',
          'نیشانەکانی کەمخوێنی (Anemia)',
        ];
      case 4:
        return [
          'مەلزەمەکەم بۆ کورت بکەرەوە',
          'دەرکێشانی خاڵە سەرەکییەکان',
          'پوختەی ئەم پارچە دەقە',
          'ڕوونکردنەوەی بە سادەیی',
        ];
      case 5:
        return [
          '٥ پرسیاری تاقیکردنەوە پێشبینی بکە',
          'کویزی خێرا لەسەر ئەم بابەتە',
          'پلانی خوێندن بۆ ٣ ڕۆژ',
          'گرنگترین پێناسەکانی فاینەڵ',
        ];
      default:
        return [
          'باسی ئەم بابەتەم بۆ بکە',
          'پوختەی وانەکە چییە؟',
          'ڕێنمایی بۆ خوێندنی تاقیکردنەوە',
          'شیکاری پرسیاری زانستی',
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadChatHistory();

    KurdishTtsService().isSpeakingNotifier.addListener(_onTtsStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
        _sendMessage(widget.initialPrompt!);
      }
    });
  }

  void _onTtsStateChanged() {
    if (!KurdishTtsService().isSpeaking && mounted && _currentlySpeakingMsg != null) {
      setState(() => _currentlySpeakingMsg = null);
    }
  }

  String _formatTime([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final hour = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTimestamp = prefs.getInt('ai_chat_saved_time');
    final rawJson = prefs.getString('ai_chat_history');

    if (rawTimestamp != null && rawJson != null) {
      final savedDate = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
      final daysDiff = DateTime.now().difference(savedDate).inDays;

      if (daysDiff < 7) {
        try {
          final List<dynamic> decoded = jsonDecode(rawJson);
          if (decoded.isNotEmpty && mounted) {
            setState(() {
              _messages.clear();
              for (var item in decoded) {
                final map = Map<String, String>.from(item);
                map['time'] ??= '4:09 pm';
                _messages.add(map);
              }
            });
            _scrollToBottom();
            return;
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    // Default clean welcome message
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    setState(() {
      _messages.clear();
      _messages.add({
        'role': 'assistant',
        'content': lang.translate('ai_welcome'),
        'time': _formatTime(),
      });
    });
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_chat_history', jsonEncode(_messages));
    await prefs.setInt('ai_chat_saved_time', DateTime.now().millisecondsSinceEpoch);
  }

  void clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_chat_history');
    await prefs.remove('ai_chat_saved_time');
    if (!mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    setState(() {
      _messages.clear();
      _messages.add({
        'role': 'assistant',
        'content': lang.translate('ai_welcome'),
        'time': _formatTime(),
      });
    });
  }

  @override
  void dispose() {
    KurdishTtsService().isSpeakingNotifier.removeListener(_onTtsStateChanged);
    KurdishTtsService().stop();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        HapticFeedback.mediumImpact();
        setState(() {
          _recordedVoiceFilePath = path;
          _isRecording = true;
          _recordSeconds = 0;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordSeconds++;
            });
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ڕێگەپێدانی مایکرۆفۆن پێویستە بۆ تۆمارکردنی دەنگ 🎙️'),
              backgroundColor: ZankoColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە لە دەستپێکردنی تۆمار: $e')),
        );
      }
    }
  }

  Future<void> _stopAndTranscribeVoice() async {
    _recordTimer?.cancel();
    final filePath = _recordedVoiceFilePath;
    final aiService = Provider.of<AiService>(context, listen: false);

    setState(() {
      _isRecording = false;
      _isTranscribingVoice = true;
    });

    HapticFeedback.mediumImpact();

    try {
      if (_recordSeconds < 1) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
      final path = await _audioRecorder.stop();
      final targetPath = path ?? filePath;

      if (targetPath != null) {
        final file = File(targetPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();

          final transcript = await aiService.transcribeAudio(
            bytes,
            'voice_chat.m4a',
            mimeType: 'audio/mp4',
          );

          if (mounted) {
            setState(() {
              _isTranscribingVoice = false;
            });

            if (transcript.trim().isNotEmpty) {
              _sendMessage(transcript.trim());
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('نەتوانرا دەنگەکە ببیسترێت، تکایە دووبارە بڵێوە.')),
              );
            }
          }

          // Clean up temp file
          try {
            await file.delete();
          } catch (_) {}
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە لە نوسینەوەی دەنگ: $e')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isTranscribingVoice = false;
      });
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordTimer?.cancel();
    final filePath = _recordedVoiceFilePath;

    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });

    HapticFeedback.lightImpact();

    try {
      await _audioRecorder.stop();
      if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  } catch (_) {}
  }



  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final aiService = Provider.of<AiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final isVip = authService.currentUser?.isVip ?? false;
    final isPendingVip = authService.currentUser?.isPendingVip ?? false;
    final timestamp = _formatTime();

    setState(() {
      _messages.add({'role': 'user', 'content': text, 'time': timestamp});
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();
    await _saveChatHistory();

    try {
      if (!mounted) return;
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      final welcomeText = lang.translate('ai_welcome');
      final historyToSend = _messages
          .sublist(0, _messages.length - 1)
          .where((m) => m['content'] != welcomeText && (m['role'] == 'user' || m['role'] == 'assistant'))
          .toList();

      final modePrefix = _selectedModeIndex != 0
          ? "[تایبەتمەندی: ${_modes[_selectedModeIndex]['tag']}]\n"
          : "";

      final response = await aiService.askTeacher(
        modePrefix + text,
        historyToSend,
        isVip: isVip,
        isPendingVip: isPendingVip,
      );

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'assistant',
            'content': response,
            'time': _formatTime(),
          });
        });
        await _saveChatHistory();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '⚠️ ببورە، کێشەیەک لە پەیوەندی بە سێرڤەر ڕوویدا. تکایە دووبارە پرسیارەکەت بنووسەوە.',
            'time': _formatTime(),
          });
          _isTyping = false;
        });
        await _saveChatHistory();
        _scrollToBottom();
      }
    }
  }

  Future<void> _pickAndSolveImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      _showImagePreviewAndNoteSheet(bytes, image.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('نەتوانرا وێنەکە باربکرێت: $e')),
        );
      }
    }
  }

  void _showImagePreviewAndNoteSheet(Uint8List bytes, String imageName) {
    final noteController = TextEditingController(text: _controller.text.trim());
    final isMathMode = _selectedModeIndex == 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161922),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grab handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ZankoColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                            icon: isMathMode ? HugeIcons.strokeRoundedAnalytics01 : HugeIcons.strokeRoundedImage01,
                            color: ZankoColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMathMode ? 'شیکاری هاوکێشەی ناو وێنە 📐' : 'ناردنی وێنە لەگەڵ تێبینی 📷',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                imageName,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, color: Colors.white38, size: 22),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Image Thumbnail Card
                    Container(
                      height: 170,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1117),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: ZankoColors.primary.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick prompt suggestion chips
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildQuickPromptChip('📐 شیکاری هەنگاو بە هەنگاو', noteController, setSheetState),
                          _buildQuickPromptChip('🎯 تەنها وەڵامی کۆتایی', noteController, setSheetState),
                          _buildQuickPromptChip('🌐 وەرگێڕان بۆ کوردی', noteController, setSheetState),
                          _buildQuickPromptChip('💡 ڕوونکردنەوەی سادە', noteController, setSheetState),
                          _buildQuickPromptChip('📝 کورتکردنەوەی ناوەڕۆک', noteController, setSheetState),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Note Input Box
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: noteController,
                        maxLines: 3,
                        minLines: 1,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'تێبینی یان پرسیارەکەت لەسەر ئەم وێنەیە بنووسە... (ئارەزوومەندانە)',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'پەشیمانبوونەوە',
                              style: TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final note = noteController.text.trim();
                              Navigator.pop(sheetCtx);
                              _controller.clear();
                              _processAndSendImage(bytes, imageName, note);
                            },
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedSent, size: 17, color: Colors.black),
                            label: const Text(
                              'ناردن بۆ مامۆستا 🚀',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ZankoColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickPromptChip(String text, TextEditingController controller, StateSetter setSheetState) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setSheetState(() {
            if (controller.text.isEmpty) {
              controller.text = text;
            } else {
              controller.text = '${controller.text} - $text';
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF242933),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: ZankoColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processAndSendImage(Uint8List bytes, String imageName, String promptText) async {
    final timestamp = _formatTime();
    final isMathMode = _selectedModeIndex == 1;
    final modeTag = isMathMode ? "📐 [شیکاری هاوکێشە و یاسا]" : "📷 [وێنەی پرسیار/وانە]";
    final base64Image = base64Encode(bytes);

    setState(() {
      _messages.add({
        'role': 'user',
        'content': promptText.isNotEmpty ? promptText : imageName,
        'time': timestamp,
        'imageName': imageName,
        'imageBase64': base64Image,
        'modeTag': modeTag,
      });
      _isTyping = true;
    });

    _scrollToBottom();
    await _saveChatHistory();

    if (!mounted) return;
    final aiService = Provider.of<AiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final isVip = authService.currentUser?.isVip ?? false;
    final isPendingVip = authService.currentUser?.isPendingVip ?? false;

    try {
      final response = await aiService.solveImageQuestion(
        bytes,
        promptText,
        isVip: isVip,
        isPendingVip: isPendingVip,
      );

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'assistant',
            'content': response,
            'time': _formatTime(),
          });
        });
        await _saveChatHistory();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'assistant',
            'content': '⚠️ ببورە، کێشەیەک لە پەیوەندی بە سێرڤەر ڕوویدا لە کاتی شیکارکردنی وێنەکە.',
            'time': _formatTime(),
          });
        });
        await _saveChatHistory();
        _scrollToBottom();
      }
    }
  }

  Future<void> _pickAndSolvePdf() async {
    try {
      final parsed = await DocumentParserService.pickAndExtractDocument();

      if (parsed == null) return;

      final extractedText = parsed.content;
      if (extractedText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('نەتوانرا دەقی ئەم فایلە دەربهێنرێت.')),
          );
        }
        return;
      }

      final safeText = extractedText.length > 5000 ? extractedText.substring(0, 5000) : extractedText;
      final promptToSend = "📄 [فایلی وانە: ${parsed.fileName} - ${parsed.typeDisplayName}]\nتکایە ئەم فایلەی خوارەوە بە کورتی و زانستی شی بکەرەوە و خاڵە سەرەکییەکانی دیاری بکە:\n\n$safeText";

      _sendMessage(promptToSend);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە لە خوێندنەوەی فایل: $e')),
        );
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 16),
            const Text(
              'هاوپێچکردنی پرسیار یان وانە 📎',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAttachmentOption(
                    icon: HugeIcons.strokeRoundedCamera01,
                    color: ZankoColors.primary,
                    label: 'کامێرای هاوکێشە',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSolveImage(source: ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAttachmentOption(
                    icon: HugeIcons.strokeRoundedImage01,
                    color: ZankoColors.primary,
                    label: 'وێنەی گەلەری',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSolveImage();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAttachmentOption(
                    icon: HugeIcons.strokeRoundedFile02,
                    color: ZankoColors.primary,
                    label: 'فایلی PDF/وانە',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSolvePdf();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required dynamic icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            appIcon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAsNote(String content) async {
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final firstLine = content.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'تێبینی مامۆستا');
      final cleanTitle = firstLine.replaceAll('#', '').replaceAll('*', '').trim();
      final title = cleanTitle.length > 40 ? '${cleanTitle.substring(0, 40)}...' : cleanTitle;

      await db.addNote(NoteModel(
        id: 'note_${DateTime.now().millisecondsSinceEpoch}',
        title: title.isNotEmpty ? title : 'تێبینی وانەی ZankoAI',
        content: content,
        createdAt: DateTime.now(),
        isAiFormatted: true,
        courseName: _modes[_selectedModeIndex]['title'],
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ بە سەرکەوتوویی لە بەشی تێبینییەکان پاشەکەوت کرا! 📑'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە لە پاشەکەوتکردنی تێبینی: $e')),
        );
      }
    }
  }

  Widget _buildNeumorphicButton({
    required dynamic icon,
    required VoidCallback onTap,
    Color? iconColor,
    double size = 44.0,
  }) {
    final effectiveColor = iconColor ?? ZankoColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1E222B),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 10,
              offset: const Offset(3, 4),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Center(
          child: appIcon(
            icon,
            color: effectiveColor,
            size: 20,
          ),
        ),
      ),
    );
  }



  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);
    final lang = Provider.of<LanguageProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final isVip = authService.currentUser?.isVip ?? false;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 10,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171B23) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (canPop) ...[
                _buildNeumorphicButton(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  onTap: () => Navigator.pop(context),
                  iconColor: const Color(0xFF035EC2),
                ),
                const SizedBox(width: 10),
              ],

              // Teacher Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF035EC2).withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF035EC2).withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: isDark ? const Color(0xFF2A2E37) : const Color(0xFFE2EDFB),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/robot.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const HugeIcon(
                        icon: HugeIcons.strokeRoundedAiMagic,
                        color: Color(0xFF035EC2),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        lang.translate('ai_tutor'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : const Color(0xFF17191F),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2EDFB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF035EC2).withValues(alpha: 0.3), width: 0.8),
                        ),
                        child: const Text(
                          '⚡ Gemini 3.7 Flash',
                          style: TextStyle(fontSize: 10, color: Color(0xFF035EC2), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVip ? 'VIP 👑 (نامەی بێسنوور)' : 'ڕژێمی ئاسایی',
                        style: TextStyle(
                          fontSize: 11,
                          color: isVip ? const Color(0xFF10B981) : Colors.white60,
                          fontWeight: isVip ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              if (!isVip)
                GestureDetector(
                  onTap: () => VipUpgradeSheet.show(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👑', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 3),
                        Text(
                          'VIP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Teaching Mode Horizontal Selector
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _modes.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedModeIndex == index;
                final mode = _modes[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedModeIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF035EC2)
                            : (isDark ? const Color(0xFF1E222A) : const Color(0xFFF4F6F9)),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF035EC2)
                              : (isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2)),
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF035EC2).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          mode['title'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      child: Center(
        child: Text(
          'ئەمڕۆ / Today',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    final emojis = [
      '📚', '🎓', '💡', '🤔', '📝', '✨', '❓', '📐',
      '🧪', '💻', '🧠', '🎯', '👍', '👋', '⭐', '🔥',
      '💬', '📊', '📖', '📌', '⚡', '🏆', '💯', '✅',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ئیمۆجییەکان',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, index) {
                    final emoji = emojis[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.text += emoji;
                        });
                        Navigator.pop(context);
                      },
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBubbleAction({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1E26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            appIcon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg, bool isUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = msg['content'] ?? '';
    final time = msg['time'] ?? _formatTime();
    final isSpeaking = _currentlySpeakingMsg == content;
    final isLimitMsg = !isUser && (content.contains('Free Daily Limit Reached') || content.contains('سنووری ١٠'));
    final imageBase64 = msg['imageBase64'];
    final imageName = msg['imageName'];
    final modeTag = msg['modeTag'];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: isUser
                  ? BoxDecoration(
                      color: const Color(0xFF035EC2),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF035EC2).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    )
                  : BoxDecoration(
                      color: isLimitMsg
                          ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F6FD))
                          : (isDark ? const Color(0xFF171B23) : Colors.white),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(5),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // If user sent an image, show interactive thumbnail
                  if (imageBase64 != null && imageBase64.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _showFullScreenImage(imageBase64, imageName ?? 'وێنە'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 220, minWidth: 180),
                          color: Colors.black.withValues(alpha: 0.25),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.memory(
                                base64Decode(imageBase64),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      HugeIcon(icon: HugeIcons.strokeRoundedMaximize01, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('گەورەکردن', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (modeTag != null && modeTag.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      margin: const EdgeInsets.only(bottom: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        modeTag,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],

                  if (content.isNotEmpty)
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                        color: isUser
                            ? Colors.white
                            : (isDark ? Colors.white : const Color(0xFF17191F)),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.75)
                            : (isDark ? Colors.white38 : const Color(0xFFA6ACB8)),
                      ),
                    ),
                  ),
                  if (isLimitMsg) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => VipUpgradeSheet.show(context),
                        icon: const Text('👑', style: TextStyle(fontSize: 15)),
                        label: const Text(
                          'بەرزکردنەوە بۆ VIP — پەیامی بێسنوور',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZankoColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action Toolbar for Assistant Messages (Copy, Save Note, TTS, Deeper Explanation)
            if (!isUser && !isLimitMsg && content.isNotEmpty) ...[
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // 1. Copy
                  _buildBubbleAction(
                    icon: HugeIcons.strokeRoundedCopy01,
                    label: 'کۆپی',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: content));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('دەقی وەڵامەکە کۆپی کرا! 📋'),
                          backgroundColor: Colors.blueGrey,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),

                  // 2. Save to Notes
                  _buildBubbleAction(
                    icon: HugeIcons.strokeRoundedBookmark02,
                    label: 'تێبینی',
                    color: ZankoColors.primary,
                    onTap: () => _saveAsNote(content),
                  ),

                  // 3. Read Aloud (TTS)
                  _buildBubbleAction(
                    icon: isSpeaking ? HugeIcons.strokeRoundedVolumeHigh : HugeIcons.strokeRoundedVolumeLow,
                    label: isSpeaking ? 'وەستان' : 'دەنگ',
                    color: isSpeaking ? ZankoColors.primary : Colors.white70,
                    onTap: () async {
                      if (isSpeaking) {
                        await KurdishTtsService().stop();
                        if (mounted) setState(() => _currentlySpeakingMsg = null);
                      } else {
                        if (mounted) setState(() => _currentlySpeakingMsg = content);
                        final lang = Provider.of<LanguageProvider>(context, listen: false);
                        String langCode = 'ku';
                        if (lang.currentLanguage == AppLanguage.arabic) {
                          langCode = 'ar';
                        } else if (lang.currentLanguage == AppLanguage.english) {
                          langCode = 'en';
                        }
                        await KurdishTtsService().speak(content, languageCode: langCode);
                      }
                    },
                  ),
                  // 4. Explain More
                  _buildBubbleAction(
                    icon: HugeIcons.strokeRoundedAiMagic,
                    label: 'ڕوونکردنەوەی زیاتر',
                    color: ZankoColors.primary,
                    onTap: () {
                      _sendMessage('تکایە بە شێوازێکی قووڵتر و بە نموونەی زیاتر ئەم بابەتە شی بکەرەوە.');
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);
    final hasText = _controller.text.trim().isNotEmpty;
    final suggestions = _currentSuggestions;

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Custom Header with Mode Selector
            _buildHeader(context),

            // Messages List
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildDateHeader(),
                  ..._messages.map((msg) {
                    final isUser = msg['role'] == 'user';
                    return _buildMessageBubble(msg, isUser);
                  }),
                  if (_isTyping)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF171B23) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF035EC2)),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'مامۆستا ZankoAI وەڵامت دەداتەوە... ⚡',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF035EC2),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Mode-specific suggestions pills
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: isDark ? const Color(0xFF171B23) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF262C36) : const Color(0xFFE2EDFB),
                          width: 1,
                        ),
                      ),
                      label: Text(
                        suggestions[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF035EC2),
                        ),
                      ),
                      onPressed: () => _sendMessage(suggestions[index]),
                    ),
                  );
                },
              ),
            ),

            // Voice Transcribing Indicator
            if (_isTranscribingVoice)
              Container(
                margin: const EdgeInsets.only(top: 6, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ZankoColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ZankoColors.primary.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'دەنگەکەت دەکرێتە دەق... ⚡',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // Math Quick Camera Solve Banner (when in Math & Formula mode)
            if (_selectedModeIndex == 1)
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ZankoColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ZankoColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedAnalytics01, color: ZankoColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'شیکاری هەنگاو بە هەنگاو: وێنەی هاوکێشە یان یاساکە بگرە 📐',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _pickAndSolveImage(source: ImageSource.camera),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: ZankoColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedCamera01, color: Colors.black, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'کامێرا',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Quick Math Symbols Toolbar (when in Math Mode or toggled)
            if (_selectedModeIndex == 1 || _showMathToolbar)
              _buildMathSymbolBar(),

            const SizedBox(height: 4),

            // Bottom Input Bar
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
              child: Row(
                children: [
                  // Main Input Container
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF171B23) : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: _isRecording
                              ? Colors.redAccent.withValues(alpha: 0.6)
                              : (isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2)),
                          width: _isRecording ? 1.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isRecording
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isRecording
                          ? Row(
                              children: [
                                IconButton(
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedDelete02,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  tooltip: 'هەڵوەشاندنەوە / Cancel',
                                  onPressed: _cancelVoiceRecording,
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(_recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'دەنگ تۆمار دەکرێت... قسە بکە 🎙️',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                // Emoji Button
                                IconButton(
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedSmile,
                                    color: Color(0xFF035EC2),
                                    size: 22,
                                  ),
                                  onPressed: _showEmojiPicker,
                                ),
                                // Math Toolbar Toggle Button
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (_selectedModeIndex == 1 || _showMathToolbar)
                                          ? const Color(0xFF035EC2).withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (_selectedModeIndex == 1 || _showMathToolbar)
                                            ? const Color(0xFF035EC2)
                                            : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'f(x)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: (_selectedModeIndex == 1 || _showMathToolbar)
                                            ? const Color(0xFF035EC2)
                                            : (isDark ? const Color(0xFF8E95A3) : const Color(0xFF6B7280)),
                                      ),
                                    ),
                                  ),
                                  tooltip: 'هێما بیرکارییەکان / Math Toolbar',
                                  onPressed: () {
                                    setState(() {
                                      _showMathToolbar = !_showMathToolbar;
                                    });
                                  },
                                ),
                                // TextField
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    onChanged: (_) => setState(() {}),
                                    onSubmitted: _sendMessage,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isDark ? Colors.white : const Color(0xFF17191F),
                                    ),
                                    decoration: InputDecoration(
                                      filled: false,
                                      fillColor: Colors.transparent,
                                      hintText: lang.translate('type_message'),
                                      hintStyle: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF9CA3AF),
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                // Attachment Icon (PDF / Image / Notes)
                                IconButton(
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedAttachment01,
                                    color: Color(0xFF035EC2),
                                    size: 20,
                                  ),
                                  tooltip: 'هاوپێچکردنی فایل یان وێنە',
                                  onPressed: _showAttachmentOptions,
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Action Button (Mic / Stop & Transcribe / Send)
                  GestureDetector(
                    onTap: () {
                      if (hasText) {
                        _sendMessage(_controller.text);
                      } else if (_isRecording) {
                        _stopAndTranscribeVoice();
                      } else if (!_isTranscribingVoice) {
                        _startVoiceRecording();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? const Color(0xFFE11D48)
                            : (_isTranscribingVoice ? const Color(0xFF4A148C) : const Color(0xFF035EC2)),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? const Color(0xFFE11D48) : const Color(0xFF035EC2)).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isTranscribingVoice
                          ? const Center(
                              child: CupertinoActivityIndicator(color: Colors.white),
                            )
                          : HugeIcon(
                              icon: hasText
                                  ? HugeIcons.strokeRoundedArrowUp01
                                  : (_isRecording ? HugeIcons.strokeRoundedCheckmarkCircle02 : HugeIcons.strokeRoundedMic01),
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMathSymbolBar() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _mathSymbols.length,
        itemBuilder: (context, index) {
          final sym = _mathSymbols[index];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _insertMathSymbol(sym),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E222A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ZankoColors.primary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      sym,
                      style: TextStyle(
                        color: ZankoColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenImage(String base64Str, String title) {
    try {
      final bytes = base64Decode(base64Str);
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.85),
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, color: Colors.white70, size: 32),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }
}
