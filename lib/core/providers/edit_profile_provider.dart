import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart'; // { changed code }


class EditProfileProvider extends ChangeNotifier {
  final Logger _logger = Logger('EditProfileProvider'); // { changed code }

  // State variables
  bool _isLoading = true;
  String? _error;

  // Options từ Firestore
  List<String> _rankOptions = [];
  List<String> _genderOptions = [];
  List<String> _gameStyleOptions = [];
  List<String> _lookingForOptions = [];
  List<String> _interestOptions = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get rankOptions => _rankOptions;
  List<String> get genderOptions => _genderOptions;
  List<String> get gameStyleOptions => _gameStyleOptions;
  List<String> get lookingForOptions => _lookingForOptions;
  List<String> get interestOptions => _interestOptions;

  Future<void> initialize({String langCode = 'vi'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadOptionsFromFirestore(
          'rankOptions',
          langCode,
          (data) => _rankOptions = data,
        ),
        _loadOptionsFromFirestore(
          'genderOptions',
          langCode,
          (data) => _genderOptions = data,
        ),
        _loadOptionsFromFirestore(
          'gameStyleOptions',
          langCode,
          (data) => _gameStyleOptions = data,
        ),
        _loadOptionsFromFirestore(
          'lookingForOptions',
          langCode,
          (data) => _lookingForOptions = data,
        ),
        _loadOptionsFromFirestore(
          'interestOptions',
          langCode,
          (data) => _interestOptions = data,
        ),
      ]);

      _logger.info('Loaded options:');
      _logger.info('Ranks: $_rankOptions');
      _logger.info('Genders: $_genderOptions');
      _logger.info('Game Styles: $_gameStyleOptions');
      _logger.info('Looking For: $_lookingForOptions');
      _logger.info('Interests: $_interestOptions');
    } catch (e) {
      _error = e.toString();
      _logger.severe('Error loading options: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadOptionsFromFirestore(
    String docName,
    String langCode,
    Function(List<String>) onData,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configurations')
          .doc(docName)
          .get();

      final data = doc.data();
      if (data != null && data['values'] is List) {
        final rawList = List<Map<String, dynamic>>.from(data['values']);
        final localizedList = rawList
            .map((item) => item[langCode] ?? item['vi'])
            .whereType<String>() // Lọc ra đúng kiểu String
            .toList();

        onData(localizedList);
      }
    } catch (e) {
      _logger.severe('Error loading $docName: $e');
      _error = 'Lỗi khi tải $docName: $e';
    }
  }
}
