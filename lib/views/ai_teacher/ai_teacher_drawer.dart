import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/ai_teacher_voice_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../homework/homework_solver_screen.dart';
import '../quiz/ai_exam_generator_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../notes/notes_screen.dart';
import '../payment/vip_upgrade_sheet.dart';
import 'kurdish_voice_tutor_screen.dart';

/// Callback when the user selects a mode or tool from the drawer.
typedef DrawerResultCallback = void Function({
  required int modeIndex,
  String? action,
  String? langMode,
});

/// Clean, text-first Gemini-style menu drawer for AI Teacher.
class AiTeacherDrawer extends StatefulWidget {
  final int currentModeIndex;
  final String currentLangMode;
  final DrawerResultCallback onResult;

  const AiTeacherDrawer({
    super.key,
    required this.currentModeIndex,
    required this.currentLangMode,
    required this.onResult,
  });

  @override
  State<AiTeacherDrawer> createState() => _AiTeacherDrawerState();
}

class _AiTeacherDrawerState extends State<AiTeacherDrawer> {
  late String _selectedLang;
  final AiTeacherVoiceService _voiceService = AiTeacherVoiceService();

  @override
  void initState() {
    super.initState();
    _selectedLang = widget.currentLangMode;
  }

  void _selectMode(int index) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onResult(modeIndex: index, langMode: _selectedLang);
  }

  void _selectAction(String action) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onResult(
      modeIndex: widget.currentModeIndex,
      action: action,
      langMode: _selectedLang,
    );
  }

  Future<void> _setLang(String code) async {
    HapticFeedback.selectionClick();
    setState(() => _selectedLang = code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_teacher_lang_mode', code);
    } catch (_) {}
    widget.onResult(modeIndex: widget.currentModeIndex, langMode: code);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final isVip = authService.currentUser?.isVip ?? false;

    final bgColor = isDark ? const Color(0xFF0F141C) : Colors.white;
    final dividerColor = isDark
        ? const Color(0xFF1E2638)
        : const Color(0xFFF1F5F9);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      backgroundColor: bgColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Minimalist Clean Header ───────────────────────────────────────
            _buildDrawerHeader(isDark, lang, isVip),

            Divider(height: 1, color: dividerColor),

            // ── Text Sections List ───────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                children: [
                  // 1. Teaching Modes (Text Section)
                  _buildSectionHeader(
                    lang.translate('filter_modes'),
                    isDark,
                  ),
                  const SizedBox(height: 4),
                  _buildModesTextSection(isDark, lang),

                  _buildDivider(dividerColor),

                  // 2. Response Language (Text Section)
                  _buildSectionHeader(
                    lang.translate('section_lang_title'),
                    isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildLanguageTextSection(isDark, lang),

                  _buildDivider(dividerColor),

                  // 3. Smart Tools (Text Section)
                  _buildSectionHeader(
                    lang.translate('filter_tools'),
                    isDark,
                  ),
                  const SizedBox(height: 4),
                  _buildToolsTextSection(isDark, lang),

                  _buildDivider(dividerColor),

                  // 4. Voice Controls (Text Section)
                  _buildSectionHeader(
                    lang.translate('section_voice_title'),
                    isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildVoiceTextSection(isDark, lang),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── VIP Footer (if not VIP) ──────────────────────────────────────
            if (!isVip) ...[
              Divider(height: 1, color: dividerColor),
              _buildVipFooter(isDark, lang),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Header: Simple & Clean
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDrawerHeader(bool isDark, LanguageProvider lang, bool isVip) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      lang.translate('ai_tutor'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (isVip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'VIP 👑',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '⚡ Gemini 3.7 • ${lang.translate('mode_active_badge')}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ZankoColors.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              size: 20,
            ),
            splashRadius: 20,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Section Header Label
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 6, right: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: color),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Teaching Modes: Pure Clean Text Rows
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildModesTextSection(bool isDark, LanguageProvider lang) {
    final modes = [
      {
        'idx': 0,
        'title': lang.translate('mode_general_title'),
        'desc': lang.translate('mode_general_desc'),
      },
      {
        'idx': 1,
        'title': lang.translate('mode_math_title'),
        'desc': lang.translate('mode_math_desc'),
      },
      {
        'idx': 2,
        'title': lang.translate('mode_code_title'),
        'desc': lang.translate('mode_code_desc'),
      },
      {
        'idx': 3,
        'title': lang.translate('mode_medical_title'),
        'desc': lang.translate('mode_medical_desc'),
      },
      {
        'idx': 4,
        'title': lang.translate('mode_summarize_title'),
        'desc': lang.translate('mode_summarize_desc'),
      },
      {
        'idx': 5,
        'title': lang.translate('mode_exam_title'),
        'desc': lang.translate('mode_exam_desc'),
      },
    ];

    return Column(
      children: modes.map((m) {
        final idx = m['idx'] as int;
        final isSelected = widget.currentModeIndex == idx;
        final title = m['title'] as String;
        final desc = m['desc'] as String;

        return _buildTextItemRow(
          title: title,
          subtitle: desc,
          isSelected: isSelected,
          isDark: isDark,
          onTap: () => _selectMode(idx),
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Response Language: Clean Dropdown Style
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildLanguageTextSection(bool isDark, LanguageProvider lang) {
    final languages = [
      {'code': 'auto', 'label': lang.translate('lang_auto')},
      {'code': 'ku', 'label': lang.translate('lang_ku')},
      {'code': 'badini', 'label': 'بادینی 🏔️'},
      {'code': 'ar', 'label': lang.translate('lang_ar')},
      {'code': 'en', 'label': lang.translate('lang_en')},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2A) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF222F42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLang,
          isExpanded: true,
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
            size: 18,
          ),
          dropdownColor: isDark ? const Color(0xFF161E2C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 6,
          items: languages.map((l) {
            final code = l['code'] as String;
            final label = l['label'] as String;
            final isSelected = _selectedLang == code;
            return DropdownMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedTranslate,
                    color: isSelected
                        ? ZankoColors.primary
                        : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? ZankoColors.primary
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                  if (isSelected)
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      color: ZankoColors.primary,
                      size: 16,
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? code) {
            if (code != null) _setLang(code);
          },
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Smart Tools: Clean Text Rows
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildToolsTextSection(bool isDark, LanguageProvider lang) {
    final tools = [
      {
        'title': lang.translate('tool_homework_title'),
        'desc': lang.translate('tool_homework_sub'),
        'icon': HugeIcons.strokeRoundedBookOpen01,
        'onTap': () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HomeworkSolverScreen()),
          );
        },
      },
      {
        'title': lang.translate('tool_exam_title'),
        'desc': lang.translate('tool_exam_sub'),
        'icon': HugeIcons.strokeRoundedTask01,
        'onTap': () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AiExamGeneratorScreen()),
          );
        },
      },
      {
        'title': lang.translate('tool_voice_title'),
        'desc': lang.translate('tool_voice_sub'),
        'icon': HugeIcons.strokeRoundedMic01,
        'onTap': () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KurdishVoiceTutorScreen()),
          );
        },
      },
      {
        'title': lang.translate('tool_camera_title'),
        'desc': lang.translate('tool_camera_sub'),
        'icon': HugeIcons.strokeRoundedCamera01,
        'onTap': () => _selectAction('camera'),
      },
      {
        'title': lang.translate('tool_pdf_title'),
        'desc': lang.translate('tool_pdf_sub'),
        'icon': HugeIcons.strokeRoundedDocumentCode,
        'onTap': () => _selectAction('pdf'),
      },
      {
        'title': lang.translate('tool_flashcard_title'),
        'desc': lang.translate('tool_flashcard_sub'),
        'icon': HugeIcons.strokeRoundedLayers01,
        'onTap': () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FlashcardsScreen()),
          );
        },
      },
      {
        'title': lang.translate('tool_notes_title'),
        'desc': lang.translate('tool_notes_sub'),
        'icon': HugeIcons.strokeRoundedNote01,
        'onTap': () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotesScreen()),
          );
        },
      },
    ];

    return Column(
      children: tools.map((t) {
        return _buildTextItemRow(
          title: t['title'] as String,
          subtitle: t['desc'] as String,
          isSelected: false,
          isDark: isDark,
          leadingIcon: t['icon'] as dynamic,
          showArrow: true,
          onTap: t['onTap'] as VoidCallback,
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Voice Controls: Simple Clean Text Settings
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildVoiceTextSection(bool isDark, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2A) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF222F42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('voice_auto_read'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.translate('voice_auto_read_sub'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: _voiceService.autoReadEnabled,
                  activeThumbColor: ZankoColors.primary,
                  activeTrackColor: ZankoColors.primary.withValues(alpha: 0.5),
                  onChanged: (val) {
                    setState(() => _voiceService.setAutoRead(val));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF222F42) : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 10),
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
                mainAxisSize: MainAxisSize.min,
                children: [0.75, 1.0, 1.25].map((speed) {
                  final isCurrent =
                      (_voiceService.playbackSpeed - speed).abs() < 0.05;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() => _voiceService.setSpeed(speed));
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? ZankoColors.primary
                              : (isDark
                                  ? const Color(0xFF222D3E)
                                  : const Color(0xFFEEF3FA)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isCurrent
                                ? Colors.white
                                : (isDark
                                    ? Colors.white60
                                    : const Color(0xFF475569)),
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

  // ──────────────────────────────────────────────────────────────────────────
  // 5. VIP Upgrade Footer
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildVipFooter(bool isDark, LanguageProvider lang) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        VipUpgradeSheet.show(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isDark ? const Color(0xFF131A26) : const Color(0xFFFFFBEB),
        child: Row(
          children: [
            const Text('👑', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang.translate('vip_promo_title'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  Text(
                    lang.translate('vip_promo_sub'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? const Color(0xFFFBBF24).withValues(alpha: 0.8)
                          : const Color(0xFF92400E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFD97706),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Common Reusable Text Item Row
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTextItemRow({
    required String title,
    String? subtitle,
    required bool isSelected,
    required bool isDark,
    dynamic leadingIcon,
    bool showArrow = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? ZankoColors.primary.withValues(alpha: 0.16)
                    : ZankoColors.primary.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                HugeIcon(
                  icon: leadingIcon,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  size: 18,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? ZankoColors.primary
                            : (isDark
                                ? Colors.white
                                : const Color(0xFF1E293B)),
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1.5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTick02,
                  color: ZankoColors.primary,
                  size: 18,
                )
              else if (showArrow)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
