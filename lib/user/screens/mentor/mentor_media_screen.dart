// lib/user/screens/mentor_media_screen.dart
import 'dart:io';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/utils/thumbnail_helper.dart'
    if (dart.library.html) '../../../core/utils/thumbnail_helper_web.dart';
import '../premium/subscription_screen.dart';
import 'mentor_media_feed_screen.dart';

const _kAccent = Color(0xFFFF6E40);
const _kLiveRed = Color(0xFFFF2D55);
const _kDarkBg = Color(0xFF121214);
const _kLightBg = Color(0xFFF4F4F0);
const _kDarkCard = Color(0xFF2A2A32);
const _kLightCard = Colors.white;

const _kFreePhotoLimit = 10;
const _kFreeVideoLimit = 3;
const _kMaxVideoDurationSec = 5;

class MentorMediaScreen extends StatefulWidget {
  final String mentorId;
  final bool isSelf;
  const MentorMediaScreen({
    super.key,
    required this.mentorId,
    required this.isSelf,
  });

  @override
  State<MentorMediaScreen> createState() => _MentorMediaScreenState();
}

class _MentorMediaScreenState extends State<MentorMediaScreen> {
  final _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0;
  late final Stream<QuerySnapshot> _mediaStream;

  @override
  void initState() {
    super.initState();
    _mediaStream = FirestoreService().getMentorMedia(widget.mentorId);
  }

  // ── Check quota ──────────────────────────────────────────────────────────
  Future<bool> _checkQuota(String type) async {
    final isPremium =
        context.read<ProfileProvider>().userData?.isPremium ?? false;
    if (isPremium) return true;

    final counts = await FirestoreService().getMonthlyMediaCount(
      widget.mentorId,
    );
    final photos = counts['photos'] ?? 0;
    final videos = counts['videos'] ?? 0;

    if (type == 'image' && photos >= _kFreePhotoLimit) {
      _showPremiumDialog('ĐÃ ĐĂNG $photos/$_kFreePhotoLimit ẢNH');
      return false;
    }
    if (type == 'video' && videos >= _kFreeVideoLimit) {
      _showPremiumDialog('ĐÃ ĐĂNG $videos/$_kFreeVideoLimit VIDEO');
      return false;
    }
    return true;
  }

  void _showPremiumDialog(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 3),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            boxShadow: const [BoxShadow(color: _kAccent, offset: Offset(6, 6))],
            borderRadius: BorderRadius.circular(13), // 16 - 3
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  border: Border.all(color: Colors.black, width: 3),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.black,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'MUA PREMIUM ĐỂ ĐĂNG ẢNH VÀ VIDEO KHÔNG GIỚI HẠN MỖI THÁNG!',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? _kDarkBg : _kLightBg,
                          border: Border.all(color: borderColor, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: borderColor,
                              offset: const Offset(3, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'ĐỂ SAU',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _kAccent,
                          border: Border.all(color: borderColor, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: borderColor,
                              offset: const Offset(3, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'MUA NGAY',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
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
    );
  }

  // ── Upload methods ───────────────────────────────────────────────────────
  Future<void> _pickAndUploadImage() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (xFile == null) return;
    final canUpload = await _checkQuota('image');
    if (!canUpload) return;

    final captionCtrl = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CaptionDialog(controller: captionCtrl),
    );
    if (confirmed != true) return;

    await _uploadFile(xFile, 'image', caption: captionCtrl.text.trim());
  }

