import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/language_provider.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';


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
  bool _isRecording = false;

  final FlutterTts _flutterTts = FlutterTts();

  Future<void> _speakKurdish(String text) async {
    String cleanText = text
        .replaceAll(RegExp(r'[\*\#\_\🔹\🔸\🎯\⭐]'), '')
        .replaceAll(RegExp(r'`{3}[\s\S]*?`{3}'), '')
        .replaceAll(RegExp(r'`[\s\S]*?`'), '');

    try {
      final isCkbAvailable = await _flutterTts.isLanguageAvailable("ckb") ?? false;
      if (isCkbAvailable) {
        await _flutterTts.setLanguage("ckb");
      } else {
        final isKuAvailable = await _flutterTts.isLanguageAvailable("ku") ?? false;
        if (isKuAvailable) {
          await _flutterTts.setLanguage("ku");
        } else {
          await _flutterTts.setLanguage("en-US");
        }
      }
    } catch (_) {
      await _flutterTts.setLanguage("en-US");
    }

    await _flutterTts.setSpeechRate(0.48);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.speak(cleanText);
  }

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
        _sendMessage(widget.initialPrompt!);
      }
    });
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
          if (decoded.isNotEmpty) {
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
    final timestamp = _formatTime();

    setState(() {
      _messages.add({'role': 'user', 'content': text, 'time': timestamp});
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();
    await _saveChatHistory();

    try {
      final response = await aiService.askTeacher(
        text,
        _messages.sublist(0, _messages.length - 1),
        isVip: isVip,
      );
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': response,
            'time': _formatTime(),
          });
          _isTyping = false;
        });
        await _saveChatHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'I encountered an issue connecting to AI servers. Please try again.',
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

      final response = await aiService.solveImageQuestion(bytes, promptText, isVip: isVip);

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': response,
            'time': _formatTime(),
          });
          _isTyping = false;
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
            child: const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFF2A2E37),
              child: Icon(Icons.psychology_rounded, color: ZankoColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            lang.translate('ai_tutor'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
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

  String? _currentlySpeakingMsg;

  Widget _buildMessageBubble(Map<String, String> msg, bool isUser) {
    final content = msg['content'] ?? '';
    final time = msg['time'] ?? '4:09 pm';
    final isSpeaking = _currentlySpeakingMsg == content;

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
                    await _flutterTts.stop();
                    if (mounted) setState(() => _currentlySpeakingMsg = null);
                  } else {
                    if (mounted) setState(() => _currentlySpeakingMsg = content);
                    _flutterTts.setCompletionHandler(() {
                      if (mounted) setState(() => _currentlySpeakingMsg = null);
                    });
                    await _speakKurdish(content);
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
                        color: const Color(0xFF1E222A),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border.all(
                          color: isSpeaking ? ZankoColors.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                child: Wrap(
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
                          side: const BorderSide(
                            color: ZankoColors.primary,
                            width: 1,
                          ),
                        ),
                        label: Text(
                          _suggestions[index],
                          style: const TextStyle(
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

            const SizedBox(height: 8),

            // Bottom Input Bar
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
              child: Row(
                children: [
                  // Main Input Container
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1E26),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Emoji Button
                          IconButton(
                            icon: const Icon(
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
                            icon: const Icon(
                              CupertinoIcons.paperclip,
                              color: ZankoColors.primary,
                              size: 20,
                            ),
                            onPressed: _pickAndSolveImage,
                          ),
                          // Camera Icon
                          IconButton(
                            icon: const Icon(
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

                  // Floating Glowing App Stamp Color Button (Mic / Send)
                  GestureDetector(
                    onTap: () {
                      if (hasText) {
                        _sendMessage(_controller.text);
                      } else {
                        setState(() {
                          _isRecording = !_isRecording;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isRecording ? 'Listening...' : 'Voice recording stopped'),
                            duration: const Duration(seconds: 1),
                            backgroundColor: ZankoColors.primary,
                          ),
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isRecording ? ZankoColors.accent : ZankoColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ZankoColors.primary.withValues(alpha: 0.6),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        hasText
                            ? CupertinoIcons.arrow_up
                            : (_isRecording ? CupertinoIcons.square_fill : CupertinoIcons.mic_fill),
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
