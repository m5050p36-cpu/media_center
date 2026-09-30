import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/i18n.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _isSignUp = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final t = I18n.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.3),
                            AppTheme.primary.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: const Icon(Icons.play_circle_fill,
                          size: 80, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(t.get('app_name'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text(t.get('welcome'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _tabBtn(t.get('login'), !_isSignUp,
                            () => setState(() => _isSignUp = false)),
                        _tabBtn(t.get('signup'), _isSignUp,
                            () => setState(() => _isSignUp = true)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _isSignUp
                        ? Column(
                            children: [
                              _input(
                                controller: _name,
                                label: t.get('full_name'),
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 14),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  _input(
                    controller: _email,
                    label: t.get('email'),
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _input(
                    controller: _password,
                    label: t.get('password'),
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: auth.loading ? null : _submit,
                      child: auth.loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(
                              _isSignUp
                                  ? t.get('signup')
                                  : t.get('login'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  if (!_isSignUp)
                    TextButton(
                      onPressed: auth.loading ? null : _forgotPassword,
                      child: Text(t.get('forgot_password')),
                    ),

                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('—'),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 20),

                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: auth.loading
                          ? null
                          : () {
                              context.read<AuthProvider>().continueAsGuest();
                              _goHome();
                            },
                      icon: const Icon(Icons.person_outline),
                      label: Text(t.get('continue_guest'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.5),
                            width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
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

  Widget _tabBtn(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : null,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary),
        suffixIcon: suffix,
      ),
    );
  }

  Future<void> _submit() async {
    final a = context.read<AuthProvider>();
    final t = I18n.of(context);

    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _snack(t.get('error'), 'يرجى إدخال البريد وكلمة المرور');
      return;
    }
    if (_isSignUp && _name.text.trim().isEmpty) {
      _snack(t.get('error'), 'يرجى إدخال الاسم الكامل');
      return;
    }
    if (_password.text.length < 6) {
      _snack(t.get('error'), 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    bool ok;
    if (_isSignUp) {
      ok = await a.signUpWithEmail(
          _email.text.trim(), _password.text, _name.text.trim());
    } else {
      ok = await a.signInWithEmail(_email.text.trim(), _password.text);
    }

    if (!mounted) return;
    if (ok) {
      if (_isSignUp) {
        _snack(t.get('success'), t.get('email_confirm_note'));
      }
      _goHome();
    } else if (a.error != null) {
      _snack(t.get('error'), a.error!);
    }
  }

  Future<void> _forgotPassword() async {
    final t = I18n.of(context);
    if (_email.text.trim().isEmpty) {
      _snack(t.get('error'), 'أدخل بريدك أولاً');
      return;
    }
    final ok =
        await context.read<AuthProvider>().resetPassword(_email.text.trim());
    if (!mounted) return;
    _snack(
      ok ? t.get('success') : t.get('error'),
      ok ? 'تم إرسال رابط الاستعادة إلى بريدك' : 'فشل الإرسال',
      success: ok,
    );
  }

  void _snack(String title, String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}