  Future<void> _pickAndUploadVideo() async {
    final xFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: _kMaxVideoDurationSec),
    );
    if (xFile == null) return;
    final canUpload = await _checkQuota('video');
    if (!canUpload) return;

    int durationSec = 0;
    if (kIsWeb) {
      durationSec = 0;
    } else {
      try {
        final vpCtrl = VideoPlayerController.file(File(xFile.path));
        await vpCtrl.initialize();
        durationSec = vpCtrl.value.duration.inSeconds;
        await vpCtrl.dispose();
        if (durationSec > _kMaxVideoDurationSec) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'VIDEO PHẢI DƯỚI ${_kMaxVideoDurationSec}S (${durationSec}S)',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              backgroundColor: _kLiveRed,
            ),
          );
          return;
        }
      } catch (e) {
        developer.log('Error reading video duration: $e', name: 'MentorMedia');
      }
    }

    final captionCtrl = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CaptionDialog(controller: captionCtrl, isVideo: true),
    );
    if (confirmed != true) return;

    await _uploadFile(
      xFile,
      'video',
      caption: captionCtrl.text.trim(),
      durationSec: durationSec > 0 ? durationSec : null,
    );
  }

  Future<void> _uploadFile(
    XFile xFile,
    String type, {
    String caption = '',
    int? durationSec,
  }) async {
    final uid = widget.mentorId;
    final ext = xFile.name.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance.ref('mentor_media/$uid/$fileName');

    Reference? uploadedMediaRef;
    Reference? uploadedThumbRef;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      String? thumbnailUrl;

      if (type == 'video') {
        try {
          final thumbResult = await generateVideoThumbnail(
            xFile,
          ).timeout(const Duration(seconds: 3), onTimeout: () => null);

          if (thumbResult != null) {
            final thumbFileName =
                'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

            final thumbRef = FirebaseStorage.instance.ref(
              'mentor_media/$uid/$thumbFileName',
            );

            uploadedThumbRef = thumbRef;

            if (kIsWeb && thumbResult.bytes != null) {
              await thumbRef.putData(
                Uint8List.fromList(thumbResult.bytes!),
                SettableMetadata(
                  contentType: 'image/jpeg',
                  cacheControl: 'public, max-age=31536000',
                ),
              );
              thumbnailUrl = await thumbRef.getDownloadURL();
            } else if (!kIsWeb && thumbResult.path != null) {
              await thumbRef.putFile(
                File(thumbResult.path!),
                SettableMetadata(
                  contentType: 'image/jpeg',
                  cacheControl: 'public, max-age=31536000',
                ),
              );
              thumbnailUrl = await thumbRef.getDownloadURL();
            }
          }
        } catch (e) {
          developer.log('Error thumbnail: $e', name: 'MentorMedia');
        }
      }

      final contentType = type == 'image'
          ? 'image/jpeg'
          : (xFile.name.split('.').last.toLowerCase() == 'webm'
                ? 'video/webm'
                : 'video/mp4');

      uploadedMediaRef = ref;

      final UploadTask task = kIsWeb
          ? ref.putData(
              await xFile.readAsBytes(),
              SettableMetadata(
                contentType: contentType,
                cacheControl: 'public, max-age=31536000',
              ),
            )
          : ref.putFile(
              File(xFile.path),
              SettableMetadata(
                contentType: contentType,
                cacheControl: 'public, max-age=31536000',
              ),
            );

      task.snapshotEvents.listen((s) {
        if (mounted) {
          setState(
            () => _uploadProgress =
                s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes),
          );
        }
      });

      await task;
      final url = await ref.getDownloadURL();

      await FirestoreService().addMentorMedia(
        mentorId: uid,
        type: type,
        url: url,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        durationSeconds: durationSec,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == 'image' ? 'ĐÃ ĐĂNG ẢNH!' : 'ĐÃ ĐĂNG VIDEO!',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      developer.log('Upload mentor media error: $e', name: 'MentorMedia');

      try {
        if (uploadedThumbRef != null) {
          await uploadedThumbRef!.delete();
        }
      } catch (_) {}

      try {
        if (uploadedMediaRef != null) {
          await uploadedMediaRef!.delete();
        }
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'LỖI: $e',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          backgroundColor: _kLiveRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteMedia(
    String docId,
    String url, {
    String? thumbnailUrl,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _kDarkCard : _kLightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white : Colors.black,
            width: 3,
          ),
        ),
        title: Text(
          'XÓA FILE?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa ảnh/video này?',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'HỦY',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kLiveRed,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'XÓA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirestoreService().deleteMentorMedia(docId);
    try {
      if (url.contains('firebasestorage')) {
        await FirebaseStorage.instance.refFromURL(url).delete();
      }
    } catch (e) {
      developer.log('Lỗi xóa media trên storage: $e', name: 'MentorMedia');
    }
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      try {
        if (thumbnailUrl.contains('firebasestorage')) {
          await FirebaseStorage.instance.refFromURL(thumbnailUrl).delete();
        }
      } catch (e) {
        developer.log('Lỗi xóa thumbnail trên storage: $e', name: 'MentorMedia');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _kDarkBg : _kLightBg;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'ALBUM MEDIA',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: borderColor, width: 3)),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kAccent,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: shadowColor, offset: const Offset(2, 2)),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
        actions: widget.isSelf
            ? [
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kAccent,
                      border: Border.all(color: borderColor, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.plus,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor, width: 3),
                  ),
                  onSelected: (val) {
                    if (val == 'image') _pickAndUploadImage();
                    if (val == 'video') _pickAndUploadVideo();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'image',
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.photo,
                            color: _kAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ĐĂNG ẢNH',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Tối đa $_kFreePhotoLimit/tháng (Free)',
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'video',
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.videocam_fill,
                            color: _kLiveRed,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ĐĂNG VIDEO',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Max ${_kMaxVideoDurationSec}s | $_kFreeVideoLimit/tháng',
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
              ]
            : null,
      ),
      body: Column(
        children: [
          if (_isUploading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kAccent,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.cloud_upload_fill,
                    color: Colors.black,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        color: Colors.white,
                      ),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

          if (widget.isSelf) _QuotaBanner(mentorId: widget.mentorId),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _mediaStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _kAccent,
                      strokeWidth: 3,
                    ),
                  );
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.camera_on_rectangle,
                          size: 64,
                          color: textColor.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.isSelf
                              ? 'TRỐNG TRƠN\nBẤM DẤU + ĐỂ ĐĂNG ẢNH!'
                              : 'MENTOR CHƯA CÓ MEDIA',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final docs = [...snapshot.data!.docs]
                  ..sort((a, b) {
                    final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
                    final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
                    if (aTs == null) return 1;
                    if (bTs == null) return -1;
                    return bTs.compareTo(aTs);
                  });

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final docId = docs[i].id;
                    final isVideo = data['type'] == 'video';
                    final url = data['url'] as String? ?? '';

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MentorMediaFeedScreen(
                            docs: docs,
                            initialIndex: i,
                          ),
                        ),
                      ),
                      onLongPress: widget.isSelf
                          ? () => _deleteMedia(
                              docId,
                              url,
                              thumbnailUrl: data['thumbnailUrl'] as String?,
                            )
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          border: Border.all(color: borderColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: shadowColor,
                              offset: const Offset(3, 3),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (url.isNotEmpty)
                                (isVideo &&
                                        (data['thumbnailUrl'] == null ||
                                            data['thumbnailUrl']
                                                .toString()
                                                .isEmpty))
                                    ? Container(
                                        color: Colors.black12,
                                        child: const Icon(
                                          CupertinoIcons.play_circle_fill,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                      )
                                    : GamenectNetworkImage(
                                        imageUrl: isVideo
                                            ? data['thumbnailUrl']!
                                            : url,
                                        fit: BoxFit.cover,
                                      )
                              else
                                Container(
                                  color: Colors.black12,
                                  child: const Icon(
                                    CupertinoIcons.photo,
                                    color: Colors.black26,
                                  ),
                                ),

                              if (isVideo)
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kLiveRed,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          CupertinoIcons.play_fill,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                        if (data['duration'] != null)
                                          Text(
                                            '${data['duration']}s',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    final photos = _counts?['photos'] ?? 0;
    final videos = _counts?['videos'] ?? 0;
    final isPremium =
        context.read<ProfileProvider>().userData?.isPremium ?? false;

    if (isPremium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber,
          border: Border(bottom: BorderSide(color: borderColor, width: 3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.black,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'PREMIUM',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            const Text(
              'KHÔNG GIỚI HẠN',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? _kDarkCard : _kLightCard,
        border: Border(bottom: BorderSide(color: borderColor, width: 3)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.photo, size: 18, color: textColor),
          const SizedBox(width: 6),
          Text(
            '$photos/$_kFreePhotoLimit',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 16),
          Icon(CupertinoIcons.videocam_fill, size: 18, color: textColor),
          const SizedBox(width: 6),
          Text(
            '$videos/$_kFreeVideoLimit',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kAccent,
                border: Border.all(color: borderColor, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.white : Colors.black,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: const Text(
                'NÂNG CẤP',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionDialog extends StatelessWidget {
  final TextEditingController controller;
  final bool isVideo;
  const _CaptionDialog({required this.controller, this.isVideo = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 3),
      ),
      title: Text(
        isVideo ? 'ĐĂNG VIDEO' : 'ĐĂNG ẢNH',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      content: Container(
        decoration: BoxDecoration(
          color: isDark ? _kDarkBg : _kLightBg,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: const [BoxShadow(color: _kAccent, offset: Offset(3, 3))],
        ),
        child: TextField(
          controller: controller,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Thêm caption... (tùy chọn)',
            hintStyle: TextStyle(
              color: textColor.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'HỦY',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            'ĐĂNG NGAY',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
