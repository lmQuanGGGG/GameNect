// lib/user/screens/camera/camera_dialogs.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../premium/subscription_screen.dart';

const _kNeoAccent = Color(0xFFFF6E40);
const _kNeoYellow = Color(0xFFFFD54F);

/// Mixin chứa tất cả các dialog của màn hình camera theo chuẩn Neo-Brutalism
mixin CameraDialogsMixin<T extends StatefulWidget> on State<T> {
  
  Future<void> showCameraPremiumUpsellDialog() async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 3),
        ),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: _kNeoAccent, offset: const Offset(6, 6))],
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kNeoYellow,
                  border: Border.all(color: Colors.black, width: 3),
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'NÂNG CẤP PREMIUM',
                style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'BẠN ĐÃ ĐĂNG ĐỦ 20 KHOẢNH KHẮC TRONG THÁNG NÀY!',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.bold, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Nâng cấp ngay để đăng không giới hạn!',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black : Colors.white,
                          border: Border.all(color: borderColor, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: borderColor, offset: const Offset(2, 2))],
                        ),
                        alignment: Alignment.center,
                        child: Text('ĐỂ SAU', style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _kNeoAccent,
                          border: Border.all(color: borderColor, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: borderColor, offset: const Offset(4, 4))],
                        ),
                        alignment: Alignment.center,
                        child: const Text('NÂNG CẤP NGAY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> showCameraCaptionDialog() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: bgColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 3),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: _kNeoAccent, offset: const Offset(6, 6))],
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THÊM CHÚ THÍCH',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : const Color(0xFFF4F4F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: [BoxShadow(color: borderColor, offset: const Offset(3, 3))],
                ),
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Bạn đang nghĩ gì?',
                    hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 14, fontWeight: FontWeight.w600),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  autofocus: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        border: Border.all(color: borderColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('HỦY', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, controller.text.trim()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: _kNeoAccent,
                        border: Border.all(color: borderColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: borderColor, offset: const Offset(3, 3))],
                      ),
                      child: const Text('ĐĂNG', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> showCameraMediaChoiceDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 3),
        ),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: _kNeoAccent, offset: const Offset(6, 6))],
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('CHỌN LOẠI FILE', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'image'),
                icon: const Icon(CupertinoIcons.photo, color: Colors.black),
                label: const Text('TẢI ẢNH LÊN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black, width: 2)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'video'),
                icon: const Icon(CupertinoIcons.videocam_fill, color: Colors.black),
                label: const Text('TẢI VIDEO (≤ 15S)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNeoYellow,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black, width: 2)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}