import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../widgets/apple_ui_components.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../services/theme_provider.dart';
import '../auth/login_screen.dart';
import '../payment/vip_upgrade_sheet.dart';
import '../../services/app_version_service.dart';
import '../update/force_update_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/university_department_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/kurdistan_universities_data.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showFeedbackModal(BuildContext context, dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textController = TextEditingController();
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String t(String k) => langProvider.translate(k);
    final types = [
      t('feedback_type_feature'),
      t('feedback_type_bug'),
      t('feedback_type_content'),
      t('feedback_type_other'),
    ];
    String feedbackType = types.first;
    int rating = 5;
    bool isSubmitting = false;

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
                      Icon(CupertinoIcons.chat_bubble_text_fill, color: ZankoColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        t('feedback_suggestions'),
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
                    t('feedback_dialog_desc'),
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
                            color: ZankoColors.primary,
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
                      hintText: t('feedback_input_hint'),
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
                            SnackBar(content: Text(t('feedback_input_empty'))),
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
                              SnackBar(
                                content: Text(t('feedback_sent_success')),
                                backgroundColor: const Color(0xFF10B981),
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
                          : Text(
                              t('send_feedback'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
                    Icon(CupertinoIcons.checkmark_seal_fill, color: ZankoColors.primary, size: 24),
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
                      border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.3), width: 1.5),
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
                                gradient: LinearGradient(
                                  colors: [ZankoColors.primary, ZankoColors.accent],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ZankoColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: ClipOval(
                                child: (user?.photoUrl != null &&
                                        user!.photoUrl!.isNotEmpty &&
                                        !user.photoUrl!.contains('student_avatar_3d.png'))
                                    ? (user.photoUrl!.startsWith('http')
                                        ? Image.network(
                                            user.photoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Image.asset('assets/images/student_avatar_3d.png', fit: BoxFit.cover),
                                          )
                                        : (user.photoUrl!.startsWith('assets/')
                                            ? Image.asset(user.photoUrl!, fit: BoxFit.cover)
                                            : (kIsWeb
                                                ? Image.network(
                                                    user.photoUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) => Image.asset('assets/images/student_avatar_3d.png', fit: BoxFit.cover),
                                                  )
                                                : Image.file(
                                                    File(user.photoUrl!),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) => Image.asset('assets/images/student_avatar_3d.png', fit: BoxFit.cover),
                                                  ))))
                                    : Image.asset(
                                        'assets/images/student_avatar_3d.png',
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
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
                        Text(
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
                _buildDetailRow(context, t('cumulative_gpa'), '0 / 100'),
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
                          backgroundColor: ZankoColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit02, color: Colors.white, size: 18),
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
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String t(String k) => langProvider.translate(k);
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
                top: 24,
                left: 20,
                right: 20,
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
                        Icon(CupertinoIcons.pencil_circle_fill, color: ZankoColors.primary, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          t('edit_profile'),
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
                      t('edit_profile_desc'),
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: t('full_name'),
                        labelStyle: TextStyle(color: ZankoColors.primary),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // University Selector
                    TextField(
                      controller: uniCtrl,
                      readOnly: true,
                      onTap: () async {
                        final chosenUni = await UniversityDepartmentPicker.showUniversityPicker(
                          context,
                          selectedUniversityName: uniCtrl.text.trim(),
                        );
                        if (chosenUni != null) {
                          setModalState(() {
                            uniCtrl.text = chosenUni.nameKu;
                            if (cityCtrl.text.isEmpty || cityCtrl.text.trim() == 'کوردستان') {
                              cityCtrl.text = chosenUni.cityNameKu;
                            }
                            deptCtrl.clear();
                          });
                        }
                      },
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: t('select_university'),
                        labelStyle: TextStyle(color: ZankoColors.primary),
                        hintText: '...',
                        suffixIcon: const Icon(Icons.arrow_drop_down_rounded, size: 28),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Faculty/Dept Selector
                    TextField(
                      controller: deptCtrl,
                      readOnly: true,
                      onTap: () async {
                        final currentUni = uniCtrl.text.trim().isNotEmpty ? uniCtrl.text.trim() : 'گشت زانکۆکان';
                        final chosenDept = await UniversityDepartmentPicker.showDepartmentPicker(
                          context,
                          universityName: currentUni,
                          selectedDepartmentName: deptCtrl.text.trim(),
                        );
                        if (chosenDept != null) {
                          setModalState(() {
                            deptCtrl.text = chosenDept;
                          });
                        }
                      },
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: t('select_department'),
                        labelStyle: TextStyle(color: ZankoColors.primary),
                        hintText: '...',
                        suffixIcon: const Icon(Icons.arrow_drop_down_rounded, size: 28),
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
                        labelText: t('select_city'),
                        labelStyle: TextStyle(color: ZankoColors.primary),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Read-only info row
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? ZankoColors.darkBackground : Colors.blue.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.blue.shade100,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'زانیارییە فەرمییە نەگۆڕەکان (تەنها ئەدمین):',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey[400] : ZankoColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildLockedDetailRow('🔒 تێکڕای گشتی نمرە:', '${user?.gpa ?? 0} / 100', isDark),
                          _buildLockedDetailRow('🔒 کرێدیتی تەواوبوو:', '96 / 120 ECTS', isDark),
                          _buildLockedDetailRow('🔒 بارودۆخی کامپس:', 'Active • Good Standing 🟢', isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          final newName = nameCtrl.text.trim();
                          final newUni  = uniCtrl.text.trim();
                          final newDept = deptCtrl.text.trim();
                          final newCity = cityCtrl.text.trim();

                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t('please_enter_full_name'))),
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
                              if (context.mounted) {
                                await Provider.of<AuthService>(context, listen: false).reloadUser();
                              }
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t('profile_updated_success')),
                                  backgroundColor: const Color(0xFF10B981),
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
                            : Text(
                                t('save_profile_data'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }


  void _showNotificationsModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String t(String k) => langProvider.translate(k);
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
                      Icon(CupertinoIcons.bell_fill, color: ZankoColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        t('notification_settings'),
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
                    activeThumbColor: ZankoColors.primary,
                    title: Text(t('exam_alerts'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(t('exam_alerts_desc'), style: const TextStyle(fontSize: 12)),
                    value: dailyExamAlert,
                    onChanged: (val) => setModalState(() => dailyExamAlert = val),
                  ),
                  const Divider(),
                  SwitchListTile(
                    activeThumbColor: ZankoColors.primary,
                    title: Text(t('study_streak_reminder'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(t('study_streak_desc'), style: const TextStyle(fontSize: 12)),
                    value: studyReminder,
                    onChanged: (val) => setModalState(() => studyReminder = val),
                  ),
                  const Divider(),
                  SwitchListTile(
                    activeThumbColor: ZankoColors.primary,
                    title: Text(t('campus_news'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(t('campus_news_desc'), style: const TextStyle(fontSize: 12)),
                    value: campusNews,
                    onChanged: (val) => setModalState(() => campusNews = val),
                  ),
                  const Divider(),
                  SwitchListTile(
                    activeThumbColor: ZankoColors.primary,
                    title: Text(t('vip_alerts'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(t('vip_alerts_desc'), style: const TextStyle(fontSize: 12)),
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
                          SnackBar(
                            content: Text(t('notifications_saved')),
                            backgroundColor: ZankoColors.success,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZankoColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(t('save'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Container(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131824) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(CupertinoIcons.shield_lefthalf_fill, color: ZankoColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سیاسەتی پاراستنی نهێنی ZankoAI',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Privacy Policy & Terms of Service',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, color: Colors.grey, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🛡️ پێشەکی',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZankoColors.primary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'ئەپی ZankoAI پابەندە بە پاراستنی تەواوی نهێنی و زانیارییە کەسییەکانی بەکارهێنەران و خوێندکاران. داتاکانت بە پارێزراوی ڕادەگیرێن و بە هیچ جۆرێک لەگەڵ لایەنی سێیەم هاوبەش ناکرێن.',
                          style: TextStyle(fontSize: 13.5, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '📋 ئەو زانیارییانەی کۆدەکرێنەوە',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZankoColors.primary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• زانیاری هەژمار: ناو، ئیمەیڵ، زانکۆ و قۆناغی خوێندن.\n'
                          '• ناوەڕۆکی نێردراو: پرسیارەکان، تێبینییە دەنگییەکان بۆ نوسینەوە، و وێنەی هاوکێشەکان بۆ شیکارکردنی ئەکادیمی لەلایەن AI.\n'
                          '• داتاکان بە تشفیری پێشکەوتووی TLS 1.3 دەگوازرێنەوە.',
                          style: TextStyle(fontSize: 13.5, height: 1.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '🤖 بەکارهێنانی ژیریی دەستکرد (AI)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZankoColors.primary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'پرسیارەکان لە ڕێگەی سێرڤەری پارێزراوی Google Gemini API بە مەبەستی فێرکاری و دەرکردنی ئەنجامی شیکاری پرسیارەکان دەخوێندرێنەوە و پارێزراون.',
                          style: TextStyle(fontSize: 13.5, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '📞 پەیوەندی و تیمی گەشەپێدەر (birdev)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZankoColors.primary),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final uri = Uri.parse('https://www.birdev.tech/');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.globe, size: 15, color: ZankoColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'ماڵپەڕی فەرمی: www.birdev.tech',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: ZankoColors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• واتسئەپ: 07509987345\n• تێلیگرام: @rawankurdi',
                          style: TextStyle(fontSize: 13.5, height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        Builder(
                          builder: (tileCtx) {
                            final lp = Provider.of<LanguageProvider>(tileCtx, listen: false);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(CupertinoIcons.trash_fill, color: ZankoColors.error),
                              title: Text(lp.translate('clear_cache'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              subtitle: Text(lp.translate('clear_cache_desc'), style: const TextStyle(fontSize: 11.5)),
                              onTap: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(lp.translate('cache_cleared_success')),
                                    backgroundColor: ZankoColors.success,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (btnCtx) {
                    final lp = Provider.of<LanguageProvider>(btnCtx, listen: false);
                    return ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZankoColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(lp.translate('understood'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ],
            ),
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
                    errorBuilder: (_, _, _) => Icon(CupertinoIcons.sparkles, color: ZankoColors.primary, size: 50),
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
              Text(
                'وەشانی v${AppVersionService.currentAppVersion} • Official Kurdistan Student AI Companion',
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
              // Check for Updates Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final updateInfo = await AppVersionService().checkForUpdate();
                    if (context.mounted) {
                      if (updateInfo.isUpdateAvailable) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ForceUpdateScreen(updateInfo: updateInfo),
                          ),
                        );
                      } else {
                        final lp = Provider.of<LanguageProvider>(context, listen: false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkBadge01, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${lp.translate('you_have_latest_version')} (v${AppVersionService.currentAppVersion})',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF34C759),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    }
                  },
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 18, color: Colors.white),
                  label: Builder(
                    builder: (btnCtx) {
                      final lp = Provider.of<LanguageProvider>(btnCtx, listen: false);
                      return Text(
                        lp.translate('check_updates'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZankoColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final uri = Uri.parse('https://www.birdev.tech/');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
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
                      Flexible(
                        child: Text(
                          'گەشەپێدراوە لەلایەن تیمی birdev ★ (birdev.tech)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Builder(
                  builder: (closeCtx) {
                    final lp = Provider.of<LanguageProvider>(closeCtx, listen: false);
                    return OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        lp.translate('close'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                        ),
                      ),
                    );
                  },
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
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String t(String k) => langProvider.translate(k);
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
                        Icon(CupertinoIcons.camera_fill, color: ZankoColors.primary, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          t('change_profile_photo'),
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
                      t('choose_avatar_or_url'),
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Selected Preview Avatar
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (picked != null) {
                            setModalState(() {
                              selectedAvatar = picked.path;
                              urlCtrl.text = picked.path;
                            });
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 106,
                              height: 106,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: ZankoColors.primary, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: ZankoColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: selectedAvatar.startsWith('http')
                                    ? Image.network(selectedAvatar, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person, size: 55))
                                    : (selectedAvatar.startsWith('assets/')
                                        ? Image.asset(selectedAvatar, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person, size: 55))
                                        : (kIsWeb
                                            ? Image.network(selectedAvatar, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person, size: 55))
                                            : Image.file(File(selectedAvatar), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person, size: 55)))),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ZankoColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 📱 Device Photo Picker Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                              if (picked != null) {
                                setModalState(() {
                                  selectedAvatar = picked.path;
                                  urlCtrl.text = picked.path;
                                });
                              }
                            },
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 18, color: Colors.white),
                            label: Text(t('phone_gallery'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ZankoColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                              if (picked != null) {
                                setModalState(() {
                                  selectedAvatar = picked.path;
                                  urlCtrl.text = picked.path;
                                });
                              }
                            },
                            icon: HugeIcon(icon: HugeIcons.strokeRoundedCamera01, size: 18, color: isDark ? Colors.white : ZankoColors.textPrimary),
                            label: Text(t('camera_photo'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : ZankoColors.textPrimary,
                              side: BorderSide(color: isDark ? Colors.white30 : Colors.grey[300]!, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Preset Avatars Grid
                    Text(
                      t('suggested_avatars'),
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
                        labelText: t('custom_image_url'),
                        labelStyle: TextStyle(color: ZankoColors.primary),
                        hintText: 'https://...',
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        prefixIcon: Icon(CupertinoIcons.link, color: ZankoColors.primary),
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
                              try {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('local_avatar_path', selectedAvatar);
                              } catch (_) {}
                              if (context.mounted) {
                                await Provider.of<AuthService>(context, listen: false).reloadUser();
                              }
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t('avatar_updated_success')),
                                  backgroundColor: const Color(0xFF10B981),
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
                            : Text(
                                t('save_avatar'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
                title: langProvider.translate('badini_name'),
                subtitle: langProvider.translate('badini_desc'),
                flag: '☀️',
                isSelected: langProvider.currentLanguage == AppLanguage.kurdishBadini,
                onTap: () {
                  langProvider.setLanguage(AppLanguage.kurdishBadini);
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
              ? ZankoColors.primary.withValues(alpha: 0.12)
              : (isDark ? ZankoColors.darkCardSecondary : Colors.grey[50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? ZankoColors.primary
                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEFEFF5)),
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
              Icon(CupertinoIcons.checkmark_circle_fill, color: ZankoColors.primary, size: 20),
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
    final isGuest = user == null ||
        user.isGuest ||
        user.name == 'مێوان' ||
        user.name == 'مێڤان' ||
        user.name == 'زائر' ||
        user.name.trim().toLowerCase() == 'guest';
    final userName = isGuest ? t('guest') : user.name;
    final userEmail = isGuest ? 'guest@zanko.edu' : user.email;
    final uniName = isGuest
        ? t('university_not_set')
        : ((user.universityName != null && user.universityName!.trim().isNotEmpty)
            ? KurdistanUniversitiesData.getLocalizedUniversityName(user.universityName!, langProvider.languageCode)
            : t('university_not_set'));
    final deptName = isGuest
        ? t('zankoai_student_role')
        : ((user.departmentName != null && user.departmentName!.trim().isNotEmpty)
            ? KurdistanUniversitiesData.getLocalizedDepartmentName(user.departmentName!, langProvider.languageCode)
            : t('zankoai_student_role'));

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: false,
        title: Text(
          t('settings_profile'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        actions: [
          if (!isGuest)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: GestureDetector(
                onTap: () => _showEditProfileModal(context, user, userName, uniName, deptName),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ZankoColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.pencil,
                    size: 18,
                    color: ZankoColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // ─── 1. Modern Hero Identity Card (App Color Gradient) ───
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF0F2038),
                          ZankoColors.primary.withValues(alpha: 0.75),
                        ]
                      : [
                          ZankoColors.primary,
                          const Color(0xFF024A9B),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? ZankoColors.primary.withValues(alpha: 0.4)
                      : const Color(0xFF388BF2),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ZankoColors.primary.withValues(alpha: isDark ? 0.25 : 0.3),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  children: [
                    // Ambient light ring 1
                    Positioned(
                      top: -40,
                      right: -30,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    // Ambient light ring 2
                    Positioned(
                      bottom: -50,
                      left: -20,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar with camera tap
                              GestureDetector(
                                onTap: () => _showPhotoChooserModal(context, user),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: (user != null &&
                                                user.photoUrl != null &&
                                                user.photoUrl!.isNotEmpty)
                                            ? (user.photoUrl!.startsWith('http')
                                                ? Image.network(user.photoUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, stack) => Image.asset(
                                                        'assets/images/student_avatar_3d.png',
                                                        fit: BoxFit.cover))
                                                : (user.photoUrl!.startsWith('assets/')
                                                    ? Image.asset(user.photoUrl!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (ctx, err, stack) => Image.asset(
                                                            'assets/images/student_avatar_3d.png',
                                                            fit: BoxFit.cover))
                                                    : (kIsWeb
                                                        ? Image.network(user.photoUrl!,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (ctx, err, stack) => Image.asset(
                                                                'assets/images/student_avatar_3d.png',
                                                                fit: BoxFit.cover))
                                                        : Image.file(File(user.photoUrl!),
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (ctx, err, stack) => Image.asset(
                                                                'assets/images/student_avatar_3d.png',
                                                                fit: BoxFit.cover)))))
                                            : Image.asset(
                                                'assets/images/student_avatar_3d.png',
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.camera_alt_rounded,
                                          size: 13,
                                          color: ZankoColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            userName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.4,
                                            ),
                                          ),
                                        ),
                                        if (!isGuest && user.isVip) ...[
                                          const SizedBox(width: 6),
                                          const Text('👑', style: TextStyle(fontSize: 16)),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    // Status Badge Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isGuest
                                                ? Icons.person_outline_rounded
                                                : Icons.verified_user_rounded,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isGuest
                                                ? t('guest_account')
                                                : (user.isVip
                                                    ? 'VIP Member'
                                                    : t('zankoai_student_role')),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.school_rounded,
                                          size: 13,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            uniName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Card bottom bar with actions
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: isGuest
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t('guest_banner_title'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withValues(alpha: 0.95),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => const LoginScreen()),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            t('login'),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: ZankoColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _showUniversityIdModal(
                                              context,
                                              user,
                                              userName,
                                              userEmail,
                                              uniName,
                                              deptName),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.qr_code_rounded,
                                                  size: 16, color: Colors.white),
                                              const SizedBox(width: 6),
                                              Text(
                                                t('digital_id'),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 16,
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _showEditProfileModal(
                                              context,
                                              user,
                                              userName,
                                              uniName,
                                              deptName),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.edit_outlined,
                                                  size: 15, color: Colors.white),
                                              const SizedBox(width: 6),
                                              Text(
                                                t('edit_profile'),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
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

            // ─── 2. VIP Membership Status Banner ───
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ZankoColors.primary
                      .withValues(alpha: user?.isVip == true ? 0.6 : 0.25),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ZankoColors.primary
                        .withValues(alpha: isDark ? 0.15 : 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ZankoColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.sparkles,
                        color: ZankoColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.isVip == true
                              ? t('vip_banner_title_active')
                              : t('vip_banner_title_guest'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isDark ? Colors.white : ZankoColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.isVip == true
                              ? t('vip_banner_desc_active')
                              : t('vip_banner_desc_guest'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? const Color(0xFFA6ACB8)
                                : ZankoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => VipUpgradeSheet.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZankoColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                    ),
                    child: Text(
                      user?.isVip == true ? t('vip_renew_btn') : t('vip_upgrade_btn'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),


            const SizedBox(height: 16),
            const AdBannerWidget(screenName: 'profile'),

            // ─── 3. Preferences Group ───
            _buildSettingsGroup(
              context,
              title: langProvider.translate('preferences'),
              children: [
                _buildSettingsTile(
                  context,
                  icon: HugeIcons.strokeRoundedMoon02,
                  iconColor: ZankoColors.primary,
                  title: langProvider.translate('dark_mode'),
                  trailing: CupertinoSwitch(
                    value: themeProvider.isDarkMode,
                    activeTrackColor: ZankoColors.primary,
                    onChanged: (val) => themeProvider.toggleTheme(val),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: HugeIcons.strokeRoundedGlobe,
                  iconColor: ZankoColors.primary,
                  title: langProvider.translate('app_language'),
                  subtitle: langProvider.currentLanguage == AppLanguage.english
                      ? 'English'
                      : (langProvider.currentLanguage == AppLanguage.kurdish
                          ? 'کوردی (سۆرانی)'
                          : (langProvider.currentLanguage == AppLanguage.kurdishBadini
                              ? 'کوردی (بادینی)'
                              : 'العربية')),
                  onTap: () => _showLanguagePickerModal(context, langProvider),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: HugeIcons.strokeRoundedNotification01,
                  iconColor: ZankoColors.primary,
                  title: langProvider.translate('notifications'),
                  subtitle: langProvider.translate('daily_reminders'),
                  onTap: () => _showNotificationsModal(context),
                ),
              ],
            ),

            // ─── 4. Support & Feedback Group ───
            _buildSettingsGroup(
              context,
              title: langProvider.translate('support_and_info'),
              children: [
                _buildSettingsTile(
                  context,
                  icon: HugeIcons.strokeRoundedChatting01,
                  iconColor: ZankoColors.primary,
                  title: langProvider.translate('feedback_suggestions'),
                  subtitle: langProvider.translate('feedback_subtitle'),
                  onTap: () => _showFeedbackModal(context, user),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: HugeIcons.strokeRoundedLockPassword,
                  iconColor: ZankoColors.primary,
                  title: langProvider.translate('privacy_security'),
                  onTap: () => _showPrivacySecurityModal(context),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  iconColor: ZankoColors.primary,
                  title: langProvider.translate('about_zanko'),
                  subtitle: langProvider.translate('version'),
                  onTap: () => _showAboutZankoModal(context),
                ),
              ],
            ),

            // ─── 5. Account Actions Group ───
            _buildSettingsGroup(
              context,
              title: langProvider.translate('account'),
              children: [
                _buildSettingsTile(
                  context,
                  icon: isGuest
                      ? HugeIcons.strokeRoundedLogin01
                      : HugeIcons.strokeRoundedLogout01,
                  iconColor: isGuest
                      ? ZankoColors.primary
                      : const Color(0xFFE11D48),
                  title: isGuest ? t('login_or_register') : t('logout'),
                  subtitle: isGuest ? t('login_register_desc') : t('logout_desc'),
                  isDestructive: !isGuest,
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
                if (!isGuest) ...[
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    context,
                    icon: HugeIcons.strokeRoundedDelete02,
                    iconColor: const Color(0xFFDC2626),
                    title: t('delete_account'),
                    subtitle: t('delete_account_desc'),
                    isDestructive: true,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          backgroundColor: isDark ? ZankoColors.darkCard : Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: Row(
                            children: [
                              const HugeIcon(
                                  icon: HugeIcons.strokeRoundedAlert02,
                                  color: Colors.redAccent,
                                  size: 24),
                              const SizedBox(width: 8),
                              Text(
                                t('delete_account_confirm_title'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                            ],
                          ),
                          content: Text(
                            t('delete_account_confirm_desc'),
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: Text(t('cancel')),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                Navigator.pop(dialogCtx);
                                await authService.deleteAccount();
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()),
                                    (route) => false,
                                  );
                                }
                              },
                              child: Text(t('yes_delete')),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // birdev footer & copyright
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final uri = Uri.parse('https://www.birdev.tech/');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.sparkles,
                              size: 14, color: ZankoColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            t('developed_by'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t('all_rights_reserved')} © ${DateTime.now().year}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, right: 6, bottom: 8, top: 18),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF262C36) : const Color(0xFFE2EDFB),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required dynamic icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(child: appIcon(icon, color: iconColor, size: 18)),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? const Color(0xFFE11D48)
              : (isDark ? Colors.white : ZankoColors.textPrimary),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFA6ACB8) : ZankoColors.textSecondary,
              ),
            )
          : null,
      trailing: trailing ??
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
    );
  }
}
