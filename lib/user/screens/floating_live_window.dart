// lib/user/screens/floating_live_window.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../core/providers/livestream_provider.dart';

class FloatingLiveWindow extends StatefulWidget {
  final String streamId;
  final bool isMentor;
  final VoidCallback onClose;
  final VoidCallback onRestore;

  const FloatingLiveWindow({
    super.key,
    required this.streamId,
    required this.isMentor,
    required this.onClose,
    required this.onRestore,
  });

  @override
  State<FloatingLiveWindow> createState() => _FloatingLiveWindowState();
}

class _FloatingLiveWindowState extends State<FloatingLiveWindow> {
  // Draggable position coordinates
  double? _x;
  double? _y;

  final double _width = 120.0;
  final double _height = 200.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Set initial position at the bottom-right corner if not set
    _x ??= screenWidth - _width - 16.0;
    _y ??= screenHeight - _height - 100.0;

    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _x = (_x! + details.delta.dx).clamp(8.0, screenWidth - _width - 8.0);
            _y = (_y! + details.delta.dy).clamp(
              MediaQuery.of(context).padding.top + 8.0,
              screenHeight - _height - MediaQuery.of(context).padding.bottom - 8.0,
            );
          });
        },
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // ── Video Feed / Screen Share ──────────────────────────────────
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: widget.onRestore,
                      child: _buildVideoContent(context),
                    ),
                  ),

                  // ── Drag overlay handle (subtle visual indicator) ────────────────
                  Positioned(
                    top: 6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  // ── Close button ───────────────────────────────────────────────
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            width: 24,
                            height: 24,
                            color: Colors.black45,
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
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
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    final provider = context.watch<LivestreamProvider>();
    if (provider.engine == null) {
      return Container(
        color: const Color(0xFF101012),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: Color(0xFFFF6E40), strokeWidth: 2),
          ),
        ),
      );
    }

    if (widget.isMentor) {
      if (provider.isScreenSharing) {
        // Screen Sharing Active placeholder for Mentor to prevent feedback loop
        return Container(
          color: const Color(0xFF101012),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.screen_share_rounded, color: Color(0xFFFF6E40), size: 24),
              const SizedBox(height: 6),
              Text(
                'Đang chia sẻ màn hình...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: provider.engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      if (provider.remoteUid == null) {
        return Container(
          color: const Color(0xFF101012),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(color: Color(0xFFFF6E40), strokeWidth: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                'Đang kết nối...',
                style: TextStyle(color: Colors.white60, fontSize: 8),
              ),
            ],
          ),
        );
      }
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: provider.engine!,
          canvas: VideoCanvas(uid: provider.remoteUid!),
          connection: RtcConnection(channelId: widget.streamId),
        ),
      );
    }
  }
}
