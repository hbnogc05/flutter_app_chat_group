import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zalo_app/screens/chat_list_screen.dart';
import 'package:zalo_app/screens/create_post_screen.dart';
import 'package:zalo_app/screens/friends_list_screen.dart';
import 'package:zalo_app/screens/tuong_nha_screen.dart';
import 'package:zalo_app/screens/profile_screen.dart';
import 'package:zalo_app/services/user_service.dart';

class MainLayoutScreen extends StatefulWidget {
  final int initialIndex;
  const MainLayoutScreen({super.key, this.initialIndex = 0});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late PageController _pageController;
  late int _currentIndex;

  // Biến trạng thái để kiểm soát animation của nút Đăng
  bool _isPostingAnimation = false;

  // Danh sách các trang thực tế trong PageView (bỏ qua nút Đăng ở giữa)
  final List<Widget> _pages = <Widget>[
    const ChatListScreen(),
    const FriendsListScreen(),
    const TuongNhaScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Đăng ký observer để lắng nghe vòng đời ứng dụng
    WidgetsBinding.instance.addObserver(this);
    // Cập nhật trạng thái online khi vào màn hình chính
    UserService().updateUserStatus(true);

    _currentIndex = widget.initialIndex;
    
    // Khởi tạo PageController với trang tương ứng
    _pageController = PageController(initialPage: _navIndexToPageIndex(_currentIndex));

    // Sync user data on startup
    _syncUserData();

    // Animation Controller for the wave and dot movement
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: _currentIndex.toDouble(),
      upperBound: 4.0,
    );
  }

  // Lắng nghe thay đổi trạng thái ứng dụng (Background/Foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Ứng dụng quay lại foreground -> Online
      UserService().updateUserStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Ứng dụng xuống background hoặc bị tắt -> Offline
      UserService().updateUserStatus(false);
    }
  }

  // Chuyển đổi index của BottomNav (0..4) sang index của PageView (0..3)
  int _navIndexToPageIndex(int navIndex) {
    if (navIndex <= 1) return navIndex;
    if (navIndex >= 3) return navIndex - 1;
    return 0; // Mặc định
  }

  // Chuyển đổi index của PageView (0..3) sang index của BottomNav (0..4)
  int _pageIndexToNavIndex(int pageIndex) {
    if (pageIndex <= 1) return pageIndex;
    return pageIndex + 1;
  }

  Future<void> _syncUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final prefs = await SharedPreferences.getInstance();
          List<String> savedAccounts = prefs.getStringList('saved_accounts') ?? [];

          int index = -1;
          Map<String, dynamic>? existingAccount;

          for (int i = 0; i < savedAccounts.length; i++) {
            try {
              final acc = jsonDecode(savedAccounts[i]) as Map<String, dynamic>;
              if (acc['uid'] == user.uid) {
                index = i;
                existingAccount = acc;
                break;
              }
            } catch (e) {
              // Ignore parse errors
            }
          }

          if (index != -1 && existingAccount != null) {
            existingAccount['displayName'] = userData['displayName'] ?? existingAccount['displayName'];
            existingAccount['photoURL'] = userData['photoURL'] ?? existingAccount['photoURL'];
            if (userData.containsKey('coverPhotoURL')) {
              existingAccount['coverPhotoURL'] = userData['coverPhotoURL'];
            }

            savedAccounts[index] = jsonEncode(existingAccount);
            await prefs.setStringList('saved_accounts', savedAccounts);
          }
        }
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint("Error syncing user data: $e");
      }
    }
  }

  @override
  void dispose() {
    // Hủy đăng ký observer
    WidgetsBinding.instance.removeObserver(this);
    // Cập nhật trạng thái offline khi thoát màn hình chính (thường là logout)
    UserService().updateUserStatus(false);
    
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      // LOGIC MỚI: Kích hoạt animation trước, sau đó mới chuyển trang
      setState(() {
        _isPostingAnimation = true;
      });

      // Chờ 1.2 giây để hiệu ứng diễn ra
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const CreatePostScreen(),
            fullscreenDialog: true,
          )).then((_) {
            // Reset trạng thái animation khi quay lại hoặc sau khi push xong
            if (mounted) {
              setState(() {
                _isPostingAnimation = false;
              });
            }
          });
        }
      });
    } else {
      if (_currentIndex != index) {
        setState(() {
          _currentIndex = index;
        });
        
        // Animate PageView
        _pageController.animateToPage(
          _navIndexToPageIndex(index),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );

        // Drive the animation controller to the new index
        _animationController.animateTo(
          index.toDouble(),
          curve: Curves.easeInOutCubic,
          duration: const Duration(milliseconds: 400),
        );
      }
    }
  }

  void _onPageChanged(int pageIndex) {
    int newNavIndex = _pageIndexToNavIndex(pageIndex);
    if (_currentIndex != newNavIndex) {
      setState(() {
        _currentIndex = newNavIndex;
      });
      _animationController.animateTo(
        newNavIndex.toDouble(),
        curve: Curves.easeInOutCubic,
        duration: const Duration(milliseconds: 400),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Cho phép body tràn xuống dưới bottom bar
      extendBody: true,
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: _pages.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double page = _currentIndex.toDouble();
              if (_pageController.hasClients && _pageController.position.hasContentDimensions) {
                 page = _pageController.page ?? _currentIndex.toDouble();
              } else {
                 // Fallback to current index mapped to page index
                 page = _navIndexToPageIndex(_currentIndex).toDouble();
              }
              
              // Tính toán độ lệch so với trang hiện tại
              double difference = (index - page).abs();
              if (difference > 1.0) difference = 1.0;

              // Hiệu ứng Opacity: Giảm dần từ 1.0 về 0.0 khi trang bị đẩy ra
              double opacity = 1.0 - difference;

              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: child,
              );
            },
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: _pages[index],
            ),
          );
        },
      ),
      bottomNavigationBar: SizedBox(
        height: 80,
        child: Stack(
          children: [
            // Layer 1: The Animated Wave Background
            Positioned.fill(
              top: 0,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WavePainter(
                      position: _animationController.value,
                      itemsCount: 5,
                      color: const Color(0xFFC6E7FF),
                      shadowColor: Colors.black.withOpacity(0.1),
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),

            // Layer 2: The Floating Blue Dot
            Positioned.fill(
              top: 0,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: DotPainter(
                      position: _animationController.value,
                      itemsCount: 5,
                      dotColor: Colors.blue,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),

            // Layer 3: The Icons and Text
            Positioned.fill(
              top: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (index) {
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _onItemTapped(index),
                      child: _buildTabItem(index),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index) {
    // Với nút Đăng (index 2), ta kiểm tra thêm biến _isPostingAnimation
    final isSelected = _currentIndex == index;
    final isAnimatingPost = (index == 2 && _isPostingAnimation);

    final color = (isSelected || isAnimatingPost) ? Colors.blue.shade800 : Colors.grey.shade600;

    String lottieAsset;
    String label;
    // ĐIỀU CHỈNH: Giảm kích thước chuẩn từ 30 xuống 28 để gọn hơn
    double iconSize = 28;

    switch (index) {
      case 0:
        label = 'Tin nhắn';
        lottieAsset = 'assets/lottie/chat (2).json';
        break;
      case 1:
        label = 'Danh bạ';
        lottieAsset = 'assets/lottie/Staff (2).json';
        break;
      case 2:
        label = 'Đăng';
        lottieAsset = 'assets/lottie/plus (1).json';
        break;
      case 3:
        label = 'Tường nhà';
        lottieAsset = 'assets/lottie/Newspaper (1).json';
        break;
      case 4:
        label = 'Cá nhân';
        lottieAsset = 'assets/lottie/user profile (2).json';
        break;
      default:
        label = '';
        lottieAsset = '';
    }

    Widget iconWidget;

    if (lottieAsset.isNotEmpty) {
      // Xác định trạng thái cần animate
      final shouldAnimate = isSelected || isAnimatingPost;

      iconWidget = Lottie.asset(
        lottieAsset,
        width: iconSize, // Sử dụng kích thước chuẩn đã giảm
        height: iconSize,
        fit: BoxFit.contain,
        // Key thay đổi để trigger rebuild khi trạng thái animate thay đổi
        key: ValueKey('$index$shouldAnimate'),
        animate: shouldAnimate,
        repeat: false,
        // Nếu đang chọn hoặc đang animate: controller = null (để Lottie tự chạy)
        // Nếu KHÔNG chọn: Dùng AlwaysStoppedAnimation(1.0) để ép hiển thị frame cuối cùng
        controller: shouldAnimate ? null : const AlwaysStoppedAnimation(1.0),
      );
    } else {
      iconWidget = Icon(Icons.error, color: color, size: 24);
    }

    // --- CẤU HÌNH SCALE RIÊNG CHO TỪNG ICON TẠI ĐÂY (ĐÃ THU NHỎ) ---
    double scaleFactor = 1.0;

    switch (index) {
      case 0: // Tin nhắn
        scaleFactor = 1.4;
        break;
      case 1: // Danh bạ
        scaleFactor = 1.8;
        break;
      case 2: // Đăng
        scaleFactor = 1.8;
        break;
      case 3: // Tường nhà
        scaleFactor = 1.3; // Đã tăng từ 1.1 lên 1.4 theo yêu cầu
        break;
      case 4: // Cá nhân
        scaleFactor = 1.2;
        break;
    }

    // Áp dụng Transform.scale nếu cần thiết
    if (scaleFactor != 1.0) {
      iconWidget = Transform.scale(
        scale: scaleFactor,
        child: iconWidget,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ... Các class WavePainter và DotPainter giữ nguyên ...
class WavePainter extends CustomPainter {
  final double position;
  final int itemsCount;
  final Color color;
  final Color shadowColor;

  WavePainter({
    required this.position,
    required this.itemsCount,
    required this.color,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final double itemWidth = size.width / itemsCount;
    final double currentX = (position + 0.5) * itemWidth;

    final double topEdge = 15.0;
    final double waveWidth = itemWidth * 0.7;
    final double waveDepth = 12.0;

    final Path path = Path();
    const double cornerRadius = 20.0;

    path.moveTo(cornerRadius, topEdge);

    double waveStart = currentX - waveWidth / 2;
    double waveEnd = currentX + waveWidth / 2;

    if (waveStart < cornerRadius) waveStart = cornerRadius;
    if (waveEnd > size.width - cornerRadius) waveEnd = size.width - cornerRadius;

    path.lineTo(waveStart, topEdge);

    path.cubicTo(
        waveStart + waveWidth * 0.25, topEdge,
        currentX - waveWidth * 0.25, topEdge + waveDepth,
        currentX, topEdge + waveDepth
    );

    path.cubicTo(
        currentX + waveWidth * 0.25, topEdge + waveDepth,
        waveEnd - waveWidth * 0.25, topEdge,
        waveEnd, topEdge
    );

    path.lineTo(size.width - cornerRadius, topEdge);
    path.quadraticBezierTo(size.width, topEdge, size.width, topEdge + cornerRadius);

    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(size.width, size.height, size.width - cornerRadius, size.height);

    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

    path.lineTo(0, topEdge + cornerRadius);
    path.quadraticBezierTo(0, topEdge, cornerRadius, topEdge);

    path.close();

    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.position != position;
  }
}

class DotPainter extends CustomPainter {
  final double position;
  final int itemsCount;
  final Color dotColor;

  DotPainter({
    required this.position,
    required this.itemsCount,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double itemWidth = size.width / itemsCount;
    final double currentX = (position + 0.5) * itemWidth;

    final paint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(currentX, 12.0), 4.0, paint);
  }

  @override
  bool shouldRepaint(covariant DotPainter oldDelegate) {
    return oldDelegate.position != position;
  }
}