import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/theme/theme_helper.dart';

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

    if (provider.plans.isEmpty) {
      provider.fetchPlans();
    }

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            child: Icon(Icons.close, color: context.textColor, size: 20),
          ),
        ),
        title: Text(
          'Nâng cấp Premium',
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Hero badge ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.textColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.textColor, width: 2.5),
                boxShadow: [BoxShadow(color: const Color(0xFFFF6E40), offset: const Offset(7, 7))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6E40),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.scaffoldBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'GameNect Premium',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: context.scaffoldBackgroundColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mở khóa tất cả tính năng độc quyền',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.scaffoldBackgroundColor.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Section label ─────────────────────────────────
            _sectionLabel('Tính năng bao gồm', context),
            const SizedBox(height: 14),

            // ── Features ──────────────────────────────────────
            _buildFeature(context,
              icon: Icons.all_inclusive_rounded,
              title: 'Đăng khoảnh khắc không giới hạn',
              subtitle: 'Chia sẻ thoải mái mỗi ngày',
            ),
            const SizedBox(height: 10),
            _buildFeature(context,
              icon: Icons.favorite_rounded,
              title: 'Xem ai đã thích bạn',
              subtitle: 'Không cần đợi match',
            ),
            const SizedBox(height: 10),
            _buildFeature(context,
              icon: Icons.undo_rounded,
              title: 'Hoàn tác lượt vuốt',
              subtitle: 'Sửa lại lỗi không mong muốn',
            ),
            const SizedBox(height: 10),
            _buildFeature(context,
              icon: Icons.star_rounded,
              title: 'Super Like mỗi ngày',
              subtitle: 'Tăng cơ hội match x3',
            ),

            const SizedBox(height: 28),
            _sectionLabel('Chọn gói đăng ký', context),
            const SizedBox(height: 14),

            // ── Plans ─────────────────────────────────────────
            if (provider.plans.isNotEmpty) ...[
              for (var plan in provider.plans)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPlanCard(
                    context,
                    provider: provider,
                    planType: plan['planType'],
                    title: plan['title'],
                    price: plan['priceText'],
                    pricePerMonth: plan['pricePerMonth'],
                    badge: plan['badge'],
                    isSelected: provider.selectedPlan == plan['planType'],
                  ),
                ),
            ] else ...[
              _buildPlanCard(context,
                provider: provider,
                planType: 'yearly',
                title: 'Gói 1 Năm',
                price: '507.000đ',
                pricePerMonth: '42.250đ/tháng',
                badge: 'Tiết kiệm 50%',
                isSelected: provider.selectedPlan == 'yearly',
              ),
              const SizedBox(height: 12),
              _buildPlanCard(context,
                provider: provider,
                planType: 'monthly',
                title: 'Gói 1 Tháng',
                price: '84.500đ',
                pricePerMonth: null,
                badge: null,
                isSelected: provider.selectedPlan == 'monthly',
              ),
            ],

            const SizedBox(height: 24),

            // ── Subscribe button ──────────────────────────────
            GestureDetector(
              onTap: provider.isLoading || provider.selectedPlan == null
                  ? null
                  : () async {
                      try {
                        final paymentData = await provider.purchasePlan(provider.selectedPlan!);
                        if (paymentData == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Không thể tạo link thanh toán'), backgroundColor: Colors.red),
                            );
                          }
                          return;
                        }

                        final checkoutUrl = paymentData['checkoutUrl'] as String;
                        final orderCode = paymentData['orderCode'] as int;

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

                        final uri = Uri.parse(checkoutUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Không thể mở trình duyệt. Vui lòng thử lại!'), backgroundColor: Colors.red),
                            );
                          }
                        }

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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: provider.selectedPlan == null ? context.dialogBgColor : context.textColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.textColor, width: 2.5),
                  boxShadow: provider.selectedPlan == null
                      ? []
                      : [BoxShadow(color: const Color(0xFFFF6E40), offset: const Offset(6, 6))],
                ),
                child: Center(
                  child: provider.isLoading
                      ? SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            color: context.scaffoldBackgroundColor,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          provider.selectedPlan == null ? 'Chọn gói để tiếp tục' : 'Đăng ký ngay',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: provider.selectedPlan == null
                                ? context.textSecondaryColor
                                : context.scaffoldBackgroundColor,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Bằng cách đăng ký, bạn đồng ý với Điều khoản dịch vụ',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textTertiaryColor, fontSize: 12),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: const Color(0xFFFF6E40)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.textColor),
        ),
      ],
    );
  }

  Widget _buildFeature(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.dialogBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.textColor, width: 2.5),
        boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6E40),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.textColor, width: 2),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: context.textColor, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: context.textSecondaryColor, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFFFF6E40), size: 20),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required SubscriptionProvider provider,
    required String planType,
    required String title,
    required String price,
    String? pricePerMonth,
    String? badge,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => provider.selectPlan(planType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? context.textColor : context.dialogBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.textColor, width: 2.5),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFFF6E40), offset: const Offset(6, 6))]
              : [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
        ),
        child: Row(
          children: [
            // Checkbox Neo
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF6E40) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF6E40) : context.textSecondaryColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? context.scaffoldBackgroundColor : context.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (pricePerMonth != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      pricePerMonth,
                      style: TextStyle(
                        color: isSelected
                            ? context.scaffoldBackgroundColor.withValues(alpha: 0.65)
                            : context.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    color: isSelected ? context.scaffoldBackgroundColor : context.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6E40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? context.scaffoldBackgroundColor : context.textColor,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}