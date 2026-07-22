import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../services/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showUniversityIdModal(BuildContext context, String name, String email, String uniName, String deptName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        String t(String key) => lang.translate(key);
        return Container(
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.checkmark_seal_fill, color: ZankoColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    t('official_student_verification'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Large Scannable Barcode / QR Simulation
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: ZankoShadows.card,
                ),
                child: Column(
                  children: [
                    const Icon(CupertinoIcons.qrcode, size: 140, color: Colors.black),
                    const SizedBox(height: 8),
                    Text(
                      'STUDENT PASS ID: 2024-ZK-8842',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.black87,
                    ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Academic Record List
              _buildDetailRow(context, t('full_name'), name.isEmpty ? t('student_role') : name),
              _buildDetailRow(context, t('university_email'), email),
              _buildDetailRow(context, t('university'), uniName.isEmpty ? 'Zanko University' : uniName),
              _buildDetailRow(context, t('faculty_major'), deptName.isEmpty ? 'Computer Science & AI' : deptName),
              _buildDetailRow(context, t('academic_stage'), 'Year 3 • Semester 6'),
              _buildDetailRow(context, t('cumulative_gpa'), '3.65 / 4.00 (Honor Roll)'),
              _buildDetailRow(context, t('credits_completed'), '96 / 120 ECTS'),
              _buildDetailRow(context, t('academic_advisor'), 'Dr. Sarah Ahmed'),
              _buildDetailRow(context, t('campus_status'), 'Active • Good Standing 🟢'),

              const SizedBox(height: 20),
              GradientButton(
                text: t('done'),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguagePickerModal(BuildContext context, LanguageProvider langProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        String t(String key) => lang.translate(key);
        return Container(
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('select_app_language'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildLangOption(
                context,
                title: langProvider.translate('english_us'),
                subtitle: langProvider.translate('english_desc'),
                flag: '🇬🇧',
                isSelected: langProvider.currentLanguage == AppLanguage.english,
                onTap: () {
                  langProvider.setLanguage(AppLanguage.english);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              _buildLangOption(
                context,
                title: langProvider.translate('kurdish_name'),
                subtitle: langProvider.translate('kurdish_desc'),
                flag: '☀️',
                isSelected: langProvider.currentLanguage == AppLanguage.kurdish,
                onTap: () {
                  langProvider.setLanguage(AppLanguage.kurdish);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              _buildLangOption(
                context,
                title: langProvider.translate('arabic_name'),
                subtitle: langProvider.translate('arabic_desc'),
                flag: '🇸🇦',
                isSelected: langProvider.currentLanguage == AppLanguage.arabic,
                onTap: () {
                  langProvider.setLanguage(AppLanguage.arabic);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLangOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? ZankoColors.primary.withOpacity(0.12)
              : (isDark ? ZankoColors.darkCardSecondary : Colors.grey[50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? ZankoColors.primary
                : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEFEFF5)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(CupertinoIcons.checkmark_circle_fill, color: ZankoColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    final user = authService.currentUser;
    final userName = user?.name ?? t('student_role');
    final userEmail = user?.email ?? 'aras@zanko.edu';
    final uniName = user?.universityName ?? 'Zanko University';
    final deptName = user?.departmentName ?? 'Computer Science & AI';

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withOpacity(0.9),
        elevation: 0,
        title: Text(
          t('settings_profile'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ─── University Digital ID Card ──────────────────────────────────
            GestureDetector(
              onTap: () => _showUniversityIdModal(context, userName, userEmail, uniName, deptName),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E1B4B),
                      Color(0xFF4338CA),
                      Color(0xFF6D28D9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4338CA).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.text_badge_checkmark,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              uniName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34C759),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                t('digital_id'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Main Student Info Row
                    Row(
                      children: [
                        // Avatar Photo
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/student_avatar_3d.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                CupertinoIcons.person_fill,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Student Metadata
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                deptName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ID: 2024-ZK-8842',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFFA5B4FC),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    Divider(height: 1, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 12),

                    // Footer Action Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(CupertinoIcons.qrcode_viewfinder, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              t('tap_for_campus_qr'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          t('valid_until'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Learning Achievements & Stats
            Text(
              langProvider.translate('learning_stats'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  StatisticCard(
                    icon: CupertinoIcons.clock,
                    value: '14h',
                    label: langProvider.translate('study_time'),
                    color: const Color(0xFFFF9F0A),
                  ),
                  const SizedBox(width: 8),
                  StatisticCard(
                    icon: CupertinoIcons.checkmark_seal,
                    value: '28',
                    label: langProvider.translate('quizzes'),
                    color: const Color(0xFF34C759),
                  ),
                  const SizedBox(width: 8),
                  StatisticCard(
                    icon: CupertinoIcons.star,
                    value: '3.65',
                    label: langProvider.translate('gpa'),
                    color: const Color(0xFF6C5CE7),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Apple Settings Grouped List
            Text(
              langProvider.translate('preferences'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingsTile(
                    context,
                    icon: CupertinoIcons.moon_fill,
                    iconColor: const Color(0xFFAF52DE),
                    title: langProvider.translate('dark_mode'),
                    trailing: CupertinoSwitch(
                      value: themeProvider.isDarkMode,
                      activeColor: ZankoColors.primary,
                      onChanged: (val) => themeProvider.toggleTheme(val),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    context,
                    icon: CupertinoIcons.globe,
                    iconColor: const Color(0xFF007AFF),
                    title: langProvider.translate('app_language'),
                    subtitle: langProvider.currentLanguage == AppLanguage.english
                        ? t('english_us')
                        : (langProvider.currentLanguage == AppLanguage.kurdish
                            ? t('kurdish_name')
                            : t('arabic_name')),
                    onTap: () => _showLanguagePickerModal(context, langProvider),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    context,
                    icon: CupertinoIcons.bell_fill,
                    iconColor: const Color(0xFFFF9F0A),
                    title: langProvider.translate('notifications'),
                    subtitle: langProvider.translate('daily_reminders'),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    context,
                    icon: CupertinoIcons.lock_fill,
                    iconColor: const Color(0xFF34C759),
                    title: langProvider.translate('privacy_security'),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    context,
                    icon: CupertinoIcons.info_circle_fill,
                    iconColor: ZankoColors.primary,
                    title: langProvider.translate('about_zanko'),
                    subtitle: '${langProvider.translate('version')} (Apple Intelligence Edition)',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : ZankoColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: ZankoColors.textSecondary,
              ),
            )
          : null,
      trailing: trailing ??
          const Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: ZankoColors.textSecondary,
          ),
    );
  }
}
