import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> purchaseSubscription(String tier, int durationDays) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');

    final endDate = DateTime.now().add(Duration(days: durationDays));

    await _firestore.collection('users').doc(userId).update({
      'subscriptionTier': tier,
      'subscriptionEndDate': endDate.toIso8601String(),
      'isPremium': true,
    });

    // Log transaction
    await _firestore.collection('transactions').add({
      'userId': userId,
      'tier': tier,
      'duration': durationDays,
      'purchaseDate': FieldValue.serverTimestamp(),
      'endDate': endDate.toIso8601String(),
    });
  }

  Future<bool> checkSubscriptionStatus(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return false;

    final endDate = data['subscriptionEndDate'];
    if (endDate == null) return false;

    final expiry = DateTime.parse(endDate);
    final isActive = DateTime.now().isBefore(expiry);

    if (!isActive) {
      // Reset to free if expired
      await _firestore.collection('users').doc(userId).update({
        'subscriptionTier': 'free',
        'isPremium': false,
      });
    }

    return isActive;
  }
}