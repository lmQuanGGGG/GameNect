import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/providers/chat_provider.dart';
import '../media/media_preview_screen.dart';

/// Thanh nhập liệu bên dưới cùng của Chat Screen
/// Bao gồm: Text input, Nút thêm Media, Nút Ghi âm / Gửi
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isRecording;
  final String matchId;
  final String peerUserId;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final void Function(String path, {required bool isVideo}) onSendMedia;
  final void Function(String text) onSendMessage;

  const ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.isRecording,
    required this.matchId,
    required this.peerUserId,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.onSendMedia,
    required this.onSendMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Nút cộng (+) để gửi ảnh/video
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFFFF453A), size: 20),
                  onPressed: () => _handleMediaPick(context),
                ),
              ),
              const SizedBox(width: 8),

              // TextField nhập tin nhắn
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'iMessage',
                      hintStyle: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF453A),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      fillColor: Colors.black.withValues(alpha: 0.3),
                      filled: true,
                      isDense: true,
                    ),
                    onChanged: (text) {
                      chatProvider.setTyping(matchId, isTyping: text.isNotEmpty);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút mic/send
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final isEmpty = value.text.trim().isEmpty;
                  return GestureDetector(
                    onLongPressStart: isEmpty ? (_) => onStartRecording() : null,
                    onLongPressEnd: isEmpty ? (_) => onStopRecording() : null,
                    onLongPressCancel: isEmpty ? () => onCancelRecording() : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRecording
                              ? const Color(0xFFFF453A)
                              : Colors.white.withValues(alpha: 0.2),
                          width: isRecording ? 2 : 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isEmpty ? Icons.mic : Icons.send,
                          color: isEmpty
                              ? (isRecording ? const Color(0xFFFF453A) : Colors.white)
                              : const Color(0xFFFF453A),
                          size: 20,
                        ),
                        onPressed: () {
                          if (!isEmpty) {
                            onSendMessage(value.text.trim());
                            controller.clear();
                            chatProvider.setTyping(matchId, isTyping: false);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleMediaPick(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo, color: Color(0xFFFF453A)),
                title: const Text('Chọn ảnh', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  final file = await picker.pickImage(source: ImageSource.gallery);
                  if (context.mounted) {
                    Navigator.pop(context, file);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Color(0xFFFF453A)),
                title: const Text('Chọn video', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  final file = await picker.pickVideo(source: ImageSource.gallery);
                  if (context.mounted) {
                    Navigator.pop(context, file);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (pickedFile != null && context.mounted) {
      final isVideo = pickedFile.path.toLowerCase().endsWith('.mp4') ||
          pickedFile.path.toLowerCase().endsWith('.mov');

      final caption = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => MediaPreviewScreen(
            file: File(pickedFile.path),
            isVideo: isVideo,
          ),
        ),
      );

      // Nếu caption không null nghĩa là user bấm Gửi
      if (caption != null) {
        onSendMedia(pickedFile.path, isVideo: isVideo);
      }
    }
  }
}
