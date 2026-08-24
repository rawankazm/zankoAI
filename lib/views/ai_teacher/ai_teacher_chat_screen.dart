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
import '../../services/kurdish_tts_service.dart';
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

  // Real Audio Recording & Speech-to-Text State
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedVoiceFilePath;
  bool _isRecording = false;
  bool _isTranscribingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;



  final List<String> _suggestions = [
    'Explain this topic',
    'Generate Quiz',
    'Summarize PDF',
    'Teach me Calculus',
  ];

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

      final response = await aiService.askTeacher(
        text,
        historyToSend,
        isVip: isVip,
        isPendingVip: isPendingVip,
      );
      if (mounted) {
        final words = response.split(' ');
        final assistantIndex = _messages.length;
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'assistant',
            'content': '',
            'time': _formatTime(),
          });
        });

        // Fast & smooth streaming typing animation
        String streamedText = '';
        const chunkSize = 3;
        for (int i = 0; i < words.length; i += chunkSize) {
          if (!mounted) break;
          final chunk = words.sublist(i, (i + chunkSize > words.length) ? words.length : i + chunkSize).join(' ');
          streamedText += (streamedText.isEmpty ? '' : ' ') + chunk;
          setState(() {
            _messages[assistantIndex]['content'] = streamedText;
          });
          _scrollToBottom();
          await Future.delayed(const Duration(milliseconds: 20));
        }

        if (mounted) {
          setState(() {
            _messages[assistantIndex]['content'] = response;
          });
          await _saveChatHistory();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '⚠️ ببورە، کێشەیەک لە پێوەستبوون بە سێرڤەرەکانی AI دروستبوو. تکایە دووبارە هەوڵ بدەرەوە.',
            'time': _formatTime(),
          });
          _isTyping = false;
        });
        await _saveChatHistory();
      }
    }
    _scrollToBottom();
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
          'content': '📷 [وێنەی تاقیکردنەوە/پرسیار بارکرا]: ${image.name}\n${promptText.isNotEmpty ? promptText : ""}',
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
        final words = response.split(' ');
        final assistantIndex = _messages.length;
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'assistant',
            'content': '',
            'time': _formatTime(),
          });
        });

        String streamedText = '';
        const chunkSize = 3;
        for (int i = 0; i < words.length; i += chunkSize) {
          if (!mounted) break;
          final chunk = words.sublist(i, (i + chunkSize > words.length) ? words.length : i + chunkSize).join(' ');
          streamedText += (streamedText.isEmpty ? '' : ' ') + chunk;
          setState(() {
            _messages[assistantIndex]['content'] = streamedText;
          });
          _scrollToBottom();
          await Future.delayed(const Duration(milliseconds: 20));
        }

        if (mounted) {
          setState(() {
            _messages[assistantIndex]['content'] = response;
          });
          await _saveChatHistory();
        }
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTyping = false);
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
        bottom: 12,
        left: 16,
        right: 16,
      ),
      color: const Color(0xFF15181E),
      child: Row(
        children: [
          if (canPop) ...[
            _buildNeumorphicButton(
              icon: CupertinoIcons.arrow_left,
              onTap: () => Navigator.pop(context),
              iconColor: ZankoColors.primary,
            ),
            const SizedBox(width: 12),
          ],

          // User Avatar & Name
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF2A2E37),
              child: Icon(Icons.psychology_rounded, color: ZankoColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.translate('ai_tutor'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
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
                    isVip ? 'VIP 👑 (بێسنوور)' : 'ڕژێمی بەخۆڕایی',
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB8860B), Color(0xFFFFD700)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('👑', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 4),
                    Text(
                      'VIP',
                      style: TextStyle(
                        fontSize: 12,
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
    );
  }

  Widget _buildDateHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: Center(
        child: Text(
          'Today',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 0.2,
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

  String? _currentlySpeakingMsg;

  Widget _buildMessageBubble(Map<String, String> msg, bool isUser) {
    final content = msg['content'] ?? '';
    final time = msg['time'] ?? '4:09 pm';
    final isSpeaking = _currentlySpeakingMsg == content;
    final isLimitMsg = !isUser && (content.contains('Free Daily Limit Reached') || content.contains('سنووری ٥'));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              GestureDetector(
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
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 6, bottom: 4),
                  decoration: BoxDecoration(
                    color: isSpeaking ? ZankoColors.primary : const Color(0xFF252934),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isSpeaking ? ZankoColors.primary : Colors.black).withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    isSpeaking ? CupertinoIcons.speaker_3_fill : CupertinoIcons.speaker_2_fill,
                    color: isSpeaking ? Colors.white : ZankoColors.primary,
                    size: 16,
                  ),
                ),
              ),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: isUser
                    ? BoxDecoration(
                        color: ZankoColors.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ZankoColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        color: isLimitMsg ? const Color(0xFF2C2003) : const Color(0xFF1E222A),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border.all(
                          color: isLimitMsg
                              ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                              : (isSpeaking ? ZankoColors.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06)),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isLimitMsg ? const Color(0xFFFFD700).withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          content,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: isUser ? Colors.white.withValues(alpha: 0.8) : Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isLimitMsg) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => VipUpgradeSheet.show(context),
                          icon: const Text('👑', style: TextStyle(fontSize: 16)),
                          label: const Text(
                            'بەرزکردنەوە بۆ VIP — پەیامی بێسنوور',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB8860B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final hasText = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF15181E),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Custom Header
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
                              color: Colors.white.withValues(alpha: 0.06),
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
                              SizedBox(width: 10),
                              Text(
                                lang.translate('ai_typing'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
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


            // Early Suggestions Pills
            if (_messages.length <= 5)

              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _suggestions.length,
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
                            color: ZankoColors.primary,
                            width: 1,
                          ),
                        ),
                        label: Text(
                          _suggestions[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ZankoColors.primary,
                          ),
                        ),
                        onPressed: () => _sendMessage(_suggestions[index]),
                      ),
                    );
                  },
                ),
              ),

            // Gemini Flash Transcribing HUD Indicator
            if (_isTranscribingVoice)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
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
                      'Gemini Flash دەنگەکەت دەکاتە دەق... ⚡',
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
                              ? Colors.redAccent.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.08),
                          width: _isRecording ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isRecording
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.5),
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
                                        fontSize: 15,
                                        color: Color(0xFF6C717B),
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                 // Attachment Icon
                                 IconButton(
                                   icon: Icon(
                                     CupertinoIcons.paperclip,
                                     color: ZankoColors.primary,
                                     size: 20,
                                   ),
                                   onPressed: _pickAndSolveImage,
                                 ),
                                // Camera Icon
                                IconButton(
                                  icon: Icon(
                                    CupertinoIcons.camera_fill,
                                    color: ZankoColors.primary,
                                    size: 20,
                                  ),
                                  onPressed: _pickAndSolveImage,
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Floating Glowing Action Button (Mic / Stop & Transcribe / Send)
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
                            color: (_isRecording ? const Color(0xFFE11D48) : ZankoColors.primary).withValues(alpha: 0.6),
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
