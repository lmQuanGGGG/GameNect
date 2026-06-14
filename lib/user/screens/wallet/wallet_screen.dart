import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/theme_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ProfileProvider>().userData;
    final coinBalance = user?.coinBalance ?? 0;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: Scaffold(
        backgroundColor: context.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Ví GameNect',
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          backgroundColor: context.scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: context.textColor),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: context.dialogBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.textColor, width: 2.5),
                  boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFFFF6E40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: context.textSecondaryColor,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Nạp Coin'),
                    Tab(text: 'Rút Tiền'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // ── Balance Card ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.textColor, // đen (light) / trắng (dark) → đảo ngược
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.textColor, width: 2.5),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF6E40), offset: const Offset(6, 6))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6E40),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.scaffoldBackgroundColor, width: 2),
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Số dư hiện tại',
                            style: TextStyle(
                              color: context.scaffoldBackgroundColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${NumberFormat('#,###').format(coinBalance)} Coin',
                            style: TextStyle(
                              color: context.scaffoldBackgroundColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6E40),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.scaffoldBackgroundColor, width: 1.5),
                      ),
                      child: Text(
                        'GameNect',
                        style: TextStyle(
                          color: context.scaffoldBackgroundColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TopupTab(),
                  _WithdrawTab(coinBalance: coinBalance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── NẠP COIN ─────────────────────────────────────────────────────────────

class _TopupTab extends StatefulWidget {
  @override
  State<_TopupTab> createState() => _TopupTabState();
}

class _TopupTabState extends State<_TopupTab> {
  late final Stream<List<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = context.read<WalletProvider>().getMyCoinOrders();
  }

  final List<Map<String, dynamic>> _coinPackages = [
    {'coins': 100,  'price': 20000,   'label': ''},
    {'coins': 500,  'price': 100000,  'label': 'Hot'},
    {'coins': 1000, 'price': 200000,  'label': 'Best'},
    {'coins': 5000, 'price': 1000000, 'label': ''},
  ];

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: const Color(0xFFFF6E40)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: context.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.red));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40)));
        final list = snapshot.data!;
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.dialogBgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.textColor, width: 2),
            ),
            child: Center(
              child: Text('Chưa có lịch sử nạp coin nào', style: TextStyle(color: context.textSecondaryColor)),
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final order = list[index];
            final status = order['status'];
            Color statusColor = const Color(0xFFFF6E40);
            String statusText = 'Đang xử lý';
            if (status == 'success') { statusColor = Colors.green; statusText = 'Thành công'; }
            if (status == 'failed') { statusColor = Colors.red; statusText = 'Thất bại'; }

            String timeStr = '';
            final createdAt = order['createdAt'] as Timestamp?;
            if (createdAt != null) {
              timeStr = DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate());
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.dialogBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.textColor, width: 2.5),
                  boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6E40),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.textColor, width: 2),
                      ),
                      child: const Icon(Icons.add_card_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${NumberFormat('#,###').format(order['coins'] ?? 0)} Coin',
                            style: TextStyle(color: context.textColor, fontWeight: FontWeight.w900),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: TextStyle(color: context.textSecondaryColor, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${NumberFormat('#,###').format(order['amount'] ?? 0)}đ',
                          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor, width: 1.5),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coin packages cards
              for (final pkg in _coinPackages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.dialogBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.textColor, width: 2.5),
                      boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(5, 5))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        // Coin icon box
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6E40),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: context.textColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${NumberFormat('#,###').format(pkg['coins'])} Coin',
                                      style: TextStyle(
                                        color: context.textColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if ((pkg['label'] as String).isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6E40),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        pkg['label'],
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '1 coin = 200đ',
                                style: TextStyle(
                                  color: context.textSecondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            try {
                              final provider = context.read<SubscriptionProvider>();
                              final payment = await provider.purchaseCoin(pkg['coins'], pkg['price']);
                              if (payment == null) return;
                              
                              final checkoutUrl = payment['checkoutUrl'] as String;
                              final orderCode = payment['orderCode'] as int;

                              bool completed = false;
                              Timer? timer;
                              timer = Timer.periodic(const Duration(seconds: 3), (t) async {
                                final status = await provider.checkPaymentStatus(orderCode);
                                if (status == 'success') {
                                  completed = true;
                                  t.cancel();
                                  await Future.delayed(const Duration(seconds: 1));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green),
                                    );
                                    context.read<ProfileProvider>().loadUserProfile();
                                  }
                                } else if (status == 'failed') {
                                  completed = true;
                                  t.cancel();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Thanh toán thất bại'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              });

                              final url = Uri.parse(checkoutUrl);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication, webOnlyWindowName: '_self');
                              }

                              if (!completed) {
                                final status = await provider.checkPaymentStatus(orderCode);
                                if (status == 'success') {
                                  await Future.delayed(const Duration(seconds: 1));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green),
                                    );
                                    context.read<ProfileProvider>().loadUserProfile();
                                  }
                                } else if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Đang xử lý thanh toán, số dư sẽ cập nhật trong giây lát.'), backgroundColor: Colors.orange),
                                  );
                                }
                              }
                              
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6E40),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.textColor,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(color: context.textColor, offset: const Offset(3, 3))
                              ],
                            ),
                            child: Text(
                              '${NumberFormat('#,###').format(pkg['price'])}đ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              _buildSectionLabel('Lịch sử nạp coin'),
              const SizedBox(height: 12),
              _buildHistoryList(),
            ],
          ),
        ),
        if (subProvider.isLoading)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40))),
          ),
      ],
    );
  }
}

