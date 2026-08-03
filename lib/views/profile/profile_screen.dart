import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../services/theme_provider.dart';
import '../auth/login_screen.dart';
import '../payment/vip_upgrade_sheet.dart';

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
    final isGuest = user == null || user.isGuest;
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
            // ─── Aqarat-Style Guest Account Callout Banner ───
            if (isGuest) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ZankoColors.primary.withValues(alpha: 0.15),
                      const Color(0xFF818CF8).withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: ZankoColors.primary.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ZankoColors.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_add_alt_1_rounded, color: ZankoColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('guest_banner_title'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t('guest_banner_sub'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZankoColors.primary,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 18, color: Colors.white),
                        label: Text(
                          t('login_or_register'),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ─── University Digital ID Card ──────────────────────────────────
            // ─── High-End Futuristic Digital Student ID Card ───
            GestureDetector(
              onTap: () => _showUniversityIdModal(context, userName, userEmail, uniName, deptName),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: -2,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    children: [
                      // Dark Metallic Mesh Gradient Background
                      Container(
                        height: 215,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0F172A),
                              Color(0xFF1E1B4B),
                              Color(0xFF312E81),
                              Color(0xFF4338CA),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),

                      // Holographic Glow Wave Overlay
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF818CF8).withValues(alpha: 0.4),
                                const Color(0xFF818CF8).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -40,
                        left: -40,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFC084FC).withValues(alpha: 0.35),
                                const Color(0xFFC084FC).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Glass Border Overlay
                      Container(
                        height: 215,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // ─── Header: University Name & Status Pill ───
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      uniName.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                // Smart Digital ID Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF34D399),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF34D399),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        t('digital_id'),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // ─── Main Body: Avatar + Details + Metallic Smart Chip ───
                            Row(
                              children: [
                                // Double Glowing Ring Avatar Container
                                Container(
                                  width: 66,
                                  height: 66,
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF818CF8), Color(0xFFF472B6)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF0F172A),
                                    ),
                                    padding: const EdgeInsets.all(2),
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
                                ),
                                const SizedBox(width: 14),

                                // Student Details & ID Tag
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        deptName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // ID Pill Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'ID: 2024-ZK-8842',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: Color(0xFFA5B4FC),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Metallic NFC Smart Chip Icon
                                Container(
                                  width: 40,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.shade200, width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.nfc_rounded,
                                      size: 20,
                                      color: Color(0xFF78350F),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // ─── Footer: Frosted Glass Bar with QR & Validity ───
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        t('tap_for_campus_qr'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(alpha: 0.95),
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
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ─── VIP Membership Status & FIB / FastPay Upgrade Banner ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: user?.isVip == true
                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                      : [const Color(0xFFFF9500), const Color(0xFFEA580C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (user?.isVip == true ? const Color(0xFF10B981) : const Color(0xFFFF9500)).withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: Icon(
                      user?.isVip == true ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.star_fill,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.isVip == true ? 'بەشداربووی فەرمی VIP (VIP Member 👑)' : 'بەشداربوونی VIP (FIB & FastPay)',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.isVip == true
                              ? 'پەیامی بێسنوور + PDF + وێنەی کامێرا چالاککراوە'
                              : 'پەیامی بێسنوور + کورتکردنەوەی PDF و وێنەی پرسیارەکان',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => VipUpgradeSheet.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: user?.isVip == true ? const Color(0xFF059669) : const Color(0xFFEA580C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      user?.isVip == true ? 'VIP' : 'چالاککردن',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
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
                        ? 'English'
                        : (langProvider.currentLanguage == AppLanguage.kurdish
                            ? 'کوردی'
                            : 'العربية'),
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
                    subtitle: langProvider.translate('version'),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    context,
                    icon: isGuest ? CupertinoIcons.person_crop_circle_badge_plus : CupertinoIcons.arrow_right_square_fill,
                    iconColor: isGuest ? const Color(0xFF6C5CE7) : const Color(0xFFE11D48),
                    title: isGuest ? t('login_or_register') : t('logout'),
                    subtitle: isGuest ? t('login_register_desc') : t('logout_desc'),
                    onTap: () async {
                      if (isGuest) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      } else {
                        await authService.logout();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      }
                    },
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
