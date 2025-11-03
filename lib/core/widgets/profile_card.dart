import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';

// Widget hiển thị card thông tin chi tiết của user
// Bao gồm ảnh đại diện, thông tin cá nhân, game stats và sở thích
class ProfileCard extends StatefulWidget {
  final UserModel user;
  const ProfileCard({super.key, required this.user});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Xây dựng gallery ảnh với PageView để vuốt xem nhiều ảnh
  Widget _buildPhotoGallery() {
    // Gộp avatar và additional photos thành một list
    List<String> allPhotos = [];
    if (widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty) {
      allPhotos.add(widget.user.avatarUrl!);
    }
    if (widget.user.additionalPhotos.isNotEmpty) {
      allPhotos.addAll(widget.user.additionalPhotos);
    }

    // Tỉ lệ 3:4 để hiển thị đẹp như card Tinder
    final double cardWidth = MediaQuery.of(context).size.width;
    final double cardHeight = cardWidth * 4 / 3;

    if (allPhotos.isEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: Container(
          width: cardWidth,
          height: cardHeight,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.person, size: 80, color: Colors.grey),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Stack(
          children: [
            // PageView cho phép vuốt qua lại giữa các ảnh
            PageView.builder(
              controller: _pageController,
              itemCount: allPhotos.length,
              itemBuilder: (context, index) {
                return Image.network(
                  allPhotos[index],
                  fit: BoxFit.cover,
                  width: cardWidth,
                  height: cardHeight,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.error_outline, size: 50)),
                );
              },
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
            ),
            // Indicator hiển thị vị trí ảnh hiện tại
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
          ],
        ),
      ),
    );
  }

  // Xây dựng card hiển thị số liệu game như play time và win rate
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

  // Hiển thị danh sách game yêu thích dưới dạng tags màu cam
  Widget _buildGameTags(List<String> games) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: games.map((game) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.deepOrange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            game,
            style: const TextStyle(
              color: Colors.deepOrange,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        );
      }).toList(),
    );
  }

  // Hiển thị danh sách sở thích khác dưới dạng tags màu xanh
  Widget _buildInterestTags(List<String> interests) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: interests.map((interest) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            interest,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Nền blur để tạo hiệu ứng frosted glass
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          // Nội dung card cuộn được
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoGallery(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hiển thị tên và rank
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.username,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.rank,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.deepOrange[400],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Thông tin cơ bản như tuổi chiều cao giới tính
                      _buildInfoSection('Thông tin cơ bản', [
                        _buildInfoRow(Icons.cake, 'Tuổi', '${user.age} tuổi'),
                        _buildInfoRow(Icons.height, 'Chiều cao', '${user.height} cm'),
                        _buildInfoRow(Icons.person, 'Giới tính', user.gender),
                        if (user.distanceKm != null)
                          _buildInfoRow(Icons.location_on, 'Khoảng cách', '${user.distanceKm!.toStringAsFixed(1)} km'),
                      ]),
                      const SizedBox(height: 24),
                      // Hiển thị play time và win rate dưới dạng card
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Thời gian chơi',
                              '${user.playTime}',
                              'p/n',
                              Icons.timer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Tỷ lệ thắng',
                              '${user.winRate}',
                              '%',
                              Icons.trending_up,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Hiển thị bio nếu có
                      if (user.bio.isNotEmpty) ...[
                        _buildInfoSection('Giới thiệu', [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              user.bio,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 24),
                      ],
                      // Thông tin về game như phong cách và mục đích
                      _buildInfoSection('Thông tin game', [
                        _buildInfoRow(Icons.gamepad, 'Phong cách', user.gameStyle),
                        _buildInfoRow(Icons.grade, 'Rank', user.rank),
                        _buildInfoRow(Icons.search, 'Mục đích', user.lookingFor),
                      ]),
                      const SizedBox(height: 24),
                      // Danh sách game yêu thích
                      Text(
                        'Game yêu thích',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGameTags(user.favoriteGames),
                      const SizedBox(height: 24),
                      // Danh sách sở thích khác nếu có
                      if (user.interests.isNotEmpty) ...[
                        Text(
                          'Sở thích khác',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInterestTags(user.interests),
                        const SizedBox(height: 24),
                      ],
                      // Hiển thị vị trí của user
                      ListTile(
                        leading: Icon(Icons.location_on, color: Colors.deepOrange[400]),
                        title: Text(
                          user.location,
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}