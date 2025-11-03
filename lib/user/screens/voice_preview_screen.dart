import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:ui';

// Màn hình preview tin nhắn thoại trước khi gửi trong chat
// Cho phép user nghe lại audio, xem thời lượng và quyết định gửi hoặc hủy
// Sử dụng just_audio package để phát audio
class VoicePreviewScreen extends StatefulWidget {
  final File audioFile; // File audio đã ghi
  final int duration; // Thời lượng audio tính bằng giây

  const VoicePreviewScreen({
    super.key,
    required this.audioFile,
    required this.duration,
  });

  @override
  State<VoicePreviewScreen> createState() => _VoicePreviewScreenState();
}

class _VoicePreviewScreenState extends State<VoicePreviewScreen> {
  late AudioPlayer _player; // Audio player để phát file audio
  bool _isPlaying = false; // Trạng thái đang phát hay đang dừng
  Duration _position = Duration.zero; // Vị trí hiện tại của audio đang phát

  @override
  void initState() {
    super.initState();
    // Khởi tạo audio player và load file audio
    _player = AudioPlayer();
    _player.setFilePath(widget.audioFile.path);
    
    // Lắng nghe trạng thái phát/dừng của player
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    // Lắng nghe vị trí hiện tại của audio để update UI
    _player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient màu đen chuyển sang đỏ nhạt
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    const Color(0xFFFF453A).withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
          ),

          // Content chính ở giữa màn hình
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Waveform animation hiển thị các thanh dao động theo nhạc
                Container(
                  width: 200,
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(20, (index) {
                      // Chiều cao mỗi thanh thay đổi để tạo hiệu ứng sóng
                      final height = 20.0 + (index % 3) * 20.0;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 4,
                        height: _isPlaying ? height : 20, // Thanh cao hơn khi đang phát
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 40),

                // Nút play/pause với gradient đỏ và shadow phát sáng
                GestureDetector(
                  onTap: () {
                    if (_isPlaying) {
                      _player.pause(); // Dừng phát nếu đang phát
                    } else {
                      _player.play(); // Phát audio nếu đang dừng
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF453A), Color(0xFFFF6961)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF453A).withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Hiển thị thời gian hiện tại / tổng thời lượng
                Text(
                  '${_position.inSeconds}s / ${widget.duration}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Bottom buttons: Hủy và Gửi
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Nút hủy với viền trắng, pop false khi nhấn
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context, false), // Trả về false để không gửi
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Hủy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Nút gửi với gradient đỏ, pop true khi nhấn
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF453A), Color(0xFFFF6961)],
                          ),
                        ),
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context, true), // Trả về true để gửi tin
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Gửi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose audio player để giải phóng bộ nhớ
    _player.dispose();
    super.dispose();
  }
}