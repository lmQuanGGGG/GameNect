import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/theme_helper.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập email';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Email không hợp lệ';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_isSignUp) {
      if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu';
      if (value != _passwordController.text) return 'Mật khẩu không khớp';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success;

    if (_isSignUp) {
      success = await authProvider.signUpWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await authProvider.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSignUp ? 'Đăng ký thất bại: ${authProvider.error}' : 'Đăng nhập thất bại: ${authProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.dialogBgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.textColor, width: 2.5),
              boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(3, 3))],
            ),
            child: Icon(Icons.arrow_back, color: context.textColor, size: 20),
          ),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Centered header ──────────────────
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6E40),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.textColor, width: 2.5),
                            boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(6, 6))],
                          ),
                          child: const Icon(CupertinoIcons.mail_solid, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _isSignUp ? 'Tạo Tài Khoản' : 'Đăng nhập Email',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: context.textColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSignUp ? 'Điền thông tin để tạo tài khoản' : 'Nhập email và mật khẩu để tiếp tục',
                          style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Form fields ───────────────────────────────
                  _buildTextField(
                    context: context,
                    controller: _emailController,
                    label: 'Email',
                    hint: 'example@email.com',
                    icon: CupertinoIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    context: context,
                    controller: _passwordController,
                    label: 'Mật khẩu',
                    hint: 'Nhập mật khẩu',
                    icon: CupertinoIcons.lock_fill,
                    obscureText: _obscurePassword,
                    onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                    validator: _validatePassword,
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 14),
                    _buildTextField(
                      context: context,
                      controller: _confirmPasswordController,
                      label: 'Xác nhận mật khẩu',
                      hint: 'Nhập lại mật khẩu',
                      icon: CupertinoIcons.lock_fill,
                      obscureText: _obscureConfirmPassword,
                      onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      validator: _validateConfirmPassword,
                    ),
                  ],
                  const SizedBox(height: 28),

                  // ── Submit button ─────────────────────────────
                  GestureDetector(
                    onTap: authProvider.isLoading ? null : _handleSubmit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: context.textColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.textColor, width: 2.5),
                        boxShadow: [BoxShadow(color: const Color(0xFFFF6E40), offset: const Offset(6, 6))],
                      ),
                      child: Center(
                        child: authProvider.isLoading
                            ? SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(color: context.scaffoldBackgroundColor, strokeWidth: 2.5),
                              )
                            : Text(
                                _isSignUp ? 'ĐĂNG KÝ' : 'ĐĂNG NHẬP',
                                style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900,
                                  color: context.scaffoldBackgroundColor,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Toggle login/signup ───────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignUp ? 'Đã có tài khoản?' : 'Chưa có tài khoản?',
                        style: TextStyle(color: context.textSecondaryColor, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: authProvider.isLoading
                            ? null
                            : () => setState(() {
                                  _isSignUp = !_isSignUp;
                                  _formKey.currentState?.reset();
                                }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6E40),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: context.textColor, width: 1.5),
                          ),
                          child: Text(
                            _isSignUp ? 'Đăng nhập' : 'Đăng ký',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (authProvider.error != null && !authProvider.isLoading) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Text(authProvider.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textColor)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: context.dialogBgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.textColor, width: 2.5),
            boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: context.textTertiaryColor),
              prefixIcon: Icon(icon, color: context.textSecondaryColor, size: 20),
              suffixIcon: onToggleObscure != null
                  ? IconButton(
                      icon: Icon(
                        obscureText ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                        color: context.textSecondaryColor, size: 18,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              errorStyle: const TextStyle(color: Colors.red),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}
