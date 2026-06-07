import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../auth/login_screen.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _textController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Khám phá\ncộng đồng\nGame thủ &\nGame trending!',
      'slogan': 'Kết nối game thủ, chinh phục thế giới ảo!',
      'icon': Icons.sports_esports_rounded,
      'color': Colors.deepOrange,
    },
    {
      'title': 'Ghép đội\n& Leo rank\ncực mượt',
      'slogan': 'Tìm "cạ cứng" đồng hành, không còn nỗi lo tạ team.',
      'icon': Icons.group_add_rounded,
      'color': Colors.pinkAccent,
    },
    {
      'title': 'Trở thành\nMentor &\nLivestream',
      'slogan': 'Chia sẻ kỹ năng, kiếm thêm thu nhập từ đam mê.',
      'icon': Icons.live_tv_rounded,
      'color': Colors.purpleAccent,
    },
  ];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _textController.forward();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (_currentPage < _onboardingData.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      } else {
        // Lặp lại từ đầu khi đến trang cuối
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _bgController.dispose();
    _textController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _textController.reset();
    _textController.forward();

    // Nếu user tự vuốt tay, reset timer để không bị nhảy trang quá nhanh
    if (_currentPage < _onboardingData.length - 1) {
      _startAutoPlay();
    } else {
      _autoPlayTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      body: Stack(
        children: [
          // Background tĩnh
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          
          // Các hạt bay lơ lửng và xoay
          ...List.generate(20, (index) {
            final random = math.Random(index);
            final size = random.nextDouble() * 50 + 20;
            final leftPercent = random.nextDouble();
            final topPercent = random.nextDouble();
            final durationOffset = random.nextDouble();
            final icons = [
              Icons.sports_esports_rounded, 
              Icons.videogame_asset_rounded, 
              Icons.gamepad_rounded, 
              Icons.headphones_rounded,
              Icons.star_rounded,
              Icons.rocket_launch_rounded
            ];
            final icon = icons[random.nextInt(icons.length)];

            return AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                final width = MediaQuery.of(context).size.width;
                final height = MediaQuery.of(context).size.height;
                
                final left = leftPercent * width;
                final top = topPercent * height;
                
                final progress = (_bgController.value + durationOffset) % 1.0;
                final yPos = top + (progress * height);
                final finalY = yPos % (height + size) - size;
                final rotation = progress * 4 * math.pi;

                return Positioned(
                  left: left,
                  top: finalY,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Opacity(
                      opacity: 0.15,
                      child: Icon(icon, color: Colors.orangeAccent, size: size),
                    ),
                  ),
                );
              },
            );
          }),

          // Lớp kính mờ (Glassmorphism)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Nội dung chính
          SafeArea(
            child: Column(
              children: [
                // Header (Logo)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.orange, Colors.deepOrangeAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.sports_esports_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GameNect',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Kết nối đam mê',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // PageView Onboarding
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _onboardingData.length,
                    itemBuilder: (context, index) {
                      final data = _onboardingData[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon to illustrate the page
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: (data['color'] as Color).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: (data['color'] as Color).withValues(alpha: 0.5), 
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(data['icon'] as IconData, size: 48, color: data['color'] as Color),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Title
                            AnimatedBuilder(
                              animation: _bgController,
                              builder: (context, child) {
                                final dy = math.sin(_bgController.value * 2 * math.pi * 8) * 8;
                                return Transform.translate(
                                  offset: Offset(0, dy),
                                  child: child,
                                );
                              },
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: Text(
                                    data['title'] as String,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                      letterSpacing: -0.5,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 20,
                                          color: data['color'] as Color,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Slogan with effect
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Text(
                                  data['slogan'] as String,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 60), // Space for button
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Indicators & Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    children: [
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? Colors.orange : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Nút CTA Glassmorphism/Gradient
                      GestureDetector(
                        onTap: () {
                          if (_currentPage < _onboardingData.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                            );
                          } else {
                            if (authService.currentUser != null) {
                              Navigator.pushReplacementNamed(context, '/main');
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              colors: _currentPage == _onboardingData.length - 1
                                  ? [Colors.orange, Colors.deepOrangeAccent, Colors.pinkAccent]
                                  : [Colors.white24, Colors.white12],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: _currentPage == _onboardingData.length - 1
                                ? [
                                    BoxShadow(
                                      color: Colors.orange.withValues(alpha: 0.4),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : [],
                            border: _currentPage != _onboardingData.length - 1
                                ? Border.all(color: Colors.white30, width: 1)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              _currentPage == _onboardingData.length - 1 ? 'BẮT ĐẦU NGAY' : 'TIẾP TỤC',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
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
