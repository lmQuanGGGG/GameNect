import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WithdrawalsScreen extends StatelessWidget {
  const WithdrawalsScreen({super.key});

  Future<void> _updateStatus(BuildContext context, String docId, String status, int coins, String userId) async {
    try {
      if (status == 'rejected') {
        // Nếu từ chối, hoàn lại coin cho user
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'coinBalance': FieldValue.increment(coins),
        });
      }

      await FirebaseFirestore.instance.collection('withdraw_requests').doc(docId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã cập nhật trạng thái thành: $status')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
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
    
    final qrUrl = 'https://img.vietqr.io/image/${Uri.encodeComponent(bankName)}-$accountNumber-compact2.png?amount=$amount&addInfo=Gamenect&accountName=${Uri.encodeComponent(accountName)}';

    Widget buildInfoRow(String label, String value, {bool copyable = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
            Expanded(
              child: Text(value, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: copyable ? FontWeight.bold : FontWeight.normal)),
            ),
            if (copyable)
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã copy: $value'), duration: const Duration(seconds: 1)));
                },
                child: const Icon(Icons.copy, color: Colors.blueAccent, size: 18),
              )
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF181A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('THÔNG TIN CHUYỂN KHOẢN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // QR Code
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                      child: const Text('Không thể tạo QR\n(Sai tên ngân hàng)', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Quét mã qua app ngân hàng để chuyển nhanh', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                
                buildInfoRow('Ngân hàng:', bankName),
                buildInfoRow('Chủ tài khoản:', accountName),
                buildInfoRow('Số tài khoản:', accountNumber, copyable: true),
                buildInfoRow('Số tiền:', '${NumberFormat('#,###').format(amount)} VNĐ', copyable: true),
                buildInfoRow('Số Coin trừ:', '${NumberFormat('#,###').format(data['coins'])} Coin'),
                
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateStatus(context, doc.id, 'rejected', data['coins'], data['userId']);
                        },
                        child: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateStatus(context, doc.id, 'approved', data['coins'], data['userId']);
                        },
                        child: const Text('Đã Duyệt', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('withdraw_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('Chưa có yêu cầu rút tiền nào', style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bankInfo = data['bankInfo'] as Map<String, dynamic>;
              final status = data['status'];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF), // Glass background
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: status == 'pending' ? Colors.orange.withValues(alpha: 0.5) : const Color(0x1FFFFFFF),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${NumberFormat('#,###').format(data['amount'])} VNĐ',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'pending' ? Colors.orange.withValues(alpha: 0.2) : (status == 'approved' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status == 'pending' ? '⏳ Đang chờ' : (status == 'approved' ? '✅ Thành công' : '❌ Từ chối'),
                              style: TextStyle(
                                color: status == 'pending' ? Colors.orange : (status == 'approved' ? Colors.green : Colors.red),
                                fontSize: 12, fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Số Coin trừ: ${NumberFormat('#,###').format(data['coins'])}', style: const TextStyle(color: Colors.orange, fontSize: 14)),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.account_balance, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${bankInfo['bankName']}', style: const TextStyle(color: Colors.white70, fontSize: 13))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${bankInfo['accountName']} - ${bankInfo['accountNumber']}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      if (status == 'pending') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _showActionDialog(context, doc),
                            child: const Text('Xử lý Yêu Cầu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
