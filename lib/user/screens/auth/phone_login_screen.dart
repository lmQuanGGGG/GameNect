import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../../core/providers/auth_provider.dart';
import 'dart:ui';
import 'dart:math' as math;

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'VN');
  Timer? _timer;
  int _timeLeft = 60;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  void startTimer() {
    _timeLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _bgController.dispose();
    super.dispose();
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
            child: Consumer<AuthProvider>(
              builder: (context, auth, child) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Colors.orange, Colors.deepOrangeAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(CupertinoIcons.phone_fill, color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Số Điện Thoại',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chúng tôi sẽ gửi mã OTP đến số điện thoại của bạn',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
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
                              if (!auth.isVerifying) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: InternationalPhoneNumberInput(
                                    onInputChanged: (PhoneNumber number) {
                                      _phoneNumber = number;
                                    },
                                    selectorConfig: const SelectorConfig(
                                      selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                                      setSelectorButtonAsPrefixIcon: true,
                                    ),
                                    ignoreBlank: false,
                                    autoValidateMode: AutovalidateMode.onUserInteraction,
                                    selectorTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
                                    textStyle: const TextStyle(color: Colors.white, fontSize: 16),
                                    initialValue: _phoneNumber,
                                    formatInput: true,
                                    keyboardType: TextInputType.phone, // Gọi bàn phím số chuẩn
                                    inputDecoration: InputDecoration(
                                      hintText: 'Số điện thoại',
                                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                                      border: InputBorder.none,
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () async {
                                          if (_formKey.currentState?.validate() ?? false) {
                                            final success = await auth.sendOTP(_phoneNumber.phoneNumber ?? '');
                                            if (success && mounted) {
                                              startTimer();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Đã gửi mã OTP'), backgroundColor: Colors.green),
                                              );
                                              auth.setVerifying(true);
                                            }
                                          }
                                        },
                                  label: 'Gửi mã OTP',
                                  isLoading: auth.isLoading,
                                ),
                              ] else ...[
                                TextFormField(
                                  controller: _otpController,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: '------',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                    filled: true,
                                    fillColor: Colors.black.withValues(alpha: 0.2),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Vui lòng nhập mã OTP';
                                    if (value!.length != 6) return 'Mã OTP phải có 6 số';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Mã OTP có hiệu lực trong $_timeLeft giây',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: _timeLeft == 0
                                            ? () async {
                                                if (_formKey.currentState?.validate() ?? false) {
                                                  final success = await auth.sendOTP(_phoneNumber.phoneNumber ?? '');
                                                  if (success && mounted) {
                                                    startTimer();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Đã gửi lại mã OTP'), backgroundColor: Colors.green),
                                                    );
                                                  }
                                                }
                                              }
                                            : null,
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                        ),
                                        child: Text(
                                          _timeLeft > 0 ? 'Gửi lại sau ${_timeLeft}s' : 'Gửi lại mã',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildButton(
                                        onPressed: auth.isLoading
                                            ? null
                                            : () async {
                                                if (_formKey.currentState?.validate() ?? false) {
                                                  final success = await auth.verifyOTP(_otpController.text);
                                                  if (success && mounted) {
                                                    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
                                                  }
                                                }
                                              },
                                        label: 'Xác nhận',
                                        isLoading: auth.isLoading,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        if (auth.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(
                              auth.error!,
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({required VoidCallback? onPressed, required String label, required bool isLoading}) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}