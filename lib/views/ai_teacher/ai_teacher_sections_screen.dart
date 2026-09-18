import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/ai_teacher_voice_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../homework/homework_solver_screen.dart';
import '../quiz/ai_exam_generator_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../notes/notes_screen.dart';
import '../payment/vip_upgrade_sheet.dart';
import 'kurdish_voice_tutor_screen.dart';

/// Dedicated Screen displaying all AI Teacher sections and smart tools.
class AiTeacherSectionsScreen extends StatefulWidget {
  final int currentModeIndex;

  const AiTeacherSectionsScreen({
    super.key,
    this.currentModeIndex = 0,
  });

  @override
  State<AiTeacherSectionsScreen> createState() => _AiTeacherSectionsScreenState();
}

class _AiTeacherSectionsScreenState extends State<AiTeacherSectionsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilter = 0;
  String _selectedLanguageMode = 'auto';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final AiTeacherVoiceService _voiceService = AiTeacherVoiceService();

  @override
  void initState() {
    super.initState();
    _loadLanguageMode();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  Future<void> _loadLanguageMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('ai_teacher_lang_mode');
      if (lang != null && mounted) {
        setState(() => _selectedLanguageMode = lang);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _returnWithMode(int modeIndex, {String? action, String? prompt}) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, {
        'mode': modeIndex,
        'lang': _selectedLanguageMode,
        'action': action,
        'prompt': prompt,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final isVip = authService.currentUser?.isVip ?? false;

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : const Color(0xFFF1F5FB),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildAppBar(context, isDark, lang),
              _buildSearchAndFilters(isDark, lang),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (!isVip) _buildVipPromoCard(context, isDark, lang),

                    if (_selectedFilter == 0 || _selectedFilter == 1) ...[
                      _buildSectionHeader(
                        title: lang.translate('section_modes_title'),
                        subtitle: lang.translate('section_modes_subtitle'),
                        icon: HugeIcons.strokeRoundedTeacher,
                        color: const Color(0xFF035EC2),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildAcademicModesGrid(context, isDark, lang),
                      const SizedBox(height: 24),
                    ],

                    if (_selectedFilter == 0 || _selectedFilter == 1) ...[
                      _buildSectionHeader(
                        title: lang.translate('section_lang_title'),
                        subtitle: lang.translate('section_lang_subtitle'),
                        icon: HugeIcons.strokeRoundedTranslate,
                        color: const Color(0xFF0284C7),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildLanguageSelectorCard(context, isDark, lang),
                      const SizedBox(height: 24),
                    ],

                    if (_selectedFilter == 0 || _selectedFilter == 2) ...[
                      _buildSectionHeader(
                        title: lang.translate('section_tools_title'),
                        subtitle: lang.translate('section_tools_subtitle'),
                        icon: HugeIcons.strokeRoundedCpu,
                        color: const Color(0xFF8B5CF6),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildSmartToolsList(context, isDark, lang),
                      const SizedBox(height: 24),
                    ],

                    if (_selectedFilter == 0) ...[
                      _buildSectionHeader(
                        title: lang.translate('section_voice_title'),
                        subtitle: lang.translate('section_voice_subtitle'),
                        icon: HugeIcons.strokeRoundedVoice,
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildVoiceSettingsCard(context, isDark, lang),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // App Bar
  // ---------------------------------------------------------------------------
  Widget _buildAppBar(BuildContext context, bool isDark, LanguageProvider lang) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1320) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E2535) : const Color(0xFFE5EDF6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2235) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C3A52) : const Color(0xFFDDE5F0),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.adaptive.arrow_back,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // AI Bot Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [ZankoColors.gradientStart, ZankoColors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: ZankoColors.primary.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: CuteAiBotIcon(size: 22, color: Colors.white, strokeWidth: 2),
            ),
          ),
          const SizedBox(width: 12),

          // Title area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.translate('sections_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  lang.translate('sections_subtitle'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? ZankoColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Current language badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ZankoColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ZankoColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTranslate,
                  color: ZankoColors.primary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _selectedLanguageMode.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: ZankoColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search & Filter Tabs
  // ---------------------------------------------------------------------------
  Widget _buildSearchAndFilters(bool isDark, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: isDark ? const Color(0xFF131825) : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Search
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2336) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF2A3650) : const Color(0xFFDDE5F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: lang.translate('sections_search_hint'),
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, '✨ ${lang.translate('ai_filter_all')}', isDark),
                const SizedBox(width: 8),
                _buildFilterChip(1, '🎓 ${lang.translate('filter_modes')}', isDark),
                const SizedBox(width: 8),
                _buildFilterChip(2, '⚡ ${lang.translate('filter_tools')}', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, bool isDark) {
    final isSelected = _selectedFilter == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedFilter = index),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? ZankoColors.primary
                  : (isDark ? const Color(0xFF1C2336) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? ZankoColors.primary
                    : (isDark ? const Color(0xFF2A3650) : const Color(0xFFDDE5F0)),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ZankoColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section Header
  // ---------------------------------------------------------------------------
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required dynamic icon,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: isDark ? 0.35 : 0.18),
                color.withValues(alpha: isDark ? 0.15 : 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: HugeIcon(icon: icon, color: color, size: 17),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? ZankoColors.darkTextSecondary : const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Academic Modes Grid
  // ---------------------------------------------------------------------------
  Widget _buildAcademicModesGrid(BuildContext context, bool isDark, LanguageProvider lang) {
    final modes = [
      {
        'index': 0,
        'titleKey': 'mode_general_title',
        'descKey': 'mode_general_desc',
        'icon': HugeIcons.strokeRoundedBook02,
        'color': const Color(0xFF0284C7),
      },
      {
        'index': 1,
        'titleKey': 'mode_math_title',
        'descKey': 'mode_math_desc',
        'icon': HugeIcons.strokeRoundedAnalytics01,
        'color': const Color(0xFFF59E0B),
      },
      {
        'index': 2,
        'titleKey': 'mode_code_title',
        'descKey': 'mode_code_desc',
        'icon': HugeIcons.strokeRoundedSourceCode,
        'color': const Color(0xFF10B981),
      },
      {
        'index': 3,
        'titleKey': 'mode_medical_title',
        'descKey': 'mode_medical_desc',
        'icon': HugeIcons.strokeRoundedHealth,
        'color': const Color(0xFFEC4899),
      },
      {
        'index': 4,
        'titleKey': 'mode_summarize_title',
        'descKey': 'mode_summarize_desc',
        'icon': HugeIcons.strokeRoundedLanguageCircle,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'index': 5,
        'titleKey': 'mode_exam_title',
        'descKey': 'mode_exam_desc',
        'icon': HugeIcons.strokeRoundedFlash,
        'color': const Color(0xFF06B6D4),
      },
    ];

    final filtered = modes.where((m) {
      if (_searchQuery.isEmpty) return true;
      final title = lang.translate(m['titleKey'] as String).toLowerCase();
      final desc = lang.translate(m['descKey'] as String).toLowerCase();
      return title.contains(_searchQuery) || desc.contains(_searchQuery);
    }).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.28,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final mode = filtered[i];
        final modeIdx = mode['index'] as int;
        final isActive = widget.currentModeIndex == modeIdx;
        final color = mode['color'] as Color;
        final title = lang.translate(mode['titleKey'] as String);
        final desc = lang.translate(mode['descKey'] as String);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _returnWithMode(modeIdx),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: isDark ? 0.18 : 0.08)
                    : (isDark ? const Color(0xFF161D2E) : Colors.white),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? color
                      : (isDark ? const Color(0xFF242E42) : const Color(0xFFE2EBF6)),
                  width: isActive ? 1.8 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isActive
                        ? color.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                    blurRadius: isActive ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.28 : 0.13),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: mode['icon'] as dynamic,
                            color: color,
                            size: 17,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            lang.translate('mode_active_badge'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowLeft01,
                              color: color.withValues(alpha: 0.6),
                              size: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Language Selector Card
  // ---------------------------------------------------------------------------
  Widget _buildLanguageSelectorCard(BuildContext context, bool isDark, LanguageProvider lang) {
    final languages = [
      {'code': 'auto', 'labelKey': 'lang_auto', 'subKey': 'lang_auto_sub'},
      {'code': 'ku', 'labelKey': 'lang_ku', 'subKey': 'lang_ku_sub'},
      {'code': 'ar', 'labelKey': 'lang_ar', 'subKey': 'lang_ar_sub'},
      {'code': 'en', 'labelKey': 'lang_en', 'subKey': 'lang_en_sub'},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161D2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF242E42) : const Color(0xFFE2EBF6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: languages.asMap().entries.map((entry) {
          final index = entry.key;
          final l = entry.value;
          final isSelected = _selectedLanguageMode == l['code'];
          final isLast = index == languages.length - 1;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final code = l['code']!;
                    setState(() => _selectedLanguageMode = code);
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('ai_teacher_lang_mode', code);
                    } catch (_) {}
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ZankoColors.primary.withValues(alpha: isDark ? 0.22 : 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? ZankoColors.primary.withValues(alpha: 0.6)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Radio dot
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? ZankoColors.primary : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? ZankoColors.primary
                                  : (isDark ? Colors.white30 : Colors.black26),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 9, color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.translate(l['labelKey']!),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected
                                      ? ZankoColors.primary
                                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                lang.translate(l['subKey']!),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ZankoColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              lang.translate('mode_active_badge'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 8,
                  color: isDark
                      ? const Color(0xFF232E42).withValues(alpha: 0.7)
                      : const Color(0xFFF1F5F9),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Smart Tools List
  // ---------------------------------------------------------------------------
  Widget _buildSmartToolsList(BuildContext context, bool isDark, LanguageProvider lang) {
    final tools = [
      {
        'titleKey': 'tool_homework_title',
        'subKey': 'tool_homework_sub',
        'tagKey': 'tool_homework_tag',
        'icon': HugeIcons.strokeRoundedTask01,
        'color': const Color(0xFF0284C7),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeworkSolverScreen()),
            ),
      },
      {
        'titleKey': 'tool_exam_title',
        'subKey': 'tool_exam_sub',
        'tagKey': 'tool_exam_tag',
        'icon': HugeIcons.strokeRoundedFlash,
        'color': const Color(0xFFF59E0B),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiExamGeneratorScreen()),
            ),
      },
      {
        'titleKey': 'tool_voice_title',
        'subKey': 'tool_voice_sub',
        'tagKey': 'tool_voice_tag',
        'icon': HugeIcons.strokeRoundedMic01,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KurdishVoiceTutorScreen()),
            ),
      },
      {
        'titleKey': 'tool_camera_title',
        'subKey': 'tool_camera_sub',
        'tagKey': 'tool_camera_tag',
        'icon': HugeIcons.strokeRoundedCamera01,
        'color': const Color(0xFF10B981),
        'onTap': () => _returnWithMode(1, action: 'camera'),
      },
      {
        'titleKey': 'tool_pdf_title',
        'subKey': 'tool_pdf_sub',
        'tagKey': 'tool_pdf_tag',
        'icon': HugeIcons.strokeRoundedFile02,
        'color': const Color(0xFFEC4899),
        'onTap': () => _returnWithMode(0, action: 'pdf'),
      },
      {
        'titleKey': 'tool_flashcard_title',
        'subKey': 'tool_flashcard_sub',
        'tagKey': 'tool_flashcard_tag',
        'icon': HugeIcons.strokeRoundedLayers01,
        'color': const Color(0xFF06B6D4),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FlashcardsScreen()),
            ),
      },
      {
        'titleKey': 'tool_notes_title',
        'subKey': 'tool_notes_sub',
        'tagKey': 'tool_notes_tag',
        'icon': HugeIcons.strokeRoundedNote01,
        'color': const Color(0xFF6366F1),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotesScreen()),
            ),
      },
    ];

    final filtered = tools.where((t) {
      if (_searchQuery.isEmpty) return true;
      final title = lang.translate(t['titleKey'] as String).toLowerCase();
      final sub = lang.translate(t['subKey'] as String).toLowerCase();
      return title.contains(_searchQuery) || sub.contains(_searchQuery);
    }).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final tool = filtered[i];
        final color = tool['color'] as Color;
        final title = lang.translate(tool['titleKey'] as String);
        final sub = lang.translate(tool['subKey'] as String);
        final tag = lang.translate(tool['tagKey'] as String);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: tool['onTap'] as VoidCallback,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161D2E) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF242E42) : const Color(0xFFE2EBF6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.22 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: tool['icon'] as dynamic,
                        color: color,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sub,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        color: color.withValues(alpha: 0.7),
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Voice & TTS Settings Card
  // ---------------------------------------------------------------------------
  Widget _buildVoiceSettingsCard(BuildContext context, bool isDark, LanguageProvider lang) {
    final isAutoRead = _voiceService.autoReadEnabled;
    final currentSpeed = _voiceService.playbackSpeed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161D2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF242E42) : const Color(0xFFE2EBF6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedVolumeHigh,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('voice_auto_read'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      lang.translate('voice_auto_read_sub'),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isAutoRead,
                activeTrackColor: ZankoColors.primary,
                onChanged: (val) async {
                  await _voiceService.setAutoRead(val);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: isDark ? const Color(0xFF222E42) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.translate('voice_speed'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              Row(
                children: [0.75, 1.0, 1.25].map((speed) {
                  final isCurrent = (currentSpeed - speed).abs() < 0.1;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      onTap: () async {
                        await _voiceService.setSpeed(speed);
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(9),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? ZankoColors.primary
                              : (isDark
                                  ? const Color(0xFF1C2840)
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: ZankoColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? Colors.white
                                : (isDark ? Colors.white60 : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIP Promo Card
  // ---------------------------------------------------------------------------
  Widget _buildVipPromoCard(BuildContext context, bool isDark, LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -15,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCrown,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.translate('vip_promo_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang.translate('vip_promo_sub'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => VipUpgradeSheet.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB45309),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    lang.translate('vip_btn'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
