import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zalo_app/widgets/comment_sheet.dart';
import 'package:zalo_app/widgets/reactions_popup.dart';

class PostItem extends StatefulWidget {
  final DocumentSnapshot postDoc;

  const PostItem({super.key, required this.postDoc});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey _likeButtonKey = GlobalKey();

  // Audio player logic is removed as per the new design. 
  // If playback is needed, it can be re-added here.

  Future<void> _updateReaction(String? reaction) async {
    if (_currentUser == null) return;

    final postRef = widget.postDoc.reference;
    final postData = widget.postDoc.data() as Map<String, dynamic>;
    final authorId = postData['authorId'];

    if (reaction == null) {
      await postRef.update({
        'reactions.${_currentUser!.uid}': FieldValue.delete(),
      });
    } else {
      await postRef.update({
        'reactions.${_currentUser!.uid}': reaction,
      });

      if (authorId != _currentUser!.uid) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
        final reactorName = userDoc.data()?['displayName'] ?? 'Một người dùng';
        final notificationMessage = reactionData[reaction]?['notification'] ?? 'đã bày tỏ cảm xúc về bài viết của bạn';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(authorId)
            .collection('notifications')
            .add({
          'title': '$reactorName $notificationMessage',
          'body': postData['content'],
          'timestamp': Timestamp.now(),
          'isRead': false,
          'postId': widget.postDoc.id,
          'type': 'reaction',
        });
      }
    }
  }

  void _showCommentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8, 
          child: CommentSheet(postId: widget.postDoc.id),
        );
      },
    );
  }

  void _showReactionsPopup() {
    showReactionsPopup(
      context,
      buttonKey: _likeButtonKey,
      onReactionSelected: (reaction) {
        _updateReaction(reaction);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final postData = widget.postDoc.data() as Map<String, dynamic>;
    final String authorName = postData['authorName'] ?? 'Người dùng';
    final String authorAvatarUrl = postData['authorAvatarUrl'] ?? '';
    final String content = postData['content'] ?? '';
    final Timestamp timestamp = postData['timestamp'] ?? Timestamp.now();
    final String? imageUrl = postData['imageUrl'];
    final Map<String, dynamic>? songInfo = postData.containsKey('songInfo') ? postData['songInfo'] as Map<String, dynamic> : null;

    final Map<String, dynamic> reactions = postData.containsKey('reactions') ? postData['reactions'] as Map<String, dynamic> : {};
    final String? currentUserReaction = _currentUser != null ? reactions[_currentUser!.uid] : null;

    return Card(
      color: Colors.white, 
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundImage: authorAvatarUrl.isNotEmpty ? NetworkImage(authorAvatarUrl) : null,
                  child: authorAvatarUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      // CORRECTED: Song info is here, or timestamp if no song
                      songInfo != null
                          ? _buildCompactSongInfo(songInfo)
                          : Text(DateFormat.yMMMd().add_Hm().format(timestamp.toDate()), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
              ],
            ),
            // Content is now below the header
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(content, style: const TextStyle(fontSize: 15)),
            ],
            if (imageUrl != null) ...[
              const SizedBox(height: 8),
              // FIX: Use FractionallySizedBox to make the image fill the width
              FractionallySizedBox(
                widthFactor: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
            ],
            // Stats and action buttons are at the bottom
            _buildPostStats(reactions),
            const Divider(height: 1, thickness: 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLikeButton(currentUserReaction),
                TextButton.icon(
                  onPressed: _showCommentSheet,
                  icon: Icon(Icons.comment_outlined, color: Colors.grey[600]),
                  label: Text('Bình luận', style: TextStyle(color: Colors.grey[700])),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.share_outlined, color: Colors.grey[600]),
                  label: Text('Chia sẻ', style: TextStyle(color: Colors.grey[700])),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // CORRECTED WIDGET as per the image
  Widget _buildCompactSongInfo(Map<String, dynamic> songInfo) {
    return Row(
      children: [
        Icon(Icons.music_note, size: 14, color: Colors.grey[800]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${songInfo['artist']} • ${songInfo['name']}',
            style: TextStyle(color: Colors.grey[800], fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLikeButton(String? currentUserReaction) {
    final reaction = reactionData[currentUserReaction];
    final iconData = reaction?['icon'] ?? Icons.thumb_up_alt_outlined;

    Widget reactionIcon;
    if (iconData is IconData) {
      reactionIcon = Icon(iconData, color: reaction?['color'] ?? Colors.grey[600]);
    } else if (iconData is String) {
      reactionIcon = Text(iconData, style: const TextStyle(fontSize: 20));
    } else {
      reactionIcon = const SizedBox.shrink();
    }

    return GestureDetector(
      onLongPress: _showReactionsPopup,
      child: TextButton.icon(
        key: _likeButtonKey,
        onPressed: () {
          if (currentUserReaction != null) {
            _updateReaction(null); 
          } else {
            _updateReaction('like');
          }
        },
        icon: reactionIcon,
        label: Text(
          reaction?['label'] ?? 'Thích',
          style: TextStyle(color: reaction?['color'] ?? Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildPostStats(Map<String, dynamic> reactions) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Row(
        children: [
          if (reactions.isNotEmpty) _buildReactionSummary(reactions),
          const Spacer(),
          StreamBuilder<QuerySnapshot>(
            stream: widget.postDoc.reference.collection('comments').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final commentCount = snapshot.data!.docs.length;
              if (commentCount > 0) {
                return Text('$commentCount bình luận', style: TextStyle(color: Colors.grey[700], fontSize: 13));
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReactionSummary(Map<String, dynamic> reactions) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    
    final reactionCounts = <String, int>{};
    reactions.forEach((key, value) {
      reactionCounts[value] = (reactionCounts[value] ?? 0) + 1;
    });

    final sortedReactions = reactionCounts.keys.toList()
      ..sort((a, b) => reactionCounts[b]!.compareTo(reactionCounts[a]!));

    final topReactions = sortedReactions.take(3).toList();

    return Row(
      children: [
        Stack(
          children: List.generate(topReactions.length, (index) {
            final iconData = reactionData[topReactions[index]]?['icon'];
            Widget reactionIcon;
            if (iconData is IconData) {
              reactionIcon = Icon(iconData, color: reactionData[topReactions[index]]?['color'], size: 16);
            } else if (iconData is String) {
              reactionIcon = Text(iconData, style: const TextStyle(fontSize: 12));
            } else {
              reactionIcon = const SizedBox.shrink();
            }

            return Padding(
              padding: EdgeInsets.only(left: (index * 12).toDouble()),
              child: CircleAvatar(radius: 9, backgroundColor: Colors.white, child: reactionIcon),
            );
          }),
        ),
        const SizedBox(width: 8),
        Text('${reactions.length}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
      ],
    );
  }
}
