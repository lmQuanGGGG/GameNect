import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/match_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/ai_match_service.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  _MatchScreenState createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final _firestoreService = FirestoreService();
  final _aiMatchService = AIMatchService();
  List<MatchModel> _activeMatches = [];
  List<UserModel> _likedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadMatches();
    await _loadLikedUsers();
    setState(() => _isLoading = false);
  }

  Future<void> _loadMatches() async {
    var matches = await _firestoreService.getActiveMatches();
    setState(() => _activeMatches = matches);
  }

  Future<void> _loadLikedUsers() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var liked = await _aiMatchService.getLikedUsers(user.uid);
      setState(() => _likedUsers = liked);
    }
  }

  Future<void> _findMatch() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var userData = await _firestoreService.getUser(user.uid);
    if (userData != null) {
      MatchModel? match = await _aiMatchService.findMatch(userData);
      if (match != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tìm thấy người chơi! Hãy xác nhận.')),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tìm thấy bạn chơi phù hợp!')),
        );
      }
    }
  }

  void _confirmMatch(String matchId, bool confirm) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _aiMatchService.confirmMatch(user.uid, matchId, confirm);
      if (confirm) {
        bool isConfirmed = await _aiMatchService.isMatchConfirmed(matchId);
        if (isConfirmed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Match thành công! Có thể trò chuyện.')),
          );
        }
      }
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ghép Bạn Chơi', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[700],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ElevatedButton(
                  onPressed: _findMatch,
                  child: Text('Tìm Bạn Chơi'),
                ),
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: [
                            Tab(text: 'Trận Đang Chờ'),
                            Tab(text: 'Ai Đã Thích Mình'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab Trận Đang Chờ
                              ListView.builder(
                                itemCount: _activeMatches.length,
                                itemBuilder: (context, index) {
                                  MatchModel match = _activeMatches[index];
                                  User? user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) return SizedBox.shrink();
                                  bool userConfirmed =
                                      match.confirmations[user.uid] ?? false;
                                  return ListTile(
                                    title: Text(match.game),
                                    subtitle: Text(
                                      'Thời gian: ${match.matchedAt.toString()}',
                                    ),
                                    trailing: userConfirmed
                                        ? Text('Đã xác nhận')
                                        : ElevatedButton(
                                            onPressed: () =>
                                                _confirmMatch(match.id, true),
                                            child: Text('Xác nhận'),
                                          ),
                                  );
                                },
                              ),
                              // Tab Ai Đã Thích Mình
                              ListView.builder(
                                itemCount: _likedUsers.length,
                                itemBuilder: (context, index) {
                                  UserModel user = _likedUsers[index];
                                  return ListTile(
                                    title: Text(user.username),
                                    subtitle: Text('Rank: ${user.rank}'),
                                    trailing: ElevatedButton(
                                      onPressed: () {
                                        final match = _activeMatches.where(
                                          (m) => m.userIds.contains(user.id),
                                        );
                                        if (match.isNotEmpty) {
                                          _confirmMatch(match.first.id, true);
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Không tìm thấy trận phù hợp!',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text('Match lại'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
