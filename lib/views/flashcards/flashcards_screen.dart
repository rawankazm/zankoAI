import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flashcard_model.dart';
import '../../services/ai_service.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import 'qr_share_sheet.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final TextEditingController _topicController = TextEditingController();
  bool _isGenerating = false;
  int _currentIndex = 0;
  final Set<int> _learnedCardIndices = {};

  final List<Map<String, String>> _quickTopics = [
    {'title': 'تۆڕەکانی کۆمپیوتەر', 'icon': '🌐'},
    {'title': 'سیستەمی کارپێکردن', 'icon': '💻'},
    {'title': 'ماتماتیک و کالکولەس', 'icon': '🧮'},
    {'title': 'ژیرەیی دەستکرد AI', 'icon': '🤖'},
  ];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateCards([String? predefinedTopic]) async {
    final topic = predefinedTopic ?? _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).translate('snackbar_enter_topic'),
            style: const TextStyle(fontFamily: 'Noto Sans Arabic'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (predefinedTopic != null) {
      _topicController.text = predefinedTopic;
    }

    setState(() {
      _isGenerating = true;
    });

    final aiService = Provider.of<AiService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    try {
      var cards = await aiService.generateFlashcards(topic);
      if (cards.isEmpty) {
        cards = _generateFallbackCards(topic);
      }
      await dbService.clearFlashcards();
      for (var card in cards) {
        await dbService.addFlashcard(card);
      }
      setState(() {
        _isGenerating = false;
        _currentIndex = 0;
        _learnedCardIndices.clear();
      });
    } catch (e) {
      final fallbackCards = _generateFallbackCards(topic);
      await dbService.clearFlashcards();
      for (var card in fallbackCards) {
        await dbService.addFlashcard(card);
      }
      setState(() {
        _isGenerating = false;
        _currentIndex = 0;
        _learnedCardIndices.clear();
      });
    }
  }

  List<FlashcardModel> _generateFallbackCards(String topic) {
    return [
      FlashcardModel(
        id: 'fc_1_${DateTime.now().millisecondsSinceEpoch}',
        front: 'چەمکی بنەڕەتی بابەتەکە ($topic) چییە؟',
        back: 'پێناسەی گشتی ($topic) بریتییە لە کۆمەڵە یاسا و چەمکە زانستییەکان کە بۆ شیکارکردن و تێگەیشتن لە بابەتەکە بەکاردێن.',
      ),
      FlashcardModel(
        id: 'fc_2_${DateTime.now().millisecondsSinceEpoch}',
        front: 'گرنگترین ئامانجی ($topic) لە بواری زانستیدا چییە؟',
        back: 'باشترکردنی خێرایی، کەمکردنەوەی هەڵە مرۆییەکان، و گەیشتن بە ئەنجامی تێروتەسەلی زانستی.',
      ),
      FlashcardModel(
        id: 'fc_3_${DateTime.now().millisecondsSinceEpoch}',
        front: 'چۆن داتاکانی ($topic) شی دەکرێنەوە؟',
        back: 'بە بەکارهێنانی مۆدێلی بیرکاری، فۆرمولە ستانداردەکان، و ئامرازە ئامارییەکان لە پرۆسەی فێربووندا.',
      ),
      FlashcardModel(
        id: 'fc_4_${DateTime.now().millisecondsSinceEpoch}',
        front: 'ڕۆڵی زیرەکی دەستکرد (AI) لە ($topic) چییە؟',
        back: 'ئۆتۆماتیکردنی پرۆسە دووبارەبووەکان، دروستکردنی پێشبینی زیرەکانە، و ئاسانکاری فێربوونی ئەکادیمی.',
      ),
    ];
  }

  void _shuffleDeck(List<FlashcardModel> cards) {
    if (cards.length <= 1) return;
    setState(() {
      cards.shuffle(Random());
      _currentIndex = 0;
      _learnedCardIndices.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎲 کارتەکان تێکەڵکرانەوە!'),
        duration: Duration(seconds: 1),
        backgroundColor: ZankoColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dbService = Provider.of<DatabaseService>(context);

    final cards = dbService.flashcards;

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            t('flashcards_title'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ZankoColors.textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.qrcode_viewfinder, color: ZankoColors.primary),
              tooltip: t('scan_qr_deck'),
              onPressed: () async {
                final success = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QrScannerView()),
                );
                if (success == true) {
                  setState(() {
                    _currentIndex = 0;
                    _learnedCardIndices.clear();
                  });
                }
              },
            ),
            if (cards.isNotEmpty)
              IconButton(
                icon: const Icon(CupertinoIcons.qrcode, color: ZankoColors.primary),
                tooltip: t('share_qr_deck'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QrShareSheet(deck: cards),
                    ),
                  );
                },
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Topic Suggestions Chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickTopics.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = _quickTopics[index];
                      return GestureDetector(
                        onTap: () => _generateCards(item['title']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? ZankoColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: ZankoColors.primary.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(item['icon']!, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 6),
                              Text(
                                item['title']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Generator Input Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? ZankoColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white12 : ZankoColors.primary.withOpacity(0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _topicController,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'بابەتێک بنووسە یان دەقێک لێرە دابنێ...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isGenerating
                          ? Container(
                              height: 48,
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: ZankoColors.primary),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'زیرەکی دەستکرد لە حاڵەتی دروستکردنی فلاشکاردایە...',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6C5CE7), Color(0xFF8E44AD)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C5CE7).withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => _generateCards(),
                                icon: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
                                label: Text(
                                  t('flashcards_generate_btn'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (cards.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(CupertinoIcons.layers, size: 54, color: ZankoColors.primary.withOpacity(0.5)),
                        const SizedBox(height: 14),
                        Text(
                          t('flashcards_empty_state'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Progress & Action Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: ZankoColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'کارتی ${_currentIndex + 1} لە ${cards.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ZankoColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_learnedCardIndices.contains(_currentIndex))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(CupertinoIcons.checkmark_seal_fill, size: 13, color: Color(0xFF10B981)),
                                  SizedBox(width: 4),
                                  Text(
                                    'زانراوە',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.shuffle, color: ZankoColors.primary, size: 20),
                        tooltip: 'تێکەڵکردن',
                        onPressed: () => _shuffleDeck(cards),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 3D Flip Card Container
                  Center(
                    child: FlipCardWidget(
                      key: ValueKey('${cards[_currentIndex].id}_$_currentIndex'),
                      front: _buildCardFace(
                        context,
                        content: cards[_currentIndex].front,
                        title: 'پێشەوە • پرسیار',
                        badgeIcon: CupertinoIcons.question_circle_fill,
                        gradientColors: isDark
                            ? [ZankoColors.darkCardSecondary, const Color(0xFF312E81)]
                            : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                        borderColor: const Color(0xFF6366F1),
                        textColor: isDark ? Colors.white : ZankoColors.darkCardSecondary,
                        tip: 'کلیک بکە بۆ گۆڕینی لای کارتەکە 🔄',
                      ),
                      back: _buildCardFace(
                        context,
                        content: cards[_currentIndex].back,
                        title: 'دواوە • وەڵام و شیکاری',
                        badgeIcon: CupertinoIcons.lightbulb_fill,
                        gradientColors: isDark
                            ? [const Color(0xFF064E3B), const Color(0xFF047857)]
                            : [const Color(0xFFECFDF5), const Color(0xD1D1FADF)],
                        borderColor: const Color(0xFF10B981),
                        textColor: isDark ? Colors.white : const Color(0xFF064E3B),
                        tip: 'کلیک بکە بۆ گۆڕینی لای کارتەکە 🔄',
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bottom Controls Navigation & Marking
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Prev Button
                      GestureDetector(
                        onTap: _currentIndex > 0
                            ? () {
                                setState(() {
                                  _currentIndex--;
                                });
                              }
                            : null,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _currentIndex > 0
                                ? (isDark ? ZankoColors.darkCard : Colors.white)
                                : (isDark ? Colors.white10 : Colors.grey[200]),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _currentIndex > 0 ? ZankoColors.primary.withOpacity(0.3) : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            color: _currentIndex > 0
                                ? (isDark ? Colors.white : ZankoColors.textPrimary)
                                : Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),

                      // Mark as Learned Toggle Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_learnedCardIndices.contains(_currentIndex)) {
                              _learnedCardIndices.remove(_currentIndex);
                            } else {
                              _learnedCardIndices.add(_currentIndex);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: _learnedCardIndices.contains(_currentIndex)
                                ? const Color(0xFF10B981)
                                : ZankoColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _learnedCardIndices.contains(_currentIndex)
                                    ? CupertinoIcons.checkmark_alt_circle_fill
                                    : CupertinoIcons.checkmark_alt_circle,
                                color: _learnedCardIndices.contains(_currentIndex) ? Colors.white : ZankoColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _learnedCardIndices.contains(_currentIndex) ? 'فێربووم ✅' : 'نیشانکردن بە فێربوو',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _learnedCardIndices.contains(_currentIndex) ? Colors.white : ZankoColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Next Button
                      GestureDetector(
                        onTap: _currentIndex < cards.length - 1
                            ? () {
                                setState(() {
                                  _currentIndex++;
                                });
                              }
                            : null,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _currentIndex < cards.length - 1
                                ? (isDark ? ZankoColors.darkCard : Colors.white)
                                : (isDark ? Colors.white10 : Colors.grey[200]),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _currentIndex < cards.length - 1 ? ZankoColors.primary.withOpacity(0.3) : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.chevron_right,
                            color: _currentIndex < cards.length - 1
                                ? (isDark ? Colors.white : ZankoColors.textPrimary)
                                : Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace(
    BuildContext context, {
    required String content,
    required String title,
    required IconData badgeIcon,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color textColor,
    required String tip,
  }) {
    return Container(
      width: double.infinity,
      height: 290,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // Header Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 14, color: textColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Card Main Text Body
          Center(
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.5,
                color: textColor,
              ),
            ),
          ),

          const Spacer(),

          // Flip Hint Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.refresh_thin, size: 14, color: textColor.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                tip,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Flip Card animation widget using standard AnimatedBuilder
class FlipCardWidget extends StatefulWidget {
  final Widget front;
  final Widget back;
  const FlipCardWidget({super.key, required this.front, required this.back});

  @override
  State<FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<FlipCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animation = Tween<double>(begin: 0.0, end: pi).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final value = _animation.value;
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 3D perspective
            ..rotateY(value);

          return Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: value < pi / 2
                ? widget.front
                : Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: widget.back,
                  ),
          );
        },
      ),
    );
  }
}
