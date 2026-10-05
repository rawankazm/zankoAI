import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/ai_service.dart';
import '../../data/academic_dictionary_data.dart';
import '../../theme.dart';

enum DepartmentCategory {
  all,
  medicine,
  computer,
  engineering,
  business,
  law,
  science,
  humanities,
}

class AcademicTerm {
  final String term;
  final String kuName;
  final String category;
  final String kuDesc;
  final String enDesc;
  final String? example;

  AcademicTerm({
    required this.term,
    required this.kuName,
    required this.category,
    required this.kuDesc,
    required this.enDesc,
    this.example,
  });
}

class AcademicDictionaryScreen extends StatefulWidget {
  const AcademicDictionaryScreen({super.key});

  @override
  State<AcademicDictionaryScreen> createState() =>
      _AcademicDictionaryScreenState();
}

class _AcademicDictionaryScreenState extends State<AcademicDictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  DepartmentCategory _selectedCategory = DepartmentCategory.all;
  bool _isSearchingAi = false;
  AcademicTerm? _aiResultTerm;

  late final List<AcademicTerm> _dictionaryTerms =
      AcademicDictionaryData.getExpandedTerms();

  List<AcademicTerm> get _filteredTerms {
    final query = _searchController.text.trim().toLowerCase();

    return _dictionaryTerms.where((item) {
      bool matchesCategory = true;
      if (_selectedCategory == DepartmentCategory.medicine) {
        matchesCategory = item.category.contains('پزیشکی');
      }
      if (_selectedCategory == DepartmentCategory.computer) {
        matchesCategory = item.category.contains('کۆمپیوتەر');
      }
      if (_selectedCategory == DepartmentCategory.engineering) {
        matchesCategory = item.category.contains('ئەندازیاری');
      }
      if (_selectedCategory == DepartmentCategory.business) {
        matchesCategory = item.category.contains('کارگێڕی');
      }
      if (_selectedCategory == DepartmentCategory.law) {
        matchesCategory = item.category.contains('یاسا');
      }
      if (_selectedCategory == DepartmentCategory.science) {
        matchesCategory = item.category.contains('زانست');
      }
      if (_selectedCategory == DepartmentCategory.humanities) {
        matchesCategory = item.category.contains('دەرونزانی');
      }

      if (!matchesCategory) return false;

      if (query.isEmpty) return true;

      return item.term.toLowerCase().contains(query) ||
          item.kuName.toLowerCase().contains(query) ||
          item.kuDesc.toLowerCase().contains(query) ||
          item.enDesc.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _searchWithAi() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تکایە سەرەتا ناوی زاراوەکەت بنووسە لە سندوقی گەڕاندا.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSearchingAi = true;
      _aiResultTerm = null;
    });

    final aiService = Provider.of<AiService>(context, listen: false);

    try {
      final prompt = '''
Act as an academic university dictionary. Define the academic term: "$query".
Provide the definition in Kurdish Sorani and English.
Return ONLY a valid JSON object with this exact structure:
{
  "term": "$query",
  "kuName": "<Kurdish translation of the term>",
  "category": "<Academic category with an emoji e.g. زانستی کۆمپیوتەر 💻 or پزیشکی 🩺>",
  "kuDesc": "<2-3 sentence accurate and clear academic explanation in Kurdish Sorani>",
  "enDesc": "<1-2 sentence concise explanation in English>",
  "example": "<Example usage sentence in English>"
}
Do not write placeholders or template text; fill all values with real academic explanations. Return ONLY the JSON object.
''';

      final responseStr = await aiService.askTeacher(prompt, [], isVip: true);

      bool isPlaceholder(String s) {
        final t = s.trim().toLowerCase();
        return t.contains('ناوی زاراوە') ||
            t.contains('ڕوونکردنەوەی کورت') ||
            t.contains('concise english') ||
            t.contains('kurdish translation') ||
            t.contains('example sentence') ||
            (t.contains('<') && t.contains('>'));
      }

      AcademicTerm? resultTerm;

      // Strategy 1: JSON decoding from possible markdown block or direct string
      try {
        final jsonBlockMatch = RegExp(r'\{[\s\S]*\}').firstMatch(responseStr);
        if (jsonBlockMatch != null) {
          final Map<String, dynamic> data = jsonDecode(jsonBlockMatch.group(0)!);
          final term = data['term']?.toString() ?? query;
          final kuName = data['kuName']?.toString() ?? query;
          final category = data['category']?.toString() ?? 'ئەکادیمی 📖';
          final kuDesc = data['kuDesc']?.toString() ?? '';
          final enDesc = data['enDesc']?.toString() ?? '';
          final example = data['example']?.toString();
          if (kuDesc.trim().isNotEmpty && !isPlaceholder(kuDesc) && !isPlaceholder(kuName)) {
            resultTerm = AcademicTerm(
              term: term,
              kuName: kuName,
              category: category,
              kuDesc: kuDesc,
              enDesc: enDesc,
              example: example,
            );
          }
        }
      } catch (_) {}

      // Strategy 2: Robust Regex field extraction across multiline text
      if (resultTerm == null) {
        final kuDescMatch = RegExp(
          r'"kuDesc"\s*:\s*"([\s\S]*?)"',
        ).firstMatch(responseStr)?.group(1);
        if (kuDescMatch != null && kuDescMatch.trim().isNotEmpty && !isPlaceholder(kuDescMatch)) {
          final termMatch = RegExp(r'"term"\s*:\s*"([^"]+)"')
              .firstMatch(responseStr)
              ?.group(1);
          final kuNameMatch = RegExp(r'"kuName"\s*:\s*"([^"]+)"')
              .firstMatch(responseStr)
              ?.group(1);
          final catMatch = RegExp(r'"category"\s*:\s*"([^"]+)"')
              .firstMatch(responseStr)
              ?.group(1);
          final enDescMatch = RegExp(r'"enDesc"\s*:\s*"([\s\S]*?)"')
              .firstMatch(responseStr)
              ?.group(1);
          final exMatch = RegExp(r'"example"\s*:\s*"([\s\S]*?)"')
              .firstMatch(responseStr)
              ?.group(1);

          resultTerm = AcademicTerm(
            term: termMatch ?? query,
            kuName: (kuNameMatch != null && !isPlaceholder(kuNameMatch)) ? kuNameMatch : query,
            category: catMatch ?? 'ئەکادیمی 📖',
            kuDesc: kuDescMatch.replaceAll(r'\n', '\n'),
            enDesc: (enDescMatch != null && !isPlaceholder(enDescMatch)) ? enDescMatch.replaceAll(r'\n', '\n') : '',
            example: (exMatch != null && !isPlaceholder(exMatch)) ? exMatch.replaceAll(r'\n', '\n') : null,
          );
        }
      }

      // Strategy 3: Plain text / Markdown fallback (when AI responds in natural text)
      if (resultTerm == null && responseStr.trim().isNotEmpty) {
        final cleanText = responseStr
            .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
            .replaceAll('```', '')
            .trim();
        if (cleanText.length > 10 && !isPlaceholder(cleanText)) {
          resultTerm = AcademicTerm(
            term: query,
            kuName: query,
            category: 'ئەکادیمی 📖',
            kuDesc: cleanText,
            enDesc: '',
            example: null,
          );
        }
      }

      // Strategy 4: Local offline dictionary match fallback
      if (resultTerm == null) {
        final q = query.toLowerCase();
        final local = _dictionaryTerms.where((t) =>
            t.term.toLowerCase() == q ||
            t.kuName.toLowerCase().contains(q) ||
            t.term.toLowerCase().contains(q)).firstOrNull;
        if (local != null) {
          resultTerm = local;
        }
      }

      if (mounted) {
        if (resultTerm != null) {
          setState(() {
            _aiResultTerm = resultTerm;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'نەتوانرا لە AI ڕوونکردنەوە وەربگیرێت. تکایە دووبارە هەوڵبدەرەوە.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      // Final fallback to local dictionary before showing error
      final q = query.toLowerCase();
      final local = _dictionaryTerms.where((t) =>
          t.term.toLowerCase() == q ||
          t.kuName.toLowerCase().contains(q) ||
          t.term.toLowerCase().contains(q)).firstOrNull;
      if (mounted) {
        if (local != null) {
          setState(() {
            _aiResultTerm = local;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('نەتوانرا لە AI ڕوونکردنەوە وەربگیرێت.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingAi = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    final font = langProvider.fontFamily ?? 'DroidKufi';
    const fontFallback = ['DroidKufi', 'Plus Jakarta Sans'];

    final bgColor = isDark ? ZankoColors.darkBackground : const Color(0xFFF1F5F9);
    final cardColor = isDark ? ZankoColors.darkCard : Colors.white;
    final borderColor = isDark ? ZankoColors.darkBorder : const Color(0xFFE2E8F0);
    const primaryColor = Color(0xFF035EC2);
    const accentBlue = Color(0xFF168DFF);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ─── Premium Gradient Header ──────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0A1628), const Color(0xFF0E1F3D)]
                      : [primaryColor, accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Column(
                    children: [
                      // Top Bar: Back + Title + Reset
                      Row(
                        children: [
                          // Back Button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.back,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.book_fill,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'فەرهەنگی زاراوە ئەکادیمییەکان',
                                        style: TextStyle(
                                          fontFamily: font,
                                          fontFamilyFallback: fontFallback,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_dictionaryTerms.length}+ زاراوەی زانستی و ئەکادیمی',
                                  style: TextStyle(
                                    fontFamily: font,
                                    fontFamilyFallback: fontFallback,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search Bar + AI Button
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                textInputAction: TextInputAction.search,
                                cursorColor: primaryColor,
                                onSubmitted: (_) {
                                  if (_filteredTerms.isEmpty) {
                                    _searchWithAi();
                                  }
                                },
                                style: TextStyle(
                                  fontFamily: font,
                                  fontFamilyFallback: fontFallback,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'گەڕان بۆ زاراوە...',
                                  hintStyle: TextStyle(
                                    fontFamily: font,
                                    fontFamilyFallback: fontFallback,
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  prefixIcon: Icon(
                                    CupertinoIcons.search,
                                    color: isDark ? const Color(0xFF94A3B8) : primaryColor,
                                    size: 20,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            CupertinoIcons.xmark_circle_fill,
                                            size: 18,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                          onPressed: () => setState(() {
                                            _searchController.clear();
                                            _aiResultTerm = null;
                                          }),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // AI Sparkle Button
                          GestureDetector(
                            onTap: _isSearchingAi ? null : _searchWithAi,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: _isSearchingAi
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: primaryColor,
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.sparkles,
                                            color: primaryColor,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'AI',
                                            style: TextStyle(
                                              fontFamily: font,
                                              fontFamilyFallback: fontFallback,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: primaryColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Category Filter Chips ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _buildCategoryChip('هەمووی 🌐', DepartmentCategory.all, isDark, font, fontFallback, primaryColor, cardColor, borderColor),
                    _buildCategoryChip('پزیشکی 🩺', DepartmentCategory.medicine, isDark, font, fontFallback, primaryColor, cardColor, borderColor),
                    _buildCategoryChip('کۆمپیوتەر 💻', DepartmentCategory.computer, isDark, font, fontFallback, primaryColor, cardColor, borderColor),
                    _buildCategoryChip('ئەندازیاری ⚙️', DepartmentCategory.engineering, isDark, font, fontFallback, primaryColor, cardColor, borderColor),
                    _buildCategoryChip('کارگێڕی 📊', DepartmentCategory.business, isDark, font, fontFallback, primaryColor, cardColor, borderColor),
                    _buildCategoryChip('یاسا ⚖️', DepartmentCategory.law, isDark, font, fontFallback, primaryColor, cardColor, borderColor),
                    _buildCategoryChip('زانست 🔬', DepartmentCategory.science, isDark, font, fontFallback, primaryColor, cardColor, borderColor),
                    _buildCategoryChip('دەرونزانی 🧠', DepartmentCategory.humanities, isDark, font, fontFallback, primaryColor, cardColor, borderColor),
                  ],
                ),
              ),
            ),

            // ─── Scrollable Content ──────────────────────────────────────
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  // AI Loading Indicator
                  if (_isSearchingAi) ...[
                    _buildAiLoadingCard(isDark, font, fontFallback, primaryColor, accentBlue),
                    const SizedBox(height: 16),
                  ],

                  // AI Result Card
                  if (_aiResultTerm != null && !_isSearchingAi) ...[
                    _buildAiResultCard(_aiResultTerm!, isDark, font, fontFallback, primaryColor, accentBlue),
                    const SizedBox(height: 16),
                  ],

                  // Terms list or empty state
                  if (_filteredTerms.isEmpty && !_isSearchingAi)
                    _buildEmptyState(isDark, font, fontFallback, primaryColor, accentBlue)
                  else
                    ..._filteredTerms.asMap().entries.map(
                      (entry) => _buildTermCard(
                        entry.value,
                        entry.key,
                        isDark,
                        font,
                        fontFallback,
                        primaryColor,
                        cardColor,
                        borderColor,
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── AI Loading Shimmer Card ───────────────────────────────────────────────
  Widget _buildAiLoadingCard(
    bool isDark,
    String font,
    List<String> fontFallback,
    Color primaryColor,
    Color accentBlue,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, accentBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      'AI لە گەڕاندایە...',
                      style: TextStyle(
                        fontFamily: font,
                        fontFamilyFallback: fontFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Shimmer lines
          for (int i = 0; i < 4; i++) ...[
            Container(
              height: i == 0 ? 16 : 12,
              width: i == 0 ? double.infinity : (i == 3 ? 180 : double.infinity),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i == 0 ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            if (i < 3) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white70,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category Filter Pill ──────────────────────────────────────────────────
  Widget _buildCategoryChip(
    String label,
    DepartmentCategory category,
    bool isDark,
    String font,
    List<String> fontFallback,
    Color primaryColor,
    Color cardColor,
    Color borderColor,
  ) {
    final bool isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedCategory = category);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [primaryColor, const Color(0xFF168DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : borderColor,
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: font,
                  fontFamilyFallback: fontFallback,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AI Result Card ────────────────────────────────────────────────────────
  Widget _buildAiResultCard(
    AcademicTerm term,
    bool isDark,
    String font,
    List<String> fontFallback,
    Color primaryColor,
    Color accentBlue,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, accentBlue, const Color(0xFF2196F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'ڕوونکردنەوەی AI',
                            style: TextStyle(
                              fontFamily: font,
                              fontFamilyFallback: fontFallback,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          term.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: font,
                            fontFamilyFallback: fontFallback,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildHeaderIconButton(CupertinoIcons.doc_on_doc, 'کۆپیکردن', () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(
                        ClipboardData(text: '${term.term} - ${term.kuName}\n${term.kuDesc}\n${term.enDesc}'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ڕوونکردنەوەکە کۆپی کرا!'), duration: Duration(seconds: 2)),
                      );
                    }),
                    const SizedBox(width: 6),
                    _buildHeaderIconButton(CupertinoIcons.xmark_circle_fill, 'داخستن', () {
                      setState(() => _aiResultTerm = null);
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Term Title
                Text(
                  term.term,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                if (term.kuName.isNotEmpty && term.kuName != term.term) ...[
                  const SizedBox(height: 3),
                  Text(
                    term.kuName,
                    style: TextStyle(
                      fontFamily: font,
                      fontFamilyFallback: fontFallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Kurdish Description
                Text(
                  term.kuDesc,
                  style: TextStyle(
                    fontFamily: font,
                    fontFamilyFallback: fontFallback,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.95),
                    height: 1.55,
                  ),
                ),

                // English Definition
                if (term.enDesc.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      term.enDesc,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                // Example
                if (term.example != null && term.example!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(CupertinoIcons.quote_bubble, color: Colors.white.withValues(alpha: 0.7), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          term.example!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }

  // ─── Term Card with Blue Accent ────────────────────────────────────────────
  Widget _buildTermCard(
    AcademicTerm term,
    int index,
    bool isDark,
    String font,
    List<String> fontFallback,
    Color primaryColor,
    Color cardColor,
    Color borderColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.7),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Blue Accent Bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, const Color(0xFF168DFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            // Card Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: English Term + Category
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            term.term,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : primaryColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [primaryColor.withValues(alpha: 0.25), const Color(0xFF168DFF).withValues(alpha: 0.15)]
                                  : [primaryColor.withValues(alpha: 0.08), const Color(0xFF168DFF).withValues(alpha: 0.06)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            term.category,
                            style: TextStyle(
                              fontFamily: font,
                              fontFamilyFallback: fontFallback,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF60A5FA) : primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Kurdish Name
                    Text(
                      term.kuName,
                      style: TextStyle(
                        fontFamily: font,
                        fontFamilyFallback: fontFallback,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Kurdish Description
                    Text(
                      term.kuDesc,
                      style: TextStyle(
                        fontFamily: font,
                        fontFamilyFallback: fontFallback,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // English Definition Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2430)
                            : primaryColor.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? borderColor.withValues(alpha: 0.5)
                              : primaryColor.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        term.enDesc,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),

                    // Example + Copy
                    if (term.example != null && term.example!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(CupertinoIcons.quote_bubble, size: 13, color: primaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              term.example!,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(
                                ClipboardData(text: '${term.term} - ${term.kuName}\n${term.kuDesc}'),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('زاراوەکە کۆپی کرا!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                CupertinoIcons.doc_on_doc,
                                size: 14,
                                color: isDark ? const Color(0xFF60A5FA) : primaryColor,
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
          ],
        ),
      ),
    );
  }

  // ─── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(
    bool isDark,
    String font,
    List<String> fontFallback,
    Color primaryColor,
    Color accentBlue,
  ) {
    final query = _searchController.text.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gradient circle icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  accentBlue.withValues(alpha: isDark ? 0.1 : 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Icon(
              CupertinoIcons.book,
              size: 44,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'هیچ زاراوەیەک نەدۆزرایەوە',
            style: TextStyle(
              fontFamily: font,
              fontFamilyFallback: fontFallback,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            query.isNotEmpty
                ? 'زاراوەی "$query" لە بنکەدراوەی ئۆفلایندا نییە.\nبە AI دەتوانیت ڕوونکردنەوەی وەربگریت.'
                : 'وشەیەک بنووسە لە سندوقی گەڕاندا\nیان بەشێک هەڵبژێرە.',
            style: TextStyle(
              fontFamily: font,
              fontFamilyFallback: fontFallback,
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(height: 22),
            GestureDetector(
              onTap: _isSearchingAi ? null : _searchWithAi,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, accentBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'شیکارکردنی "$query" بە AI',
                      style: TextStyle(
                        fontFamily: font,
                        fontFamilyFallback: fontFallback,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
