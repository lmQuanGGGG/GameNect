import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import 'package:intl/intl.dart';

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
        backgroundColor: const Color(0xFF1C1C1E),
        appBar: AppBar(
          title: const Text('Ví của tôi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFF6E40),
            labelColor: const Color(0xFFFF6E40),
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Nạp Coin'),
              Tab(text: 'Rút Tiền'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Balance Header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A65), Color(0xFFFF6E40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6E40).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Số dư hiện tại', style: TextStyle(color: Colors.white, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('GameNect Coin', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 36),
                      const SizedBox(width: 8),
                      Text(
                        NumberFormat('#,###').format(coinBalance),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
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
  final List<Map<String, dynamic>> _coinPackages = [
    {'coins': 100, 'price': 20000},
    {'coins': 500, 'price': 100000},
    {'coins': 1000, 'price': 200000},
    {'coins': 5000, 'price': 1000000},
  ];

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _coinPackages.length,
          itemBuilder: (context, index) {
            final pkg = _coinPackages[index];
            return Card(
              color: const Color(0xFF2C2C2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: const Icon(Icons.monetization_on, color: Colors.amber, size: 32),
                title: Text('${NumberFormat('#,###').format(pkg['coins'])} Coin', 
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6E40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () async {
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
                          // Webhook đã ghi vào DB, delay 1s để chắc chắn dữ liệu cập nhật
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
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }

                      // Nếu app quay lại mà timer vẫn đang chạy, kiểm tra 1 lần cuối
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
                  child: Text('${NumberFormat('#,###').format(pkg['price'])} đ', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
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
  final _amountCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();

  // Tỷ giá rút: 100 Coin = 10.000 VNĐ (chia 10)
  int get _vndAmount {
    final coins = int.tryParse(_amountCtrl.text) ?? 0;
    return coins * 100; // 1 coin = 100 vnđ
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
      // Reload profile to update UI
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
              const Text('Thông tin rút tiền', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Tỷ giá: 100 Coin = 10.000 VNĐ\nTối thiểu: 500 Coin', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              
              _buildTextField('Số Coin muốn rút', _amountCtrl, isNumber: true, onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              Text('Số tiền thực nhận: ${NumberFormat('#,###').format(_vndAmount)} VNĐ', 
                style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              const Text('Tài khoản Ngân hàng', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTextField('Tên Ngân hàng (VD: Vietcombank)', _bankNameCtrl),
              const SizedBox(height: 12),
              _buildTextField('Tên Chủ Tài Khoản (Không dấu)', _accountNameCtrl),
              const SizedBox(height: 12),
              _buildTextField('Số Tài Khoản', _accountNumberCtrl, isNumber: true),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6E40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: isLoading ? null : _submit,
                  child: const Text('TẠO LỆNH RÚT TIỀN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Lịch sử rút tiền', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
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

  Widget _buildTextField(String hint, TextEditingController controller, {bool isNumber = false, Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<WalletProvider>().getMyWithdrawRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Text('Chưa có lệnh rút tiền nào', style: TextStyle(color: Colors.white54));
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final req = list[index];
            final status = req['status'];
            Color statusColor = Colors.orange;
            String statusText = 'Đang xử lý';
            if (status == 'approved') { statusColor = Colors.green; statusText = 'Thành công'; }
            if (status == 'rejected') { statusColor = Colors.red; statusText = 'Bị từ chối'; }

            return Card(
              color: const Color(0xFF2C2C2E),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${NumberFormat('#,###').format(req['coins'])} Coin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${req['bankInfo']['bankName']} - ${req['bankInfo']['accountNumber']}', style: const TextStyle(color: Colors.white70)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${NumberFormat('#,###').format(req['amount'])} đ', style: const TextStyle(color: Colors.white)),
                    Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
