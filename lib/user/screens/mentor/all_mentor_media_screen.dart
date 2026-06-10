import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'mentor_media_feed_screen.dart';

const _kAccent = Color(0xFFE040FB);

class AllMentorMediaScreen extends StatelessWidget {
  const AllMentorMediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mentor_media')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: _kAccent)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có bài viết nào từ Mentor',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        // Trả về trực tiếp Feed Screen thay vì Grid View
        return MentorMediaFeedScreen(
          docs: docs,
          initialIndex: 0,
        );
      },
    );
  }
}
