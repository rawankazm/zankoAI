import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../services/theme_provider.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final user = authService.currentUser;
    final userName = user?.name ?? 'خوێندکار';
    final userEmail = user?.email ?? 'student@zanko.edu';
    final userRole = user?.role == UserRole.teacher 
        ? 'مامۆستا / Teacher' 
        : user?.role == UserRole.admin 
            ? 'بەڕێوەبەر / Admin' 
            : 'خوێندکار / Student';

    final university = user?.universityName ?? 'زانکۆی سلێمانی';
    final department = user?.departmentName ?? 'تەکنەلۆجیای زانیاری';

    // Translations
    final String title = langProvider.currentLanguage == AppLanguage.english
        ? 'My Profile & ID Card'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'الملف الشخصي والبطاقة الجامعية'
            : 'پڕۆفایل و ناسنامەی خوێندکاریم';

    final String idCardHeader = langProvider.currentLanguage == AppLanguage.english
        ? 'Virtual Student ID'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'البطاقة الجامعية الرقمية'
            : 'ناسنامەی خوێندکاری دیجیتاڵی';

    final String themeSettings = langProvider.currentLanguage == AppLanguage.english
        ? 'App Appearance'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'مظهر التطبيق'
            : 'دۆخی پیشاندانی ئەپەکە';

    final String darkThemeLabel = langProvider.currentLanguage == AppLanguage.english
        ? 'Dark Mode'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'الوضع الداكن'
            : 'دۆخی تاریک (شەو)';

    final String universityLabel = langProvider.currentLanguage == AppLanguage.english
        ? 'University'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'الجامعة'
            : 'زانکۆ';

    final String departmentLabel = langProvider.currentLanguage == AppLanguage.english
        ? 'Department'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'القسم'
            : 'بەش';

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Virtual ID Card title
              Text(
                idCardHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Noto Sans Arabic',
                ),
              ),
              const SizedBox(height: 12),

              // Glassmorphic ID Card
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade800,
                      Colors.indigo.shade900,
                      Colors.purple.shade900,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Circular background shapes for premium glow
                      Positioned(
                        right: -40,
                        top: -40,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.pinkAccent.withOpacity(0.15),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -30,
                        bottom: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueAccent.withOpacity(0.2),
                          ),
                        ),
                      ),

                      // Glass overlay
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                        child: Container(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),

                      // Card Content
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'ZankoAI ID CARD',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // User details
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Noto Sans Arabic',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userRole,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Noto Sans Arabic',
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      universityLabel,
                                      style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'Noto Sans Arabic'),
                                    ),
                                    Text(
                                      university,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic'),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      departmentLabel,
                                      style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'Noto Sans Arabic'),
                                    ),
                                    Text(
                                      department,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Theme Switch Settings
              Text(
                themeSettings,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Noto Sans Arabic',
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: themeProvider.isDarkMode ? Colors.purple : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            darkThemeLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic'),
                          ),
                        ],
                      ),
                      Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (isOn) {
                          themeProvider.toggleTheme(isOn);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Custom Color Palette Selector
              Text(
                langProvider.currentLanguage == AppLanguage.english
                    ? 'Theme Palette'
                    : langProvider.currentLanguage == AppLanguage.arabic
                        ? 'ألوان السمة'
                        : 'ڕەنگەکانی ئەپەکە (Themes)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Noto Sans Arabic',
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildThemeBubble(context, themeProvider, AppThemeType.blueGlass, const Color(0xFF1565C0), "Blue Glass"),
                      _buildThemeBubble(context, themeProvider, AppThemeType.emeraldForest, const Color(0xFF1B5E20), "Emerald"),
                      _buildThemeBubble(context, themeProvider, AppThemeType.sunsetViolet, const Color(0xFF4A148C), "Sunset"),
                      _buildThemeBubble(context, themeProvider, AppThemeType.midnightGold, const Color(0xFFFFB300), "Gold"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Email Detail Info row
              Card(
                child: ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email Address', style: TextStyle(fontFamily: 'Noto Sans Arabic', fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(userEmail),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeBubble(BuildContext context, ThemeProvider provider, AppThemeType themeType, Color color, String name) {
    final isSelected = provider.activeTheme == themeType;
    return GestureDetector(
      onTap: () {
        provider.setAppTheme(themeType);
      },
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isSelected ? 0.6 : 0.2),
                  blurRadius: isSelected ? 8 : 4,
                  spreadRadius: isSelected ? 1 : 0,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Noto Sans Arabic',
            ),
          )
        ],
      ),
    );
  }
}