// ── RÚT TIỀN ─────────────────────────────────────────────────────────────

class _WithdrawTab extends StatefulWidget {
  final int coinBalance;
  const _WithdrawTab({required this.coinBalance});

  @override
  State<_WithdrawTab> createState() => _WithdrawTabState();
}

class _WithdrawTabState extends State<_WithdrawTab> {
  late final Stream<List<Map<String, dynamic>>> _requestsStream;

  @override
  void initState() {
    super.initState();
    _requestsStream = context.read<WalletProvider>().getMyWithdrawRequests();
  }

  final _amountCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();

  int get _vndAmount {
    final coins = int.tryParse(_amountCtrl.text) ?? 0;
    return coins * 100;
  }

  void _submit() async {
    final coins = int.tryParse(_amountCtrl.text) ?? 0;
    if (coins < 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số lượng rút tối thiểu là 500 Coin')));
      return;
    }
    if (coins > widget.coinBalance) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số dư Coin không đủ')));
      return;
    }
    if (_bankNameCtrl.text.isEmpty || _accountNameCtrl.text.isEmpty || _accountNumberCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin ngân hàng')));
      return;
    }

    final success = await context.read<WalletProvider>().createWithdrawRequest(
      coins, 
      _vndAmount, 
      {
        'bankName': _bankNameCtrl.text.trim(),
        'accountName': _accountNameCtrl.text.trim().toUpperCase(),
        'accountNumber': _accountNumberCtrl.text.trim(),
      }
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo lệnh rút tiền thành công!')));
      _amountCtrl.clear();
      _bankNameCtrl.clear();
      _accountNameCtrl.clear();
      _accountNumberCtrl.clear();
      context.read<ProfileProvider>().loadUserProfile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Có lỗi xảy ra, vui lòng thử lại sau.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<WalletProvider>().isLoading;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.dialogBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.textColor, width: 2.5),
                  boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(5, 5))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFFF6E40), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tỷ giá: 100 Coin = 10.000 VNĐ\nTối thiểu rút: 500 Coin',
                        style: TextStyle(color: context.textSecondaryColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionLabel('Số lượng Coin rút'),
              const SizedBox(height: 8),
              _buildTextField('VD: 500', _amountCtrl, isNumber: true, onChanged: (_) => setState(() {})),
              const SizedBox(height: 10),
              // Conversion display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6E40).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF6E40), width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.currency_exchange_rounded, color: Color(0xFFFF6E40), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Thực nhận: ${NumberFormat('#,###').format(_vndAmount)} VNĐ',
                      style: const TextStyle(color: Color(0xFFFF6E40), fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionLabel('Tài khoản Ngân hàng'),
              const SizedBox(height: 8),
              _buildTextField('Tên Ngân hàng (VD: Vietcombank)', _bankNameCtrl),
              const SizedBox(height: 12),
              _buildTextField('Tên Chủ Tài Khoản (Không dấu)', _accountNameCtrl),
              const SizedBox(height: 12),
              _buildTextField('Số Tài Khoản', _accountNumberCtrl, isNumber: true),
              const SizedBox(height: 28),

              // Submit button
              GestureDetector(
                onTap: isLoading ? null : _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: context.textColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.textColor, width: 2.5),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF6E40), offset: const Offset(5, 5))],
                  ),
                  child: Center(
                    child: Text(
                      'TẠO LỆNH RÚT TIỀN',
                      style: TextStyle(
                        color: context.scaffoldBackgroundColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              _buildSectionLabel('Lịch sử rút tiền'),
              const SizedBox(height: 12),
              _buildHistoryList(),
            ],
          ),
        ),
        if (isLoading)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40))),
          ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: const Color(0xFFFF6E40)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: context.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {bool isNumber = false, Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: context.dialogBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.textColor, width: 2.5),
        boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
        onChanged: onChanged,
        style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.textTertiaryColor),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.red));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.dialogBgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.textColor, width: 2),
            ),
            child: Center(
              child: Text('Chưa có lệnh rút tiền nào', style: TextStyle(color: context.textSecondaryColor)),
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final req = list[index];
            final status = req['status'];
            Color statusColor = const Color(0xFFFF6E40);
            String statusText = 'Đang xử lý';
            if (status == 'approved') { statusColor = Colors.green; statusText = 'Thành công'; }
            if (status == 'rejected') { statusColor = Colors.red; statusText = 'Bị từ chối'; }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.dialogBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.textColor, width: 2.5),
                  boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6E40),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.textColor, width: 2),
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${NumberFormat('#,###').format(req['coins'])} Coin',
                            style: TextStyle(color: context.textColor, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${req['bankInfo']['bankName']} - ${req['bankInfo']['accountNumber']}',
                            style: TextStyle(color: context.textSecondaryColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${NumberFormat('#,###').format(req['amount'])}đ',
                          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor, width: 1.5),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
