import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

enum AuthView { login, signup }

/// Sign-in and registration.
///
/// Presented as a masthead over a form rather than a centred hero: the point
/// of the screen is to state which body operates the service before asking for
/// credentials, the way a government portal does.
class AuthScreen extends StatefulWidget {
  final AuthView initialView;

  const AuthScreen({super.key, this.initialView = AuthView.login});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late bool _isLogin = widget.initialView == AuthView.login;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _toggleAuthView() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final appProvider = context.read<AppProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_isLogin) {
        await appProvider.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await appProvider.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _usernameController.text.trim(),
        );
      }
      if (mounted) navigator.pushReplacementNamed('/home');
    } on AppAuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final appProvider = context.read<AppProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await appProvider.signInWithGoogle();
      if (mounted) navigator.pushReplacementNamed('/home');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Masthead(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ModeToggle(
                        isLogin: _isLogin,
                        enabled: !_isLoading,
                        onChanged: (login) {
                          if (login != _isLogin) _toggleAuthView();
                        },
                      ),
                      const SizedBox(height: 22),

                      if (!_isLogin) ...[
                        _Field(
                          label: 'Username',
                          controller: _usernameController,
                          icon: Icons.badge_outlined,
                          hint: 'How you will appear on complaints',
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return 'Choose a username';
                            if (v.length < 3) {
                              return 'Use at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      _Field(
                        label: 'Email',
                        controller: _emailController,
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Enter your email';
                          final pattern = RegExp(
                            r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$',
                          );
                          if (!pattern.hasMatch(v)) {
                            return 'That does not look like an email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _Field(
                        label: 'Password',
                        controller: _passwordController,
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 19,
                            color: AppColors.slate600,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (value) {
                          final v = value ?? '';
                          if (v.isEmpty) return 'Enter your password';
                          if (!_isLogin && v.length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isLogin ? 'Sign in' : 'Create account'),
                      ),

                      const SizedBox(height: 18),
                      const _OrRule(),
                      const SizedBox(height: 18),

                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.account_circle_outlined, size: 19),
                        label: const Text('Continue with Google'),
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : _toggleAuthView,
                          child: Text(
                            _isLogin
                                ? 'No account? Register to report issues'
                                : 'Already registered? Sign in',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The navy header block: who runs this, and what it is for.
class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy900,
      padding: const EdgeInsets.fromLTRB(20, 68, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.navy200),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'MUNICIPAL SERVICES',
              style: AppTypography.badge(color: AppColors.navy200),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Civic Connect',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Report a civic issue, track it to resolution, and see what '
            'your neighbours have already raised.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.navy200),
          ),
        ],
      ),
    );
  }
}

/// Sign in / Register, as one control rather than a hidden mode.
class _ModeToggle extends StatelessWidget {
  final bool isLogin;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({
    required this.isLogin,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTab(
              label: 'Sign in',
              selected: isLogin,
              onTap: enabled ? () => onChanged(true) : null,
            ),
          ),
          Expanded(
            child: _ModeTab(
              label: 'Register',
              selected: !isLogin,
              onTap: enabled ? () => onChanged(false) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        color: selected ? AppColors.navy900 : Colors.transparent,
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: selected ? Colors.white : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?) validator;

  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    required this.validator,
    this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.sectionLabel()),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 19, color: AppColors.slate600),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class _OrRule extends StatelessWidget {
  const _OrRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR', style: AppTypography.sectionLabel()),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
