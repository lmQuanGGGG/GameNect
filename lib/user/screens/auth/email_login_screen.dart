import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../user_app.dart';
import 'dart:ui';
import 'dart:math' as math;

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late AnimationController _bgController;
  
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bgController.dispose();
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
      backgroundColor: const Color(0xFF0F0C29), // Khắc phục viền trắng ở dưới
      extendBodyBehindAppBar: true,
      extendBody: true, // Thêm để Gradient bao phủ cả thanh điều hướng dưới
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          
          // Background lơ lửng nhẹ
          ...List.generate(15, (index) {
            final random = math.Random(index);
            final size = random.nextDouble() * 60 + 20;
            final leftPercent = random.nextDouble();
            final topPercent = random.nextDouble();
            final durationOffset = random.nextDouble();

            return AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                final width = MediaQuery.of(context).size.width;
                final height = MediaQuery.of(context).size.height;
                final left = leftPercent * width;
                final top = topPercent * height;
                final progress = (_bgController.value + durationOffset) % 1.0;
                final yPos = top + (math.sin(progress * 2 * math.pi) * 30);
                
                return Positioned(
                  left: left,
                  top: yPos,
                  child: Opacity(
                    opacity: 0.05,
                    child: Icon(Icons.star_rounded, color: Colors.white, size: size),
                  ),
                );
              },
            );
          }),

          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Colors.teal, Colors.tealAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(CupertinoIcons.mail_solid, color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(height: 32),

                        Text(
                          _isSignUp ? 'Tạo Tài Khoản' : 'Email Đăng Nhập',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isSignUp ? 'Điền thông tin để tạo tài khoản' : 'Nhập email và mật khẩu để tiếp tục',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 48),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _emailController,
                                labelText: 'Email',
                                hintText: 'example@email.com',
                                icon: CupertinoIcons.mail,
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _passwordController,
                                labelText: 'Mật khẩu',
                                hintText: 'Nhập mật khẩu',
                                icon: CupertinoIcons.lock_fill,
                                obscureText: _obscurePassword,
                                onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                                validator: _validatePassword,
                              ),
                              if (_isSignUp) ...[
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  labelText: 'Xác nhận mật khẩu',
                                  hintText: 'Nhập lại mật khẩu',
                                  icon: CupertinoIcons.lock_fill,
                                  obscureText: _obscureConfirmPassword,
                                  onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  validator: _validateConfirmPassword,
                                ),
                              ],
                              const SizedBox(height: 32),
                              
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Colors.teal, Colors.tealAccent]),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.teal.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(28),
                                    onTap: authProvider.isLoading ? null : _handleSubmit,
                                    child: Center(
                                      child: authProvider.isLoading
                                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Text(
                                              _isSignUp ? 'ĐĂNG KÝ' : 'ĐĂNG NHẬP',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp ? 'Đã có tài khoản?' : 'Chưa có tài khoản?',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                            ),
                            TextButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isSignUp = !_isSignUp;
                                        _formKey.currentState?.reset();
                                      });
                                    },
                              style: TextButton.styleFrom(foregroundColor: Colors.tealAccent),
                              child: Text(
                                _isSignUp ? 'Đăng nhập' : 'Đăng ký',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),

                        if (authProvider.error != null && !authProvider.isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              authProvider.error!,
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(obscureText ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill, color: Colors.white.withValues(alpha: 0.7)),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: validator,
    );
  }
}
