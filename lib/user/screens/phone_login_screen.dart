import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../core/providers/auth_provider.dart';

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
  int _timeLeft = 60; // 60 giây

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
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Logo và tiêu đề
                    Icon(
                      CupertinoIcons.phone_circle_fill,
                      size: 80,
                      color: Colors.deepOrange.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Đăng nhập bằng số điện thoại',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Chúng tôi sẽ gửi mã OTP đến số điện thoại của bạn',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (!auth.isVerifying) ...[
                      // Widget nhập số điện thoại
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
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
                          selectorTextStyle: const TextStyle(color: Colors.black87),
                          initialValue: _phoneNumber,
                          formatInput: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          inputDecoration: const InputDecoration(
                            hintText: 'Số điện thoại',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                if (_formKey.currentState?.validate() ?? false) {
                                  final success = await auth.sendOTP(
                                    _phoneNumber.phoneNumber ?? '',
                                  );
                                  if (success && mounted) {
                                    startTimer();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Đã gửi mã OTP'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    auth.setVerifying(true);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Gửi mã OTP',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ] else ...[
                      // Widget nhập OTP
                      TextFormField(
                        controller: _otpController,
                        decoration: InputDecoration(
                          labelText: 'Mã OTP',
                          hintText: 'Nhập mã 6 số',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.deepOrange),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          suffixIcon: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              '${_timeLeft}s',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Vui lòng nhập mã OTP';
                          }
                          if (value!.length != 6) {
                            return 'Mã OTP phải có 6 số';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mã OTP có hiệu lực trong $_timeLeft giây',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _timeLeft == 0 
                                ? () async {
                                    if (_formKey.currentState?.validate() ?? false) {
                                      final success = await auth.sendOTP(
                                        _phoneNumber.phoneNumber ?? '',
                                      );
                                      if (success && mounted) {
                                        startTimer();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đã gửi lại mã OTP'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.deepOrange,
                              ),
                              child: Text(
                                _timeLeft > 0 
                                  ? 'Gửi lại sau ${_timeLeft}s' 
                                  : 'Gửi lại mã',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () async {
                                      if (_formKey.currentState?.validate() ??
                                          false) {
                                        final success = await auth
                                            .verifyOTP(_otpController.text);
                                        if (success && mounted) {
                                          Navigator.pushReplacementNamed(
                                            context,
                                            '/home',
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Xác nhận',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (auth.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          auth.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}