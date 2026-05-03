import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gamenect_new/core/widgets/profile_card.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/edit_profile_provider.dart';
import '../../../core/providers/location_provider.dart';

import 'avatar_picker_section.dart';
import 'basic_info_section.dart';
import 'gaming_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _usernameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _heightController = TextEditingController(text: '160');
  final _bioController = TextEditingController();
  
  String? _rank = 'Gà Mờ';
  int _playTime = 0;
  int _winRate = 0;
  List<String> _favoriteGames = [];
  List<String> _searchResultGames = [];
  bool _isSearching = false;
  
  bool _isLoading = true;
  bool _isUpdating = false;
  
  final String _apiKey = dotenv.env['RAWG_API_KEY']!;
  final FirestoreService _firestoreService = FirestoreService();
  
  File? _avatarImage;
  String? _avatarUrl;
  
  final List<File> _additionalImages = [];
  List<String> _additionalPhotoUrls = [];
  
  final ImagePicker _picker = ImagePicker();

  String _gender = 'Nam';
  List<String> _interests = [];
  String _lookingFor = 'Bạn chơi game';
  String _gameStyle = 'Casual';

  final List<String> _hotGames = [
    "League of Legends", "Arena of Valor", "Free Fire", "Genshin Impact",
    "PUBG Mobile", "Valorant", "Call of Duty: Mobile", "FIFA Online 4",
    "Minecraft", "Mobile Legends",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EditProfileProvider>().initialize();
      _loadLocation();
    });
    _initializeData();
  }

  Future<void> _loadLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLocation == null) {
      await locationProvider.getCurrentLocation();
    }
  }

  Future<void> _initializeData() async {
    try {
      await _loadUserProfile();
    } catch (e) {
      developer.log('Error init data', name: 'EditProfile', error: e);
    }
  }

  Future<void> _searchGames(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResultGames = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    try {
      final response = await http.get(Uri.parse('https://api.rawg.io/api/games?key=$_apiKey&search=$query&page_size=10'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final games = data['results'] as List;
        setState(() {
          _searchResultGames = games.map((game) => game['name'] as String).toList();
        });
      }
    } catch (e) {
      setState(() {
        _searchResultGames = [];
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await _firestoreService.getUser(user.uid);
        if (!mounted) return;
        final provider = Provider.of<EditProfileProvider>(context, listen: false);
        
        if (userData != null) {
          setState(() {
            _isUpdating = true;
            _usernameController.text = userData.username;
            _rank = userData.rank;
            _favoriteGames = userData.favoriteGames;
            _playTime = userData.playTime;
            _winRate = userData.winRate;
            _avatarUrl = userData.avatarUrl;
            _additionalPhotoUrls = userData.additionalPhotos;

            _gender = provider.genderOptions.contains(userData.gender) ? userData.gender : 'Nam';
            _lookingFor = provider.lookingForOptions.contains(userData.lookingFor) ? userData.lookingFor : 'Bạn chơi game';
            _gameStyle = provider.gameStyleOptions.contains(userData.gameStyle) ? userData.gameStyle : 'Casual';

            final dateFormat = DateFormat('dd/MM/yyyy');
            _birthDateController.text = dateFormat.format(userData.dateOfBirth);
            _heightController.text = userData.height.toString();
            _bioController.text = userData.bio;
            _interests = userData.interests;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể tải hồ sơ: $e')));
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickAvatar() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickAdditionalPhoto() async {
    final currentPhotoCount = _additionalPhotoUrls.length + _additionalImages.length;
    if (currentPhotoCount >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chỉ được phép thêm tối đa 4 ảnh')));
      return;
    }
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _additionalImages.add(File(pickedFile.path));
      });
    }
  }
  
  Future<void> _editAdditionalPhoto(int index) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (index < _additionalPhotoUrls.length) {
          _additionalPhotoUrls.removeAt(index);
          _additionalImages.add(File(pickedFile.path));
        } else {
          _additionalImages[index - _additionalPhotoUrls.length] = File(pickedFile.path);
        }
      });
    }
  }

  void _removeAdditionalPhoto(int index) {
    setState(() {
      if (index < _additionalPhotoUrls.length) {
        _additionalPhotoUrls.removeAt(index);
      } else {
        _additionalImages.removeAt(index - _additionalPhotoUrls.length);
      }
    });
  }

  Future<void> _uploadImages(String userId) async {
    try {
      if (_avatarImage != null) {
        final avatarFileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _avatarUrl = await _firestoreService.uploadImage(_avatarImage!, userId, avatarFileName);
        if (_avatarUrl == null) throw Exception('Không thể tải lên ảnh đại diện');
      }

      List<String> newPhotoUrls = List.from(_additionalPhotoUrls);
      for (int i = 0; i < _additionalImages.length; i++) {
        final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final url = await _firestoreService.uploadImage(_additionalImages[i], userId, fileName);
        if (url != null) {
          newPhotoUrls.add(url);
        } else {
          throw Exception('Không thể tải lên ảnh bổ sung');
        }
      }
      _additionalPhotoUrls = newPhotoUrls;
    } catch (e) {
      throw Exception('Lỗi khi tải ảnh lên: $e');
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _heightController.dispose();
    _bioController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate() && _rank != null && _favoriteGames.isNotEmpty) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          setState(() { _isLoading = true; });
          await _uploadImages(user.uid);
          
          final dateParts = _birthDateController.text.split('/');
          final birthDate = DateTime(int.parse(dateParts[2]), int.parse(dateParts[1]), int.parse(dateParts[0]));
          
          if (!mounted) return;
          final locationProvider = Provider.of<LocationProvider>(context, listen: false);
          if (locationProvider.currentLocation == null) {
            await locationProvider.getCurrentLocation();
            await locationProvider.updateUserLocation(user.uid);
          }

          final locationText = locationProvider.currentLocation ?? locationProvider.address ?? locationProvider.city ?? 'Không xác định';

          UserModel newUser = UserModel(
            id: user.uid,
            username: _usernameController.text,
            favoriteGames: _favoriteGames,
            rank: _rank!,
            location: locationText,
            playTime: _playTime,
            winRate: _winRate,
            avatarUrl: _avatarUrl,
            additionalPhotos: _additionalPhotoUrls,
            latitude: locationProvider.latitude,
            longitude: locationProvider.longitude,
            address: locationProvider.address,
            city: locationProvider.city,
            country: locationProvider.country,
            gender: _gender,
            dateOfBirth: birthDate,
            age: _calculateAge(birthDate),
            height: int.parse(_heightController.text),
            bio: _bioController.text,
            interests: _interests,
            lookingFor: _lookingFor,
            gameStyle: _gameStyle,
          );
          
          await _firestoreService.addUser(newUser);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isUpdating ? 'Cập nhật hồ sơ thành công!' : 'Tạo hồ sơ thành công!')));
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(newUser.username), backgroundColor: Colors.white, foregroundColor: Colors.deepOrange),
                backgroundColor: Colors.white,
                body: Center(child: ProfileCard(user: newUser)),
              ),
            ),
          );
        } catch (e) {
          developer.log('Error saving profile', name: 'EditProfile', error: e);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu hồ sơ thất bại: $e')));
        } finally {
          if (mounted) setState(() { _isLoading = false; });
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin và chọn ít nhất một game!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF101012),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40))),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF101012),
      appBar: AppBar(
        title: Text(_isUpdating ? 'Chỉnh sửa hồ sơ' : 'Tạo hồ sơ', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Orbs
          Positioned(
            top: 50, right: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6E40).withValues(alpha: 0.12),
                boxShadow: [BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.1), blurRadius: 100, spreadRadius: 40)],
              ),
            ),
          ),
          Positioned(
            bottom: -80, left: -80,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBF360C).withValues(alpha: 0.15),
                boxShadow: [BoxShadow(color: const Color(0xFFBF360C).withValues(alpha: 0.1), blurRadius: 120, spreadRadius: 50)],
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),
          
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: 420,
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Consumer<EditProfileProvider>(
                            builder: (context, provider, child) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Hình ảnh', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 18),
                                  AvatarPickerSection(
                                    avatarImage: _avatarImage,
                                    avatarUrl: _avatarUrl,
                                    additionalImages: _additionalImages,
                                    additionalPhotoUrls: _additionalPhotoUrls,
                                    onPickAvatar: _pickAvatar,
                                    onPickAdditionalPhoto: _pickAdditionalPhoto,
                                    onEditAdditionalPhoto: _editAdditionalPhoto,
                                    onRemoveAdditionalPhoto: _removeAdditionalPhoto,
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  Text('Thông tin cơ bản', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 18),
                                  BasicInfoSection(
                                    usernameController: _usernameController,
                                    birthDateController: _birthDateController,
                                    heightController: _heightController,
                                    bioController: _bioController,
                                    gender: _gender,
                                    onGenderChanged: (v) => setState(() => _gender = v!),
                                    genderOptions: provider.genderOptions,
                                    interests: _interests,
                                    onInterestsChanged: (v) => setState(() => _interests = v),
                                    interestOptions: provider.interestOptions,
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  Text('Thông tin Gaming', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 18),
                                  GamingSection(
                                    rank: _rank,
                                    onRankChanged: (v) => setState(() => _rank = v),
                                    rankOptions: provider.rankOptions,
                                    favoriteGames: _favoriteGames,
                                    onFavoriteGamesChanged: (v) => setState(() => _favoriteGames = v),
                                    isSearching: _isSearching,
                                    searchResultGames: _searchResultGames,
                                    hotGames: _hotGames,
                                    onSearchGames: _searchGames,
                                    playTime: _playTime,
                                    onPlayTimeChanged: (v) => setState(() => _playTime = v),
                                    winRate: _winRate,
                                    onWinRateChanged: (v) => setState(() => _winRate = v),
                                    gameStyle: _gameStyle,
                                    onGameStyleChanged: (v) => setState(() => _gameStyle = v!),
                                    gameStyleOptions: provider.gameStyleOptions,
                                    lookingFor: _lookingFor,
                                    onLookingForChanged: (v) => setState(() => _lookingFor = v!),
                                    lookingForOptions: provider.lookingForOptions,
                                  ),
                                  const SizedBox(height: 32),
                                  
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF6E40).withValues(alpha: 0.3),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _handleSave,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF6E40),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          _isUpdating ? 'Cập nhật hồ sơ' : 'Lưu hồ sơ',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
