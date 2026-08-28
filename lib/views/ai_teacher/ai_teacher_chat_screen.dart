import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;
import '../../services/language_provider.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/kurdish_tts_service.dart';
import '../../models/note_model.dart';
import '../../theme.dart';
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
    {'title': 'کۆد و IT 💻', 'tag': 'Coding & Computer Science'},
    {'title': 'بیرکاری و زانست 📐', 'tag': 'Math, Physics & Engineering'},
    {'title': 'پزیشکی و دەرمان 🏥', 'tag': 'Medicine & Health'},
    {'title': 'کورتکردنەوە 📝', 'tag': 'Summarize & Simplify'},
    {'title': 'تاقیکردنەوە ⚡', 'tag': 'Exam Preparation & Prediction'},
  ];

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
          'پێناسەی OOP و چەمکەکانی',
          'جیاوازی نێوان SQL و NoSQL',
          'چۆن فلاتەر کار دەکات؟',
          'شیکاری ئەم هەڵەی کۆدە',
        ];
      case 2:
        return [
          'یاسای داتاشراو (Derivatives)',
          'تەواوکاری شیکار بکە (Integrals)',
          'ماتریسەکان لە جەبری هێڵی',
          'یاساکانی نیوتن لە فیزیا',
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

  void _showApiKeyDialog(BuildContext context) {
    final aiService = Provider.of<AiService>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final controller = TextEditingController(text: aiService.apiKey ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang.translate('enter_api_key'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gemini API Key (Google AI Studio):',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: const Color(0xFF15181E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.translate('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZankoColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              aiService.apiKey = controller.text.trim();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ API Key updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(lang.translate('save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
            mimeType: 'audio/m4a',
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

  Future<void> _pickAndSolveImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final promptText = _controller.text.trim();
      _controller.clear();

      final timestamp = _formatTime();
      setState(() {
        _messages.add({
          'role': 'user',
          'content': '📷 [وێنەی پرسیار/تاقیکردنەوە بارکرا]: ${image.name}\n${promptText.isNotEmpty ? promptText : ""}',
          'time': timestamp,
        });
        _isTyping = true;
      });

      _scrollToBottom();
      await _saveChatHistory();

      final aiService = Provider.of<AiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final isVip = authService.currentUser?.isVip ?? false;
      final isPendingVip = authService.currentUser?.isPendingVip ?? false;

      final response = await aiService.solveImageQuestion(bytes, promptText, isVip: isVip, isPendingVip: isPendingVip);

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
        setState(() => _isTyping = false);
      }
    }
  }

  Future<void> _pickAndSolvePdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      String extractedText = '';
      if (file.bytes != null) {
        if (file.name.toLowerCase().endsWith('.pdf')) {
          final doc = sync_pdf.PdfDocument(inputBytes: file.bytes!);
          extractedText = sync_pdf.PdfTextExtractor(doc).extractText();
          doc.dispose();
        } else {
          extractedText = utf8.decode(file.bytes!);
        }
      } else if (file.path != null) {
        final ioFile = File(file.path!);
        final bytes = await ioFile.readAsBytes();
        if (file.name.toLowerCase().endsWith('.pdf')) {
          final doc = sync_pdf.PdfDocument(inputBytes: bytes);
          extractedText = sync_pdf.PdfTextExtractor(doc).extractText();
          doc.dispose();
        } else {
          extractedText = utf8.decode(bytes);
        }
      }

      if (extractedText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('نەتوانرا دەقی ئەم فایلە دەربهێنرێت.')),
          );
        }
        return;
      }

      final safeText = extractedText.length > 5000 ? extractedText.substring(0, 5000) : extractedText;
      final promptToSend = "📄 [فایلی وانە: ${file.name}]\nتکایە ئەم فایلەی خوارەوە بە کورتی و زانستی شی بکەرەوە و خاڵە سەرەکییەکانی دیاری بکە:\n\n$safeText";

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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: CupertinoIcons.photo,
                  color: Colors.purpleAccent,
                  label: 'وێنەی گەلەری',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSolveImage();
                  },
                ),
                _buildAttachmentOption(
                  icon: CupertinoIcons.doc_text_fill,
                  color: Colors.blueAccent,
                  label: 'فایلی PDF/وانە',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSolvePdf();
                  },
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
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
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
    required IconData icon,
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
        child: Icon(
          icon,
          color: effectiveColor,
          size: 20,
        ),
      ),
    );
  }



  Widget _buildHeader(BuildContext context) {
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
      color: const Color(0xFF15181E),
      child: Column(
        children: [
          Row(
            children: [
              if (canPop) ...[
                _buildNeumorphicButton(
                  icon: CupertinoIcons.arrow_left,
                  onTap: () => Navigator.pop(context),
                  iconColor: ZankoColors.primary,
                ),
                const SizedBox(width: 10),
              ],

              // Teacher Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: ZankoColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFF2A2E37),
                  child: Icon(Icons.psychology_rounded, color: ZankoColors.primary, size: 22),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: const Text(
                          '⚡ Gemini 3.7 Flash',
                          style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isVip ? const Color(0xFFFFD700) : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVip ? 'VIP 👑 (نامەی بێسنوور)' : 'ڕژێمی ئاسایی',
                        style: TextStyle(
                          fontSize: 11,
                          color: isVip ? const Color(0xFFFFD700) : Colors.white60,
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
                        colors: [Color(0xFFB8860B), Color(0xFFFFD700)],
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
                            color: Color(0xFF2C1F00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _buildNeumorphicButton(
                icon: Icons.key_rounded,
                onTap: () => _showApiKeyDialog(context),
                iconColor: ZankoColors.primary,
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
                        color: isSelected ? ZankoColors.primary : const Color(0xFF1E222A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? ZankoColors.primary : Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: ZankoColors.primary.withValues(alpha: 0.4),
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
                            color: isSelected ? Colors.white : Colors.white70,
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
            color: Colors.white.withOpacity(0.4),
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
    required IconData icon,
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
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
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
    final content = msg['content'] ?? '';
    final time = msg['time'] ?? _formatTime();
    final isSpeaking = _currentlySpeakingMsg == content;
    final isLimitMsg = !isUser && (content.contains('Free Daily Limit Reached') || content.contains('سنووری ١٠'));

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
                      color: ZankoColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ZankoColors.primary.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : BoxDecoration(
                      color: isLimitMsg ? const Color(0xFF2C2003) : const Color(0xFF1E222A),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: isLimitMsg
                            ? const Color(0xFFFFD700).withOpacity(0.5)
                            : Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isUser ? Colors.white.withOpacity(0.7) : Colors.white38,
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
                          backgroundColor: const Color(0xFFB8860B),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Copy
                  _buildBubbleAction(
                    icon: CupertinoIcons.doc_on_doc,
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
                  const SizedBox(width: 6),

                  // 2. Save to Notes
                  _buildBubbleAction(
                    icon: CupertinoIcons.bookmark,
                    label: 'تێبینی',
                    color: Colors.amberAccent,
                    onTap: () => _saveAsNote(content),
                  ),
                  const SizedBox(width: 6),

                  // 3. Read Aloud (TTS)
                  _buildBubbleAction(
                    icon: isSpeaking ? CupertinoIcons.speaker_3_fill : CupertinoIcons.speaker_2,
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
                  const SizedBox(width: 6),

                  // 4. Explain More
                  _buildBubbleAction(
                    icon: CupertinoIcons.sparkles,
                    label: 'ڕوونکردنەوەی زیاتر',
                    color: Colors.cyanAccent,
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
    final lang = Provider.of<LanguageProvider>(context);
    final hasText = _controller.text.trim().isNotEmpty;
    final suggestions = _currentSuggestions;

    return Scaffold(
      backgroundColor: const Color(0xFF15181E),
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
                            color: const Color(0xFF1E222A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(ZankoColors.primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'مامۆستا ZankoAI وەڵامت دەداتەوە... ⚡',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
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
                      backgroundColor: const Color(0xFF1E222A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: ZankoColors.primary.withOpacity(0.6),
                          width: 1,
                        ),
                      ),
                      label: Text(
                        suggestions[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ZankoColors.primary,
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
                  color: ZankoColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ZankoColors.primary.withOpacity(0.4),
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
                        color: const Color(0xFF1B1E26),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: _isRecording
                              ? Colors.redAccent.withOpacity(0.6)
                              : Colors.white.withOpacity(0.08),
                          width: _isRecording ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isRecording
                                ? Colors.redAccent.withOpacity(0.2)
                                : Colors.black.withOpacity(0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _isRecording
                          ? Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.trash,
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
                                const Expanded(
                                  child: Text(
                                    'دەنگ تۆمار دەکرێت... قسە بکە 🎙️',
                                    style: TextStyle(
                                      color: Colors.white70,
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
                                  icon: Icon(
                                    CupertinoIcons.smiley,
                                    color: ZankoColors.primary,
                                    size: 22,
                                  ),
                                  onPressed: _showEmojiPicker,
                                ),
                                // TextField
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    onChanged: (_) => setState(() {}),
                                    onSubmitted: _sendMessage,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: lang.translate('type_message'),
                                      hintStyle: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6C717B),
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
                                  icon: Icon(
                                    CupertinoIcons.paperclip,
                                    color: ZankoColors.primary,
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

                  // Glowing Action Button (Mic / Stop & Transcribe / Send)
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
                            : (_isTranscribingVoice ? const Color(0xFF4A148C) : ZankoColors.primary),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? const Color(0xFFE11D48) : ZankoColors.primary).withOpacity(0.6),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isTranscribingVoice
                          ? const Center(
                              child: CupertinoActivityIndicator(color: Colors.white),
                            )
                          : Icon(
                              hasText
                                  ? CupertinoIcons.arrow_up
                                  : (_isRecording ? CupertinoIcons.checkmark_alt : CupertinoIcons.mic_fill),
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
}
