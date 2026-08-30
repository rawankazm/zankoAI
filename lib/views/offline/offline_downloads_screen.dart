import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/offline_archive_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';

class OfflineDownloadsScreen extends StatefulWidget {
  const OfflineDownloadsScreen({super.key});

  @override
  State<OfflineDownloadsScreen> createState() => _OfflineDownloadsScreenState();
}

class _OfflineDownloadsScreenState extends State<OfflineDownloadsScreen> {
  String _selectedCategory = 'all'; // 'all' | 'flashcard' | 'summary' | 'quiz'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OfflineArchiveService.instance.loadOfflineItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    final offlineService = OfflineArchiveService.instance;

    return ListenableBuilder(
      listenable: offlineService,
      builder: (context, _) {
        final allItems = offlineService.cachedItems;
        final filteredItems = _selectedCategory == 'all'
            ? allItems
            : allItems.where((e) => e.category == _selectedCategory).toList();

        return Scaffold(
          backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          langProvider.translate('offline_archive'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        actions: [
          if (allItems.isNotEmpty)
            IconButton(
              icon: const Icon(CupertinoIcons.trash, size: 20, color: ZankoColors.error),
              tooltip: 'پاککردنەوەی هەمووی',
              onPressed: () async {
                final confirm = await showCupertinoDialog<bool>(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: const Text('پاککردنەوەی ئەرشیف'),
                    content: const Text('دڵنیایت لە سڕینەوەی هەموو بابەتە داگیراوەکانی ئۆفلاین؟'),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('پاشگەزبوونەوە'),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        child: const Text('سڕینەوە'),
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await offlineService.clearAll();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Offline Mode Banner & Storage Meter ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.wifi_slash,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'دۆخی ئۆفلاین بەگەڕخراوە ✅',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${allItems.length} بابەتی داگیراو • ${offlineService.getTotalStorageKB()} KB میمۆری',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Category Selector Chips ──
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip('all', 'هەمووی (${allItems.length})', CupertinoIcons.square_grid_2x2_fill),
                  const SizedBox(width: 8),
                  _buildCategoryChip('flashcard', '🎴 فلاش کارتەکان', CupertinoIcons.rectangle_on_rectangle_angled),
                  const SizedBox(width: 8),
                  _buildCategoryChip('summary', '📝 کورتکراوەی PDF', CupertinoIcons.doc_text),
                  const SizedBox(width: 8),
                  _buildCategoryChip('quiz', '✏️ کویزەکان', CupertinoIcons.checkmark_seal),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Items List ──
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.square_stack_3d_up_slash,
                            size: 54,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            langProvider.translate('no_offline_items'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildOfflineItemCard(context, item, isDark, offlineService);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildCategoryChip(String categoryId, String label, IconData icon) {
    final isSelected = _selectedCategory == categoryId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = categoryId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ZankoColors.primary : (isDark ? const Color(0xFF1E222A) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? ZankoColors.primary : (isDark ? Colors.white10 : Colors.grey[300]!),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineItemCard(
    BuildContext context,
    OfflineItemModel item,
    bool isDark,
    OfflineArchiveService service,
  ) {
    IconData categoryIcon;
    Color categoryColor;
    String categoryLabel;

    switch (item.category) {
      case 'flashcard':
        categoryIcon = CupertinoIcons.rectangle_on_rectangle_angled;
        categoryColor = const Color(0xFFFF9F0A);
        categoryLabel = 'فلاش کارت';
        break;
      case 'quiz':
        categoryIcon = CupertinoIcons.checkmark_seal_fill;
        categoryColor = const Color(0xFF34C759);
        categoryLabel = 'کویز';
        break;
      default:
        categoryIcon = CupertinoIcons.doc_text_fill;
        categoryColor = const Color(0xFF6C5CE7);
        categoryLabel = 'کورتکراوە';
        break;
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(categoryIcon, color: categoryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        categoryLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${item.fileSizeKB} KB',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
                Text(
                  item.courseName.isNotEmpty ? item.courseName : 'زانیاری کارپێکردن',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _openOfflineRevisionModal(context, item),
            style: ElevatedButton.styleFrom(
              backgroundColor: ZankoColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'خوێندنەوە',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.trash, size: 16, color: Colors.grey),
            onPressed: () => service.deleteOfflineItem(item.id),
          ),
        ],
      ),
    );
  }

  void _openOfflineRevisionModal(BuildContext context, OfflineItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15181E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            if (item.category == 'flashcard') {
              return _buildOfflineFlashcardPlayer(context, item, scrollController);
            } else if (item.category == 'quiz') {
              return _buildOfflineQuizPlayer(context, item, scrollController);
            } else {
              return _buildOfflineSummaryReader(context, item, scrollController);
            }
          },
        );
      },
    );
  }

  Widget _buildOfflineSummaryReader(
    BuildContext context,
    OfflineItemModel item,
    ScrollController scrollController,
  ) {
    final summaryText = item.payload['summaryText'] ?? 'هیچ دەقێک بەردەست نییە';

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Text(
                summaryText,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineFlashcardPlayer(
    BuildContext context,
    OfflineItemModel item,
    ScrollController scrollController,
  ) {
    final List<dynamic> cards = item.payload['cards'] ?? [];
    int currentIndex = 0;
    bool isFlipped = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        if (cards.isEmpty) {
          return const Center(child: Text('هیچ فلاش کارتێک بەردەست نییە', style: TextStyle(color: Colors.white)));
        }

        final card = cards[currentIndex];

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.title} (${currentIndex + 1}/${cards.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GestureDetector(
                  onTap: () => setModalState(() => isFlipped = !isFlipped),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isFlipped ? ZankoColors.darkCardSecondary : const Color(0xFF1E222A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isFlipped ? const Color(0xFFFF9F0A) : ZankoColors.primary,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isFlipped ? '💡 وەڵام:' : '❓ پرسیار:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isFlipped ? const Color(0xFFFF9F0A) : ZankoColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isFlipped ? (card['back'] ?? '') : (card['front'] ?? ''),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'داگرە تا وەڵامەکە یان پرسیارەکە بگەڕێتەوە 🔄',
                            style: TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: currentIndex > 0
                          ? () => setModalState(() {
                                currentIndex--;
                                isFlipped = false;
                              })
                          : null,
                      icon: const Icon(CupertinoIcons.arrow_right),
                      label: const Text('پێشوو'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: currentIndex < cards.length - 1
                          ? () => setModalState(() {
                                currentIndex++;
                                isFlipped = false;
                              })
                          : null,
                      icon: const Icon(CupertinoIcons.arrow_left),
                      label: const Text('داهاتوو'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineQuizPlayer(
    BuildContext context,
    OfflineItemModel item,
    ScrollController scrollController,
  ) {
    final List<dynamic> questions = item.payload['questions'] ?? [];
    int currentIndex = 0;
    int? selectedOption;
    bool isAnswered = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        if (questions.isEmpty) {
          return const Center(child: Text('هیچ پرسیارێک بەردەست نییە', style: TextStyle(color: Colors.white)));
        }

        final q = questions[currentIndex];
        final List<dynamic> options = q['options'] ?? [];
        final int correctIndex = q['correctIndex'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.title} (${currentIndex + 1}/${questions.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                q['question'] ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: options.length,
                  itemBuilder: (context, optIdx) {
                    final isCorrect = optIdx == correctIndex;
                    final isSelected = selectedOption == optIdx;

                    Color bgColor = const Color(0xFF1E222A);
                    Color borderColor = Colors.white10;

                    if (isAnswered) {
                      if (isCorrect) {
                        bgColor = const Color(0xFF059669).withValues(alpha: 0.3);
                        borderColor = const Color(0xFF10B981);
                      } else if (isSelected) {
                        bgColor = const Color(0xFFE11D48).withValues(alpha: 0.3);
                        borderColor = const Color(0xFFF43F5E);
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        if (!isAnswered) {
                          setModalState(() {
                            selectedOption = optIdx;
                            isAnswered = true;
                          });
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${optIdx + 1}.',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                options[optIdx].toString(),
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (currentIndex < questions.length - 1)
                ElevatedButton(
                  onPressed: () {
                    setModalState(() {
                      currentIndex++;
                      selectedOption = null;
                      isAnswered = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZankoColors.primary,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('پرسیاری داهاتوو ➡️'),
                ),
            ],
          ),
        );
      },
    );
  }
}
