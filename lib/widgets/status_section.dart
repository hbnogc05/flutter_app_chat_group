import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class StatusSection extends StatelessWidget {
  const StatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.none,
        children: [
          _CurrentUserStatusNode(uid: currentUser.uid),
          _FriendsStatusList(currentUser: currentUser),
        ],
      ),
    );
  }
}

// --- WIDGET: Ghi chú của bản thân ---
class _CurrentUserStatusNode extends StatelessWidget {
  final String uid;
  const _CurrentUserStatusNode({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final note = data?['note'] as String?;
        final timestamp = data?['noteTimestamp'] as Timestamp?;
        final photoUrl = data?['photoURL'] as String? ?? '';

        bool isExpired = true;
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toDate());
          if (diff.inHours < 24) isExpired = false;
        }

        final displayNote = (note != null && note.isNotEmpty && !isExpired) ? note : "Suy nghĩ...";
        final bool hasActiveNote = (note != null && note.isNotEmpty && !isExpired);

        return _StatusItem(
          avatarUrl: photoUrl,
          name: "Bạn",
          note: displayNote,
          isMe: true,
          hasActiveNote: hasActiveNote,
          onTap: () {
            // LOGIC MỚI: Phân biệt hành động dựa trên trạng thái note
            if (hasActiveNote) {
              _showViewStatusBottomSheet(context, note!, photoUrl);
            } else {
              // Truyền thêm photoUrl để hiển thị avatar trong dialog mới
              _showEditNoteDialog(context, '', photoUrl);
            }
          },
        );
      },
    );
  }

  // --- HÀM 1: Xem chi tiết trạng thái (Kéo từ dưới lên 40%) ---
  void _showViewStatusBottomSheet(BuildContext context, String currentNote, String photoUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.grey[200],
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty ? const Icon(Icons.person, size: 35, color: Colors.grey) : null,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  currentNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Đã chia sẻ với bạn bè",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Gọi dialog sửa với giao diện mới
                      _showEditNoteDialog(context, currentNote, photoUrl);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1239F4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Viết ghi chú mới",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'note': FieldValue.delete(),
                    'noteTimestamp': FieldValue.delete(),
                  });
                },
                child: const Text(
                  "Xóa ghi chú",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // --- HÀM 2: Giao diện Viết/Sửa trạng thái (Full màn hình, Cập nhật nút Chia sẻ sáng lên) ---
  void _showEditNoteDialog(BuildContext context, String? currentNote, String userAvatarUrl) {
    final controller = TextEditingController(text: currentNote);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Full màn hình
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) {
        // Sử dụng StatefulBuilder để cập nhật trạng thái nút bấm khi gõ chữ
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final bool hasText = controller.text.trim().isNotEmpty;

            return Scaffold(
              backgroundColor: Colors.white,
              // Dùng Stack để Close button và Bottom Bar luôn cố định
              body: SafeArea(
                child: Stack(
                  children: [
                    // 1. Nút Đóng (Góc trái trên)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 30, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // 2. Nội dung chính (Giữa màn hình)
                    Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bong bóng suy nghĩ (Chứa TextField)
                            Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 180,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: controller,
                                    autofocus: true, // Tự động bật bàn phím
                                    textAlign: TextAlign.center,
                                    maxLength: 60,
                                    maxLines: null,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    // Lắng nghe thay đổi để cập nhật nút Chia sẻ
                                    onChanged: (value) {
                                      setState(() {});
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "Chia sẻ ghi chú",
                                      hintStyle: TextStyle(color: Colors.grey),
                                      border: InputBorder.none,
                                      counterText: "",
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                // Hai chấm tròn nhỏ tạo hiệu ứng đuôi bong bóng
                                Positioned(
                                  bottom: -8,
                                  right: 60,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -16,
                                  right: 50,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 25),

                            // Avatar người dùng
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: userAvatarUrl.isNotEmpty ? NetworkImage(userAvatarUrl) : null,
                                  child: userAvatarUrl.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
                                ),
                                // Icon bút chì nhỏ
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: Colors.black12, blurRadius: 2)
                                      ]
                                  ),
                                  child: const Icon(Icons.edit, size: 14, color: Colors.orange),
                                )
                              ],
                            ),

                            const SizedBox(height: 25),

                            // Các nút icon phụ (Nhạc, Vị trí)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildCircleIconButton(Icons.music_note, Colors.pinkAccent),
                                const SizedBox(width: 20),
                                _buildCircleIconButton(Icons.location_on, Colors.purpleAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Thanh Bottom (Chia sẻ với bạn bè + Nút Chia sẻ)
                    // Positioned bottom để nằm ngay trên bàn phím
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        color: Colors.white, // Nền trắng che nội dung nếu cuộn
                        child: Row(
                          // Đổi từ spaceBetween sang end để nút nằm bên phải
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Đã xóa dòng chữ "Chia sẻ với bạn bè" ở đây

                            // Nút Chia sẻ: Chỉ kích hoạt (sáng lên) khi có chữ
                            ElevatedButton(
                              onPressed: hasText ? () async {
                                final text = controller.text.trim();
                                Navigator.pop(context);

                                if (text.isNotEmpty) {
                                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                                    'note': text,
                                    'noteTimestamp': FieldValue.serverTimestamp(),
                                  });
                                }
                              } : null, // Vô hiệu hóa nếu không có chữ
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                                  if (states.contains(MaterialState.disabled)) {
                                    return const Color(0xFFB4C6FC); // Màu nhạt khi vô hiệu hóa
                                  }
                                  return const Color(0xFF133FED); // Màu đậm (sáng lên) khi kích hoạt
                                }),
                                foregroundColor: MaterialStateProperty.all(Colors.white),
                                elevation: MaterialStateProperty.all(0),
                                padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                              child: const Text("Chia sẻ", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCircleIconButton(IconData icon, Color color) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

// --- WIDGET: Danh sách ghi chú bạn bè ---
class _FriendsStatusList extends StatelessWidget {
  final User currentUser;
  const _FriendsStatusList({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        // Lấy danh sách bạn bè từ field 'friends' thay vì query từ 'chats'
        final List<dynamic> friends = userData?['friends'] ?? [];

        if (friends.isEmpty) return const SizedBox.shrink();

        return Row(
          // Hiển thị status của từng người bạn
          children: friends.map((friendId) => _FriendStatusItem(friendId: friendId.toString())).toList(),
        );
      },
    );
  }
}

