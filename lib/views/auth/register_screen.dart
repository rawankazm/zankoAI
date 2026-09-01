import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../navigation_shell.dart';
import '../../models/user_model.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _universityController = TextEditingController();
  final _departmentController = TextEditingController();
  String _selectedCityKey = 'city_slemani';

  final List<String> _kurdishCities = const [
    'city_erbil',
    'city_slemani',
    'city_duhok',
    'city_karkuk',
    'city_halabja',
  ];

  File? _profileImage;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نەتوانرا وێنەکە دیاریبکرێت.')),
        );
      }
    }
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'تکایە سەرەتا ڕەزامەند بە لەسەر مەرج و ڕێنماییەکان.';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'وشەی نهێنی و دووبارەکردنەوەی یەکناگرنەوە.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    bool success = false;

    try {
      success = await authService
          .register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text.trim(),
            UserRole.student,
            universityName: _universityController.text.trim(),
            departmentName: _departmentController.text.trim(),
            cityName: langProvider.translate(_selectedCityKey),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      success = false;
      _errorMessage = 'پڕۆسەکە کاتی بەسەرچوو. تکایە هێڵی ئینتەرنێتەکەت بپشکنە.';
    } catch (e) {
      success = false;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('ip-limit-exceeded') || errStr.contains('٣ ناونیشانی ip') || errStr.contains('ip limit')) {
        _errorMessage = '⛔ ناتوانیت لە زیاتر لە ٣ ناونیشانی IP جیاواز ئەکاونت دروست بکەیت یان بەکاربهێنیت.';
      } else if (errStr.contains('email-already-in-use')) {
        _errorMessage = 'ئەم ئیمەیڵە پێشتر تۆمار کراوە. تکایە چوونەژوورەوە بکە.';
      } else if (errStr.contains('weak-password')) {
        _errorMessage = 'وشەی نهێنی زۆر لاوازە (لانی کەم ٦ پیت).';
      } else if (errStr.contains('invalid-email')) {
        _errorMessage = 'ئیمەیڵەکە شێوازێکی دروستی نییە.';
      } else {
        _errorMessage = 'تۆمارکردن سەرکەوتوو نەبوو. تکایە هێڵی ئینتەرنێتەکەت بپشکنە.';
      }
    } finally {
      if (mounted && !success) {
        setState(() {
          _isLoading = false;
          _errorMessage ??= 'تۆمارکردن سەرکەوتوو نەبوو.';
        });
      }
    }

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NavigationShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Directionality(
              textDirection: langProvider.textDirection,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Subtitle
                  Text(
                    'دروستکردنی هەژماری نوێ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'بەخێر بێیت بۆ ZankoAI - فۆڕمی تۆمارکردن پڕ بکەرەوە',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Profile Image Picker Avatar (Aqarat Style) ───
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : const AssetImage('assets/images/student_avatar_3d.png') as ImageProvider,
                            child: _profileImage == null
                                ? Align(
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 52,
                                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.colorScheme.surface, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('select_profile_image'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: theme.colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Registration Form
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Full Name Input
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: t('full_name'),
                                hintText: t('full_name_hint'),
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'تکایە ناوی تەواوت بنووسە';
                                }
                                if (val.trim().length < 2) {
                                  return 'ناو پێویستە لانی کەم ٢ پیت بێت';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // University / College Input
                            TextFormField(
                              controller: _universityController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: t('select_university'),
                                hintText: 'نموونە: زانکۆی سلێمانی',
                                prefixIcon: const Icon(Icons.school_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'تکایە زانکۆ یان کۆلێژ بنووسە';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Department / Major Input
                            TextFormField(
                              controller: _departmentController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: t('select_department'),
                                hintText: 'نموونە: تەکنەلۆجیای زانیاری',
                                prefixIcon: const Icon(Icons.account_tree_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'تکایە بەش یان پسپۆڕی بنووسە';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // City Dropdown Select (5 Kurdish Cities)
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCityKey,
                              decoration: InputDecoration(
                                labelText: t('select_city'),
                                prefixIcon: const Icon(Icons.location_city_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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

                            // Email Input
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: t('email'),
                                hintText: 'student@zanko.edu',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'تکایە ئیمەیڵ بنووسە';
                                }
                                final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                if (!emailRegex.hasMatch(val.trim())) {
                                  return 'تکایە ئیمەیڵێکی دروست بنووسە (نموونە: student@zanko.edu)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Password Input
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: t('password'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'تکایە وشەی نهێنی بنووسە';
                                }
                                if (val.length < 6) {
                                  return 'وشەی نهێنی پێویستە لانی کەم ٦ پیت بێت';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Confirm Password Input
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: t('confirm_password'),
                                prefixIcon: const Icon(Icons.lock_reset_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'تکایە وشەی نهێنی دووبارە بکەرەوە';
                                }
                                if (val != _passwordController.text) {
                                  return 'وشەی نهێنی یەکناگرێتەوە';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Terms & Conditions Checkbox (Aqarat Style)
                            Row(
                              children: [
                                Checkbox(
                                  value: _agreedToTerms,
                                  onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                                  activeColor: theme.colorScheme.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                                    child: Text(
                                      t('terms_agree'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'تۆمارکردن',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Footer link to Login Screen
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'هەژمارت هەیە؟ ',
                                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                    );
                                  },
                                  child: Text(
                                    'چوونەژوورەوە',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
