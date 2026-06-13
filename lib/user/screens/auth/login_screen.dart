import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/theme_helper.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                // 1. Đổi căn lề sang center
                crossAxisAlignment: CrossAxisAlignment.center, 
                children: [
                  // 2. Ép Column chiếm full chiều ngang màn hình
                  const SizedBox(width: double.infinity, height: 16),

                  // ── Logo ────────────────────────────────────────
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6E40),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.textColor, width: 2.5),
                      boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(5, 5))],
                    ),
                    child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 28),

                  // ── Title ────────────────────────────────────────
                  Text(
                    'GameNect',
                    textAlign: TextAlign.center, // 3. Căn giữa chữ
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: context.textColor,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đăng nhập để bắt đầu hành trình gaming',
                    textAlign: TextAlign.center, // 3. Căn giữa chữ
                    style: TextStyle(fontSize: 15, color: context.textSecondaryColor),
                  ),

                  const SizedBox(height: 48),

                  // ── Buttons ──────────────────────────────────────
                  _buildLoginButton(
                    context: context,
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            final success = await authProvider.signInWithGoogle();
                            if (!context.mounted) return;
                            if (success) {
                              Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Đăng nhập thất bại: ${authProvider.error}'), backgroundColor: Colors.red),
                              );
                            }
                          },
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 22, height: 22,
                      errorBuilder: (_, __, ___) => Icon(Icons.login, color: context.textColor, size: 22),
                    ),
                    label: 'Tiếp tục với Google',
                    filled: false,
                  ),
                  const SizedBox(height: 14),

                  _buildLoginButton(
                    context: context,
                    onPressed: authProvider.isLoading
                        ? null
                        : () => Navigator.pushNamed(context, '/phone-login'),
                    icon: const Icon(CupertinoIcons.phone_fill, color: Colors.white, size: 22),
                    label: 'Tiếp tục với số điện thoại',
                    filled: true,
                  ),
                  const SizedBox(height: 14),

                  _buildLoginButton(
                    context: context,
                    onPressed: authProvider.isLoading
                        ? null
                        : () => Navigator.pushNamed(context, '/email-login'),
                    icon: Icon(CupertinoIcons.mail_solid, color: context.textColor, size: 22),
                    label: 'Tiếp tục với Email',
                    filled: false,
                  ),

                  if (authProvider.isLoading) ...[
                    const SizedBox(height: 28),
                    Center(child: CircularProgressIndicator(color: const Color(0xFFFF6E40), strokeWidth: 2.5)),
                  ],

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

                  const SizedBox(height: 40),

                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiaryColor,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Bằng việc đăng nhập, bạn đồng ý với\n'),
                          TextSpan(
                            text: 'Điều khoản sử dụng',
                            style: const TextStyle(
                              color: Color(0xFFFF6E40),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                final url = Uri.parse(
                                  kIsWeb
                                      ? '${Uri.base.scheme}://${Uri.base.authority}/terms.html'
                                      : 'https://gamenect-9bec0.web.app/terms.html',
                                );
                                try {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                } catch (_) {}
                              },
                          ),
                          const TextSpan(text: ' và '),
                          TextSpan(
                            text: 'Chính sách bảo mật',
                            style: const TextStyle(
                              color: Color(0xFFFF6E40),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                final url = Uri.parse(
                                  kIsWeb
                                      ? '${Uri.base.scheme}://${Uri.base.authority}/privacy.html'
                                      : 'https://gamenect-9bec0.web.app/privacy.html',
                                );
                                try {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                } catch (_) {}
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: filled ? context.textColor : context.dialogBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.textColor, width: 2.5),
          boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(5, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: filled ? context.scaffoldBackgroundColor : context.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
