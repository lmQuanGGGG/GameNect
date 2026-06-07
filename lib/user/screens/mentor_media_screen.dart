// lib/user/screens/mentor_media_screen.dart
// Trang ảnh/video của Mentor — 10 ảnh + 3 video/tháng cho free, premium không giới hạn
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/firestore_service.dart';
import 'premium/subscription_screen.dart';

const _kBg = Color(0xFF101012);
const _kAccent = Color(0xFFFF6E40);

const _kFreePhotoLimit = 10;
const _kFreeVideoLimit = 3;
const _kMaxVideoDurationSec = 15;

class MentorMediaScreen extends StatefulWidget {
  final String mentorId;
  final bool isSelf;
  const MentorMediaScreen({super.key, required this.mentorId, required this.isSelf});

  @override
  State<MentorMediaScreen> createState() => _MentorMediaScreenState();
}

class _MentorMediaScreenState extends State<MentorMediaScreen> {
  final _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0;

  // ── Check quota ──────────────────────────────────────────────────────────

  Future<bool> _checkQuota(String type) async {
    final isPremium = context.read<ProfileProvider>().userData?.isPremium ?? false;
    if (isPremium) return true;

    final counts = await FirestoreService().getMonthlyMediaCount(widget.mentorId);
    final photos = counts['photos'] ?? 0;
    final videos = counts['videos'] ?? 0;

    if (type == 'image' && photos >= _kFreePhotoLimit) {
      _showPremiumDialog('Bạn đã đăng $photos/$_kFreePhotoLimit ảnh tháng này');
      return false;
    }
    if (type == 'video' && videos >= _kFreeVideoLimit) {
      _showPremiumDialog('Bạn đã đăng $videos/$_kFreeVideoLimit video tháng này');
      return false;
    }
    return true;
  }

