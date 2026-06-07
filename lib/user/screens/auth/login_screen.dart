import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../user_app.dart';
import 'dart:ui';
import 'dart:math' as math;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;

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
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Tĩnh
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
                    child: Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: size,
                    ),
                  ),
                );
              },
            );
          }),

          // Kính mờ
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Colors.orange, Colors.deepOrangeAccent, Colors.pinkAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.sports_esports_rounded,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'GameNect',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color: Colors.deepOrange,
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ]
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Đăng nhập để bắt đầu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Form đăng nhập (Glassmorphism card)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              )
                            ]
                          ),
                          child: Column(
                            children: [
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
                                  'assets/images/google_logo.png',
                                  width: 24,
                                  height: 24,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.login, color: Colors.black87);
                                  },
                                ),
                                label: 'Tiếp tục với Google',
                                backgroundColor: Colors.white,
                                textColor: Colors.black87,
                              ),
                              const SizedBox(height: 16),
                              _buildLoginButton(
                                context: context,
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () {
                                        Navigator.pushNamed(context, '/phone-login');
                                      },
                                icon: const Icon(CupertinoIcons.phone_fill, color: Colors.white, size: 24),
                                label: 'Tiếp tục với số điện thoại',
                                backgroundColor: Colors.orange,
                                textColor: Colors.white,
                                isGradient: true,
                                gradientColors: [Colors.orange, Colors.deepOrange],
                              ),
                              const SizedBox(height: 16),
                              _buildLoginButton(
                                context: context,
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () {
                                        Navigator.pushNamed(context, '/email-login');
                                      },
                                icon: const Icon(CupertinoIcons.mail_solid, color: Colors.white, size: 24),
                                label: 'Tiếp tục với Email',
                                backgroundColor: Colors.transparent,
                                textColor: Colors.white,
                                borderColor: Colors.white.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        if (authProvider.isLoading)
                          const CircularProgressIndicator(color: Colors.orange),

                        if (authProvider.error != null && !authProvider.isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              authProvider.error!,
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 24),

                        Text(
                          'Bằng việc đăng nhập, bạn đồng ý với\nĐiều khoản sử dụng và Chính sách bảo mật',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
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
    bool isGradient = false,
    List<Color>? gradientColors,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: !isGradient ? backgroundColor : null,
        gradient: isGradient ? LinearGradient(colors: gradientColors!) : null,
        borderRadius: BorderRadius.circular(28),
        border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
        boxShadow: isGradient ? [
          BoxShadow(
            color: gradientColors!.last.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
