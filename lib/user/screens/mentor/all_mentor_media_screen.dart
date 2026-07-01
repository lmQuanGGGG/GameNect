import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'mentor_media_feed_screen.dart';

const _kAccent = Color(0xFFE040FB);

class AllMentorMediaScreen extends StatefulWidget {
  final String? initialPostId;
  const AllMentorMediaScreen({super.key, this.initialPostId});

  @override
  State<AllMentorMediaScreen> createState() => _AllMentorMediaScreenState();
}

class _AllMentorMediaScreenState extends State<AllMentorMediaScreen> {
  late final Stream<QuerySnapshot> _mediaStream;

  @override
  void initState() {
    super.initState();
    _mediaStream = FirebaseFirestore.instance
        .collection('mentor_media')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _mediaStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40))),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white, offset: const Offset(4, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      'CHƯA CÓ BÀI VIẾT',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                  ],
                ),
              ),
            ),

          );
        }

        final docs = snapshot.data!.docs;
        int initialIndex = 0;
        if (widget.initialPostId != null) {
          final index = docs.indexWhere((doc) => doc.id == widget.initialPostId);
          if (index != -1) {
            initialIndex = index;
          }
        }

        // Trả về trực tiếp Feed Screen thay vì Grid View
        return MentorMediaFeedScreen(
          docs: docs,
          initialIndex: initialIndex,
        );
      },
    );
  }
}
