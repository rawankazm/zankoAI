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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontFamily: 'Noto Sans Arabic',
                    ),
                  ),
                  Text(
                    _isLoginMode ? t('slogan') : t('register'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontFamily: 'Noto Sans Arabic',
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
                          fontFamily: 'Noto Sans Arabic',
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
                                  hintText: 'example@zanko.edu',
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
                                          fontFamily: 'Noto Sans Arabic',
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
                                      fontFamily: 'Noto Sans Arabic',
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

/// ─── Role Selection Section ───────────────────────────────────────────────────
class _RoleSelectionSection extends StatelessWidget {
  final UserRole selectedRole;
  final bool roleSelected;
  final void Function(UserRole) onRoleSelected;
  final String Function(String) t;
  final ThemeData theme;

  const _RoleSelectionSection({
    required this.selectedRole,
    required this.roleSelected,
    required this.onRoleSelected,
    required this.t,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('select_role'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            fontFamily: 'Noto Sans Arabic',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t('select_role_desc'),
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withOpacity(0.55),
            fontFamily: 'Noto Sans Arabic',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _RoleCard(
                role: UserRole.student,
                icon: Icons.school_rounded,
                label: t('student'),
                description: t('role_student_desc'),
                isSelected: roleSelected && selectedRole == UserRole.student,
                primaryColor: const Color(0xFF2196F3),
                onTap: () => onRoleSelected(UserRole.student),
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleCard(
                role: UserRole.teacher,
                icon: Icons.cast_for_education_rounded,
                label: t('teacher'),
                description: t('role_teacher_desc'),
                isSelected: roleSelected && selectedRole == UserRole.teacher,
                primaryColor: const Color(0xFF7C3AED),
                onTap: () => onRoleSelected(UserRole.teacher),
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;
  final ThemeData theme;

  const _RoleCard({
    required this.role,
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.15),
                    primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : theme.colorScheme.surface,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? primaryColor.withOpacity(0.18)
                    : theme.colorScheme.surfaceVariant,
              ),
              child: Icon(
                icon,
                size: 32,
                color: isSelected
                    ? primaryColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? primaryColor
                    : theme.colorScheme.onSurface,
                fontFamily: 'Noto Sans Arabic',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                fontFamily: 'Noto Sans Arabic',
                height: 1.4,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 10),
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
