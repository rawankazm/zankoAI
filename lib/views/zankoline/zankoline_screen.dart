import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/language_provider.dart';
import '../../services/zankoline_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';

class ZankolineScreen extends StatefulWidget {
  const ZankolineScreen({super.key});

  @override
  State<ZankolineScreen> createState() => _ZankolineScreenState();
}

class _ZankolineScreenState extends State<ZankolineScreen> {
  bool _isScientific = true;
  final TextEditingController _markController = TextEditingController();

  List<ZankolineDepartmentModel> _matchedDepartments = [];
  String? _aiAdvice;
  bool _isAiLoading = false;

  @override
  void dispose() {
    _markController.dispose();
    super.dispose();
  }

  void _matchDepartments() async {
    final markText = _markController.text.trim();
    final mark = double.tryParse(markText);

    if (mark == null || mark <= 0 || mark > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە نمرەیەکی دروست داخڵ بکە (لە نێوان 0 بۆ 100)')),
      );
      return;
    }

    final track = _isScientific ? 'scientific' : 'literary';
    final zankolineService = Provider.of<ZankolineService>(context, listen: false);
    final matched = zankolineService.filterMatchingDepartments(mark, track);

    setState(() {
      _matchedDepartments = matched;
      _aiAdvice = null;
      _isAiLoading = true;
    });

    final aiAdvice = await zankolineService.askZankolineAiAdvisor(mark, track, matched);

    if (mounted) {
      setState(() {
        _aiAdvice = aiAdvice;
        _isAiLoading = false;
      });
    }
  }

  Future<void> _openZankolinePortal() async {
    final urls = [
      'https://www.regayzanko.com',
      'https://regayzanko.gov.krd',
      'https://www.zankoline.org',
    ];

    for (final urlStr in urls) {
      final uri = Uri.parse(urlStr);
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {
        try {
          final launchedFallback = await launchUrl(uri, mode: LaunchMode.platformDefault);
          if (launchedFallback) return;
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          t('zankoline'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // ─── Hero Banner ───
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('zankoline'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t('zankoline_subtitle'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _openZankolinePortal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E1B4B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: Text(
                      t('zankoline_portal'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Single Average Mark Form ───
            Text(
              'تێکڕای نمرەی پۆلی ۱۲',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isScientific = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isScientific ? ZankoColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'زانستی (Scientific)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _isScientific ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isScientific = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isScientific ? ZankoColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'وێژەیی (Literary)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: !_isScientific ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'تێکڕای نمرەکەت داخڵ بکە (%):',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _markController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'نموونە: 88.5',
                      hintStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                      suffixText: '%',
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _matchDepartments,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZankoColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'دۆزینەوەی بەشە گونجاوەکان',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── AI Advisor Kurdish Detailed Analysis ───
            if (_isAiLoading || _aiAdvice != null) ...[
              const SizedBox(height: 24),
              Text(
                'ڕاوێژکاری زیرەکی زانکۆلاین (AI Advisor)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: _isAiLoading
                    ? const Row(
                        children: [
                          CupertinoActivityIndicator(),
                          SizedBox(width: 14),
                          Text('AI داواکارییەکەت شیدەکاتەوە...'),
                        ],
                      )
                    : Directionality(
                        textDirection: TextDirection.rtl,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(CupertinoIcons.sparkles, color: ZankoColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'شیکاری و پێشنیاری مامۆستا AI',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ZankoColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _aiAdvice ?? '',
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(fontSize: 13, height: 1.7),
                            ),
                          ],
                        ),
                      ),
              ),
            ],

            // ─── Matched KRG Departments List ───
            if (_matchedDepartments.isNotEmpty) ...[
              const SizedBox(height: 24),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Text(
                      t('department_matcher'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'بەشی گونجاو: ${_matchedDepartments.length}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZankoColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._matchedDepartments.map((dept) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ZankoColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'لانی کەم: %${dept.minMark}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ZankoColors.primary),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    dept.city,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              dept.college,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dept.university,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dept.description,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: isDark ? Colors.grey[300] : ZankoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
