import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Màn hình quản lý yêu cầu rút tiền
// Giao diện Neo-Brutalism nền trắng, chữ đen chủ đạo.
class WithdrawalsScreen extends StatelessWidget {
  const WithdrawalsScreen({super.key});

  Future<void> _updateStatus(
    BuildContext context,
    String docId,
    String status,
    int coins,
    String userId,
  ) async {
    try {
      if (status == 'rejected') {
        // Nếu từ chối, hoàn lại coin cho user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'coinBalance': FieldValue.increment(coins)});
      }

      await FirebaseFirestore.instance
          .collection('withdraw_requests')
          .doc(docId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? '✅ Đã duyệt yêu cầu rút tiền'
                  : '❌ Đã từ chối yêu cầu',
            ),
            backgroundColor:
                status == 'approved' ? Colors.green : Colors.red,
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
  }

  void _showActionDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bankInfo = data['bankInfo'] as Map<String, dynamic>;
    final amount = data['amount'];
    final bankName = bankInfo['bankName']?.toString() ?? '';
    final accountName = bankInfo['accountName']?.toString() ?? '';
    final accountNumber = bankInfo['accountNumber']?.toString() ?? '';

    final qrUrl =
        'https://img.vietqr.io/image/${Uri.encodeComponent(bankName)}-$accountNumber-compact2.png'
        '?amount=$amount&addInfo=Gamenect&accountName=${Uri.encodeComponent(accountName)}';

    Widget buildInfoRow(String label, String value,
        {bool copyable = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight:
                      copyable ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
            if (copyable)
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã copy: $value'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: Colors.black,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.copy,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tiêu đề
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'THÔNG TIN CHUYỂN KHOẢN',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2.5),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(3, 3),
                      ),
                    ],
                  ),
                  child: Image.network(
                    qrUrl,
                    height: 200,
                    width: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      width: 200,
                      alignment: Alignment.center,
                      child: const Text(
                        'Không thể tạo QR\n(Sai tên ngân hàng)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Quét mã để chuyển nhanh',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Thông tin tài khoản
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      buildInfoRow('Ngân hàng:', bankName),
                      const Divider(color: Colors.black12, height: 12),
                      buildInfoRow('Chủ tài khoản:', accountName),
                      const Divider(color: Colors.black12, height: 12),
                      buildInfoRow('Số tài khoản:', accountNumber,
                          copyable: true),
                      const Divider(color: Colors.black12, height: 12),
                      buildInfoRow(
                        'Số tiền:',
                        '${NumberFormat('#,###').format(amount)} VNĐ',
                        copyable: true,
                      ),
                      const Divider(color: Colors.black12, height: 12),
                      buildInfoRow(
                        'Coin trừ:',
                        '${NumberFormat('#,###').format(data['coins'])} Coin',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Nút hành động
                Row(
                  children: [
                    // Nút Từ chối
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350),
                          border: Border.all(color: Colors.black, width: 2.5),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateStatus(context, doc.id, 'rejected',
                                data['coins'], data['userId']);
                          },
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                          label: const Text(
                            'Từ chối',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Nút Duyệt
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF66BB6A),
                          border: Border.all(color: Colors.black, width: 2.5),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateStatus(context, doc.id, 'approved',
                                data['coins'], data['userId']);
                          },
                          icon: const Icon(Icons.check,
                              color: Colors.white, size: 18),
                          label: const Text(
                            'Đã Duyệt',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Badge trạng thái
  Widget _statusBadge(String status) {
    final Color bg;
    final Color border;
    final String label;
    final IconData icon;

    switch (status) {
      case 'approved':
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFF66BB6A);
        label = 'Đã duyệt';
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFEF5350);
        label = 'Từ chối';
        icon = Icons.cancel_outlined;
        break;
      default:
        bg = const Color(0xFFFFF8E1);
        border = const Color(0xFFFFB300);
        label = 'Đang chờ';
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: border),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: border,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Quản lý Rút Tiền',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black, height: 1.5),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('withdraw_requests')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.black));
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2.5),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 48, color: Colors.black38),
                          SizedBox(height: 12),
                          Text(
                            'Chưa có yêu cầu rút tiền',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Đếm pending
            final pendingCount =
                docs.where((d) => (d.data() as Map)['status'] == 'pending').length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Thống kê nhanh
                if (pendingCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      border: Border.all(
                          color: const Color(0xFFFFB300), width: 2.5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black, offset: Offset(3, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_empty,
                            color: Colors.black, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          '$pendingCount yêu cầu đang chờ xử lý',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Danh sách
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final bankInfo =
                      data['bankInfo'] as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'pending';
                  final isPending = status == 'pending';

                  // Màu border theo trạng thái
                  final Color borderColor = isPending
                      ? const Color(0xFFFFB300)
                      : status == 'approved'
                          ? const Color(0xFF66BB6A)
                          : Colors.black;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor, width: 2.5),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(4, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dòng trên: Số tiền + Badge trạng thái
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payments_outlined,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${NumberFormat('#,###').format(data['amount'])} VNĐ',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              _statusBadge(status),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Coin trừ
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${NumberFormat('#,###').format(data['coins'])} Coin',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Đường kẻ
                          Container(
                            height: 1.5,
                            color: Colors.black,
                          ),
                          const SizedBox(height: 12),

                          // Thông tin ngân hàng
                          Row(
                            children: [
                              const Icon(Icons.account_balance,
                                  color: Colors.black54, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${bankInfo['bankName']}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  color: Colors.black, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${bankInfo['accountName']}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.credit_card,
                                  color: Colors.black54, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${bankInfo['accountNumber']}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text:
                                          '${bankInfo['accountNumber']}'));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Đã copy số tài khoản'),
                                      backgroundColor: Colors.black,
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.copy,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Nút xử lý (chỉ hiện khi pending)
                          if (isPending) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  border: Border.all(
                                      color: Colors.black, width: 2.5),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(3, 3),
                                    ),
                                  ],
                                ),
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _showActionDialog(context, doc),
                                  icon: const Icon(
                                    Icons.open_in_new,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Xử lý Yêu Cầu',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
