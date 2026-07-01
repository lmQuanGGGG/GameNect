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
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/utils/thumbnail_helper.dart'
    if (dart.library.html) '../../../core/utils/thumbnail_helper_web.dart';
import '../premium/subscription_screen.dart';
import 'mentor_media_feed_screen.dart';
import '../matching/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

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
  String _mentorName = 'Mentor';
  String _mentorAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _mediaStream = FirestoreService().getMentorMedia(widget.mentorId);
    _loadMentorData();
  }

  Future<void> _loadMentorData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.mentorId).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _mentorName = data['username'] ?? 'Mentor';
          _mentorAvatarUrl = data['avatarUrl'] ?? '';
        });
      }
    } catch (_) {}
  }
  
  void _showShareBottomSheet(
    BuildContext context,
    String postId,
    String previewUrl,
    bool isVideo,
    String mentorName,
    String mentorId,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: Provider.of<MatchProvider>(
                context,
                listen: false,
              ).fetchMatchedUsersWithMatchId(currentUserId),
              builder: (context, snapshot) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: const Border(
                      top: BorderSide(color: Colors.black, width: 1.5),
                      left: BorderSide(color: Colors.black, width: 1.5),
                      right: BorderSide(color: Colors.black, width: 1.5),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(0, -4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 20),
                        width: 40,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const Text(
                        'CHIA SẺ BÀI VIẾT',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'GỬI POST CỦA "${mentorName.toUpperCase()}"',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: 'https://gamenect.vn/mentor/$mentorId/post/$postId'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'ĐÃ SAO CHÉP LIÊN KẾT',
                                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                  backgroundColor: Colors.white,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Colors.black, width: 1.5),
                                  ),
                                ),
                              );
                              Navigator.pop(bottomSheetContext);
                            },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black, width: 1.5),
                                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5))],
                                  ),
                                  child: const Icon(Icons.link, color: Colors.black, size: 24),
                                ),
                                const SizedBox(height: 8),
                                const Text('Copy Link', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Share.share('Xem bài viết cực hay trên Gamenect ngay: https://gamenect.vn/mentor/$mentorId/post/$postId');
                              Navigator.pop(bottomSheetContext);
                            },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black, width: 1.5),
                                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5))],
                                  ),
                                  child: const Icon(Icons.share_outlined, color: Colors.black, size: 24),
                                ),
                                const SizedBox(height: 8),
                                const Text('Ứng dụng khác', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value.toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm bạn bè...',
                            hintStyle: const TextStyle(color: Colors.black54),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.black54,
                            ),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(
                        color: Colors.black,
                        height: 4,
                        thickness: 4,
                      ),
                      Expanded(
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF6E40),
                                ),
                              )
                            : snapshot.hasError ||
                                  !snapshot.hasData ||
                                  snapshot.data!.isEmpty
                            ? const Center(
                                child: Text(
                                  'BẠN CHƯA CÓ MATCH NÀO',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  final allMatches = snapshot.data!;
                                  final filteredMatches = searchQuery.isEmpty
                                      ? allMatches
                                      : allMatches.where((m) {
                                          final username =
                                              (m['user'].username ?? '')
                                                  .toLowerCase();
                                          return username.contains(searchQuery);
                                        }).toList();

                                  if (filteredMatches.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'KHÔNG TÌM THẤY BẠN BÈ',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    itemCount: filteredMatches.length,
                                    itemBuilder: (context, index) {
                                      final matchData = filteredMatches[index];
                                      final user = matchData['user'];
                                      final matchId = matchData['matchId'];

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 8,
                                            ),
                                        leading: ClipOval(
                                          child: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child:
                                                user.avatarUrl != null &&
                                                    user.avatarUrl!.isNotEmpty
                                                ? GamenectNetworkImage(
                                                    imageUrl: user.avatarUrl!,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Container(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                            ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Container(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                              child: const Icon(
                                                                Icons.person,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                            ),
                                                  )
                                                : Container(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.1),
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        title: Text(
                                          user.username ?? 'User',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        trailing: GestureDetector(
                                          onTap: () {
                                            Navigator.pop(bottomSheetContext);

                                            Provider.of<ChatProvider>(
                                              context,
                                              listen: false,
                                            ).sendMentorPostMessage(
                                              matchId,
                                              postId,
                                              previewUrl,
                                              isVideo,
                                              mentorName,
                                              peerUser: user,
                                            );

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'ĐÃ GỬI BÀI VIẾT CHO ${user.username?.toUpperCase() ?? "BẠN BÈ"}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                backgroundColor: Colors.white,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: const BorderSide(
                                                    color: Colors.black,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.black,
                                                width: 1.5,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black,
                                                  offset: Offset(1.5, 1.5),
                                                ),
                                              ],
                                            ),
                                            child: const Text(
                                              'GỬI',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0,
                                              ),
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
              },
            );
          },
        );
      },
    );
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
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final docId = docs[i].id;
                    final isVideo = data['type'] == 'video';
                    final url = data['url'] as String? ?? '';
                    final likes = List<String>.from(data['likes'] as List? ?? const []);
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                    final isLiked = likes.contains(currentUserId);
                    final thumbnailUrl = data['thumbnailUrl'] as String? ?? '';

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
                          color: const Color(0xFFF4F4F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Background
                              ColoredBox(
                                color: isVideo ? Colors.black : const Color(0xFFF4F4F4),
                                child: (url.isNotEmpty)
                                    ? ((isVideo && thumbnailUrl.isEmpty)
                                        ? Container(
                                            color: Colors.black12,
                                            child: const Icon(
                                              CupertinoIcons.play_circle_fill,
                                              color: Colors.white,
                                              size: 36,
                                            ),
                                          )
                                        : GamenectNetworkImage(
                                            imageUrl: isVideo ? thumbnailUrl : url,
                                            fit: BoxFit.cover,
                                          ))
                                    : Container(
                                        color: Colors.black12,
                                        child: const Icon(CupertinoIcons.photo, color: Colors.black26),
                                      ),
                              ),

                              // Bottom solid bar
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  height: 50,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      top: BorderSide(color: Colors.black, width: 1.5),
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom bar content (Avatar + name + share button)
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 8,
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 1.5),
                                      ),
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: const Color(0xFF00E676),
                                        child: _mentorAvatarUrl.isNotEmpty
                                            ? ClipOval(
                                                child: GamenectNetworkImage(
                                                  imageUrl: _mentorAvatarUrl,
                                                  width: 28,
                                                  height: 28,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Text(
                                                _mentorName.isNotEmpty ? _mentorName[0].toUpperCase() : '?',
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _mentorName,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Share button
                                    GestureDetector(
                                      onTap: () {
                                        _showShareBottomSheet(
                                          context,
                                          docId,
                                          isVideo && thumbnailUrl.isNotEmpty ? thumbnailUrl : url,
                                          isVideo,
                                          _mentorName,
                                          widget.mentorId,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(
                                          Icons.share_rounded,
                                          color: Colors.black,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Heart/Likes badge at top right
                              if (likes.isNotEmpty)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (currentUserId.isEmpty) return;
                                      FirestoreService().toggleLikeMentorMedia(docId, currentUserId);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.black, width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            color: isLiked ? Colors.red : Colors.black,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${likes.length}',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else 
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (currentUserId.isEmpty) return;
                                      FirestoreService().toggleLikeMentorMedia(docId, currentUserId);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                                        ],
                                      ),
                                      child: Icon(
                                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        color: isLiked ? Colors.red : Colors.black,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),

                              // Video duration (if video) at top left
                              if (isVideo && data['duration'] != null)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _kLiveRed,
                                      border: Border.all(color: Colors.white, width: 1.5),
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
                                        const SizedBox(width: 2),
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
