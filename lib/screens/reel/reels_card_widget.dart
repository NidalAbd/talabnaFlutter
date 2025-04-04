import 'package:flutter/material.dart';
import 'package:talabna/screens/reel/user_details_bar.dart';
import 'package:talabna/screens/reel/video_player_item.dart';
import 'package:talabna/data/models/service_post.dart';
import 'interaction_buttons.dart';

class ReelCardWidget extends StatelessWidget {
  final ServicePost servicePost;
  final bool isFavorite;
  final VoidCallback onLikePressed;
  final VoidCallback onCommentPressed;
  final VoidCallback onContactPressed;
  final VoidCallback onSharePressed;

  const ReelCardWidget({
    super.key,
    required this.servicePost,
    required this.isFavorite,
    required this.onLikePressed,
    required this.onCommentPressed,
    required this.onContactPressed,
    required this.onSharePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        servicePost.photos!.first.isVideo!
            ? VideoPlayerItem(videoUrl: servicePost.photos!.first.src!)
            : Image.network(servicePost.photos!.first.src!, fit: BoxFit.cover),
        InteractionButtons(
          isFavorite: isFavorite,
          onCommentPressed: onCommentPressed,
          onContactPressed: onContactPressed,
          onSharePressed: onSharePressed,
          favoritesCount: servicePost.favoritesCount!,
          commentsCount: servicePost.commentsCount!,
          onFavoritePressed: () {},
        ),
        UserDetailsBar(
          userPhotoUrl: servicePost.userPhoto!.src!,
        ),
      ],
    );
  }
}
