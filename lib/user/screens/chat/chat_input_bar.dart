import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:async';
import '../../../core/providers/chat_provider.dart';
import '../media/media_preview_screen.dart';
import '../../../core/theme/theme_helper.dart';

/// Thanh nhập liệu Liquid Glass Floating Pill
/// Hỗ trợ: Ghi âm Zero-Delay (onPointerDown) và Vuốt sang trái để hủy (Slide to cancel).
class ChatInputBar extends StatefulWidget {
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
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  double _startX = 0.0;
  bool _isCanceledBySlide = false;

  Timer? _recordTimer;
  int _recordDuration = 0; // Tính bằng giây

  void _startTimer() {
    _recordDuration = 0;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordDuration++;
        });
      }
    });
  }

  void _stopTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
    if (mounted) {
      setState(() {
        _recordDuration = 0;
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.controller.text.trim().isEmpty) {
      _startX = event.position.dx;
      _isCanceledBySlide = false;
      _startTimer();
      widget.onStartRecording();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!widget.isRecording || _isCanceledBySlide) return;

    final currentX = event.position.dx;
    // Nếu vuốt sang trái hơn 60 pixels
    if (_startX - currentX > 60) {
      _isCanceledBySlide = true;
      _stopTimer();
      widget.onCancelRecording();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (widget.isRecording && !_isCanceledBySlide) {
      _stopTimer();
      widget.onStopRecording();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (widget.isRecording && !_isCanceledBySlide) {
      _stopTimer();
      widget.onCancelRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        bottomPadding == 0 ? 12 : bottomPadding,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: context.cardBgColor,
                border: Border.all(
                  color: context.cardBorderColor,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Nút (+) gửi ảnh/video
                  if (!widget.isRecording)
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(bottom: 2, left: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Color(0xFFFF6E40),
                          size: 22,
                        ),
                        onPressed: () => _handleMediaPick(context),
                      ),
                    ),

                  const SizedBox(width: 8),

                  // TextField hoặc Label Đang ghi âm
                  Expanded(
                    child: widget.isRecording
                        ? _buildRecordingStatus()
                        : Container(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: TextField(
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 15,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'iMessage',
                                hintStyle: TextStyle(
                                  color: context.textTertiaryColor,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                filled: false,
                                fillColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                isDense: true,
                              ),
                              onChanged: (text) {
                                chatProvider.setTyping(
                                  widget.matchId,
                                  isTyping: text.isNotEmpty,
                                );
                              },
                            ),
                          ),
                  ),

                  const SizedBox(width: 8),

                  // Nút Mic / Send (Zero Delay)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, child) {
                      final isEmpty = value.text.trim().isEmpty;
                      return Listener(
                        onPointerDown: isEmpty ? _handlePointerDown : null,
                        onPointerMove: isEmpty ? _handlePointerMove : null,
                        onPointerUp: isEmpty ? _handlePointerUp : null,
                        onPointerCancel: isEmpty ? _handlePointerCancel : null,
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(bottom: 2, right: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: widget.isRecording
                                  ? [
                                      const Color(0xFFFF6E40),
                                      const Color(0xFFBF360C),
                                    ]
                                  : [
                                      const Color(
                                        0xFFFF6E40,
                                      ).withValues(alpha: 0.8),
                                      const Color(
                                        0xFFFF8A65,
                                      ).withValues(alpha: 0.8),
                                    ],
                            ),
                            boxShadow: [
                              if (widget.isRecording)
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF6E40,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              isEmpty ? Icons.mic_rounded : Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              if (!isEmpty) {
                                widget.onSendMessage(value.text.trim());
                                widget.controller.clear();
                                chatProvider.setTyping(
                                  widget.matchId,
                                  isTyping: false,
                                );
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
        ),
      ),
    );
  }

  Widget _buildRecordingStatus() {
    return Container(
      height: 44,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic_rounded, color: Color(0xFFFF6E40), size: 18),
          const SizedBox(width: 6),
          // Bộ đếm thời gian
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              color: Color(0xFFFF6E40),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '•  Vuốt ⬅️ để hủy',
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMediaPick(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.dialogBgColor.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: context.cardBorderColor),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: context.textColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_rounded,
                  color: Color(0xFFFF6E40),
                ),
                title: Text(
                  'Chọn ảnh',
                  style: TextStyle(color: context.textColor),
                ),
                onTap: () async {
                  final file = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                    maxWidth: 800,
                  );
                  if (context.mounted) Navigator.pop(context, file);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.videocam_rounded,
                  color: Color(0xFFFF6E40),
                ),
                title: Text(
                  'Chọn video',
                  style: TextStyle(color: context.textColor),
                ),
                onTap: () async {
                  final file = await picker.pickVideo(
                    source: ImageSource.gallery,
                  );
                  if (context.mounted) Navigator.pop(context, file);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (pickedFile != null && context.mounted) {
      final isVideo =
          pickedFile.path.toLowerCase().endsWith('.mp4') ||
          pickedFile.path.toLowerCase().endsWith('.mov');

      final caption = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MediaPreviewScreen(file: File(pickedFile.path), isVideo: isVideo),
        ),
      );

      if (caption != null) {
        widget.onSendMedia(pickedFile.path, isVideo: isVideo);
      }
    }
  }
}
