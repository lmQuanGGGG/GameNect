import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../user_app.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/providers/edit_profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _birthDateController = TextEditingController();
  String? _rank = 'Gà Mờ'; // Thêm ? để cho phép null
  String? _location;
  String? _district;
  String? _ward;
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
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _wards = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  final String _apiKey = dotenv.env['RAWG_API_KEY']!;
  final FirestoreService _firestoreService = FirestoreService();
  File? _avatarImage;
  String? _avatarUrl;
  List<File> _additionalImages = [];
  List<String> _additionalPhotoUrls = [];
  final ImagePicker _picker = ImagePicker();

  // Sửa lại giá trị mặc định
  String _gender = 'Nam';
  final _heightController = TextEditingController(text: '160');
  final _bioController = TextEditingController();
  List<String> _interests = [];
  String _lookingFor = 'Bạn chơi game';
  String _gameStyle = 'Casual';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EditProfileProvider>().initialize();
    });
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // 1. Fetch provinces first
      await _fetchProvinces();

      // 2. Then load user profile
      await _loadUserProfile();
    } catch (e) {
      print('Error initializing data: $e');
    }
  }

  Future<void> _fetchProvinces() async {
    try {
      final response = await http.get(
        Uri.parse('https://provinces.open-api.vn/api/?depth=1'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _provinces = List<Map<String, dynamic>>.from(
            json.decode(response.body),
          );
        });
      } else {
        throw Exception('Không thể tải danh sách tỉnh/thành phố');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải danh sách tỉnh/thành phố: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDistricts(String provinceCode) async {
    setState(() {
      _districts = [];
      _wards = [];
      _district = null;
      _ward = null;
    });
    try {
      final response = await http.get(
        Uri.parse('https://provinces.open-api.vn/api/p/$provinceCode?depth=2'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _districts = List<Map<String, dynamic>>.from(data['districts']);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchWards(String districtCode) async {
    setState(() {
      _wards = [];
      _ward = null;
    });
    try {
      final response = await http.get(
        Uri.parse('https://provinces.open-api.vn/api/d/$districtCode?depth=2'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _wards = List<Map<String, dynamic>>.from(data['wards']);
        });
      }
    } catch (_) {}
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
      final response = await http.get(
        Uri.parse(
          'https://api.rawg.io/api/games?key=$_apiKey&search=$query&page_size=10',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final games = data['results'] as List;
        setState(() {
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

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await _firestoreService.getUser(user.uid);
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

            // Sử dụng provider để kiểm tra giá trị
            _gender = provider.genderOptions.contains(userData.gender)
                ? userData.gender
                : 'Nam';
            _lookingFor = provider.lookingForOptions.contains(userData.lookingFor)
                ? userData.lookingFor
                : 'Bạn chơi game';
            _gameStyle = provider.gameStyleOptions.contains(userData.gameStyle)
                ? userData.gameStyle
                : 'Casual';

            // Giữ nguyên phần còn lại
            final dateFormat = DateFormat('dd/MM/yyyy');
            _birthDateController.text = dateFormat.format(userData.dateOfBirth);
            _heightController.text = userData.height.toString();
            _bioController.text = userData.bio;
            _interests = userData.interests;
          });

          // Xử lý địa chỉ sau khi đã có provinces
          final locationParts = userData.location.split(', ');
          if (locationParts.length == 3) {
            setState(() {
              _location = locationParts[0];
            });

            // Tìm province code
            final selectedProvince = _provinces.firstWhere(
              (p) => p['name'] == _location,
              orElse: () => {},
            );

            if (selectedProvince.isNotEmpty) {
              // Fetch districts
              await _fetchDistricts(selectedProvince['code'].toString());

              setState(() {
                _district = locationParts[1];
              });

              // Tìm district code
              final selectedDistrict = _districts.firstWhere(
                (d) => d['name'] == _district,
                orElse: () => {},
              );

              if (selectedDistrict.isNotEmpty) {
                // Fetch wards
                await _fetchWards(selectedDistrict['code'].toString());

                setState(() {
                  _ward = locationParts[2];
                });
              }
            }
          }
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

  Future<void> _pickAvatar() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickAdditionalPhoto() async {
    // Kiểm tra tổng số ảnh hiện tại
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

  Future<void> _uploadImages(String userId) async {
    try {
      // Upload avatar image if changed
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

      // Keep existing photo URLs
      List<String> newPhotoUrls = List.from(_additionalPhotoUrls);

      // Upload new additional images
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

      // Update the list after all uploads are successful
      _additionalPhotoUrls = newPhotoUrls;
    } catch (e) {
      throw Exception('Lỗi khi tải ảnh lên: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _heightController.dispose();
    _bioController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // Thêm phương thức tính tuổi
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  bool _isValidDate(String input) {
    if (input.isEmpty) return false;

    // Format dd/MM/yyyy
    final RegExp dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegex.hasMatch(input)) return false;

    final parts = input.split('/');
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    // Kiểm tra năm hợp lệ (từ 1950 đến hiện tại - 18)
    final now = DateTime.now();
    final minYear = 1950;
    final maxYear = now.year - 18;
    if (year < minYear || year > maxYear) return false;

    // Kiểm tra số ngày trong tháng
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInMonth) return false;

    return true;
  }

  /*Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ), // Giới hạn 18 tuổi
      locale: const Locale('vi', 'VN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepOrange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }*/

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
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade900.withValues(alpha :0.85),
                    Colors.deepOrange.shade400.withValues(alpha :0.55),
                    Colors.black.withValues(alpha :0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Column(
                children: [
                  SizedBox(height: kToolbarHeight + 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: 420,
                        constraints: BoxConstraints(maxWidth: 500),
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha :0.13),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha :0.22),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha :0.10),
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
                                    Text(
                                      'Thông tin cá nhân',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                    SizedBox(height: 18),
                                    Center(
                                      child: GestureDetector(
                                        onTap: _pickAvatar,
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundImage: _avatarImage != null
                                              ? FileImage(_avatarImage!)
                                              : (_avatarUrl != null
                                                    ? NetworkImage(_avatarUrl!)
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
                                    Text(
                                      'Ảnh bổ sung (tối đa 4)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange[400],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    SizedBox(
                                      height: 100,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _additionalImages.length + _additionalPhotoUrls.length + 
                                          (_additionalImages.length + _additionalPhotoUrls.length < 4 ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          // Nếu là nút thêm ảnh mới
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

                                          // Hiển thị ảnh đã có hoặc mới chọn
                                          return Stack(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _editAdditionalPhoto(index),
                                                child: Container(
                                                  width: 100,
                                                  height: 100,
                                                  margin: EdgeInsets.only(right: 8),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    image: DecorationImage(
                                                      image: index < _additionalPhotoUrls.length
                                                          ? NetworkImage(_additionalPhotoUrls[index])
                                                          : FileImage(_additionalImages[index - _additionalPhotoUrls.length]) as ImageProvider,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Nút xóa ảnh
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
                                              // Nút sửa ảnh
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
                                    TextFormField(
                                      controller: _usernameController,
                                      decoration: InputDecoration(
                                        labelText: 'Tên người dùng',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha :
                                          0.85,
                                        ),
                                      ),
                                      validator: (value) => value!.isEmpty
                                          ? 'Vui lòng nhập tên người dùng'
                                          : null,
                                    ),
                                    SizedBox(height: 14),
                                    Consumer<EditProfileProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButtonFormField<String>(
                                          value: _rank,
                                          hint: Text('Chọn rank'),
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha :0.85),
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
                                    SizedBox(height: 14),
                                    DropdownButtonFormField<String>(
                                      hint: Text('Chọn tỉnh/thành phố'),
                                      value: _location,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(
                                          0.85,
                                        ),
                                      ),
                                      items: _provinces
                                          .map(
                                            (province) =>
                                                DropdownMenuItem<String>(
                                                  value: province['name'],
                                                  child: Text(province['name']),
                                                ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _location = value;
                                          _district = null;
                                          _ward = null;
                                        });
                                        final selectedProvince = _provinces
                                            .firstWhere(
                                              (p) => p['name'] == value,
                                              orElse: () => {},
                                            );
                                        if (selectedProvince.isNotEmpty) {
                                          _fetchDistricts(
                                            selectedProvince['code'].toString(),
                                          );
                                        }
                                      },
                                      validator: (value) => value == null
                                          ? 'Vui lòng chọn tỉnh/thành phố'
                                          : null,
                                    ),
                                    SizedBox(height: 14),
                                    DropdownButtonFormField<String>(
                                      hint: Text('Chọn quận/huyện'),
                                      value: _district,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha :
                                          0.85,
                                        ),
                                      ),
                                      items: _districts
                                          .map(
                                            (district) =>
                                                DropdownMenuItem<String>(
                                                  value: district['name'],
                                                  child: Text(district['name']),
                                                ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _district = value;
                                          _ward = null;
                                        });
                                        final selectedDistrict = _districts
                                            .firstWhere(
                                              (d) => d['name'] == value,
                                              orElse: () => {},
                                            );
                                        if (selectedDistrict.isNotEmpty) {
                                          _fetchWards(
                                            selectedDistrict['code'].toString(),
                                          );
                                        }
                                      },
                                      validator: (value) => value == null
                                          ? 'Vui lòng chọn quận/huyện'
                                          : null,
                                    ),
                                    SizedBox(height: 14),
                                    DropdownButtonFormField<String>(
                                      hint: Text('Chọn phường/xã'),
                                      value: _ward,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha :
                                          0.85,
                                        ),
                                      ),
                                      items: _wards
                                          .map(
                                            (ward) => DropdownMenuItem<String>(
                                              value: ward['name'],
                                              child: Text(ward['name']),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) =>
                                          setState(() => _ward = value),
                                      validator: (value) => value == null
                                          ? 'Vui lòng chọn phường/xã'
                                          : null,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      "Game yêu thích (tối đa 5)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange[400],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    TextFormField(
                                      decoration: InputDecoration(
                                        hintText: "Tìm kiếm game...",
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha :
                                          0.85,
                                        ),
                                      ),
                                      onChanged: _searchGames,
                                    ),
                                    SizedBox(height: 8),
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
                                        color: Colors.white.withValues(alpha :0.85),
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
                                    TextFormField(
                                      initialValue: _playTime
                                          .toString(), // Hiển thị giá trị hiện tại
                                      decoration: InputDecoration(
                                        labelText: 'Thời gian chơi (phút/ngày)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha :0.85),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) => setState(() {
                                        // Thêm setState để cập nhật UI
                                        _playTime =
                                            int.tryParse(value) ??
                                            _playTime; // Giữ lại giá trị cũ nếu parse thất bại
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
                                    TextFormField(
                                      initialValue: _winRate
                                          .toString(), // Hiển thị giá trị hiện tại
                                      decoration: InputDecoration(
                                        labelText: 'Tỷ lệ thắng (%)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha :0.85),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) => setState(() {
                                        // Thêm setState để cập nhật UI
                                        _winRate =
                                            int.tryParse(value) ??
                                            _winRate; // Giữ lại giá trị cũ nếu parse thất bại
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
                                    Text(
                                      'Thông tin cá nhân',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange[400],
                                      ),
                                    ),
                                    SizedBox(height: 14),
                                    Consumer<EditProfileProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButtonFormField<String>(
                                          value: _gender,
                                          hint: Text('Chọn giới tính'),
                                          decoration: InputDecoration(
                                            labelText: 'Giới tính',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(
                                                8,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha :0.85),
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
                                    TextFormField(
                                      controller: _birthDateController,
                                      decoration: InputDecoration(
                                        labelText: 'Ngày sinh (dd/MM/yyyy)',
                                        hintText: 'VD: 25/12/1990',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha :0.85),
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
                                      onChanged: (value) {
                                        // Tự động thêm dấu / khi nhập
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
                                    TextFormField(
                                      controller: _heightController,
                                      decoration: InputDecoration(
                                        labelText: 'Chiều cao (cm)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha :0.85),
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
                                    TextFormField(
                                      controller: _bioController,
                                      decoration: InputDecoration(
                                        labelText: 'Giới thiệu bản thân',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha :0.85),
                                      ),
                                      maxLines: 3,
                                      maxLength: 200,
                                    ),
                                    SizedBox(height: 14),
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
                                            color: Colors.white.withValues(alpha :0.85),
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
                                    Consumer<EditProfileProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButtonFormField<String>(
                                          value: _lookingFor,
                                          hint: Text('Chọn mục đích'),
                                          decoration: InputDecoration(
                                            labelText: 'Mục đích tìm kiếm',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(
                                                8,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha :0.85),
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
                                    Consumer<EditProfileProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButtonFormField<String>(
                                          value: _gameStyle,
                                          hint: Text('Chọn phong cách'),
                                          decoration: InputDecoration(
                                            labelText: 'Phong cách chơi game',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(
                                                8,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha :0.85),
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
                                    Center(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (_formKey.currentState!
                                                  .validate() &&
                                              _rank != null &&
                                              _location != null &&
                                              _district != null &&
                                              _ward != null &&
                                              _favoriteGames.isNotEmpty) {
                                            User? user = FirebaseAuth
                                                .instance
                                                .currentUser;
                                            if (user != null) {
                                              try {
                                                setState(() {
                                                  _isLoading = true;
                                                });
                                                await _uploadImages(user.uid);
                                                final dateParts =
                                                    _birthDateController.text
                                                        .split('/');
                                                final birthDate = DateTime(
                                                  int.parse(
                                                    dateParts[2],
                                                  ), // năm
                                                  int.parse(
                                                    dateParts[1],
                                                  ), // tháng
                                                  int.parse(
                                                    dateParts[0],
                                                  ), // ngày
                                                );

                                                UserModel newUser = UserModel(
                                                  id: user.uid,
                                                  username:
                                                      _usernameController.text,
                                                  favoriteGames: _favoriteGames,
                                                  rank: _rank!,
                                                  location:
                                                      '$_location, $_district, $_ward',
                                                  playTime: _playTime,
                                                  winRate: _winRate,
                                                  avatarUrl: _avatarUrl,
                                                  additionalPhotos:
                                                      _additionalPhotoUrls,
                                                  // Thêm các trường mới
                                                  gender: _gender,
                                                  dateOfBirth: birthDate,
                                                  age: _calculateAge(
                                                    birthDate,
                                                  ), // Vẫn giữ trường age để tiện tính toán
                                                  height: int.parse(
                                                    _heightController.text,
                                                  ),
                                                  bio: _bioController.text,
                                                  interests: _interests,
                                                  lookingFor: _lookingFor,
                                                  gameStyle: _gameStyle,
                                                );
                                                await _firestoreService.addUser(
                                                  newUser,
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      _isUpdating
                                                          ? 'Cập nhật hồ sơ thành công!'
                                                          : 'Tạo hồ sơ thành công!',
                                                    ),
                                                  ),
                                                );
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const UserApp(
                                                          initialRoute:
                                                              '/home_profile',
                                                        ),
                                                  ),
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Lưu hồ sơ thất bại: $e',
                                                    ),
                                                  ),
                                                );
                                              } finally {
                                                setState(() {
                                                  _isLoading = false;
                                                });
                                              }
                                            }
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Vui lòng điền đầy đủ thông tin và chọn ít nhất một game!',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.deepOrange[400],
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 40,
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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

  Future<void> _editAdditionalPhoto(int index) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (index < _additionalPhotoUrls.length) {
          // If editing an existing uploaded photo
          _additionalPhotoUrls.removeAt(index);
          _additionalImages.add(File(pickedFile.path));
        } else {
          // If editing a newly selected photo
          _additionalImages[index - _additionalPhotoUrls.length] = File(
            pickedFile.path,
          );
        }
      });
    }
  }

  void _removeAdditionalPhoto(int index) {
    setState(() {
      if (index < _additionalPhotoUrls.length) {
        // Remove from uploaded photos
        _additionalPhotoUrls.removeAt(index);
      } else {
        // Remove from newly selected photos
        _additionalImages.removeAt(index - _additionalPhotoUrls.length);
      }
    });
  }
}
