import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../data/academic_dictionary_data.dart';
import '../../theme.dart';

enum DepartmentCategory {
  all,
  medicine,
  engineering,
  computer,
  law,
  science,
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
  State<AcademicDictionaryScreen> createState() => _AcademicDictionaryScreenState();
}

class _AcademicDictionaryScreenState extends State<AcademicDictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  DepartmentCategory _selectedCategory = DepartmentCategory.all;
  bool _isSearchingAi = false;
  AcademicTerm? _aiResultTerm;

  late final List<AcademicTerm> _dictionaryTerms = AcademicDictionaryData.getExpandedTerms();

  List<AcademicTerm> get _filteredTerms {
    final query = _searchController.text.trim().toLowerCase();

    return _dictionaryTerms.where((item) {
      bool matchesCategory = true;
      if (_selectedCategory == DepartmentCategory.medicine) matchesCategory = item.category.contains('پزیشکی');
      if (_selectedCategory == DepartmentCategory.engineering) matchesCategory = item.category.contains('ئەندازیاری');
      if (_selectedCategory == DepartmentCategory.computer) matchesCategory = item.category.contains('کۆمپیوتەر');
      if (_selectedCategory == DepartmentCategory.law) matchesCategory = item.category.contains('یاسا');
      if (_selectedCategory == DepartmentCategory.science) matchesCategory = item.category.contains('زانست');

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
        const SnackBar(content: Text('تکایە سەرەتا ناوی زاراوەکەت بنووسە لە سندوقی گەڕاندا.')),
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
تۆ فەرهەنگێکی ئەکادیمی زۆر شارەزایت. ئەم زاراوە ئەکادیمییە ڕوون بکەرەوە: "$query".
وەڵامەکەت تەنها و تەنها بەم فۆرماتەی JSON بنووسە بە کوردی سۆرانی و ئینگلیزی:
{
  "term": "$query",
  "kuName": "ناوی زاراوەکە بە کوردی یان ناوی کوردی باو",
  "category": "پزیشکی 🩺 / ئەندازیاری ⚙️ / کۆمپیوتەر 💻 / یاسا ⚖️ / زانست 🔬",
  "kuDesc": "ڕوونکردنەوەی زۆر کورت و پرۆفێشناڵ بە کوردی سۆرانی (تەنها ۲-۳ ڕستە)",
  "enDesc": "Concise English definition (2-3 sentences)",
  "example": "Example sentence using the term in English."
}
تەنها فۆرماتی JSON بنووسە بەبێ نووسینی تر.
''';

      final responseStr = await aiService.askTeacher(prompt, [], isVip: true);

      String cleanJson = responseStr.trim();
      if (cleanJson.startsWith("```json")) cleanJson = cleanJson.substring(7);
      if (cleanJson.startsWith("```")) cleanJson = cleanJson.substring(3);
      if (cleanJson.endsWith("```")) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      cleanJson = cleanJson.trim();

      // Simple parsing
      final termMatch = RegExp(r'"term"\s*:\s*"([^"]+)"').firstMatch(cleanJson)?.group(1);
      final kuNameMatch = RegExp(r'"kuName"\s*:\s*"([^"]+)"').firstMatch(cleanJson)?.group(1);
      final catMatch = RegExp(r'"category"\s*:\s*"([^"]+)"').firstMatch(cleanJson)?.group(1);
      final kuDescMatch = RegExp(r'"kuDesc"\s*:\s*"([^"]+)"').firstMatch(cleanJson)?.group(1);
      final enDescMatch = RegExp(r'"enDesc"\s*:\s*"([^"]+)"').firstMatch(cleanJson)?.group(1);
      final exMatch = RegExp(r'"example"\s*:\s*"([^"]+)"').firstMatch(cleanJson)?.group(1);

      if (mounted && kuDescMatch != null) {
        setState(() {
          _aiResultTerm = AcademicTerm(
            term: termMatch ?? query,
            kuName: kuNameMatch ?? query,
            category: catMatch ?? 'ئەکادیمی 📖',
            kuDesc: kuDescMatch,
            enDesc: enDescMatch ?? 'Academic term explanation.',
            example: exMatch,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نەتوانرا لە AI ڕوونکردنەوە وەربگیرێت.')),
        );
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

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withOpacity(0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ZankoColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.book_fill, color: ZankoColors.primary, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              'فەرهەنگی زاراوە ئەکادیمییەکان',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? ZankoColors.darkCard : Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: 'گەڕان بۆ زاراوە بە کوردی یان ئینگلیزی...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
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
                      ElevatedButton(
                        onPressed: _isSearchingAi ? null : _searchWithAi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZankoColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: _isSearchingAi
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                children: [
                                  Icon(CupertinoIcons.sparkles, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildCategoryChip('هەمووی 🌐', DepartmentCategory.all, isDark),
                        _buildCategoryChip('پزیشکی 🩺', DepartmentCategory.medicine, isDark),
                        _buildCategoryChip('ئەندازیاری ⚙️', DepartmentCategory.engineering, isDark),
                        _buildCategoryChip('کۆمپیوتەر 💻', DepartmentCategory.computer, isDark),
                        _buildCategoryChip('یاسا ⚖️', DepartmentCategory.law, isDark),
                        _buildCategoryChip('زانست 🔬', DepartmentCategory.science, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // AI Search Result Banner (If active)
            if (_aiResultTerm != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ZankoColors.primary, ZankoColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: ZankoColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'ڕوونکردنەوەی AI بۆ: ${_aiResultTerm!.term}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiResultTerm!.kuName,
                      style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiResultTerm!.kuDesc,
                      style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.3),
                    ),
                    if (_aiResultTerm!.enDesc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _aiResultTerm!.enDesc,
                        style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),

            // Term List
            Expanded(
              child: _filteredTerms.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.book, size: 64, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'هیچ زاراوەیەک نەدۆزرایەوە',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : ZankoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'دەتوانیت دوگمەی ✨ AI داگریت تا زانیاری تەواو لەسەر ئەم زاراوەیە بەدەست بهێنیت.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredTerms.length,
                      itemBuilder: (context, index) {
                        final term = _filteredTerms[index];
                        return _buildTermCard(term, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, DepartmentCategory category, bool isDark) {
    final bool isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        selectedColor: ZankoColors.primary,
        onSelected: (_) => setState(() => _selectedCategory = category),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  Widget _buildTermCard(AcademicTerm term, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEFEFF7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  term.term,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : ZankoColors.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ZankoColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  term.category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ZankoColors.primary,
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : ZankoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Kurdish Description
          Text(
            term.kuDesc,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : ZankoColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),

          // English Description
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF3F4F6),
              ),
            ),
            child: Text(
              term.enDesc,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),

          if (term.example != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(CupertinoIcons.quote_bubble, size: 14, color: ZankoColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    term.example!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${term.term} - ${term.kuName}\n${term.kuDesc}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('زاراوەکە کۆپی کرا!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
