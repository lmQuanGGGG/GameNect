import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import '../../core/models/user_model.dart';
import '../theme/theme_helper.dart';
import '../services/rawg_service.dart';
import '../utils/icon_helper.dart';
import 'game_tag_widget.dart';
import 'network_image.dart';

// Custom ScrollBehavior cho phép kéo bằng chuột trên Web
class _WebDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
      };
}

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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dùng constraints.maxWidth để lấy chiều rộng thực tế của widget (hỗ trợ web constrained)
        final double cardWidth = constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
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
              decoration: BoxDecoration(
                color: context.cardBgColor,
                border: Border.all(color: context.cardBorderColor, width: 1.5),
              ),
              child: Center(
                child: Icon(Icons.person, size: 80, color: context.textTertiaryColor),
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
                // ScrollConfiguration cho phép kéo bằng chuột trên Web
                ScrollConfiguration(
                  behavior: _WebDragScrollBehavior(),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: allPhotos.length,
                    itemBuilder: (context, index) {
                      return _KeepAliveWrapper(
                        child: GamenectNetworkImage(
                          imageUrl: allPhotos[index],
                          fit: BoxFit.cover,
                          width: cardWidth,
                          height: cardHeight,
                          errorWidget: (context, url, error) =>
                              const Center(child: Icon(Icons.error_outline, size: 50)),
                        ),
                      );
                    },
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                  ),
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
                              : (context.isDarkMode ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                // Tap zones để chuyển ảnh (bấm trái/phải)
                if (allPhotos.length > 1) ...[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: cardWidth * 0.4,
                    child: GestureDetector(
                      onTap: () {
                        if (_currentPage > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: cardWidth * 0.4,
                    child: GestureDetector(
                      onTap: () {
                        if (_currentPage < allPhotos.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }, // end builder
    ); // end LayoutBuilder
  }

  // Xây dựng card hiển thị số liệu game như play time và win rate
  Widget _buildStatCard(String title, String value, String unit, IconData icon) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: 3,
          left: 3,
          bottom: -3,
          right: -3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 2.5),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 2.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: const Color(0xFFFF6E40)),
                  const SizedBox(height: 8),
                  Text(title, style: TextStyle(color: Colors.black.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(value,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                      const SizedBox(width: 4),
                      Text(unit, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black.withValues(alpha: 0.8))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: context.textColor,
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 3,
              left: 3,
              bottom: -3,
              right: -3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 2.5),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 2.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Hiển thị danh sách game yêu thích dưới dạng tags màu cam
  Widget _buildGameTags(List<String> games) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: 3,
          left: 3,
          bottom: -3,
          right: -3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 2.5),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 2.5),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: games.map((g) => GameTagWidget(gameName: g)).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Hiển thị danh sách sở thích khác dưới dạng tags
  Widget _buildInterestTags(List<String> interests) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: interests.map((interest) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(IconHelper.getInterestIcon(interest), size: 20, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Text(
                interest,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 500 : 650),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 4,
          left: 4,
          bottom: -4,
          right: -4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: context.textColor, width: 3),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: context.textColor, width: 3),
            ),
            child: Stack(
              children: [
                // Nền blur để tạo hiệu ứng frosted glass
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.isDarkMode 
                          ? const Color(0xFF101012).withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.8),
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
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: context.textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.rank,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFFFF6E40),
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
                        Text(
                          'Giới thiệu',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: context.textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            user.bio,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: context.textColor,
                            ),
                          ),
                        ),
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
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: context.textColor,
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
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: context.textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInterestTags(user.interests),
                        const SizedBox(height: 24),
                      ],
                      // Hiển thị vị trí của user
                      ListTile(
                        leading: const Icon(Icons.location_on, color: Color(0xFFFF6E40)),
                        title: Text(
                          user.address ?? user.location,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.textColor),
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
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// Helper widget để giữ trạng thái cho các ảnh trong PageView, tránh bị dispose và re-render lại khi lướt qua lướt lại
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}


