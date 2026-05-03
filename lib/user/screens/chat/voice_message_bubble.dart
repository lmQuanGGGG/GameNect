import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:ui';

/// Widget hiển thị voice message bubble
/// Quản lý waveform (hoặc placeholder) và nút play/pause, thời lượng
class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int duration; // Thời lượng tính bằng giây
  final bool isMe;

  const VoiceMessageBubble({
    required this.audioUrl,
    required this.duration,
    required this.isMe,
    super.key,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late AudioPlayer _player;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    
    // Lắng nghe trạng thái play/pause
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          // Có thể tự dừng khi phát xong
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _player.pause();
            _player.seek(Duration.zero);
          }
        });
      }
    });

    _player.setUrl(widget.audioUrl).catchError((e) {
      // Bỏ qua lỗi stream nếu audio chưa stream được
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
        bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
        bottomRight: Radius.circular(widget.isMe ? 4 : 20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          margin: EdgeInsets.only(
            left: widget.isMe ? 40 : 0,
            right: widget.isMe ? 8 : 40,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: widget.isMe
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFF6E40).withValues(alpha: 0.8),
                      const Color(0xFFFF8A65).withValues(alpha: 0.8),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.15),
                    ],
                  ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 20),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _player.pause();
              } else {
                // Nếu chưa load url
                if (_player.duration == null) {
                  await _player.setUrl(widget.audioUrl);
                }
                await _player.play();
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final durationSecs = _player.duration?.inSeconds ?? widget.duration;
                    final posSecs = position.inSeconds;
                    
                    final fraction = durationSecs > 0 ? (posSecs / durationSecs).clamp(0.0, 1.0) : 0.0;
                    
                    return Row(
                      children: [
                        Container(
                          width: 100,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: fraction),
                            // just_audio position stream nhảy mỗi 200ms
                            // Nên dùng duration 250ms tuyến tính để nội suy mượt mà
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.linear,
                            builder: (context, value, child) {
                              return FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.white,
                                        blurRadius: 4,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          posSecs > 0 || _isPlaying
                              ? '${posSecs ~/ 60}:${(posSecs % 60).toString().padLeft(2, '0')}'
                              : '${widget.duration ~/ 60}:${(widget.duration % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
