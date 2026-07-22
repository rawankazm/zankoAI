import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
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

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateCards() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('snackbar_enter_topic'), style: const TextStyle())),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    final aiService = Provider.of<AiService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    try {
      final cards = await aiService.generateFlashcards(topic);
      await dbService.clearFlashcards();
      for (var card in cards) {
        await dbService.addFlashcard(card);
      }
      setState(() {
        _isGenerating = false;
        _currentIndex = 0;
        _topicController.clear();
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Provider.of<LanguageProvider>(context, listen: false).translate('failed_to_generate')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final __lang = Provider.of<LanguageProvider>(context);
    String t(String key) => __lang.translate(key);
    final theme = Theme.of(context);
    final dbService = Provider.of<DatabaseService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    final cards = dbService.flashcards;

    // Translation maps
    final String title = t('flashcards_title');
    final String inputLabel = t('flashcards_input_label');
    final String generateBtn = t('flashcards_generate_btn');
    final String emptyState = t('flashcards_empty_state');
    final String tapToFlip = t('flashcards_tap_to_flip');

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: t('scan_qr_deck'),
              onPressed: () async {
                final success = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QrScannerView()),
                );
                if (success == true) {
                  setState(() {
                    _currentIndex = 0;
                  });
                }
              },
            ),
            if (cards.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded),
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Generator card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _topicController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: inputLabel,
                          hintText: t('flashcards_hint'),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isGenerating
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _generateCards,
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(generateBtn),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade600),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (cards.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(emptyState, style: const TextStyle()),
                  ),
                )
              else ...[
                // Deck Display
                Center(
                  child: FlipCardWidget(
                    key: ValueKey(cards[_currentIndex].id),
                    front: _buildCardFace(
                      context,
                      content: cards[_currentIndex].front,
                      title: 'پێشەوە / Front',
                      color: Colors.blue.shade900.withOpacity(0.15),
                      textColor: theme.colorScheme.primary,
                      tip: tapToFlip,
                    ),
                    back: _buildCardFace(
                      context,
                      content: cards[_currentIndex].back,
                      title: 'دواوە / Back',
                      color: Colors.purple.shade900.withOpacity(0.15),
                      textColor: Colors.purple.shade300,
                      tip: tapToFlip,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      onPressed: _currentIndex > 0
                          ? () {
                              setState(() {
                                _currentIndex--;
                              });
                            }
                          : null,
                    ),
                    Text(
                      '${_currentIndex + 1} / ${cards.length}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded),
                      onPressed: _currentIndex < cards.length - 1
                          ? () {
                              setState(() {
                                _currentIndex++;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace(
    BuildContext context, {
    required String content,
    required String title,
    required Color color,
    required Color textColor,
    required String tip,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark 
            ? color 
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor.withOpacity(0.8),
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Center(
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flip_camera_android_rounded, size: 14, color: textColor.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                tip,
                style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6), ),
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
      duration: const Duration(milliseconds: 500),
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
            ..setEntry(3, 2, 0.001) // perspective
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
