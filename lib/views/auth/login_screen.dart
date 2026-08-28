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
        success = await authService.loginWithRole(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          UserRole.student,
        );
      } else {
        success = await authService.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text.trim(),
          UserRole.student,
        );
      }
    } catch (e) {
      success = false;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('email-already-in-use')) {
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
    }

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const NavigationShell()),
        (route) => false,
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage ??= 'پڕۆسەکە سەرکەوتوو نەبوو. تکایە زانیارییەکان بپشکنە.';
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.loginWithGoogle(UserRole.student);

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavigationShell()),
          (route) => false,
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'چوونەژوورەوە بە گووگڵ بەدی نەهات. تکایە دووبارە تاقیبکەرەوە.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'هەڵە لە چوونەژوورەوە بە گووگڵ: تکایە دڵنیابەرەوە لە پەیوەندی ئینتەرنێت.';
      });
    }
  }

  Future<void> _loginAsGuest() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.loginAsGuest();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const NavigationShell()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
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
                                  ? const Center(
                                      child: CircularProgressIndicator())
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

