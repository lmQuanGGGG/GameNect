import 'package:flutter/material.dart';
import 'package:gamenect_new/core/widgets/network_image.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/theme_helper.dart';

class ForwardMessageDialog extends StatefulWidget {
  final Map<String, dynamic> originalMsg;

  const ForwardMessageDialog({super.key, required this.originalMsg});

  @override
  State<ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<ForwardMessageDialog> {
  final Set<String> _selectedMatchIds = {};
  bool _isForwarding = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _forward() async {
    if (_selectedMatchIds.isEmpty) return;
    setState(() {
      _isForwarding = true;
    });

    try {
      await Provider.of<ChatProvider>(
        context,
        listen: false,
      ).forwardMessage(_selectedMatchIds.toList(), widget.originalMsg);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chuyển tiếp tin nhắn!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isForwarding = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black, width: 2),
      ),
      backgroundColor: context.cardBgColor,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chuyển tiếp tin nhắn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm người nhận...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black26),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Flexible(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<MatchProvider>(
                  context,
                  listen: false,
                ).matchedUsersStream(currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    );
                  }
                  var matches = snapshot.data ?? [];

                  if (_searchQuery.isNotEmpty) {
                    matches = matches.where((item) {
                      final peerUser = item['user'] as UserModel?;
                      if (peerUser == null) return false;
                      return peerUser.username.toLowerCase().contains(
                        _searchQuery,
                      );
                    }).toList();
                  }

                  if (matches.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Không tìm thấy kết quả.'
                              : 'Bạn chưa có ai để chuyển tiếp.',
                          style: TextStyle(color: context.textSecondaryColor),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final item = matches[index];
                      final peerUser = item['user'] as UserModel?;
                      final matchId = item['matchId'] as String?;
                      if (peerUser == null || matchId == null)
                        return const SizedBox.shrink();

                      final isSelected = _selectedMatchIds.contains(matchId);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.black12,
                          child: peerUser.avatarUrl?.isNotEmpty == true
                              ? ClipOval(
                                  child: GamenectNetworkImage(
                                    imageUrl: peerUser.avatarUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          peerUser.username,
                          style: TextStyle(
                            color: context.textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected
                              ? Colors.green
                              : context.textSecondaryColor,
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedMatchIds.remove(matchId);
                            } else {
                              _selectedMatchIds.add(matchId);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isForwarding
                      ? null
                      : () => Navigator.pop(context),
                  child: Text(
                    'Huỷ',
                    style: TextStyle(color: context.textSecondaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.black),
                    ),
                  ),
                  onPressed: _selectedMatchIds.isEmpty || _isForwarding
                      ? null
                      : _forward,
                  child: _isForwarding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('Gửi (${_selectedMatchIds.length})'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