  void _showPremiumDialog(String reason) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_kAccent, Colors.amber.shade600],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.workspace_premium, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Nâng cấp Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 10),
              Text(reason, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Premium: đăng ảnh & video không giới hạn mỗi tháng!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Để sau'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      );
                    },
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('Mua Premium'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Upload image ─────────────────────────────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    final canUpload = await _checkQuota('image');
    if (!canUpload) return;

    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xFile == null) return;

    final captionCtrl = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CaptionDialog(controller: captionCtrl),
    );
    if (confirmed != true) return;

    await _uploadFile(File(xFile.path), 'image', caption: captionCtrl.text.trim());
  }

  // ── Upload video ─────────────────────────────────────────────────────────

  Future<void> _pickAndUploadVideo() async {
    final canUpload = await _checkQuota('video');
    if (!canUpload) return;

    final xFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: _kMaxVideoDurationSec),
    );
    if (xFile == null) return;

    // Verify duration using VideoPlayerController
    final vpCtrl = VideoPlayerController.file(File(xFile.path));
    await vpCtrl.initialize();
    final durationSec = vpCtrl.value.duration.inSeconds;
    await vpCtrl.dispose();

    if (durationSec > _kMaxVideoDurationSec) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video phải dưới ${_kMaxVideoDurationSec}s (video của bạn: ${durationSec}s)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final captionCtrl = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CaptionDialog(controller: captionCtrl, isVideo: true),
    );
    if (confirmed != true) return;

    await _uploadFile(File(xFile.path), 'video',
      caption: captionCtrl.text.trim(), durationSec: durationSec);
  }

  // ── Generic upload to Firebase Storage ──────────────────────────────────

  Future<void> _uploadFile(File file, String type, {String caption = '', int? durationSec}) async {
    final uid = widget.mentorId;
    final ext = file.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance.ref('mentor_media/$uid/$fileName');

    setState(() { _isUploading = true; _uploadProgress = 0; });

    try {
      final task = ref.putFile(file);
      task.snapshotEvents.listen((s) {
        if (mounted) {
          setState(() => _uploadProgress = s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes));
        }
      });
      await task;
      final url = await ref.getDownloadURL();

      await FirestoreService().addMentorMedia(
        mentorId: uid,
        type: type,
        url: url,
        caption: caption,
        durationSeconds: durationSec,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(type == 'image' ? 'Đã đăng ảnh!' : 'Đã đăng video!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải lên: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<void> _deleteMedia(String docId, String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: const Text('Xóa?', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có chắc muốn xóa ảnh/video này?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await FirestoreService().deleteMentorMedia(docId);
    try { await FirebaseStorage.instance.refFromURL(url).delete(); } catch (_) {}
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Ảnh & Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: widget.isSelf ? [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            color: const Color(0xFF1E1E22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'image') _pickAndUploadImage();
              if (val == 'video') _pickAndUploadVideo();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'image', child: Row(children: [
                const Icon(Icons.photo, color: _kAccent, size: 20),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Đăng ảnh', style: TextStyle(color: Colors.white)),
                  Text('Tối đa $_kFreePhotoLimit ảnh/tháng (free)',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                ]),
              ])),
              PopupMenuItem(value: 'video', child: Row(children: [
                const Icon(Icons.videocam, color: _kAccent, size: 20),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Đăng video', style: TextStyle(color: Colors.white)),
                  Text('Tối đa ${_kMaxVideoDurationSec}s | $_kFreeVideoLimit video/tháng (free)',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                ]),
              ])),
            ],
          ),
          const SizedBox(width: 8),
        ] : null,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
      ),
      body: Column(
        children: [
          // Upload progress
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _kAccent.withValues(alpha: 0.15),
              child: Row(children: [
                const Icon(Icons.cloud_upload, color: _kAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(child: LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(_kAccent),
                )),
                const SizedBox(width: 10),
                Text('${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold)),
              ]),
            ),

          // Quota info for self
          if (widget.isSelf)
            _QuotaBanner(mentorId: widget.mentorId),

          // Media grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService().getMentorMedia(widget.mentorId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _kAccent));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64,
                          color: Colors.white.withValues(alpha: 0.25)),
                        const SizedBox(height: 12),
                        Text(
                          widget.isSelf ? 'Chưa có ảnh/video nào\nBấm + để đăng lên!' : 'Mentor chưa đăng ảnh/video nào',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Sort by createdAt descending client-side
                final docs = [...snapshot.data!.docs];
                docs.sort((a, b) {
                  final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
                  final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return bTs.compareTo(aTs);
                });

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final docId = docs[i].id;
                    final isVideo = data['type'] == 'video';
                    final url = data['url'] as String? ?? '';

                    return GestureDetector(
                      onTap: () => _viewMedia(context, data, docId),
                      onLongPress: widget.isSelf ? () => _deleteMedia(docId, url) : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (url.isNotEmpty)
                              Image.network(
                                isVideo ? (data['thumbnailUrl'] ?? url) : url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _e, _st) => Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.broken_image, color: Colors.white38),
                                ),
                              )
                            else
                              Container(color: Colors.white10,
                                child: const Icon(Icons.image, color: Colors.white24)),
                            if (isVideo)
                              Positioned(
                                bottom: 4, right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                                    if (data['duration'] != null)
                                      Text('${data['duration']}s',
                                        style: const TextStyle(color: Colors.white, fontSize: 9)),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _viewMedia(BuildContext context, Map<String, dynamic> data, String docId) {
    final isVideo = data['type'] == 'video';
    final url = data['url'] as String? ?? '';
    final caption = data['caption']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: isVideo
                  ? _VideoPlayer(url: url)
                  : InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(caption, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Quota banner ──────────────────────────────────────────────────────────

class _QuotaBanner extends StatefulWidget {
  final String mentorId;
  const _QuotaBanner({required this.mentorId});

  @override
  State<_QuotaBanner> createState() => _QuotaBannerState();
}

class _QuotaBannerState extends State<_QuotaBanner> {
  Map<String, int>? _counts;

  @override
  void initState() {
    super.initState();
    FirestoreService().getMonthlyMediaCount(widget.mentorId).then((c) {
      if (mounted) setState(() => _counts = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = _counts?['photos'] ?? 0;
    final videos = _counts?['videos'] ?? 0;
    final isPremium = context.read<ProfileProvider>().userData?.isPremium ?? false;
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.amber.withValues(alpha: 0.1),
        child: Row(children: [
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          const Text('Premium — Đăng không giới hạn', style: TextStyle(color: Colors.amber, fontSize: 13)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withValues(alpha: 0.04),
      child: Row(children: [
        const Icon(Icons.photo, size: 15, color: Colors.white54),
        const SizedBox(width: 4),
        Text('$photos/$_kFreePhotoLimit ảnh', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(width: 16),
        const Icon(Icons.videocam, size: 15, color: Colors.white54),
        const SizedBox(width: 4),
        Text('$videos/$_kFreeVideoLimit video', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
            ),
            child: const Text('Nâng cấp', style: TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ── Caption dialog ────────────────────────────────────────────────────────

class _CaptionDialog extends StatelessWidget {
  final TextEditingController controller;
  final bool isVideo;
  const _CaptionDialog({required this.controller, this.isVideo = false});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isVideo ? 'Đăng video' : 'Đăng ảnh',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Thêm caption... (tùy chọn)',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kAccent)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Đăng'),
        ),
      ],
    );
  }
}

// ── Video player widget ───────────────────────────────────────────────────

class _VideoPlayer extends StatefulWidget {
  final String url;
  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
          _ctrl.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: _kAccent));
    }
    return GestureDetector(
      onTap: () {
        if (_ctrl.value.isPlaying) {
          _ctrl.pause();
        } else {
          _ctrl.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl)),
          if (!_ctrl.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
        ],
      ),
    );
  }
}
