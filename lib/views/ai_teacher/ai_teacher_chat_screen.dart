import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../services/ai_service.dart';

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
      final prefs = await SharedPreferences.getInstance();
      final hasPrompted = prefs.getBool('has_prompted_api_key') ?? false;
      if (!mounted) return;
      final aiService = Provider.of<AiService>(context, listen: false);

      if (!hasPrompted && !aiService.hasRealApiKey) {
        await prefs.setBool('has_prompted_api_key', true);
        if (mounted) {
          _showApiKeyModal(context);
        }
      }

      if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
        _sendMessage(widget.initialPrompt!);
      }
    });
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
                _messages.add(Map<String, String>.from(item));
              }
            });
            _scrollToBottom();
            return;
          }
        } catch (_) {}
      }
    }

    // Default welcome message if expired or empty
    setState(() {
      _messages.clear();
      _messages.add({
        'role': 'assistant',
        'content': 'Hello! I am your AI Tutor powered by Apple Intelligence & ZankoAI. How can I help you excel today?',
      });
    });
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_chat_history', jsonEncode(_messages));
    await prefs.setInt('ai_chat_saved_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_chat_history');
    await prefs.remove('ai_chat_saved_time');
    setState(() {
      _messages.clear();
      _messages.add({
        'role': 'assistant',
        'content': 'Hello! I am your AI Tutor powered by Apple Intelligence & ZankoAI. How can I help you excel today?',
      });
    });
  }

  void _showApiKeyModal(BuildContext context) {
    final aiService = Provider.of<AiService>(context, listen: false);
    final controller = TextEditingController(text: aiService.apiKey ?? '');

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.sparkles, color: ZankoColors.primary, size: 22),
            SizedBox(width: 8),
            Text(Provider.of<LanguageProvider>(context, listen: false).translate('gemini_api_key')),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Column(
            children: [
              Text(
                'Configure your Google Gemini API key for real-time online AI responses.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: controller,
                placeholder: 'Paste API Key here (AIzaSy...)',
                obscureText: true,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('cancel')),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('save_key')),
            onPressed: () {
              final key = controller.text.trim();
              aiService.apiKey = key.isNotEmpty ? key : null;
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      key.isNotEmpty ? 'API Key saved successfully!' : 'Cleared API Key.',
                    ),
                    backgroundColor: ZankoColors.primary,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
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

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();
    await _saveChatHistory();

    try {
      final response = await aiService.askTeacher(
        text,
        _messages.sublist(0, _messages.length - 1),
      );
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response});
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
          });
          _isTyping = false;
        });
        await _saveChatHistory();
      }
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String key) => lang.translate(key);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withOpacity(0.9),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(CupertinoIcons.back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ZankoColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.sparkles,
                color: ZankoColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              langProvider.translate('ai_tutor'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.trash, size: 18, color: ZankoColors.textSecondary),
            tooltip: t('clear_chat_tooltip'),
            onPressed: () {
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: Text(t('clear_chat_history')),
                  content: Text(t('clear_chat_desc')),
                  actions: [
                    CupertinoDialogAction(
                      child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('cancel')),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      child: Text(t('clear')),
                      onPressed: () {
                        Navigator.pop(context);
                        _clearChatHistory();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.key_rounded, size: 20, color: ZankoColors.primary),
            tooltip: t('config_api_key_tooltip'),
            onPressed: () => _showApiKeyModal(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? ZankoColors.primary
                            : (isDark ? ZankoColors.darkCard : Colors.white),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(22),
                          topRight: const Radius.circular(22),
                          bottomLeft: Radius.circular(isUser ? 22 : 6),
                          bottomRight: Radius.circular(isUser ? 6 : 22),
                        ),
                        boxShadow: isUser
                            ? [
                                BoxShadow(
                                  color: ZankoColors.primary.withOpacity(0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : (isDark ? [] : ZankoShadows.card),
                        border: isUser
                            ? null
                            : Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : const Color(0xFFF0F0F6),
                              ),
                      ),
                      child: Text(
                        msg['content']!,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                          color: isUser
                              ? Colors.white
                              : (isDark ? Colors.white : ZankoColors.textPrimary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.sparkles,
                        color: ZankoColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Tutor is thinking...',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: ZankoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Suggestions horizontal list if early conversation
            if (_messages.length <= 2)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: isDark ? ZankoColors.darkCard : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: ZankoColors.primary.withOpacity(0.2),
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

            const SizedBox(height: 10),

            // Bottom Input Bar
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? ZankoColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(ZankoRadius.input),
                  boxShadow: isDark ? [] : ZankoShadows.card,
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFEFEFF7),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.paperclip,
                        color: ZankoColors.textSecondary,
                        size: 22,
                      ),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: _sendMessage,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: t('ask_ai_anything'),
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: ZankoColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.mic,
                        color: ZankoColors.textSecondary,
                        size: 22,
                      ),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _sendMessage(_controller.text),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [ZankoColors.primary, ZankoColors.accent],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: ZankoShadows.glow,
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_up,
                          color: Colors.white,
                          size: 20,
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
}
