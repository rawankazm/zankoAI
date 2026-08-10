import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/language_provider.dart';
import '../../services/zankoline_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../../widgets/ad_banner_widget.dart';


class ZankolineScreen extends StatefulWidget {
  const ZankolineScreen({super.key});

  @override
  State<ZankolineScreen> createState() => _ZankolineScreenState();
}

class _ZankolineScreenState extends State<ZankolineScreen> {
  bool _isScientific = true;
  bool _isParallel = false;
  String? _selectedCity;
  final TextEditingController _markController = TextEditingController();

  List<ZankolineDepartmentModel> _matchedDepartments = [];
  String? _aiAdvice;
  bool _isAiLoading = false;

  Widget _buildCityChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ZankoColors.primary : Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ZankolineService>(context, listen: false).loadDepartments();
    });
  }

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
    final matched = await zankolineService.filterMatchingDepartments(mark, track, isParallel: _isParallel);

    setState(() {
      _matchedDepartments = matched;
      _aiAdvice = null;
      _isAiLoading = true;
    });

    final aiAdvice = await zankolineService.askZankolineAiAdvisor(mark, track, matched, isParallel: _isParallel);

    if (mounted) {
      setState(() {
        _aiAdvice = aiAdvice;
        _isAiLoading = false;
      });
    }
  }

  void _onModeOrTrackChanged({bool? isScientific, bool? isParallel}) {
    setState(() {
      if (isScientific != null) _isScientific = isScientific;
      if (isParallel != null) _isParallel = isParallel;
    });
    if (_markController.text.trim().isNotEmpty) {
      _matchDepartments();
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
            // ─── Sponsor Ad Banner ───
            const AdBannerWidget(screenName: 'zankoline'),
            const SizedBox(height: 12),

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



            // ─── Single Average Mark Form ───
            Text(
              t('zankoline_avg_label'),
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
                          onTap: () => _onModeOrTrackChanged(isScientific: true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            decoration: BoxDecoration(
                              color: _isScientific ? ZankoColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  t('zankoline_track_scientific'),
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
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onModeOrTrackChanged(isScientific: false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            decoration: BoxDecoration(
                              color: !_isScientific ? ZankoColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  t('zankoline_track_literary'),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ─── General vs Parallel Study System Selector ───
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _onModeOrTrackChanged(isParallel: false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              decoration: BoxDecoration(
                                color: !_isParallel ? ZankoColors.primary.withValues(alpha: 0.85) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    t('zankoline_mode_general'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: !_isParallel ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _onModeOrTrackChanged(isParallel: true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              decoration: BoxDecoration(
                                color: _isParallel ? const Color(0xFFFF9500) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    t('zankoline_mode_parallel'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: _isParallel ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    t('zankoline_input_hint'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _markController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '88.5',
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
                        backgroundColor: _isParallel ? const Color(0xFFFF9500) : ZankoColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isParallel ? t('zankoline_search_btn_parallel') : t('zankoline_search_btn_general'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
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
                t('zankoline_ai_advisor_title'),
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
                          Text('AI ...'),
                        ],
                      )
                    : Directionality(
                        textDirection: langProvider.textDirection,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(CupertinoIcons.sparkles, color: ZankoColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isParallel ? t('zankoline_ai_card_header_parallel') : t('zankoline_ai_card_header_general'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _isParallel ? const Color(0xFFFF9500) : ZankoColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _aiAdvice ?? '',
                              textAlign: langProvider.currentLanguage == AppLanguage.english ? TextAlign.left : TextAlign.right,
                              textDirection: langProvider.textDirection,
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
                textDirection: langProvider.textDirection,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('department_matcher'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_isParallel ? const Color(0xFFFF9500) : ZankoColors.primary).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${t('zankoline_matched_count')}: ${_matchedDepartments.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isParallel ? const Color(0xFFFF9500) : ZankoColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildCityChip(t('zankoline_city_all'), _selectedCity == null, () => setState(() => _selectedCity = null)),
                          const SizedBox(width: 8),
                          _buildCityChip(t('city_erbil'), _selectedCity == 'هەولێر', () => setState(() => _selectedCity = 'هەولێر')),
                          const SizedBox(width: 8),
                          _buildCityChip(t('city_slemani'), _selectedCity == 'سلێمانی', () => setState(() => _selectedCity = 'سلێمانی')),
                          const SizedBox(width: 8),
                          _buildCityChip(t('city_duhok'), _selectedCity == 'دهۆک', () => setState(() => _selectedCity = 'دهۆک')),
                          const SizedBox(width: 8),
                          _buildCityChip(t('city_halabja'), _selectedCity == 'هەڵەبجە', () => setState(() => _selectedCity = 'هەڵەبجە')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...(_selectedCity == null
                      ? _matchedDepartments
                      : _matchedDepartments.where((d) => d.city.contains(_selectedCity!)).toList())
                  .map((dept) {
                final cutoff = _isParallel ? dept.parallelMinMark : dept.minMark;
                return Padding(
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
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_isParallel ? const Color(0xFFFF9500) : ZankoColors.primary).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _isParallel ? 'پاڕاڵێڵ: %$cutoff (گشتی: %${dept.minMark})' : 'گشتی: %$cutoff',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: _isParallel ? const Color(0xFFFF9500) : ZankoColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
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
                          if (_isParallel) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.payments_rounded, color: Color(0xFFFF9500), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${t('zankoline_fee_discount_tag')}: ${dept.formattedParallelFee}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF9500),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
