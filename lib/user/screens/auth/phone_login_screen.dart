import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/theme_helper.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'VN');
  Timer? _timer;
  int _timeLeft = 60;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
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
            child: Icon(Icons.arrow_back, color: context.textColor, size: 20),
          ),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Centered header ──────────────────────────
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6E40),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.textColor, width: 2.5),
                            boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(6, 6))],
                          ),
                          child: const Icon(CupertinoIcons.phone_fill, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Số Điện Thoại',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: context.textColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          auth.isVerifying
                              ? 'Nhập mã OTP đã gửi về số điện thoại'
                              : 'Chúng tôi sẽ gửi mã OTP đến số điện thoại của bạn',
                          style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!auth.isVerifying) ...[
                    // ── Phone input ───────────────────────────
                    Text(
                      'Số điện thoại',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textColor),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: context.dialogBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.textColor, width: 2.5),
                        boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
                      ),
                      child: InternationalPhoneNumberInput(
                        onInputChanged: (PhoneNumber number) => _phoneNumber = number,
                        selectorConfig: const SelectorConfig(
                          selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                          setSelectorButtonAsPrefixIcon: true,
                        ),
                        ignoreBlank: false,
                        autoValidateMode: AutovalidateMode.onUserInteraction,
                        selectorTextStyle: TextStyle(color: context.textColor, fontSize: 15),
                        textStyle: TextStyle(color: context.textColor, fontSize: 15, fontWeight: FontWeight.w600),
                        initialValue: _phoneNumber,
                        formatInput: true,
                        keyboardType: TextInputType.phone,
                        inputDecoration: InputDecoration(
                          hintText: 'Số điện thoại',
                          hintStyle: TextStyle(color: context.textTertiaryColor),
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildPrimaryButton(
                      context: context,
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
                    // ── OTP input ─────────────────────────────
                    Text(
                      'Mã OTP',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textColor),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: context.dialogBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.textColor, width: 2.5),
                        boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
                      ),
                      child: TextFormField(
                        controller: _otpController,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 10,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '······',
                          hintStyle: TextStyle(color: context.textTertiaryColor, letterSpacing: 8),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Vui lòng nhập mã OTP';
                          if (value!.length != 6) return 'Mã OTP phải có 6 số';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Timer display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _timeLeft > 0
                            ? context.dialogBgColor
                            : const Color(0xFFFF6E40).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _timeLeft > 0 ? context.textColor : const Color(0xFFFF6E40),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mã có hiệu lực trong ${_timeLeft}s',
                            style: TextStyle(color: context.textSecondaryColor, fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: _timeLeft == 0
                                ? () async {
                                    final success = await auth.sendOTP(_phoneNumber.phoneNumber ?? '');
                                    if (success && mounted) {
                                      startTimer();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Đã gửi lại mã OTP'), backgroundColor: Colors.green),
                                      );
                                    }
                                  }
                                : null,
                            child: Text(
                              'Gửi lại',
                              style: TextStyle(
                                color: _timeLeft == 0 ? const Color(0xFFFF6E40) : context.textTertiaryColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildPrimaryButton(
                      context: context,
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
                      label: 'Xác nhận OTP',
                      isLoading: auth.isLoading,
                    ),
                  ],

                  if (auth.error != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Text(auth.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required String label,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.textColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.textColor, width: 2.5),
          boxShadow: [BoxShadow(color: const Color(0xFFFF6E40), offset: const Offset(6, 6))],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: context.scaffoldBackgroundColor, strokeWidth: 2.5),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: context.scaffoldBackgroundColor,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}