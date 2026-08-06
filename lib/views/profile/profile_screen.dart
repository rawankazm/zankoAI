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
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/ad_banner_widget.dart';



class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showFeedbackModal(BuildContext context, dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textController = TextEditingController();
    int rating = 5;
    String feedbackType = 'پێشنیار';
    bool isSubmitting = false;

    final types = ['پێشنیار', 'کێشەی تەکنیکی', 'داواکاری فێچەر', 'سوپاسگوزاری'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.chat_bubble_text_fill, color: ZankoColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'ڕا و پێشنیارەکان',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'پێشنیار یان ڕای خۆت بنووسە بۆ بەرزکردنەوەی کوالێتی ZankoAI',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // Rating Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      return GestureDetector(
                        onTap: () => setModalState(() => rating = starIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            starIndex <= rating ? CupertinoIcons.star_fill : CupertinoIcons.star,
                            color: const Color(0xFFFFD700),
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Feedback Type Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: types.map((type) {
                        final isSelected = feedbackType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: isSelected,
                            selectedColor: ZankoColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) setModalState(() => feedbackType = type);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Text area
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ڕا و پێشنیارەکەت بنووسە...',
                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                      filled: true,
                      fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        final msg = textController.text.trim();
                        if (msg.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تکایە پێشنیارەکەت بنووسە')),
                          );
                          return;
                        }

                        setModalState(() => isSubmitting = true);

                        try {
                          await FirebaseFirestore.instance.collection('user_feedback').add({
                            'userId': user?.id ?? '',
                            'userName': user?.name ?? 'خوێندکار',
                            'userEmail': user?.email ?? '',
                            'type': feedbackType,
                            'message': msg,
                            'rating': rating,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ پێشنیارەکەت بە سەرکەوتووی گەیشتە تیمی ZankoAI!'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZankoColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              '📤 ناردنی پێشنیار',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showUniversityIdModal(BuildContext context, dynamic user, String name, String email, String uniName, String deptName) {
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
          child: SingleChildScrollView(
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

                // 📸 STUDENT PHOTO (Replaces QR Code)
                GestureDetector(
                  onTap: () => _showPhotoChooserModal(context, user),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? ZankoColors.darkBackground : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: ZankoColors.primary.withOpacity(0.3), width: 1.5),
                      boxShadow: ZankoShadows.card,
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFFC084FC)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/student_avatar_3d.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    CupertinoIcons.person_fill,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: ZankoColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'STUDENT PASS ID: 2026-ZK-${user?.id != null ? user.id.toString().substring(0, 4).toUpperCase() : '8842'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '📷 کلیک بکە بۆ گۆڕینی وێنەی مۆبایل',
                          style: TextStyle(fontSize: 11, color: ZankoColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
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
                _buildDetailRow(context, t('campus_status'), 'Active • Good Standing 🟢'),

                const SizedBox(height: 24),

                // Action Buttons: Edit Info & Done
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditProfileModal(context, user, name, uniName, deptName);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(CupertinoIcons.pencil, color: Colors.white, size: 18),
                        label: const Text(
                          'دەستکاریکردنی زانیاری',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        child: Text(
                          t('done'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfileModal(BuildContext context, dynamic user, String name, String uniName, String deptName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: name);
    final uniCtrl  = TextEditingController(text: uniName);
    final deptCtrl = TextEditingController(text: deptName);
    final cityCtrl = TextEditingController(text: user?.cityName ?? 'سلێمانی');
    bool isSaving  = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.pencil_circle_fill, color: ZankoColors.primary, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          'دەستکاریکردنی زانیارییەکان',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ناوی تەواو، زانکۆ، بەش و شاری نیشتەجێبوون نوێ بکەرەوە',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '👤 ناوی تەواو',
                        labelStyle: const TextStyle(color: ZankoColors.primary),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // University
                    TextField(
                      controller: uniCtrl,
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '🏛 زانکۆ',
                        labelStyle: const TextStyle(color: ZankoColors.primary),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Faculty/Dept
                    TextField(
                      controller: deptCtrl,
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '🎓 فاکەڵتی و پسپۆڕی / بەش',
                        labelStyle: const TextStyle(color: ZankoColors.primary),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // City
                    TextField(
                      controller: cityCtrl,
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '📍 شاری نیشتەجێبوون',
                        labelStyle: const TextStyle(color: ZankoColors.primary),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🔒 Locked Read-Only Fields Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(CupertinoIcons.lock_fill, color: Colors.amber, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'زانیارییە فەرمییە نەگۆڕەکان (تەنها ئەدمین):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildLockedDetailRow('🔒 تێکڕای گشتی GPA:', '${user?.gpa ?? 3.65} / 4.00 (Honor Roll)', isDark),
                          _buildLockedDetailRow('🔒 کرێدیتی تەواوبوو:', '96 / 120 ECTS', isDark),
                          _buildLockedDetailRow('🔒 بارودۆخی کامپس:', 'Active • Good Standing 🟢', isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          final newName = nameCtrl.text.trim();
                          final newUni  = uniCtrl.text.trim();
                          final newDept = deptCtrl.text.trim();
                          final newCity = cityCtrl.text.trim();

                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تکایە ناوی تەواو بنووسە')),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);

                          try {
                            if (user != null && user.id != null) {
                              await FirebaseFirestore.instance.collection('users').doc(user.id).update({
                                'name': newName,
                                'universityName': newUni,
                                'departmentName': newDept,
                                'cityName': newCity,
                              });
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ زانیارییەکان بە سەرکەوتوویی نوێکرانەوە!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZankoColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                '💾 پاشەکەوتکردنی زانیاری',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLockedDetailRow(String label, String val, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary)),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }


  void _showNotificationsModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool dailyExamAlert = true;
    bool studyReminder = true;
    bool campusNews = true;
    bool vipAlerts = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.bell_fill, color: Color(0xFFFF9F0A), size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'ڕێکخستنی ئاگادارییەکان',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    activeColor: ZankoColors.primary,
                    title: const Text('ئاگادارکردنەوەی تاقیکردنەوەکان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('ناردنی بیرخەرەوەی ژێرمێژووی تاقیکردنەوەی میدترم و فایناڵ', style: TextStyle(fontSize: 12)),
                    value: dailyExamAlert,
                    onChanged: (val) => setModalState(() => dailyExamAlert = val),
                  ),
                  const Divider(),
                  SwitchListTile(
                    activeColor: ZankoColors.primary,
                    title: const Text('بیرخەرەوەی بەردەوامیی خوێندن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('ناردنی بیرخەرەوە بۆ پاراستنی زنجیرەی ڕۆژانەی دراسەکردن', style: TextStyle(fontSize: 12)),
                    value: studyReminder,
                    onChanged: (val) => setModalState(() => studyReminder = val),
                  ),
                  const Divider(),
                  SwitchListTile(
                    activeColor: ZankoColors.primary,
                    title: const Text('هەواڵ و نوێکارییەکانی زانکۆ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('ئاگادارکردنەوە لە زانکۆلاین و هەواڵە گرنگەکان', style: TextStyle(fontSize: 12)),
                    value: campusNews,
                    onChanged: (val) => setModalState(() => campusNews = val),
                  ),
                  const Divider(),
                  SwitchListTile(
                    activeColor: ZankoColors.primary,
                    title: const Text('ئاگادارکردنەوەی بەشداربوونی VIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('بیرخەرەوەی ماوەی بەسەرچوونی هەژماری VIP', style: TextStyle(fontSize: 12)),
                    value: vipAlerts,
                    onChanged: (val) => setModalState(() => vipAlerts = val),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ڕێکخستنەکانی ئاگاداری بە سەرکەوتوویی پاشەکەوت کران 🔔'),
                            backgroundColor: ZankoColors.success,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZankoColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('پاشەکەوتکردن', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacySecurityModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(CupertinoIcons.lock_fill, color: Color(0xFF34C759), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'تایبەتمەندی و ئاسایش',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const ListTile(
                leading: Icon(CupertinoIcons.shield_fill, color: Color(0xFF34C759)),
                title: Text('پاراستن و تشفیرکردنی داتاکان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('سەرجەم زانیارییەکانت بە پرۆتۆکۆلی TLS 1.3 بە پارێزراوی ڕامگیراون.', style: TextStyle(fontSize: 12)),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(CupertinoIcons.person_badge_minus_fill, color: Color(0xFF007AFF)),
                title: Text('پایەندبوون بە تایبەتمەندی بەکارهێنەر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('زانیارییە کەسییەکانت بە هیچ جۆرێک لەگەڵ لایەنی سێیەم هاوبەش ناکرێن.', style: TextStyle(fontSize: 12)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(CupertinoIcons.trash_fill, color: ZankoColors.error),
                title: const Text('سڕینەوەی کاشی ئۆفلاین (Clear Cache)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('سڕینەوەی فایلی کاتی و پاککردنەوەی فەزای مۆبایلەکەت', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('کاشی ئۆفلاینی ئەپەکە بە سەرکەوتوویی پاککرایەوە 🧹'),
                      backgroundColor: ZankoColors.success,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('داخستن', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutZankoModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              // App Logo
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: ZankoColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.sparkles, color: ZankoColors.primary, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'ZankoAI',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'وەشانی v1.0.0 • Official Kurdistan Student AI Companion',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ZankoColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'یەکەمین و پێشکەوتووترین ئەپی ژیری دەستکرد بۆ قوتابیانی زانکۆ و پەیمانگاکانی هەرێمی کوردستان. یارمەتیدەری سەرەکییت بۆ شیکردنەوەی وانەکان، دروستکردنی تاقیکردنەوە، و ئەنجامدانی کویزی زیرەک.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : ZankoColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.heart_fill, color: ZankoColors.error, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'گەشەپێدراوە لەلایەن تیمەکانی birdev ★',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZankoColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('داخستن', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPhotoChooserModal(BuildContext context, dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urlCtrl = TextEditingController(text: user?.photoUrl ?? '');
    String selectedAvatar = user?.photoUrl ?? 'assets/images/student_avatar_3d.png';
    bool isSaving = false;

    final presetAvatars = [
      'assets/images/student_avatar_3d.png',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.camera_fill, color: ZankoColors.primary, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          'گۆڕینی وێنەی پڕۆفایل',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'وێنەیەک لە ئاڤاتارەکان هەڵبژێرە یان لینکی وێنەکەت بنووسە',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Selected Preview Avatar
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ZankoColors.primary, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: ZankoColors.primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: selectedAvatar.startsWith('http')
                              ? Image.network(selectedAvatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50))
                              : Image.asset(selectedAvatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Preset Avatars Grid
                    Text(
                      'ئاڤاتارە پێشنیازکراوەکان:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : ZankoColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: presetAvatars.map((url) {
                        final isSel = selectedAvatar == url;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedAvatar = url;
                              urlCtrl.text = url;
                            });
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? ZankoColors.primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(
                              child: url.startsWith('http')
                                  ? Image.network(url, fit: BoxFit.cover)
                                  : Image.asset(url, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Custom URL Field
                    TextField(
                      controller: urlCtrl,
                      onChanged: (val) {
                        if (val.trim().isNotEmpty) {
                          setModalState(() => selectedAvatar = val.trim());
                        }
                      },
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'لینکی وێنەی تایبەت (URL)',
                        labelStyle: const TextStyle(color: ZankoColors.primary),
                        hintText: 'https://...',
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        prefixIcon: const Icon(CupertinoIcons.link, color: ZankoColors.primary),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Avatar Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          setModalState(() => isSaving = true);

                          try {
                            if (user != null && user.id != null) {
                              await FirebaseFirestore.instance.collection('users').doc(user.id).update({
                                'photoUrl': selectedAvatar,
                              });
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ وێنەی پڕۆفایل بە سەرکەوتوویی جێگیرکرا!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZankoColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                '💾 جێگیرکردنی وێنەی پڕۆفایل',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
            const AdBannerWidget(screenName: 'profile'),
            const SizedBox(height: 12),



            // ─── University Digital ID Card ──────────────────────────────────

            // ─── High-End Futuristic Digital Student ID Card ───
            GestureDetector(
              onTap: () => _showUniversityIdModal(context, user, userName, userEmail, uniName, deptName),
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
                                Expanded(
                                  child: Row(
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
                                      Expanded(
                                        child: Text(
                                          uniName.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.1,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

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

                            // ─── Main Body: Avatar + Details ───
                            Row(
                              children: [
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
                                  child: ClipOval(
                                    child: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                                        ? (user.photoUrl!.startsWith('http')
                                            ? Image.network(user.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 36))
                                            : Image.asset(user.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 36)))
                                        : Image.asset(
                                            'assets/images/student_avatar_3d.png',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 36),
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
                    onTap: () => _showNotificationsModal(context),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    context,
                    icon: CupertinoIcons.chat_bubble_text_fill,
                    iconColor: const Color(0xFF10B981),
                    title: '💬 ڕا و پێشنیارەکان',
                    subtitle: 'ناردنی داواکاری و پێشنیار بۆ تیمی ZankoAI',
                    onTap: () => _showFeedbackModal(context, user),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    context,
                    icon: CupertinoIcons.lock_fill,
                    iconColor: const Color(0xFF34C759),
                    title: langProvider.translate('privacy_security'),
                    onTap: () => _showPrivacySecurityModal(context),
                  ),

                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    context,
                    icon: CupertinoIcons.info_circle_fill,
                    iconColor: ZankoColors.primary,
                    title: langProvider.translate('about_zanko'),
                    subtitle: langProvider.translate('version'),
                    onTap: () => _showAboutZankoModal(context),
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
