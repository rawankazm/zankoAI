import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../navigation_shell.dart';
import '../../models/user_model.dart';

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

  bool _isLoginMode = true;
  bool _isLoading = false;
  UserRole _selectedRole = UserRole.student;
  String? _errorMessage;
  bool _roleSelected = true;

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

    if (_isLoginMode) {
      success = await authService.loginWithRole(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedRole,
      );
    } else {
      success = await authService.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedRole,
      );
    }

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NavigationShell()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'پڕۆسەکە سەرکەوتوو نەبوو. تکایە زانیارییەکان بپشکنە.';
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.loginWithGoogle(_selectedRole);

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NavigationShell()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'چوونەژوورەوە بە گووگڵ سەرکەوتوو نەبوو.';
      });
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
                  // App Logo
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            width: 1.5),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
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
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const SizedBox(height: 20),

                  // ─── Error Message ───
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.1),
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

                  // ─── Form (shown only after role selection) ───
                  if (_roleSelected) ...[
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
                                validator: (value) =>
                                    value == null || !value.contains('@')
                                        ? t('please_enter_email')
                                        : null,
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
                                validator: (value) =>
                                    value == null || value.length < 6
                                        ? t('please_enter_password')
                                        : null,
                              ),
                              const SizedBox(height: 24),

                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : SizedBox(
                                      width: double.maxFinite,
                                      child: ElevatedButton(
                                        onPressed: _submitForm,
                                        child: Text(_isLoginMode
                                            ? t('login')
                                            : t('register')),
                                      ),
                                    ),
                              const SizedBox(height: 16),

                              // Google Sign In Button (login mode only)
                              if (_isLoginMode) ...[
                                SizedBox(
                                  width: double.maxFinite,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _isLoading ? null : _loginWithGoogle,
                                    icon: Image.network(
                                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                      height: 20,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.g_mobiledata,
                                              size: 24),
                                    ),
                                    label: Text(t('google_login')),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 52),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      textStyle: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Mode Toggle
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoginMode = !_isLoginMode;
                                    _errorMessage = null;
                                  });
                                },
                                child: Text(
                                  _isLoginMode
                                      ? t('no_account')
                                      : t('has_account'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

