// lib/widgets/reactions_popup.dart
import 'package:flutter/material.dart';

// Mapping from reaction string to its data
const Map<String, Map<String, dynamic>> reactionData = {
  'like': {
    'icon': Icons.thumb_up,
    'color': Colors.blue,
    'label': 'Thích',
    'notification': 'đã thích bài viết của bạn'
  },
  'love': {
    'icon': Icons.favorite,
    'color': Colors.red,
    'label': 'Yêu thích',
    'notification': 'đã yêu thích bài viết của bạn'
  },
  'haha': {
    'icon': '😂',
    'color': Colors.orange,
    'label': 'Haha',
    'notification': 'đã haha bài viết của bạn'
  },
  'wow': {
    'icon': '😮',
    'color': Colors.amber,
    'label': 'Wow',
    'notification': 'đã wow bài viết của bạn'
  },
  'sad': {
    'icon': '😢',
    'color': Colors.amber,
    'label': 'Buồn',
    'notification': 'đã buồn về bài viết của bạn'
  },
  'angry': {
    'icon': '😠',
    'color': Colors.red,
    'label': 'Phẫn nộ',
    'notification': 'đã phẫn nộ với bài viết của bạn'
  },
};

void showReactionsPopup(
  BuildContext context, {
  required GlobalKey buttonKey,
  required ValueChanged<String> onReactionSelected,
}) {
  OverlayEntry? overlayEntry;

  final RenderBox button = buttonKey.currentContext!.findRenderObject() as RenderBox;
  final RenderBox overlay = Overlay.of(context)!.context.findRenderObject() as RenderBox;
  final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

  overlayEntry = OverlayEntry(
    builder: (context) {
      return Stack(
        children: [
          // Full screen GestureDetector to dismiss the popup
          Positioned.fill(
            child: GestureDetector(
              onTap: () => overlayEntry?.remove(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // The reactions bar
          Positioned(
            top: buttonPosition.dy - 75, // Position above the button
            left: buttonPosition.dx - 20, // Center it roughly
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: reactionData.keys.map((reactionKey) {
                    return _ReactionItem(
                      reactionKey: reactionKey,
                      onSelect: (reaction) {
                        onReactionSelected(reaction);
                        overlayEntry?.remove();
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Overlay.of(context)!.insert(overlayEntry);
}

class _ReactionItem extends StatefulWidget {
  final String reactionKey;
  final ValueChanged<String> onSelect;

  const _ReactionItem({required this.reactionKey, required this.onSelect});

  @override
  _ReactionItemState createState() => _ReactionItemState();
}

class _ReactionItemState extends State<_ReactionItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = reactionData[widget.reactionKey]!;
    final iconData = data['icon'];

    Widget reactionIcon;
    if (iconData is IconData) {
      reactionIcon = Icon(iconData, color: data['color'], size: 32);
    } else if (iconData is String) {
      reactionIcon = Text(iconData, style: const TextStyle(fontSize: 28));
    } else {
      reactionIcon = const SizedBox.shrink();
    }

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onSelect(widget.reactionKey);
      },
      onTapCancel: () => _controller.reverse(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              reactionIcon,
              const SizedBox(height: 4),
              Text(
                data['label'],
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
