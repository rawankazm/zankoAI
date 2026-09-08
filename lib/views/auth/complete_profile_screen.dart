import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../widgets/university_department_picker.dart';
import '../navigation_shell.dart';

/// Screen presented when an existing user's account was reset or deleted,
/// prompting them to enter fresh academic and personal information.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  final _departmentController = TextEditingController();
  String _selectedCityKey = 'city_slemani';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _kurdishCities = const [
    'city_erbil',
    'city_slemani',
    'city_duhok',
    'city_karkuk',
    'city_halabja',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _selectUniversity() async {
    final uni = await UniversityDepartmentPicker.showUniversityPicker(
      context,
      selectedUniversityName: _universityController.text.isNotEmpty
          ? _universityController.text
          : null,
    );
    if (uni != null) {
      setState(() {
        _universityController.text = uni.nameKu;
        _departmentController.clear();
      });
    }
  }

  Future<void> _selectDepartment() async {
    final uniName = _universityController.text.trim();
    if (uniName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە سەرەتا زانکۆ دیاری بکە')),
      );
      return;
    }
    final dept = await UniversityDepartmentPicker.showDepartmentPicker(
      context,
      universityName: uniName,
      selectedDepartmentName: _departmentController.text.isNotEmpty
          ? _departmentController.text
          : null,
    );
    if (dept != null) {
      setState(() {
        _departmentController.text = dept;
      });
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final success = await authService.updateProfile(
        fullName: _nameController.text.trim(),
        universityName: _universityController.text.trim(),
        departmentName: _departmentController.text.trim(),
        cityName: langProvider.translate(_selectedCityKey),
      );

      // Reactivate profile status in Supabase
      try {
        final userId = authService.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client
              .from('profiles')
              .update({
                'status': 'active',
                'full_name': _nameController.text.trim(),
                'university_name': _universityController.text.trim(),
                'department_name': _departmentController.text.trim(),
                'city_name': langProvider.translate(_selectedCityKey),
              })
              .eq('id', userId);
        }
      } catch (_) {}

      if (mounted && success) {
        await authService.reloadUser();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const NavigationShell()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'هەڵەیەک ڕوویدا: $e';
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String k) => langProvider.translate(k);

    return Scaffold(
      backgroundColor: isDark
          ? ZankoColors.darkBackground
          : ZankoColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: ZankoColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.school_rounded,
                        size: 38,
                        color: ZankoColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Subtitle
                  Text(
                    'تەواوکردنی زانیارییەکانی پڕۆفایل',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تکایە زانیارییە نوێیەکانت بنووسە بۆ چالاککردنەوەی هەژمارەکەت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey[400]
                          : ZankoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ZankoColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ZankoColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: ZankoColors.error,
                          fontSize: 12.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Full name
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t('full_name'),
                      hintText: t('full_name_hint'),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'تکایە ناوی تەواوت بنووسە';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // City selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCityKey,
                    decoration: InputDecoration(
                      labelText: t('select_city'),
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: _kurdishCities.map((cityKey) {
                      return DropdownMenuItem<String>(
                        value: cityKey,
                        child: Text(t(cityKey)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCityKey = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // University picker
                  TextFormField(
                    controller: _universityController,
                    readOnly: true,
                    onTap: _selectUniversity,
                    decoration: InputDecoration(
                      labelText: t('select_university'),
                      hintText: 'کلیک بکە بۆ هەڵبژاردنی زانکۆ...',
                      prefixIcon: const Icon(Icons.account_balance_outlined),
                      suffixIcon: const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 28,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'تکایە زانکۆت دیاریبکە';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Department picker
                  TextFormField(
                    controller: _departmentController,
                    readOnly: true,
                    onTap: _selectDepartment,
                    decoration: InputDecoration(
                      labelText: t('select_department'),
                      hintText: 'کلیک بکە بۆ دیاریکردنی بەشی زانستی...',
                      prefixIcon: const Icon(Icons.account_tree_outlined),
                      suffixIcon: const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 28,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'تکایە بەش یان پسپۆڕی دیاریبکە';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZankoColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'تەواوکردن و بەردەوامبوون ✓',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
