import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../user_app.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập GameNect')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isLoading) {
                return const CircularProgressIndicator();
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ===== GOOGLE LOGIN =====
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập bằng Google'),
                      onPressed: () async {
                        final success = await authProvider.signInWithGoogle();
                        if (!context.mounted) return;

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đăng nhập Google thành công')),
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const UserApp()),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đăng nhập Google thất bại: ${authProvider.error}')),
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
                        final success = await authProvider.signInWithFacebook();
                        if (!context.mounted) return;

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đăng nhập Facebook thành công')),
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const UserApp()),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đăng nhập Facebook thất bại: ${authProvider.error}')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // ===== PHONE LOGIN =====
                    ElevatedButton.icon(
                      icon: const Icon(Icons.phone),
                      label: const Text('Đăng nhập bằng số điện thoại'),
                      onPressed: () {
                        Navigator.pushNamed(context, '/phone-login');
                      },
                    ),
                    const SizedBox(height: 32),

                    // ===== LOGOUT =====
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        await authProvider.signOut();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Đã đăng xuất")),
                        );
                      },
                      child: const Text("Đăng xuất"),
                    ),

                    if (authProvider.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          authProvider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
