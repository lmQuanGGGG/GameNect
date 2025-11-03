import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gamenect_new/core/widgets/profile_card.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
//import '../user_app.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/providers/edit_profile_provider.dart';
import '../../core/providers/location_provider.dart';

// Màn hình tạo/chỉnh sửa hồ sơ cá nhân
// Cho phép user nhập đầy đủ thông tin: avatar, game yêu thích, thống kê game, thông tin cá nhân
// Tích hợp RAWG API để tìm kiếm game và lấy vị trí GPS để matching
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers cho các text field
  final _usernameController = TextEditingController();
  final _birthDateController = TextEditingController();
  String? _rank = 'Gà Mờ';
  int _playTime = 0;
  int _winRate = 0;
  final List<String> _hotGames = [
    "League of Legends",
    "Arena of Valor",
    "Free Fire",
    "Genshin Impact",
    "PUBG Mobile",
    "Valorant",
    "Call of Duty: Mobile",
    "FIFA Online 4",
    "Minecraft",
    "Mobile Legends",
  ];
  List<String> _favoriteGames = [];
  List<String> _searchResultGames = [];
  bool _isSearching = false;
  bool _isLoading = true;
  bool _isUpdating = false;
  final String _apiKey = dotenv.env['RAWG_API_KEY']!;
  final FirestoreService _firestoreService = FirestoreService();
  File? _avatarImage;
  String? _avatarUrl;
  List<File> _additionalImages = [];
  List<String> _additionalPhotoUrls = [];
  final ImagePicker _picker = ImagePicker();

  String _gender = 'Nam';
  final _heightController = TextEditingController(text: '160');
  final _bioController = TextEditingController();
  List<String> _interests = [];
  String _lookingFor = 'Bạn chơi game';
  String _gameStyle = 'Casual';

  @override
  void initState() {
    super.initState();
    // Khởi tạo EditProfileProvider sau khi build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EditProfileProvider>().initialize();
      _loadLocation(); // Load vị trí GPS
    });
    _initializeData();
  }

  // Load vị trí hiện tại từ GPS
  // Dùng để matching user gần nhau
  Future<void> _loadLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    if (locationProvider.currentLocation == null) {
      developer.log('Chưa có location, đang lấy từ GPS...', name: 'EditProfile');
      await locationProvider.getCurrentLocation();
    }
    
    developer.log('Location loaded: ${locationProvider.currentLocation}', name: 'EditProfile');
  }

  // Khởi tạo dữ liệu ban đầu
  Future<void> _initializeData() async {
    try {
      await _loadUserProfile(); // Load profile nếu đã có
    } catch (e) {
      developer.log('Error initializing data', name: 'EditProfile', error: e);
    }
  }

  // Tìm kiếm game từ RAWG API
  // API trả về danh sách game match với query
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
      // Call RAWG API với query và page_size=10
      final response = await http.get(
        Uri.parse(
          'https://api.rawg.io/api/games?key=$_apiKey&search=$query&page_size=10',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final games = data['results'] as List;
        setState(() {
          // Map kết quả thành list tên game
          _searchResultGames = games
              .map((game) => game['name'] as String)
              .toList();
        });
      }
    } catch (e) {
      setState(() {
        _searchResultGames = [];
      });
    }
  }

  // Load thông tin profile hiện tại của user từ Firestore
  // Nếu có rồi thì fill vào các field để chỉnh sửa
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await _firestoreService.getUser(user.uid);
        final provider = Provider.of<EditProfileProvider>(context, listen: false);
        
        if (userData != null) {
          setState(() {
            _isUpdating = true; // Đánh dấu đang update profile
            
            // Fill dữ liệu vào các field
            _usernameController.text = userData.username;
            _rank = userData.rank;
            _favoriteGames = userData.favoriteGames;
            _playTime = userData.playTime;
            _winRate = userData.winRate;
            _avatarUrl = userData.avatarUrl;
            _additionalPhotoUrls = userData.additionalPhotos;

            // Validate các giá trị từ provider options
            _gender = provider.genderOptions.contains(userData.gender)
                ? userData.gender
                : 'Nam';
            _lookingFor = provider.lookingForOptions.contains(userData.lookingFor)
                ? userData.lookingFor
                : 'Bạn chơi game';
            _gameStyle = provider.gameStyleOptions.contains(userData.gameStyle)
                ? userData.gameStyle
                : 'Casual';

            // Format ngày sinh theo dd/MM/yyyy
            final dateFormat = DateFormat('dd/MM/yyyy');
            _birthDateController.text = dateFormat.format(userData.dateOfBirth);
            _heightController.text = userData.height.toString();
            _bioController.text = userData.bio;
            _interests = userData.interests;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải hồ sơ: $e')),
        );
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  // Chọn ảnh đại diện từ gallery
  Future<void> _pickAvatar() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
      });
    }
  }

  // Chọn ảnh bổ sung từ gallery
  // Giới hạn tối đa 4 ảnh
  Future<void> _pickAdditionalPhoto() async {
    final currentPhotoCount = _additionalPhotoUrls.length + _additionalImages.length;
    if (currentPhotoCount >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ được phép thêm tối đa 4 ảnh')),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _additionalImages.add(File(pickedFile.path));
      });
    }
  }

  // Upload tất cả ảnh (avatar + additional) lên Firebase Storage
  // Trả về URL để lưu vào Firestore
  Future<void> _uploadImages(String userId) async {
    try {
      // Upload avatar nếu có chọn ảnh mới
      if (_avatarImage != null) {
        final avatarFileName =
            'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _avatarUrl = await _firestoreService.uploadImage(
          _avatarImage!,
          userId,
          avatarFileName,
        );
        if (_avatarUrl == null) {
          throw Exception('Không thể tải lên ảnh đại diện');
        }
      }

      // Upload các ảnh bổ sung mới
      List<String> newPhotoUrls = List.from(_additionalPhotoUrls);

      for (int i = 0; i < _additionalImages.length; i++) {
        final fileName =
            'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final url = await _firestoreService.uploadImage(
          _additionalImages[i],
          userId,
          fileName,
        );

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

  @override
  void dispose() {
    // Dispose tất cả controllers
    _usernameController.dispose();
    _heightController.dispose();
    _bioController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // Tính tuổi từ ngày sinh
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    // Điều chỉnh nếu chưa qua sinh nhật năm nay
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // Validate format ngày sinh: dd/MM/yyyy
  // Kiểm tra ngày hợp lệ và phải đủ 18 tuổi
  bool _isValidDate(String input) {
    if (input.isEmpty) return false;

    // Regex check format dd/MM/yyyy
    final RegExp dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegex.hasMatch(input)) return false;

    final parts = input.split('/');
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    // Kiểm tra năm sinh hợp lệ (từ 1950 đến hiện tại - 18)
    final now = DateTime.now();
    final minYear = 1950;
    final maxYear = now.year - 18; // Phải đủ 18 tuổi
    if (year < minYear || year > maxYear) return false;

    // Kiểm tra ngày hợp lệ trong tháng (tháng 2 có 28/29 ngày)
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInMonth) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isUpdating ? 'Chỉnh sửa hồ sơ' : 'Tạo hồ sơ',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade900.withValues(alpha: 0.85),
                    Colors.deepOrange.shade400.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Content với glassmorphism effect
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Column(
                children: [
                  SizedBox(height: kToolbarHeight + 24),
                  // Container chứa form với glassmorphism
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: 420,
                        constraints: BoxConstraints(maxWidth: 500),
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.10),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? Center(child: CircularProgressIndicator())
                            : Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Thông tin cá nhân
                                    Text(
                                      'Thông tin cá nhân',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                    SizedBox(height: 18),
                                    
                                    // Avatar picker - CircleAvatar có thể tap để chọn ảnh
                                    Center(
                                      child: GestureDetector(
                                        onTap: _pickAvatar,
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundImage: _avatarImage != null
                                              ? FileImage(_avatarImage!)
                                              : (_avatarUrl != null
                                                    ? CachedNetworkImageProvider(_avatarUrl!)
                                                    : null),
                                          child:
                                              _avatarImage == null &&
                                                  _avatarUrl == null
                                              ? Icon(
                                                  Icons.person,
                                                  size: 50,
                                                  color: Colors.grey,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Center(
                                      child: TextButton(
                                        onPressed: _pickAvatar,
                                        child: Text(
                                          'Chọn ảnh đại diện',
                                          style: TextStyle(
                                            color: Colors.deepOrange[400],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // Section ảnh bổ sung
                                    Text(
                                      'Ảnh bổ sung (tối đa 4)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange[400],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    // Horizontal scroll để hiển thị và thêm ảnh bổ sung
                                    SizedBox(
                                      height: 100,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        // itemCount = số ảnh hiện có + 1 nút Add (nếu chưa đủ 4)
                                        itemCount: _additionalImages.length + _additionalPhotoUrls.length + 
                                          (_additionalImages.length + _additionalPhotoUrls.length < 4 ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          // Item cuối cùng là nút Add
                                          if (index == _additionalImages.length + _additionalPhotoUrls.length &&
                                              _additionalImages.length + _additionalPhotoUrls.length < 4) {
                                            return GestureDetector(
                                              onTap: _pickAdditionalPhoto,
                                              child: Container(
                                                width: 100,
                                                height: 100,
                                                margin: EdgeInsets.only(right: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(Icons.add, color: Colors.white),
                                              ),
                                            );
                                          }

                                          // Các item khác là ảnh đã chọn với nút Edit và Delete
                                          return Stack(
                                            children: [
                                              // Ảnh preview
                                              GestureDetector(
                                                onTap: () => _editAdditionalPhoto(index),
                                                child: Container(
                                                  width: 100,
                                                  height: 100,
                                                  margin: EdgeInsets.only(right: 8),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    image: DecorationImage(
                                                      // Hiển thị từ URL hoặc File tùy index
                                                      image: index < _additionalPhotoUrls.length
                                                          ? CachedNetworkImageProvider(_additionalPhotoUrls[index])
                                                          : FileImage(_additionalImages[index - _additionalPhotoUrls.length]) as ImageProvider,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Nút Delete ở góc trên
                                              Positioned(
                                                top: 4,
                                                right: 12,
                                                child: GestureDetector(
                                                  onTap: () => _removeAdditionalPhoto(index),
                                                  child: Container(
                                                    padding: EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Nút Edit ở góc dưới
                                              Positioned(
                                                bottom: 4,
                                                right: 12,
                                                child: GestureDetector(
                                                  onTap: () => _editAdditionalPhoto(index),
                                                  child: Container(
                                                    padding: EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.deepOrange,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.edit,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // TextField: Tên người dùng
                                    TextFormField(
                                      controller: _usernameController,
                                      decoration: InputDecoration(
                                        labelText: 'Tên người dùng',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.85),
                                      ),
                                      validator: (value) => value!.isEmpty
                                          ? 'Vui lòng nhập tên người dùng'
                                          : null,
                                    ),
                                    SizedBox(height: 14),
                                    
                                    // Dropdown: Chọn rank game
                                    Consumer<EditProfileProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButtonFormField<String>(
                                         initialValue: _rank,
                                          hint: Text('Chọn rank'),
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha: 0.85),
                                          ),
                                          items: provider.rankOptions
                                              .map((rank) => DropdownMenuItem(
                                                    value: rank,
                                                    child: Text(rank),
                                                  ))
                                              .toList(),
                                          onChanged: (value) => setState(() => _rank = value),
                                          validator: (value) => value == null ? 'Vui lòng chọn rank' : null,
                                        );
                                      },
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // Section: Game yêu thích
                                    Text(
                                      "Game yêu thích (tối đa 5)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange[400],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    
                                    // TextField: Tìm kiếm game từ RAWG API
                                    TextFormField(
                                      decoration: InputDecoration(
                                        hintText: "Tìm kiếm game...",
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.85),
                                      ),
                                      onChanged: _searchGames, // Gọi API khi user gõ
                                    ),
                                    SizedBox(height: 8),
                                    
                                    // MultiSelectDialogField: Chọn nhiều game từ danh sách
                                    // Hiển thị kết quả search hoặc hot games
                                    MultiSelectDialogField<String>(
                                      items:
                                          (_isSearching &&
                                                      _searchResultGames
                                                          .isNotEmpty
                                                  ? _searchResultGames
                                                  : _hotGames)
                                              .map((e) => MultiSelectItem(e, e))
                                              .toList(),
                                      initialValue: _favoriteGames,
                                      title: Text("Chọn game"),
                                      selectedColor: Colors.deepOrange,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                        border: Border.all(
                                          color: Colors.deepOrange,
                                          width: 2,
                                        ),
                                      ),
                                      buttonIcon: Icon(
                                        Icons.videogame_asset,
                                        color: Colors.deepOrange[400],
                                      ),
                                      buttonText: Text(
                                        "Chọn tối đa 5 game",
                                        style: TextStyle(
                                          color: Colors.deepOrange[400],
                                          fontSize: 16,
                                        ),
                                      ),
                                      // Callback khi chọn/bỏ chọn game
                                      onSelectionChanged: (selectedList) {
                                        if (selectedList.length > 5) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Chỉ được chọn tối đa 5 game!',
                                              ),
                                            ),
                                          );
                                          selectedList.removeLast();
                                        }
                                      },
                                      // Callback khi confirm chọn
                                      onConfirm: (results) {
                                        if (results.length > 5) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Chỉ được chọn tối đa 5 game!',
                                              ),
                                            ),
                                          );
                                          setState(() {
                                            _favoriteGames = results.sublist(
                                              0,
                                              5,
                                            );
                                          });
                                        } else {
                                          setState(() {
                                            _favoriteGames = results;
                                          });
                                        }
                                      },
                                      validator: (values) =>
                                          values == null || values.isEmpty
                                          ? "Chọn ít nhất 1 game"
                                          : null,
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // TextField: Thời gian chơi game/ngày
                                    TextFormField(
                                      initialValue: _playTime.toString(),
                                      decoration: InputDecoration(
                                        labelText: 'Thời gian chơi (phút/ngày)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.85),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) => setState(() {
                                        _playTime =
                                            int.tryParse(value) ??
                                            _playTime;
                                      }),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Vui lòng nhập thời gian chơi';
                                        }
                                        if (int.tryParse(value) == null) {
                                          return 'Nhập số hợp lệ';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 14),
                                    
                                    // TextField: Tỷ lệ thắng (%)
                                    TextFormField(
                                      initialValue: _winRate.toString(),
                                      decoration: InputDecoration(
                                        labelText: 'Tỷ lệ thắng (%)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.85),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) => setState(() {
                                        _winRate =
                                            int.tryParse(value) ??
                                            _winRate;
                                      }),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Vui lòng nhập tỷ lệ thắng';
                                        }
                                        final number = int.tryParse(value);
                                        if (number == null) {
                                          return 'Nhập số hợp lệ';
                                        }
                                        if (number < 0 || number > 100) {
                                          return 'Tỷ lệ thắng phải từ 0 đến 100%';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // Header: Thông tin cá nhân
                                    Text(
                                      'Thông tin cá nhân',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange[400],
                                      ),
                                    ),
                                    SizedBox(height: 14),
                                    
                                    // Dropdown: Giới tính
                                    Consumer<EditProfileProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButtonFormField<String>(
                                         initialValue: _gender,
                                          hint: Text('Chọn giới tính'),
                                          decoration: InputDecoration(
                                            labelText: 'Giới tính',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha: 0.85),
                                          ),
                                          items: provider.genderOptions
                                              .map((gender) => DropdownMenuItem(
                                                    value: gender,
                                                    child: Text(gender),
                                                  ))
                                              .toList(),
                                          onChanged: (value) => setState(() => _gender = value!),
                                        );
                                      },
                                    ),
                                    SizedBox(height: 14),
                                    
                                    // TextField: Ngày sinh với format dd/MM/yyyy
                                    TextFormField(
                                      controller: _birthDateController,
                                      decoration: InputDecoration(
                                        labelText: 'Ngày sinh (dd/MM/yyyy)',
                                        hintText: 'VD: 25/12/1990',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.85),
                                        suffixIcon: Icon(
                                          Icons.calendar_today,
                                          color: Colors.deepOrange,
                                        ),
                                        helperText:
                                            'Nhập theo định dạng: ngày/tháng/năm',
                                      ),
                                      keyboardType: TextInputType.datetime,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Vui lòng nhập ngày sinh';
                                        }
                                        if (!_isValidDate(value)) {
                                          return 'Ngày sinh không hợp lệ (phải đủ 18 tuổi)';
                                        }
                                        return null;
                                      },
                                      // Tự động thêm dấu "/" khi nhập
                                      onChanged: (value) {
                                        if (value.length == 2 &&
                                            !value.contains('/')) {
                                          _birthDateController.text = '$value/';
                                          _birthDateController.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: _birthDateController
                                                      .text
                                                      .length,
                                                ),
                                              );
                                        } else if (value.length == 5 &&
                                            value.split('/').length == 2) {
                                          _birthDateController.text = '$value/';
                                          _birthDateController.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: _birthDateController
                                                      .text
                                                      .length,
                                                ),
                                              );
                                        }
                                      },
                                    ),
                                    SizedBox(height: 14),
                                    
                                    // TextField: Chiều cao
                                    TextFormField(
                                      controller: _heightController,
                                      decoration: InputDecoration(
                                        labelText: 'Chiều cao (cm)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.85),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty)
                                          return 'Vui lòng nhập chiều cao';
                                        final height = int.tryParse(value);
                                        if (height == null ||
                                            height < 140 ||
                                            height > 220)
                                          return 'Chiều cao phải từ 140-220cm';
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 14),
                                    
                                    // TextField: Bio - giới thiệu bản thân
                                    TextFormField(
                                      controller: _bioController,
                                      decoration: InputDecoration(
                                        labelText: 'Giới thiệu bản thân',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.85),
                                      ),
                                      maxLines: 3,
                                      maxLength: 200, // Giới hạn 200 ký tự
                                    ),
                                    SizedBox(height: 14),
                                    
                                    // MultiSelectDialogField: Chọn sở thích khác
                                    Consumer<EditProfileProvider>(
                                      builder: (context, provider, child) {
                                        return MultiSelectDialogField<String>(
                                          items: provider.interestOptions
                                              .map((e) => MultiSelectItem(e, e))
                                              .toList(),
                                          initialValue: _interests,
                                          title: Text("Sở thích khác"),
                                          selectedColor: Colors.deepOrange,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.deepOrange,
                                            ),
                                          ),
                                          buttonIcon: Icon(
                                            Icons.interests,
                                            color: Colors.deepOrange[400],
                                          ),
                                          buttonText: Text(
                                            "Chọn sở thích",
                                            style: TextStyle(
                                              color: Colors.deepOrange[400],
                                            ),
                                          ),
                                          onConfirm: (values) => setState(() => _interests = values),
                                        );
                                      },
                                    ),
                                    SizedBox(height: 14),
                                    
                                    // Dropdown: Mục đích tìm kiếm
                                    Consumer<EditProfileProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButtonFormField<String>(
                                         initialValue: _lookingFor,
                                          hint: Text('Chọn mục đích'),
                                          decoration: InputDecoration(
                                            labelText: 'Mục đích tìm kiếm',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha: 0.85),
                                          ),
                                          items: provider.lookingForOptions
                                              .map((option) => DropdownMenuItem(
                                                    value: option,
                                                    child: Text(option),
                                                  ))
                                              .toList(),
                                          onChanged: (value) => setState(() => _lookingFor = value!),
                                        );
                                      },
                                    ),
                                    SizedBox(height: 14),
                                    
                                    // Dropdown: Phong cách chơi game
                                    Consumer<EditProfileProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButtonFormField<String>(
                                         initialValue: _gameStyle,
                                          hint: Text('Chọn phong cách'),
                                          decoration: InputDecoration(
                                            labelText: 'Phong cách chơi game',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha: 0.85),
                                          ),
                                          items: provider.gameStyleOptions
                                              .map((style) => DropdownMenuItem(
                                                    value: style,
                                                    child: Text(style),
                                                  ))
                                              .toList(),
                                          onChanged: (value) => setState(() => _gameStyle = value!),
                                        );
                                      },
                                    ),
                                    SizedBox(height: 24),
                                    
                                    // Nút Lưu/Cập nhật hồ sơ
                                    Center(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          // Validate form và các field bắt buộc
                                          if (_formKey.currentState!.validate() &&
                                              _rank != null &&
                                              _favoriteGames.isNotEmpty) {
                                            User? user = FirebaseAuth.instance.currentUser;
                                            if (user != null) {
                                              try {
                                                setState(() {
                                                  _isLoading = true;
                                                });
                                                
                                                // Upload tất cả ảnh lên Firebase Storage
                                                await _uploadImages(user.uid);
                                                
                                                // Parse ngày sinh từ string dd/MM/yyyy
                                                final dateParts =
                                                    _birthDateController.text.split('/');
                                                final birthDate = DateTime(
                                                  int.parse(dateParts[2]),
                                                  int.parse(dateParts[1]),
                                                  int.parse(dateParts[0]),
                                                );

                                                // Lấy vị trí GPS từ LocationProvider
                                                final locationProvider = Provider.of<LocationProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                                
                                                // Nếu chưa có location thì lấy từ GPS
                                                if (locationProvider.currentLocation == null) {
                                                  developer.log('Đang lấy location từ GPS...', name: 'EditProfile');
                                                  await locationProvider.getCurrentLocation();
                                                  await locationProvider.updateUserLocation(user.uid);
                                                }

                                                // Format location text để hiển thị
                                                final locationText = locationProvider.currentLocation ?? 
                                                                    locationProvider.address ?? 
                                                                    locationProvider.city ?? 
                                                                    'Không xác định';

                                                developer.log('Saving profile with location: $locationText', name: 'EditProfile');
                                                developer.log('Full address: ${locationProvider.address}', name: 'EditProfile');
                                                developer.log('City: ${locationProvider.city}', name: 'EditProfile');

                                                // Tạo UserModel với tất cả thông tin
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
                                                  // Lưu tọa độ GPS để matching theo khoảng cách
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
                                                
                                                // Lưu vào Firestore
                                                await _firestoreService.addUser(newUser);
                                                
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      _isUpdating
                                                          ? 'Cập nhật hồ sơ thành công!'
                                                          : 'Tạo hồ sơ thành công!',
                                                    ),
                                                  ),
                                                );

                                                // Sau khi lưu, chuyển sang màn hình xem profile card
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => Scaffold(
                                                      appBar: AppBar(
                                                        title: Text(newUser.username),
                                                        backgroundColor: Colors.white,
                                                        foregroundColor: Colors.deepOrange,
                                                      ),
                                                      backgroundColor: Colors.white,
                                                      body: Center(
                                                        child: ProfileCard(user: newUser),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                developer.log('Error saving profile', name: 'EditProfile', error: e);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Lưu hồ sơ thất bại: $e'),
                                                  ),
                                                );
                                              } finally {
                                                setState(() {
                                                  _isLoading = false;
                                                });
                                              }
                                            }
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Vui lòng điền đầy đủ thông tin và chọn ít nhất một game!',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepOrange[400],
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 40,
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 8,
                                          shadowColor: Colors.deepOrange,
                                        ),
                                        child: Text(
                                          _isUpdating
                                              ? 'Cập nhật hồ sơ'
                                              : 'Lưu hồ sơ',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
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

  // Chỉnh sửa ảnh bổ sung tại index
  // Cho phép user chọn ảnh mới thay thế
  Future<void> _editAdditionalPhoto(int index) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (index < _additionalPhotoUrls.length) {
          // Xóa URL cũ và thêm file mới vào list để upload
          _additionalPhotoUrls.removeAt(index);
          _additionalImages.add(File(pickedFile.path));
        } else {
          // Thay thế file cũ
          _additionalImages[index - _additionalPhotoUrls.length] = File(
            pickedFile.path,
          );
        }
      });
    }
  }

  // Xóa ảnh bổ sung tại index
  void _removeAdditionalPhoto(int index) {
    setState(() {
      if (index < _additionalPhotoUrls.length) {
        _additionalPhotoUrls.removeAt(index);
      } else {
        _additionalImages.removeAt(index - _additionalPhotoUrls.length);
      }
    });
  }
}
