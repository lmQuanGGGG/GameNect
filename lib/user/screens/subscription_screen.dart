import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter_web_browser/flutter_web_browser.dart';
import '../../core/providers/subscription_provider.dart';


class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SubscriptionProvider(),
      child: const _SubscriptionScreenContent(),
    );
  }
}

class _SubscriptionScreenContent extends StatelessWidget {
  const _SubscriptionScreenContent();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.deepOrange.withValues(alpha: 0.3),
                  Colors.black,
                  Colors.black,
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Icon Premium
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber, Colors.orange.shade600],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 72,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.amber, Colors.orange.shade600],
                    ).createShader(bounds),
                    child: const Text(
                      'Nâng cấp Premium',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mở khóa tất cả tính năng độc quyền',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Features list
                  _buildFeature(
                    icon: Icons.all_inclusive,
                    title: 'Đăng khoảnh khắc không giới hạn',
                    subtitle: 'Chia sẻ thoải mái mỗi ngày',
                  ),
                  const SizedBox(height: 20),
                  _buildFeature(
                    icon: Icons.favorite_rounded,
                    title: 'Xem ai đã thích bạn',
                    subtitle: 'Không cần đợi match',
                  ),
                  const SizedBox(height: 20),
                  _buildFeature(
                    icon: Icons.undo_rounded,
                    title: 'Hoàn tác lượt vuốt',
                    subtitle: 'Sửa lại lỗi không mong muốn',
                  ),
                  /*const SizedBox(height: 20),
                  _buildFeature(
                    icon: Icons.visibility_off_rounded,
                    title: 'Duyệt ẩn danh',
                    subtitle: 'Chỉ người bạn thích mới thấy',
                  ),*/
                  const SizedBox(height: 20),
                  _buildFeature(
                    icon: Icons.star_rounded,
                    title: 'Super Like mỗi ngày',
                    subtitle: 'Tăng cơ hội match x3',
                  ),
                  const SizedBox(height: 40),

                  // Plan cards
                  _buildPlanCard(
                    context,
                    planType: 'yearly',
                    title: 'Gói 1 Năm',
                    price: '507.000đ',
                    pricePerMonth: '42.250đ/tháng',
                    badge: 'Tiết kiệm 50%',
                    isSelected: provider.selectedPlan == 'yearly',
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    context,
                    planType: 'monthly',
                    title: 'Gói 1 Tháng',
                    price: '84.500đ',
                    pricePerMonth: null,
                    badge: null,
                    isSelected: provider.selectedPlan == 'monthly',
                  ),
                  const SizedBox(height: 32),

                  // Subscribe button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: provider.isLoading || provider.selectedPlan == null
                          ? null
                          : () async {
                              try {
                                final paymentData = await provider.purchasePlan(provider.selectedPlan!);
                                if (paymentData == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Không thể tạo link thanh toán'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }

                                final checkoutUrl = paymentData['checkoutUrl'] as String;
                                final orderCode = paymentData['orderCode'] as int;

                                // Bắt đầu polling trong nền
                                bool completed = false;
                                Timer? timer;
                                timer = Timer.periodic(const Duration(seconds: 3), (t) async {
                                  final status = await provider.checkPaymentStatus(orderCode);
                                  if (status == 'success') {
                                    completed = true;
                                    t.cancel();
                                    final userId = FirebaseAuth.instance.currentUser?.uid;
                                    if (userId != null) {
                                      await provider.activatePremium(userId, provider.selectedPlan!, orderCode);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green),
                                      );
                                      // Có thể đóng màn hình đăng ký nếu muốn:
                                      Navigator.of(context).maybePop();
                                    }
                                  } else if (status == 'failed') {
                                    completed = true;
                                    t.cancel();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Thanh toán thất bại'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                });

                                // Mở Custom Tabs / SafariVC (await cho đến khi người dùng đóng)
                                await FlutterWebBrowser.openWebPage(
                                  url: checkoutUrl,
                                  customTabsOptions: const CustomTabsOptions(
                                    colorScheme: CustomTabsColorScheme.dark,
                                    shareState: CustomTabsShareState.off,
                                    showTitle: true,
                                    urlBarHidingEnabled: true,
                                  ),
                                  safariVCOptions: const SafariViewControllerOptions(
                                    barCollapsingEnabled: true,
                                    preferredBarTintColor: Colors.black,
                                    preferredControlTintColor: Colors.white,
                                    dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
                                  ),
                                );

                                // Người dùng đã đóng trình duyệt → kiểm tra lần cuối nếu chưa xong
                                if (!completed) {
                                  final status = await provider.checkPaymentStatus(orderCode);
                                  if (status == 'success') {
                                    final userId = FirebaseAuth.instance.currentUser?.uid;
                                    if (userId != null) {
                                      await provider.activatePremium(userId, provider.selectedPlan!, orderCode);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green),
                                      );
                                    }
                                  } else if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Chưa xác nhận thanh toán. Vui lòng chờ vài giây hoặc thử lại.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                }

                                timer.cancel();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: provider.selectedPlan == null
                            ? Colors.grey.shade700
                            : Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.deepOrange.withValues(alpha: 0.5),
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              provider.selectedPlan == null
                                  ? 'Chọn gói để tiếp tục'
                                  : 'Đăng ký ngay',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Restore button
                  TextButton(
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            try {
                              await provider.restorePurchase();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã khôi phục gói đăng ký'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    child: Text(
                      'Khôi phục gói đã mua',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Terms
                  Text(
                    'Bằng cách đăng ký, bạn đồng ý với Điều khoản dịch vụ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepOrange.withValues(alpha: 0.3), Colors.orange.withValues(alpha: 0.2)],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.deepOrange, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String planType,
    required String title,
    required String price,
    String? pricePerMonth,
    String? badge,
    required bool isSelected,
  }) {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);

    return GestureDetector(
      onTap: () => provider.selectPlan(planType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.deepOrange.withValues(alpha: 0.3),
                    Colors.orange.withValues(alpha: 0.2),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.deepOrange : Colors.grey.shade800,
            width: isSelected ? 3 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Radio
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.deepOrange : Colors.grey.shade600,
                  width: 2,
                ),
                color: isSelected ? Colors.deepOrange : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (pricePerMonth != null)
                    Text(
                      pricePerMonth,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),

            // Giá tiền + badge bên dưới
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber, Colors.orange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}