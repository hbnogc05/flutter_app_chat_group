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

        // Lấy danh sách reactions (Map<uid, emoji>)
        final reactions = data?['noteReactions'] as Map<String, dynamic>? ?? {};

        bool isExpired = true;
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toDate());
          if (diff.inHours < 24) isExpired = false;
        }

        final bool hasActiveNote = (note != null && note.isNotEmpty && !isExpired);
        final displayNote = hasActiveNote ? note : "Suy nghĩ...";

        return _StatusItem(
          avatarUrl: photoUrl,
          name: "Bạn",
          note: displayNote,
          isMe: true,
          hasActiveNote: hasActiveNote,
          onTap: () {
            if (hasActiveNote) {
              // Truyền thêm reactions vào hàm xem chi tiết
              _showViewStatusBottomSheet(context, note!, photoUrl, reactions);
            } else {
              _showEditNoteDialog(context, '', photoUrl);
            }
          },
        );
      },
    );
  }

  // --- HÀM 1: Xem chi tiết trạng thái (CỦA BẢN THÂN) ---
  void _showViewStatusBottomSheet(BuildContext context, String currentNote, String photoUrl, Map<String, dynamic> initialReactions) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Sử dụng StreamBuilder để cập nhật reaction real-time khi đang mở bảng xem
        return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              Map<String, dynamic> reactions = initialReactions;
              if (snapshot.hasData && snapshot.data!.data() != null) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                reactions = data['noteReactions'] as Map<String, dynamic>? ?? {};
              }

              return Container(
                height: MediaQuery.of(context).size.height * 0.5, // Tăng chiều cao xíu để chứa reaction
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Stack(
                  children: [
                    Column(
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
                        const SizedBox(height: 24),
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  currentNote,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -6,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Transform.rotate(
                                    angle: 45 * 3.14159 / 180,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      color: Colors.grey[100],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          "Đã chia sẻ với bạn bè",
                          style: TextStyle(fontSize: 12, color: Colors.grey, height: 2),
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
                                _showEditNoteDialog(context, '', photoUrl);
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
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final uid = FirebaseAuth.instance.currentUser!.uid;
                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              'note': FieldValue.delete(),
                              'noteTimestamp': FieldValue.delete(),
                              'noteReactions': FieldValue.delete(), // Xóa cả reactions khi xóa note
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          child: const Text(
                            "Xóa ghi chú",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),

                    // --- UI HIỂN THỊ CẢM XÚC (Góc dưới trái) ---
                    if (reactions.isNotEmpty)
                      Positioned(
                        bottom: 160,
                        left: 20,
                        child: GestureDetector(
                          onTap: () {
                            // Bấm vào thì hiện danh sách chi tiết
                            _showReactionListSheet(context, reactions);
                          },
                          child: _ReactionFacePile(reactions: reactions),
                        ),
                      ),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  // --- HÀM 2: Giao diện Viết/Sửa trạng thái ---
  void _showEditNoteDialog(BuildContext context, String? currentNote, String userAvatarUrl) {
    final controller = TextEditingController(text: currentNote);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final bool hasText = controller.text.trim().isNotEmpty;

            return Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 10,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 30, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 16,
                      child: GestureDetector(
                        onTap: hasText ? () async {
                          final text = controller.text.trim();
                          Navigator.pop(context);

                          if (text.isNotEmpty) {
                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              'note': text,
                              'noteTimestamp': FieldValue.serverTimestamp(),
                              'noteReactions': {}, // Reset reactions khi đăng note mới
                            });
                          }
                        } : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: hasText ? const Color(0xFF133FED) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            "Chia sẻ",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: hasText ? Colors.white : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 200,
                                  constraints: const BoxConstraints(minHeight: 80),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    textAlign: TextAlign.center,
                                    maxLength: 60,
                                    maxLines: 3,
                                    minLines: 1,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                    onChanged: (value) => setState(() {}),
                                    decoration: const InputDecoration(
                                      hintText: "Bạn đang nghĩ gì?",
                                      hintStyle: TextStyle(color: Colors.grey),
                                      border: InputBorder.none,
                                      counterText: "",
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -10,
                                  right: 60,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -22,
                                  right: 45,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 35),
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: userAvatarUrl.isNotEmpty ? NetworkImage(userAvatarUrl) : null,
                              child: userAvatarUrl.isEmpty ? const Icon(Icons.person, size: 45, color: Colors.grey) : null,
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

  // --- HÀM 3: Hiển thị danh sách chi tiết người thả reaction ---
  void _showReactionListSheet(BuildContext context, Map<String, dynamic> reactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Cảm xúc", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: reactions.length,
                  itemBuilder: (context, index) {
                    final uid = reactions.keys.elementAt(index);
                    final emoji = reactions.values.elementAt(index);

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                        final name = userData?['displayName'] ?? 'Người dùng';
                        final photo = userData?['photoURL'] ?? '';

                        return ListTile(
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                child: photo.isEmpty ? const Icon(Icons.person) : null,
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Text(emoji, style: const TextStyle(fontSize: 16)),
                              )
                            ],
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final List<dynamic> friends = userData?['friends'] ?? [];

        if (friends.isEmpty) return const SizedBox.shrink();

        return Row(
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

        // Lấy reactions
        final reactions = data['noteReactions'] as Map<String, dynamic>? ?? {};

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
          onTap: () {
            // Mở BottomSheet xem note bạn bè và thả reaction
            _showFriendNoteBottomSheet(context, friendId, note, photoUrl, name, reactions);
          },
        );
      },
    );
  }

  void _showFriendNoteBottomSheet(BuildContext context, String friendId, String note, String photoUrl, String name, Map<String, dynamic> reactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.45,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 40,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
              ),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        note,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ),
                    Positioned(
                      top: -6, left: 0, right: 0,
                      child: Center(
                        child: Transform.rotate(
                          angle: 45 * 3.14159 / 180,
                          child: Container(width: 12, height: 12, color: Colors.grey[100]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // --- THANH CẢM XÚC ---
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text("Bày tỏ cảm xúc", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ReactionButton(emoji: "😮", friendId: friendId),
                    _ReactionButton(emoji: "😂", friendId: friendId),
                    _ReactionButton(emoji: "😢", friendId: friendId),
                    _ReactionButton(emoji: "❤️", friendId: friendId),
                    _ReactionButton(emoji: "😡", friendId: friendId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final String emoji;
  final String friendId;

  const _ReactionButton({required this.emoji, required this.friendId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        // 1. Lấy vị trí toàn cục của nút reaction để bắt đầu animation
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset offset = renderBox.localToGlobal(renderBox.size.center(Offset.zero));

        // 2. Kích hoạt hiệu ứng bay emoji (gọi hàm global/static helper)
        _showFlyingEmojis(context, offset, emoji);

        // 3. Update DB
        await FirebaseFirestore.instance.collection('users').doc(friendId).set({
          'noteReactions': {
            currentUser.uid: emoji
          }
        }, SetOptions(merge: true));

        // 4. Đóng bottom sheet
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã thả $emoji"), duration: const Duration(seconds: 1)));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

// --- HÀM HELPER: Tạo hiệu ứng bay emoji ---
void _showFlyingEmojis(BuildContext context, Offset startPos, String emoji) {
  // Lấy Overlay hiện tại (thường là của MaterialApp)
  final overlay = Overlay.of(context);

  // GIẢM SỐ LƯỢNG xuong 20 cho đỡ rối
  for (int i = 0; i < 10; i++) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyingEmoji(
        startPos: startPos,
        emoji: emoji,
        onFinished: () {
          // Khi animation xong thì xóa entry khỏi overlay để tránh leak memory
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

// --- WIDGET: Emoji bay (Animation) ---
class _FlyingEmoji extends StatefulWidget {
  final Offset startPos;
  final String emoji;
  final VoidCallback onFinished;

  const _FlyingEmoji({
    required this.startPos,
    required this.emoji,
    required this.onFinished,
  });

  @override
  State<_FlyingEmoji> createState() => _FlyingEmojiState();
}

class _FlyingEmojiState extends State<_FlyingEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _opacityAnimation;
  late double _randomXOffset;
  late double _randomSize;

  @override
  void initState() {
    super.initState();
    final random = math.Random();

    // TỐC ĐỘ CHẬM HƠN: 2000ms - 3500ms (trước đây là 500-1500ms)
    final duration = Duration(milliseconds: 2000 + random.nextInt(1500));
    _controller = AnimationController(vsync: this, duration: duration);

    // Bay cao hơn để ra ngoài viền màn hình (từ -800 đến -1200 pixel)
    _yAnimation = Tween<double>(begin: 0, end: -800.0 - random.nextInt(400)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );

    // Mờ dần khi gần kết thúc
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
    );

    // BUNG RỘNG RA 2 BÊN: Random từ -300 đến +300 (phủ rộng chiều ngang điện thoại)
    // Tạo hình rẻ quạt từ vị trí nút bấm
    _randomXOffset = (random.nextDouble() - 0.5) * 600;

    // Random kích thước (20 đến 45) - to hơn xíu để rõ
    _randomSize = 20.0 + random.nextInt(25);

    _controller.forward().then((_) {
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: widget.startPos.dy + _yAnimation.value,
          left: widget.startPos.dx + (_randomXOffset * _controller.value), // Bung dần ra theo thời gian
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: Text(
                widget.emoji,
                style: TextStyle(fontSize: _randomSize),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- WIDGET HELPER: Hiển thị FacePile (Gom nhóm reaction) ---
class _ReactionFacePile extends StatelessWidget {
  final Map<String, dynamic> reactions;

  const _ReactionFacePile({required this.reactions});

  @override
  Widget build(BuildContext context) {
    // Lấy tối đa 2 người đầu tiên để hiển thị avatar
    final uids = reactions.keys.toList();
    final displayCount = uids.length > 2 ? 2 : uids.length;
    final remainingCount = uids.length - 2;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
          ]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hiển thị Avatar của tối đa 2 người
          for (int i = 0; i < displayCount; i++)
            Align(
              widthFactor: 0.7, // Xếp chồng lên nhau
              child: _SingleReactorAvatar(uid: uids[i], emoji: reactions[uids[i]]),
            ),

          // Nếu còn dư người thì hiện số lượng
          if (remainingCount > 0)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  "+$remainingCount",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
              ),
            ),

          const SizedBox(width: 8), // Padding phải
        ],
      ),
    );
  }
}

class _SingleReactorAvatar extends StatelessWidget {
  final String uid;
  final String emoji;

  const _SingleReactorAvatar({required this.uid, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        String? photoUrl;
        if (snapshot.hasData) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          photoUrl = data?['photoURL'];
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                image: photoUrl != null && photoUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                    : null,
                color: Colors.grey[300],
              ),
              child: photoUrl == null || photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.grey)
                  : null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Text(emoji, style: const TextStyle(fontSize: 12)),
            )
          ],
        );
      },
    );
  }
}

// --- PAINTER: Vẽ viền Instagram ---
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
      colors: [Color(0xFF0517DD), Color(0xFFDF4A09), Color(0xFF95061C), Color(0xFF0517DD)],
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

// --- UI ITEM STATUS ---
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

    if (widget.hasActiveNote) {
      _formationController.value = 1.0;
    }
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
            // Hiệu ứng Ripple
            if (widget.hasActiveNote)
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

            // Chỉ hiện nút (+) màu xanh nếu LÀ MÌNH và CHƯA CÓ NOTE
            if (widget.isMe && !widget.hasActiveNote)
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
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(2, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.blue.withOpacity(0.1), width: 1),
                    ),
                    child: Text(
                      widget.note ?? "",
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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