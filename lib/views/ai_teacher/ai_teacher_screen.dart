import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';

class AiTeacherScreen extends StatefulWidget {
  const AiTeacherScreen({super.key});

  @override
  State<AiTeacherScreen> createState() => _AiTeacherScreenState();
}

class _AiTeacherScreenState extends State<AiTeacherScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content': 'سڵاو! من ZankoAI مامۆستای زیرەکی تۆم. لە کام بابەتدا دەتەوێت ئەمڕۆ یارمەتیت بدەم؟ دەتوانیت لەسەر لایەنی تیۆری یان کۆدنووسین پرسیار بکەیت.'
    }
  ];

  bool _isTyping = false;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsEnabled = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    if (!_isTtsEnabled) return;
    String cleanText = text
        .replaceAll(RegExp(r'[\*\#\_]'), '')
        .replaceAll(RegExp(r'`{3}[\s\S]*?`{3}'), '[کۆدی بەرنامەسازی]')
        .replaceAll(RegExp(r'`[\s\S]*?`'), '[کۆد]');

    if (RegExp(r'[\u0600-\u06FF]').hasMatch(cleanText)) {
      await _flutterTts.setLanguage("ar");
    } else {
      await _flutterTts.setLanguage("en-US");
    }
    await _flutterTts.speak(cleanText);
  }

  Future<void> _stopTts() async {
    await _flutterTts.stop();
  }

  void _startListening() {
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      if (lang.currentLanguage == AppLanguage.english) {
        _messageController.text = "What are the key concepts of memory management?";
      } else if (lang.currentLanguage == AppLanguage.arabic) {
        _messageController.text = "ما هي المفاهيم الأساسية لإدارة الذاكرة؟";
      } else {
        _messageController.text = "باسی گرنگترین بیرۆکەکانی بەڕێوەبردنی یادگە (Memory Management) بکە.";
      }
    });
  }

  String _getGreetingText(LanguageProvider lang) {
    if (lang.currentLanguage == AppLanguage.english) {
      return "Hello! I am ZankoAI, your smart tutor. How can I help you study today? Feel free to ask about theory, concepts, or coding.";
    } else if (lang.currentLanguage == AppLanguage.arabic) {
      return "مرحباً! أنا ZankoAI أستاذك الذكي. كيف يمكنني مساعدتك في الدراسة اليوم؟ يمكنك السؤال عن الجانب النظري أو البرمجة.";
    } else {
      return "سڵاو! من ZankoAI مامۆستای زیرەکی تۆم. لە کام بابەتدا دەتەوێت ئەمڕۆ یارمەتیت بدەم؟ دەتوانیت لەسەر لایەنی تیۆری یان کۆدنووسین پرسیار بکەیت.";
    }
  }

  List<String> _getPresets(LanguageProvider lang) {
    if (lang.currentLanguage == AppLanguage.english) {
      return [
        'Explain Operating Systems.',
        'Explain this code snippet.',
        'How does Flutter work?',
        'Summarize the OSI Model.'
      ];
    } else if (lang.currentLanguage == AppLanguage.arabic) {
      return [
        'شرح مادة نظم التشغيل (OS).',
        'اشرح هذا الكود البرمجي.',
        'كيف يعمل فلاتر (Flutter)؟',
        'لخص طبقات نموذج OSI.',
      ];
    } else {
      return [
        'وانەی Operating System بۆم فێر بکە.',
        'ئەم کۆدە ڕوون بکەرەوە.',
        'پڕۆگرامی فلاتەر چۆن کاردەکات؟',
        'مۆدێلی OSI کورت بکەرەوە.'
      ];
    }
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
    
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isTyping = true;
    });
    
    _messageController.clear();
    _scrollToBottom();

    final aiService = Provider.of<AiService>(context, listen: false);
    try {
      final response = await aiService.askTeacher(text, _messages.sublist(0, _messages.length - 1));
      
      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _isTyping = false;
      });
      _speak(response);
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'ببوورە، ناتوانم وەڵامت بدەمەوە لەم کاتەدا. هەڵەیەک لە تۆڕدا هەیە.'});
        _isTyping = false;
      });
    }
    
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiService = Provider.of<AiService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    // Update greeting dynamically in place
    if (_messages.isNotEmpty && _messages[0]['role'] == 'assistant' && _messages.length == 1) {
      _messages[0]['content'] = _getGreetingText(langProvider);
    }

    final presets = _getPresets(langProvider);

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded, size: 20),
              ),
              const SizedBox(width: 8),
              Text(t('nav_ai_teacher')),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_isTtsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
              tooltip: 'Text to Speech (بەدەنگ خوێندنەوە)',
              onPressed: () {
                setState(() {
                  _isTtsEnabled = !_isTtsEnabled;
                });
                if (!_isTtsEnabled) {
                  _stopTts();
                } else {
                  // Speak last message if possible
                  if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
                    _speak(_messages.last['content']!);
                  }
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Status bar indicating model mode (Real Gemini vs Mock)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: aiService.hasRealApiKey 
                  ? Colors.green.shade900.withOpacity(0.2) 
                  : Colors.amber.shade900.withOpacity(0.2),
              child: Row(
                children: [
                  Icon(
                    aiService.hasRealApiKey ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 16,
                    color: aiService.hasRealApiKey ? Colors.green : Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiService.hasRealApiKey ? t('gemini_active') : t('mock_active'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: aiService.hasRealApiKey ? Colors.green.shade300 : Colors.amber.shade300,
                        fontFamily: 'Noto Sans Arabic',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isUser 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 16),
                        ),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message['content']!,
                            style: TextStyle(
                              color: isUser 
                                  ? Colors.white 
                                  : theme.colorScheme.onSurfaceVariant,
                              fontFamily: 'Noto Sans Arabic',
                              height: 1.4,
                            ),
                          ),
                          if (!isUser) ...[
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.record_voice_over_rounded, size: 60, color: Colors.blue),
                                              const SizedBox(height: 16),
                                              const Text(
                                                'خوێندنەوەی دەنگی چالاکە 🔊',
                                                style: TextStyle(fontFamily: 'Noto Sans Arabic', fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: List.generate(5, (index) => Container(
                                                  width: 6,
                                                  height: 20.0 + (index % 2 == 0 ? 15.0 : 0.0),
                                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blueAccent,
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                )),
                                              ),
                                              const SizedBox(height: 16),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('وەستان / Stop', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.volume_up_rounded, size: 16, color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Read Aloud',
                                        style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Typing state indicator
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t('ai_thinking'),
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontFamily: 'Noto Sans Arabic',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

            // Presets suggestions
            if (_messages.length == 1)
              SizedBox(
                height: 46,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(
                          presets[index],
                          style: const TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 11),
                        ),
                        onPressed: () => _sendMessage(presets[index]),
                      ),
                    );
                  },
                ),
              ),
              
            const SizedBox(height: 8),

            // Message Input bar
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: t('ask_teacher_hint'),
                        hintStyle: const TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onLongPressStart: (_) => _startListening(),
                    onLongPressEnd: (_) => _stopListening(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.red.withOpacity(0.2) : theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        color: _isListening ? Colors.red : theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: () => _sendMessage(_messageController.text),
                    mini: true,
                    child: const Icon(Icons.send_rounded),
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
