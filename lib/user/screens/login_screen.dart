import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../user_app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập GameNect')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ===== GOOGLE LOGIN =====
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Đăng nhập bằng Google'),
                  onPressed: () async {
                    try {
                      await authService.signInWithGoogle();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đăng nhập Google thành công'),
                        ),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const UserApp()),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đăng nhập Google thất bại: $e')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // ===== FACEBOOK LOGIN =====
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Đăng nhập bằng Facebook'),
                  onPressed: () async {
                    try {
                      await authService.signInWithFacebook();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đăng nhập Facebook thành công'),
                        ),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const UserApp()),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đăng nhập Facebook thất bại: $e')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 32),

                

                // ===== LOGOUT =====
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () async {
                    await authService.signOut();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Đã đăng xuất")),
                    );
                  },
                  child: const Text("Đăng xuất"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
