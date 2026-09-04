import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/language_provider.dart';
import '../../services/zankoline_service.dart';
import '../../widgets/apple_ui_components.dart';

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
  bool _hasSearched = false;
  String _activeTab = 'departments'; // 'departments' or 'ai'

  final List<double> _quickPresets = [65.0, 75.0, 85.0, 92.0, 97.0];

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

  void _findDepartments() async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final markText = _markController.text.trim();
    final mark = double.tryParse(markText);

    if (mark == null || mark <= 0 || mark > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langProvider.translate('enter_valid_mark')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    if (_hasSearched && _matchedDepartments.isNotEmpty && _activeTab != 'departments') {
      setState(() {
        _activeTab = 'departments';
      });
      return;
    }

    final track = _isScientific ? 'scientific' : 'literary';
    final zankolineService = Provider.of<ZankolineService>(context, listen: false);
    final matched = await zankolineService.filterMatchingDepartments(
      mark,
      track,
      isParallel: _isParallel,
    );

    if (mounted) {
      setState(() {
        _matchedDepartments = matched;
        _hasSearched = true;
        _activeTab = 'departments';
      });
    }
  }

  void _getAiAdvice({bool forceRegenerate = false}) async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final markText = _markController.text.trim();
    final mark = double.tryParse(markText);

    if (mark == null || mark <= 0 || mark > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langProvider.translate('enter_valid_mark')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    if (!forceRegenerate && _aiAdvice != null && _hasSearched) {
      setState(() {
        _activeTab = 'ai';
      });
      return;
    }

    final track = _isScientific ? 'scientific' : 'literary';
    final zankolineService = Provider.of<ZankolineService>(context, listen: false);

    setState(() {
      _hasSearched = true;
      _activeTab = 'ai';
      _isAiLoading = true;
    });

    var matched = _matchedDepartments;
    if (matched.isEmpty) {
      matched = await zankolineService.filterMatchingDepartments(
        mark,
        track,
        isParallel: _isParallel,
      );
      if (mounted) {
        setState(() {
          _matchedDepartments = matched;
        });
      }
    }

    final aiAdvice = await zankolineService.askZankolineAiAdvisor(
      mark,
      track,
      matched,
      isParallel: _isParallel,
      isEnglish: langProvider.currentLanguage == AppLanguage.english,
    );

    if (mounted) {
      setState(() {
        _aiAdvice = aiAdvice;
        _isAiLoading = false;
      });
    }
  }

  void _onModeOrTrackChanged({bool? isScientific, bool? isParallel}) {
    HapticFeedback.selectionClick();
    setState(() {
      if (isScientific != null) _isScientific = isScientific;
      if (isParallel != null) _isParallel = isParallel;
      _hasSearched = false;
      _aiAdvice = null;
      _matchedDepartments = [];
    });
  }

  void _setPresetMark(double val) {
    HapticFeedback.selectionClick();
    setState(() {
      _markController.text = val.toStringAsFixed(1);
      _hasSearched = false;
      _aiAdvice = null;
      _matchedDepartments = [];
    });
  }

  Future<void> _openZankolinePortal() async {
    HapticFeedback.lightImpact();
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

  String _localizedCity(String rawCity, LanguageProvider lang) {
    if (rawCity.contains('هەولێر') || rawCity.toLowerCase().contains('erbil') || rawCity.toLowerCase().contains('hawler')) {
      return lang.translate('city_erbil');
    }
    if (rawCity.contains('سلێمانی') || rawCity.toLowerCase().contains('slemani') || rawCity.toLowerCase().contains('sulaymaniyah')) {
      return lang.translate('city_slemani');
    }
    if (rawCity.contains('دهۆک') || rawCity.toLowerCase().contains('duhok')) {
      return lang.translate('city_duhok');
    }
    if (rawCity.contains('هەڵەبجە') || rawCity.toLowerCase().contains('halabja')) {
      return lang.translate('city_halabja');
    }
    return rawCity;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    const primaryBlue = Color(0xFF035EC2);
    const warmGold = Color(0xFFE4D27D);
    final cardBg = isDark ? const Color(0xFF171B23) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2);
    final textPrimary = isDark ? Colors.white : const Color(0xFF17191F);
    final textSecondary = isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1117) : const Color(0xFFFAFAFB),
      appBar: AppBar(
        backgroundColor: (isDark ? const Color(0xFF0E1117) : const Color(0xFFFAFAFB)).withValues(alpha: 0.95),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          t('zankoline'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: textPrimary,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: GestureDetector(
              onTap: _openZankolinePortal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171B23) : const Color(0xFFE2EDFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryBlue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedCompass,
                      size: 14,
                      color: primaryBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      t('zankoline_portal'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Admission Calculator Card ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2EDFB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedFilter,
                          color: primaryBlue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('zankoline_avg_label'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t('zankoline_avg_desc'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Track Selector (Scientific vs Literary) ──
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF11151D) : const Color(0xFFF1F4F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF202734) : const Color(0xFFE1E7EF),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSegmentButton(
                            label: t('zankoline_track_scientific'),
                            icon: HugeIcons.strokeRoundedAtom01,
                            isSelected: _isScientific,
                            onTap: () => _onModeOrTrackChanged(isScientific: true),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildSegmentButton(
                            label: t('zankoline_track_literary'),
                            icon: HugeIcons.strokeRoundedBook02,
                            isSelected: !_isScientific,
                            onTap: () => _onModeOrTrackChanged(isScientific: false),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Mode Selector (General vs Parallel) ──
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF11151D) : const Color(0xFFF1F4F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF202734) : const Color(0xFFE1E7EF),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSegmentButton(
                            label: t('zankoline_mode_general'),
                            icon: HugeIcons.strokeRoundedMortarboard02,
                            isSelected: !_isParallel,
                            onTap: () => _onModeOrTrackChanged(isParallel: false),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildSegmentButton(
                            label: t('zankoline_mode_parallel'),
                            icon: HugeIcons.strokeRoundedCoins01,
                            isSelected: _isParallel,
                            badge: '45%',
                            onTap: () => _onModeOrTrackChanged(isParallel: true),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Mark Input Field ──
                  Text(
                    t('zankoline_input_hint'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0E1117) : const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: primaryBlue.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE2EDFB),
                            shape: BoxShape.circle,
                          ),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedPercent,
                            color: primaryBlue,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _markController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: primaryBlue,
                              letterSpacing: -0.5,
                            ),
                            decoration: InputDecoration(
                              hintText: '88.5',
                              hintStyle: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey[600] : const Color(0xFFA6ACB8),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) {
                              if (_hasSearched) {
                                setState(() {
                                  _hasSearched = false;
                                  _aiAdvice = null;
                                  _matchedDepartments = [];
                                });
                              }
                            },
                            onSubmitted: (_) => _findDepartments(),
                          ),
                        ),
                        if (_markController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() {
                              _markController.clear();
                              _hasSearched = false;
                              _aiAdvice = null;
                              _matchedDepartments = [];
                            }),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedCancelCircle,
                              color: Color(0xFFA6ACB8),
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Quick Mark Presets
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _quickPresets.map((preset) {
                      final currentVal = double.tryParse(_markController.text.trim());
                      final isSelected = currentVal != null && (currentVal == preset);

                      return GestureDetector(
                        onTap: () => _setPresetMark(preset),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF035EC2), Color(0xFF024A9B)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : (isDark ? const Color(0xFF111620) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? primaryBlue
                                  : (isDark ? const Color(0xFF232B3A) : const Color(0xFFE2E8F0)),
                              width: 1.2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryBlue.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            '${preset.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFFA6ACB8) : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // ── Action Buttons: 1. Find Departments | 2. AI Advice ──
                  Row(
                    children: [
                      // Button 1: Find Departments (App Primary Zanko Blue)
                      Expanded(
                        child: GestureDetector(
                          onTap: _findDepartments,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: (!_hasSearched || _activeTab == 'departments')
                                  ? const LinearGradient(
                                      colors: [Color(0xFF035EC2), Color(0xFF024A9B)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: (_hasSearched && _activeTab != 'departments')
                                  ? (isDark ? const Color(0xFF141D2B) : const Color(0xFFEAF2FD))
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (!_hasSearched || _activeTab == 'departments')
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : primaryBlue.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              boxShadow: (!_hasSearched || _activeTab == 'departments')
                                  ? [
                                      BoxShadow(
                                        color: primaryBlue.withValues(alpha: isDark ? 0.45 : 0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 5),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedSearch01,
                                    color: (!_hasSearched || _activeTab == 'departments')
                                        ? Colors.white
                                        : primaryBlue,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      _hasSearched && _matchedDepartments.isNotEmpty
                                          ? '${t('zankoline_find_btn')} (${_matchedDepartments.length})'
                                          : t('zankoline_find_btn'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: (!_hasSearched || _activeTab == 'departments')
                                            ? Colors.white
                                            : primaryBlue,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Button 2: AI Advice (Zanko AI Azure Intelligence Gradient)
                      Expanded(
                        child: GestureDetector(
                          onTap: _getAiAdvice,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: (!_hasSearched || _activeTab == 'ai')
                                  ? LinearGradient(
                                      colors: isDark
                                          ? [const Color(0xFF0D47A1), const Color(0xFF0284C7)]
                                          : [const Color(0xFF0250A8), const Color(0xFF0EA5E9)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: (_hasSearched && _activeTab != 'ai')
                                  ? (isDark ? const Color(0xFF132238) : const Color(0xFFE8F6FD))
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (!_hasSearched || _activeTab == 'ai')
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : const Color(0xFF0284C7).withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              boxShadow: (!_hasSearched || _activeTab == 'ai')
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.4 : 0.28),
                                        blurRadius: 16,
                                        offset: const Offset(0, 5),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Image.asset(
                                      'assets/images/robot.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, e, s) => HugeIcon(
                                        icon: HugeIcons.strokeRoundedAiMagic,
                                        color: (!_hasSearched || _activeTab == 'ai')
                                            ? Colors.white
                                            : const Color(0xFF0284C7),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      t('zankoline_ai_advice_btn'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: (!_hasSearched || _activeTab == 'ai')
                                            ? Colors.white
                                            : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Results Section ───
            if (_hasSearched) ...[
              const SizedBox(height: 20),

              // ── Tab 1: AI Academic Advice ──
              if (_activeTab == 'ai') ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: primaryBlue.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isAiLoading
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: Image.asset(
                                  'assets/images/robot.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const CupertinoActivityIndicator(color: primaryBlue),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const CupertinoActivityIndicator(color: primaryBlue),
                              const SizedBox(height: 12),
                              Text(
                                t('ai_analyzing'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: Image.asset(
                                    'assets/images/robot.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => const HugeIcon(
                                      icon: HugeIcons.strokeRoundedAiMagic,
                                      color: primaryBlue,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isParallel
                                        ? t('zankoline_ai_card_header_parallel')
                                        : t('zankoline_ai_card_header_general'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: primaryBlue,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: warmGold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'AI Insights',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF9E7C00),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              height: 1,
                              color: borderColor,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _aiAdvice ?? '',
                              textAlign: langProvider.currentLanguage == AppLanguage.english
                                  ? TextAlign.left
                                  : TextAlign.right,
                              textDirection: langProvider.textDirection,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.7,
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Quick Action Buttons inside AI tab
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _activeTab = 'departments');
                                    },
                                    icon: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedMortarboard02,
                                      color: primaryBlue,
                                      size: 16,
                                    ),
                                    label: Text(
                                      t('view_departments'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: primaryBlue,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: primaryBlue.withValues(alpha: 0.4)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _getAiAdvice(forceRegenerate: true),
                                  tooltip: t('regenerate_advice'),
                                  style: IconButton.styleFrom(
                                    backgroundColor: isDark ? const Color(0xFF1E2634) : const Color(0xFFE2EDFB),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: primaryBlue,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ] else ...[
                // ── Tab 2: Matched Departments List ──
                if (_matchedDepartments.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          t('department_matcher'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2EDFB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_matchedDepartments.length} ${t('zankoline_matched_count')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Horizontal City Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildAppleCityChip(
                          label: t('zankoline_city_all'),
                          isSelected: _selectedCity == null,
                          onTap: () => setState(() => _selectedCity = null),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildAppleCityChip(
                          label: t('city_erbil'),
                          isSelected: _selectedCity == 'هەولێر',
                          onTap: () => setState(() => _selectedCity = 'هەولێر'),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildAppleCityChip(
                          label: t('city_slemani'),
                          isSelected: _selectedCity == 'سلێمانی',
                          onTap: () => setState(() => _selectedCity = 'سلێمانی'),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildAppleCityChip(
                          label: t('city_duhok'),
                          isSelected: _selectedCity == 'دهۆک',
                          onTap: () => setState(() => _selectedCity = 'دهۆک'),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildAppleCityChip(
                          label: t('city_halabja'),
                          isSelected: _selectedCity == 'هەڵەبجە',
                          onTap: () => setState(() => _selectedCity = 'هەڵەبجە'),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Department Cards
                  ...(_selectedCity == null
                          ? _matchedDepartments
                          : _matchedDepartments.where((d) => d.city.contains(_selectedCity!)).toList())
                      .map((dept) {
                    final cutoff = _isParallel ? dept.parallelMinMark : dept.minMark;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Directionality(
                          textDirection: langProvider.textDirection,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Min Cutoff Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _isParallel
                                          ? warmGold.withValues(alpha: 0.2)
                                          : const Color(0xFFE2EDFB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _isParallel
                                            ? const Color(0xFFB59300).withValues(alpha: 0.3)
                                            : primaryBlue.withValues(alpha: 0.25),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _isParallel
                                          ? '${t('parallel_label')}: %$cutoff (${t('general_label')}: %${dept.minMark})'
                                          : '${t('min_mark_label')}: %$cutoff',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                        color: _isParallel ? const Color(0xFF8A6C00) : primaryBlue,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Spacer(),
                                  // City Pin
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0E1117) : const Color(0xFFF1F3F6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        HugeIcon(
                                          icon: HugeIcons.strokeRoundedLocation01,
                                          size: 11,
                                          color: textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _localizedCity(dept.city, langProvider),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Department / College Name
                              Text(
                                dept.college,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  color: textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              // University Name
                              Row(
                                children: [
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedBuilding03,
                                    size: 13,
                                    color: primaryBlue,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      dept.university,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: primaryBlue,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (dept.description.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  dept.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (_isParallel) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: warmGold.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: warmGold.withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const HugeIcon(
                                        icon: HugeIcons.strokeRoundedCoins01,
                                        color: Color(0xFF8A6C00),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${t('zankoline_fee_discount_tag')}: ${dept.formattedParallelFeeLocalized(isEnglish: langProvider.currentLanguage == AppLanguage.english)}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF8A6C00),
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
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedSearch01,
                          size: 38,
                          color: primaryBlue,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t('no_departments_found'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('try_another_mark_or_parallel'),
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required dynamic icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    String? badge,
  }) {
    const primaryBlue = Color(0xFF035EC2);
    const warmGold = Color(0xFFE4D27D);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1D2636) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: primaryBlue.withValues(alpha: isDark ? 0.5 : 0.25),
                  width: 1.2,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            appIcon(
              icon,
              size: 16,
              color: isSelected
                  ? primaryBlue
                  : (isDark ? const Color(0xFF7A8494) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF17191F))
                      : (isDark ? const Color(0xFF8E97A8) : const Color(0xFF64748B)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: warmGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17191F),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppleCityChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    const primaryBlue = Color(0xFF035EC2);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF035EC2), Color(0xFF024A9B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF161B24) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryBlue
                : (isDark ? const Color(0xFF262E3D) : const Color(0xFFECEEF2)),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFA6ACB8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}
