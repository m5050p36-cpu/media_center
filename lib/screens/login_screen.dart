import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                  const Text('Media Center',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  const Text('استمع، شاهد، واستمتع في مكان واحد',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.sub, fontSize: 14)),
                  const SizedBox(height: 40),

                  // التبويبات
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _tabBtn('تسجيل الدخول', !_isSignUp,
                            () => setState(() => _isSignUp = false)),
                        _tabBtn('حساب جديد', _isSignUp,
                            () => setState(() => _isSignUp = true)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // الحقول
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _isSignUp
                        ? Column(
                            children: [
                              _inputField(
                                controller: _name,
                                label: 'الاسم الكامل',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 14),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  _inputField(
                    controller: _email,
                    label: 'البريد الإلكتروني',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _inputField(
                    controller: _password,
                    label: 'كلمة المرور',
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

                  // زر الإجراء
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
                              _isSignUp ? 'إنشاء الحساب' : 'تسجيل الدخول',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (!_isSignUp)
                    TextButton(
                      onPressed: auth.loading ? null : _forgotPassword,
                      child: const Text('نسيت كلمة المرور؟',
                          style: TextStyle(color: AppTheme.sub)),
                    ),

                  const SizedBox(height: 24),

                  // الفاصل
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppTheme.sub.withValues(alpha: 0.3),
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('أو',
                            style: TextStyle(
                                color: AppTheme.sub.withValues(alpha: 0.8))),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppTheme.sub.withValues(alpha: 0.3),
                          height: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // زر الزائر
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: auth.loading
                          ? null
                          : () {
                              context
                                  .read<AuthProvider>()
                                  .continueAsGuest();
                              _goHome();
                            },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('المتابعة كزائر',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.text,
                        side: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.sub.withValues(alpha: 0.7),
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
              color: active ? Colors.white : AppTheme.sub,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
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
        filled: true,
        fillColor: AppTheme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppTheme.sub.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final a = context.read<AuthProvider>();

    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _snack('يرجى إدخال البريد وكلمة المرور');
      return;
    }
    if (_isSignUp && _name.text.trim().isEmpty) {
      _snack('يرجى إدخال الاسم الكامل');
      return;
    }
    if (_password.text.length < 6) {
      _snack('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
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
        _snack('تم إنشاء الحساب، تحقق من بريدك للتأكيد', success: true);
      }
      _goHome();
    } else if (a.error != null) {
      _snack(a.error!);
    }
  }

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty) {
      _snack('أدخل بريدك أولاً');
      return;
    }
    final ok =
        await context.read<AuthProvider>().resetPassword(_email.text.trim());
    if (!mounted) return;
    _snack(ok ? 'تم إرسال رابط الاستعادة إلى بريدك' : 'فشل الإرسال',
        success: ok);
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}
