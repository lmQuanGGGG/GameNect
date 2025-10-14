import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';

class HomeProfileScreen extends StatefulWidget {
  final String? userId;  // Thêm tham số userId
  const HomeProfileScreen({super.key, this.userId});

  @override
State<HomeProfileScreen> createState() => _HomeProfileScreenState();
}

class _HomeProfileScreenState extends State<HomeProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  UserModel? _userData;
  bool _isLoading = true;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final double _sheetPosition = 0.45; // tỉ lệ chiều cao ban đầu

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Sử dụng userId nếu có, nếu không thì lấy user hiện tại
      final userData = widget.userId != null 
          ? await _firestoreService.getUser(widget.userId!)
          : await _firestoreService.getCurrentUser();
          
      if (userData != null) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPhotoGallery() {
    List<String> allPhotos = [];

    if (_userData?.avatarUrl != null && _userData!.avatarUrl!.isNotEmpty) {
      allPhotos.add(_userData!.avatarUrl!);
    }

    if (_userData?.additionalPhotos != null && _userData!.additionalPhotos.isNotEmpty) {
      allPhotos.addAll(_userData!.additionalPhotos);
    }

    if (allPhotos.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.45,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.person, size: 80, color: Colors.grey),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: allPhotos.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: allPhotos[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) =>
                const Center(child: Icon(Icons.error_outline, size: 50)),
            );
          },
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
        ),
        // Indicator
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              allPhotos.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.deepOrange
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        // Navigation buttons
        Positioned(
          left: 8,
          top: MediaQuery.of(context).size.height * 0.2,
          child: IconButton(
            icon: const Icon(Icons.chevron_left, size: 40, color: Colors.white),
            onPressed: () {
              if (_currentPage > 0) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        ),
        Positioned(
          right: 8,
          top: MediaQuery.of(context).size.height * 0.2,
          child: IconButton(
            icon: const Icon(Icons.chevron_right, size: 40, color: Colors.white),
            onPressed: () {
              if (_currentPage < allPhotos.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('Không tìm thấy hồ sơ'))
              : Stack(
                  children: [
                    _buildPhotoGallery(),
                    // Draggable info panel (vuốt lên xuống)
                    DraggableScrollableSheet(
                      initialChildSize: _sheetPosition,
                      minChildSize: 0.2,
                      maxChildSize: 0.9,
                      builder: (context, scrollController) {
                        return ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.5), //độ trong suốt
                              child: SingleChildScrollView(
                                controller: scrollController,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 40,
                                        height: 5,
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[400],
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _userData!.username,
                                                style: const TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _userData!.rank,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.deepOrange[400],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pushNamed(context, '/profile');
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.deepOrange,
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(12),
                                          ),
                                          child: const Icon(Icons.edit, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    // Basic Info Section
                                    _buildInfoSection('Thông tin cơ bản', [
                                      _buildInfoRow(Icons.cake, 'Tuổi', '${_userData!.age} tuổi'),
                                      _buildInfoRow(Icons.height, 'Chiều cao', '${_userData!.height} cm'),
                                      _buildInfoRow(Icons.person, 'Giới tính', _userData!.gender),
                                    ]),

                                    const SizedBox(height: 24),
                                    // Gaming Stats Section
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatCard(
                                            'Thời gian chơi',
                                            '${_userData!.playTime}',
                                            'phút/ngày',
                                            Icons.timer,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildStatCard(
                                            'Tỷ lệ thắng',
                                            '${_userData!.winRate}',
                                            '%',
                                            Icons.trending_up,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 24),
                                    // Bio Section
                                    if (_userData!.bio.isNotEmpty) ...[
                                      _buildInfoSection('Giới thiệu', [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Text(
                                            _userData!.bio,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ]),
                                      const SizedBox(height: 24),
                                    ],

                                    // Gaming Style Section
                                    _buildInfoSection('Thông tin game', [
                                      _buildInfoRow(Icons.gamepad, 'Phong cách', _userData!.gameStyle),
                                      _buildInfoRow(Icons.grade, 'Rank', _userData!.rank),
                                      _buildInfoRow(Icons.search, 'Mục đích', _userData!.lookingFor),
                                    ]),

                                    const SizedBox(height: 24),
                                    // Favorite Games Section
                                    Text(
                                      'Game yêu thích',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _userData!.favoriteGames.map((game) {
                                        return Chip(
                                          label: Text(game),
                                          backgroundColor: Colors.deepOrange.withValues(alpha: 0.1),
                                          labelStyle: TextStyle(
                                            color: Colors.deepOrange[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      }).toList(),
                                    ),

                                    const SizedBox(height: 24),
                                    // Interests Section
                                    if (_userData!.interests.isNotEmpty) ...[
                                      Text(
                                        'Sở thích khác',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _userData!.interests.map((interest) {
                                          return Chip(
                                            label: Text(interest),
                                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                            labelStyle: TextStyle(
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 24),
                                    ],

                                    // Location Section
                                    ListTile(
                                      leading: Icon(Icons.location_on, color: Colors.deepOrange[400]),
                                      title: Text(
                                        _userData!.location,
                                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String title, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepOrange[400]),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.deepOrange[400]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
