import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../user_app.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 0,
        title: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12.0),
              child: Icon(
                CupertinoIcons.game_controller_solid,
                color: Colors.deepOrange,
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'gamenect',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo và tiêu đề
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.game_controller_solid,
                        size: 60,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Chào mừng đến với',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'GameNect',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kết nối game thủ trên toàn quốc',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Nút đăng nhập Google
                    _buildLoginButton(
                      context: context,
                      onPressed: authProvider.isLoading
                          ? null
                          : () async {
                              final success = await authProvider.signInWithGoogle();
                              if (!context.mounted) return;

                              if (success) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const UserApp()),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đăng nhập thất bại: ${authProvider.error}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      icon: Image.asset(
                        'assets/images/google_logo.png', // Thêm logo Google vào assets
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.login, color: Colors.white);
                        },
                      ),
                      label: 'Tiếp tục với Google',
                      backgroundColor: Colors.white,
                      textColor: Colors.black87,
                      borderColor: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),

                    // Nút đăng nhập Facebook
                    _buildLoginButton(
                      context: context,
                      onPressed: authProvider.isLoading
                          ? null
                          : () async {
                              final success = await authProvider.signInWithFacebook();
                              if (!context.mounted) return;

                              if (success) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const UserApp()),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đăng nhập thất bại: ${authProvider.error}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.facebook, color: Colors.white, size: 24),
                      label: 'Tiếp tục với Facebook',
                      backgroundColor: const Color(0xFF1877F2),
                      textColor: Colors.white,
                    ),
                    const SizedBox(height: 16),

                    // Nút đăng nhập số điện thoại
                    _buildLoginButton(
                      context: context,
                      onPressed: authProvider.isLoading
                          ? null
                          : () {
                              Navigator.pushNamed(context, '/phone-login');
                            },
                      icon: const Icon(CupertinoIcons.phone_fill, color: Colors.white, size: 24),
                      label: 'Tiếp tục với số điện thoại',
                      backgroundColor: Colors.deepOrange,
                      textColor: Colors.white,
                    ),

                    const SizedBox(height: 32),

                    // Loading indicator
                    if (authProvider.isLoading)
                      const CircularProgressIndicator(
                        color: Colors.deepOrange,
                      ),

                    // Hiển thị lỗi
                    if (authProvider.error != null && !authProvider.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          authProvider.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Terms and Privacy
                    Text(
                      'Bằng việc đăng nhập, bạn đồng ý với\nĐiều khoản sử dụng và Chính sách bảo mật',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: borderColor != null
                ? BorderSide(color: borderColor, width: 1)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