class _FriendStatusItem extends StatelessWidget {
  final String friendId;
  const _FriendStatusItem({required this.friendId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(friendId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final note = data['note'] as String?;
        final timestamp = data['noteTimestamp'] as Timestamp?;
        final photoUrl = data['photoURL'] as String? ?? '';
        final name = data['displayName'] as String? ?? 'Người dùng';

        bool isExpired = true;
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toDate());
          if (diff.inHours < 24) isExpired = false;
        }

        if (note == null || note.isEmpty || isExpired) {
          return const SizedBox.shrink();
        }

        return _StatusItem(
          avatarUrl: photoUrl,
          name: name,
          note: note,
          isMe: false,
          hasActiveNote: true,
          onTap: () {},
        );
      },
    );
  }
}

// --- PAINTER: Vẽ viền chạy từ 12h nối đuôi nhau ---
class InstagramBorderPainter extends CustomPainter {
  final double progress;

  InstagramBorderPainter({this.progress = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 3) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    paint.shader = const SweepGradient(
      colors: [
        Color(0xFF0517DD),
        Color(0xFFDF4A09),
        Color(0xFF95061C),
        Color(0xFF0517DD),
      ],
      stops: [0.0, 0.4, 0.8, 1.0],
      transform: GradientRotation(-math.pi / 2),
    ).createShader(rect);

    if (progress >= 1.0) {
      canvas.drawCircle(center, radius, paint);
    } else {
      final double sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant InstagramBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// --- UI CHUNG CHO 1 ITEM STATUS ---
class _StatusItem extends StatefulWidget {
  final String avatarUrl;
  final String name;
  final String? note;
  final bool isMe;
  final bool hasActiveNote;
  final VoidCallback onTap;

  const _StatusItem({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.note,
    required this.isMe,
    required this.hasActiveNote,
    required this.onTap,
  });

  @override
  State<_StatusItem> createState() => _StatusItemState();
}

class _StatusItemState extends State<_StatusItem> with TickerProviderStateMixin {
  late AnimationController _formationController;
  late Animation<double> _formationAnimation;
  late AnimationController _rippleController;
  late Animation<double> _rippleScaleAnimation;
  late Animation<double> _rippleOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _formationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _formationAnimation = CurvedAnimation(parent: _formationController, curve: Curves.easeOut);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _rippleScaleAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _rippleOpacityAnimation = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeIn),
    );

    if (widget.hasActiveNote) _startAnimations();
  }

  void _startAnimations() {
    _formationController.forward(from: 0.05);
    _rippleController.forward();
  }

  @override
  void didUpdateWidget(covariant _StatusItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasActiveNote) {
      if (!oldWidget.hasActiveNote || widget.note != oldWidget.note) {
        _formationController.reset();
        _formationController.forward(from: 0.05);
        _rippleController.reset();
        _rippleController.forward();
      }
    } else {
      _formationController.reset();
    }
  }

  @override
  void dispose() {
    _formationController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double avatarRadius = 35;
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 22,
              child: AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _rippleOpacityAnimation.value,
                    child: Transform.scale(
                      scale: _rippleScaleAnimation.value,
                      child: Container(
                        width: avatarRadius * 2,
                        height: avatarRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.pink.withOpacity(0.3),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.hasActiveNote)
                      AnimatedBuilder(
                        animation: _formationAnimation,
                        builder: (context, child) {
                          return SizedBox(
                            width: (avatarRadius * 2) + 14,
                            height: (avatarRadius * 2) + 14,
                            child: CustomPaint(
                              painter: InstagramBorderPainter(progress: _formationAnimation.value),
                            ),
                          );
                        },
                      )
                    else
                      Container(width: (avatarRadius * 2) + 14, height: (avatarRadius * 2) + 14),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: widget.avatarUrl.isNotEmpty ? NetworkImage(widget.avatarUrl) : null,
                        child: widget.avatarUrl.isEmpty ? const Icon(Icons.person, size: 35, color: Colors.grey) : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isMe ? "Bạn" : widget.name.split(' ').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                )
              ],
            ),
            if (widget.isMe)
              Positioned(
                bottom: 22,
                right: 10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            if (widget.hasActiveNote || widget.isMe)
              Positioned(
                top: 3,
                right: -15,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      alignment: Alignment.bottomLeft,
                      child: child,
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 90),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(2, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.blue.withOpacity(0.1), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isMe && !widget.hasActiveNote) ...[
                          Icon(Icons.edit_note_rounded, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            widget.note ?? "Suy nghĩ...",
                            style: TextStyle(
                                fontSize: 11,
                                color: (widget.isMe && !widget.hasActiveNote) ? Colors.grey : Colors.black87,
                                fontWeight: (widget.isMe && !widget.hasActiveNote) ? FontWeight.normal : FontWeight.w500
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}