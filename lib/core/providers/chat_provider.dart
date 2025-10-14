import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

class ChatProvider with ChangeNotifier {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isPeerTyping = false;
  UserModel? _currentUser;

  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isPeerTyping => _isPeerTyping;
  UserModel? get currentUser => _currentUser;

  set isPeerTyping(bool value) {
    _isPeerTyping = value;
    notifyListeners();
  }

  Future<void> fetchMessages(String matchId) async {
    _isLoading = true;
    notifyListeners();
    _messages = await FirestoreService().getMessages(matchId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage(String matchId, String text) async {
    _isLoading = true;
    notifyListeners();
    await FirestoreService().sendMessage(matchId, text);
    await fetchMessages(matchId);
    _isLoading = false;
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> messagesStream(String matchId) {
    return FirestoreService().messagesStream(matchId);
  }

  Future<void> endCall(String matchId, int duration, {bool missed = false}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await FirestoreService().addCallMessage(
      matchId: matchId,
      senderId: userId,
      duration: duration,
      missed: missed,
    );
    notifyListeners();
  }

  Future<void> fetchCurrentUser() async {
    _currentUser = await FirestoreService().getCurrentUser();
    notifyListeners();
  }
}