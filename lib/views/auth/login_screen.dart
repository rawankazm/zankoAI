import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../navigation_shell.dart';
import '../../models/user_model.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final bool _isLoginMode = true;
  bool _isLoading = false;
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
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    
    // Automatically animate the form fields in since role is pre-selected
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    bool success = false;

    try {
      if (_isLoginMode) {
        success = await authService
            .loginWithRole(
              _emailController.text.trim(),
              _passwordController.text.trim(),
              UserRole.student,
            )
            .timeout(const Duration(seconds: 15));
      } else {
        success = await authService
            .register(
              _nameController.text.trim(),
              _emailController.text.trim(),
              _passwordController.text.trim(),
              UserRole.student,
            )
            .timeout(const Duration(seconds: 15));
      }
    } on TimeoutException {
      success = false;
      _errorMessage = 'پڕۆسەکە کاتی بەسەرچوو. تکایە هێڵی ئینتەرنێتەکەت بپشکنە.';
    } catch (e) {
      success = false;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('ip-limit-exceeded') || errStr.contains('٣ ناونیشانی ip') || errStr.contains('ip limit')) {
        _errorMessage = '⛔ ناتوانیت لە زیاتر لە ٣ ناونیشانی IP جیاواز ئەکاونتەکەت بکەیتەوە.\nئەمە بۆ پاراستنی ئەکاونت و ڕێگرییە لە هاوبەشکردنی نایاسایی.';
      } else if (errStr.contains('email-already-in-use')) {
        _errorMessage = 'ئەم ئیمەیڵە پێشتر تۆمار کراوە.';
      } else if (errStr.contains('wrong-password') || errStr.contains('invalid-credential')) {
        _errorMessage = 'وشەی نهێنی یان ئیمەیڵ هەڵەیە.';
      } else if (errStr.contains('user-not-found')) {
        _errorMessage = 'هیچ هەژمارێک بەم ئیمەیڵە نەدۆزرایەوە.';
      } else if (errStr.contains('weak-password')) {
        _errorMessage = 'وشەی نهێنی زۆر لاوازە (لانی کەم ٦ پیت).';
      } else if (errStr.contains('invalid-email')) {
        _errorMessage = 'ئیمەیڵەکە شێوازێکی دروستی نییە.';
      } else {
        _errorMessage = 'پڕۆسەکە سەرکەوتوو نەبوو. تکایە هێڵی ئینتەرنێتەکەت بپشکنە.';
      }
    } finally {
      if (mounted && !success) {
        setState(() {
          _isLoading = false;
          _errorMessage ??= 'پڕۆسەکە سەرکەوتوو نەبوو. تکایە زانیارییەکان بپشکنە.';
        });
      }
    }

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const NavigationShell()),
        (route) => false,
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool success = false;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      success = await authService
          .loginWithGoogle(UserRole.student)
          .timeout(const Duration(seconds: 25), onTimeout: () => false);
    } on TimeoutException {
      success = false;
      _errorMessage = 'چوونەژوورەوە بە گووگڵ کاتی بەسەرچوو. تکایە هێڵی ئینتەرنێتەکەت بپشکنە.';
    } catch (e) {
      success = false;
      _errorMessage = 'هەڵە لە چوونەژوورەوە بە گووگڵ. تکایە دووبارە تاقیبکەرەوە.';
    } finally {
      if (mounted && !success) {
        setState(() {
          _isLoading = false;
          _errorMessage ??= 'چوونەژوورەوە بە گووگڵ بەدی نەهات. تکایە دووبارە تاقیبکەرەوە.';
        });
      }
    }

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const NavigationShell()),
        (route) => false,
      );
    }
  }

  Future<void> _loginAsGuest() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.loginAsGuest();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const NavigationShell()),
        (route) => false,
      );
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showIpAppealSheet() {
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.contact_support_rounded, color: Color(0xFF7D2AE8), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'داواکاریی نوێکردنەوەی IP 🌐',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ئەگەر هێڵی ئینتەرنێت یان مۆبایلت گۆڕیوە، هۆکارەکەی بنووسە تا بەڕێوەبەر پێداچوونەوەی بۆ بکات.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'نموونە: هێڵی ئینتەرنێتم گۆڕیوە، تکایە ڕێگەم پێبدەن...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF282E3A) : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              try {
                                final email = _emailController.text.trim();
                                await FirebaseFirestore.instance.collection('security_alerts').add({
                                  'email': email,
                                  'name': email.isNotEmpty && email.contains('@') ? email.split('@').first : 'خوێندکار',
                                  'type': 'ip_limit_appeal',
                                  'reason': 'داواکاری نوێکردنەوەی IP لەلایەن بەکارهێنەرەوە',
                                  'userNote': noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : 'داواکاری نوێکردنەوەی IP لەلایەن بەکارهێنەرەوە',
                                  'status': 'pending',
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ داواکارییەکەت بۆ ئەدمین نێردرا. دوای پێداچوونەوە دەتوانیت بچیتە ژوورەوە.'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7D2AE8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('ناردنی داواکاری بۆ ئەدمین', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip (Guest) Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 16.0, left: 16.0),
                child: TextButton.icon(
                  onPressed: _loginAsGuest,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  label: Text(
                    t('skip_guest'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Directionality(
                    textDirection: langProvider.textDirection,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  // App Logo
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            width: 1.5),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.school_rounded,
                            size: 80,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ZankoAI',
                    textAlign: TextAlign.center,style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                  ),
                  Text(
                    _isLoginMode ? t('slogan') : t('register'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),



                  // ─── Error Message ───
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_errorMessage!.contains('IP') || _errorMessage!.contains('ئایپی')) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _showIpAppealSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.send_rounded, size: 15),
                              label: const Text(
                                'ناردنی داواکاری بۆ ئەدمین 📩',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Form ───
                  FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!_isLoginMode) ...[
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: t('fullname'),
                                    prefixIcon:
                                        const Icon(Icons.person_outline),
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? t('please_enter_name')
                                          : null,
                                ),
                                const SizedBox(height: 16),
                              ],
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: t('email'),
                                  prefixIcon:
                                      const Icon(Icons.email_outlined),
                                  hintText: t('email_hint'),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'تکایە ئیمەیڵ بنووسە';
                                  }
                                  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'تکایە ئیمەیڵێکی دروست بنووسە (نموونە: student@zanko.edu)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: t('password'),
                                  prefixIcon:
                                      const Icon(Icons.lock_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'تکایە وشەی نهێنی بنووسە';
                                  }
                                  if (value.length < 6) {
                                    return 'وشەی نهێنی لانی کەم ٦ پیت بێت';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              _isLoading
                                  ? Column(
                                      children: [
                                        const Center(
                                            child: CircularProgressIndicator()),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () {
                                            setState(() => _isLoading = false);
                                          },
                                          child: const Text(
                                            'پەشیمانبوونەوە / هەڵوەشاندنەوە',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        SizedBox(
                                          width: double.maxFinite,
                                          child: ElevatedButton(
                                            onPressed: _submitForm,
                                            child: Text(_isLoginMode
                                                ? t('login')
                                                : t('register')),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.maxFinite,
                                          child: OutlinedButton.icon(
                                            onPressed: _isLoading ? null : _loginWithGoogle,
                                            icon: Image.network(
                                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                              height: 22,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.g_mobiledata, size: 24),
                                            ),
                                            label: Text(t('google_login')),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 52),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16)),
                                              side: BorderSide(
                                                color: theme.brightness == Brightness.dark
                                                    ? Colors.white24
                                                    : Colors.grey[300]!,
                                                width: 1.5,
                                              ),
                                              textStyle: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),

                              // Guest Access Button (Optional Login)
                              SizedBox(
                                width: double.maxFinite,
                                child: TextButton.icon(
                                  onPressed: _isLoading ? null : _loginAsGuest,
                                  icon: const Icon(Icons.person_outline_rounded, size: 20),
                                  label: Text(
                                    t('guest_login'),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Mode Toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'هەژمارت نییە؟ ',
                                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                      );
                                    },
                                    child: Text(
                                      'دروستکردنی هەژمار',
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
      ],
    ),
  ),
);
  }
}

