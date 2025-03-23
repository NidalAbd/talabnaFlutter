import 'package:flutter/material.dart';
import 'package:talabna/screens/widgets/video_feed_controller.dart';
import 'feed_video_player.dart';

class FeedVideoPlayerWrapper extends StatefulWidget {
  final String url;
  final String videoId;
  final double maxHeight;
  final double maxWidth;
  final VideoFeedController feedController;
  final VoidCallback? onVideoEnd;
  final BorderRadius? borderRadius;
  final bool autoPlay;
  final bool showControls;
  final bool isReelsMode;
  final VoidCallback? onReelsTap;

  const FeedVideoPlayerWrapper({
    Key? key,
    required this.url,
    required this.videoId,
    required this.maxHeight,
    required this.maxWidth,
    required this.feedController,
    this.onVideoEnd,
    this.borderRadius,
    this.autoPlay = true,
    this.showControls = false,
    this.isReelsMode = false,
    this.onReelsTap,
  }) : super(key: key);

  @override
  State<FeedVideoPlayerWrapper> createState() => _FeedVideoPlayerWrapperState();
}

class _FeedVideoPlayerWrapperState extends State<FeedVideoPlayerWrapper> {
  @override
  void initState() {
    super.initState();
    widget.feedController.addListener(_handleControllerChanges);
  }

  @override
  void dispose() {
    widget.feedController.removeListener(_handleControllerChanges);
    super.dispose();
  }

  void _handleControllerChanges() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleMute() {
    widget.feedController.toggleMute();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // In reels mode, don't add the overlay tap handler
    if (widget.isReelsMode) {
      return Stack(
        children: [
          // Main video player
          FeedVideoPlayer(
            url: widget.url,
            videoId: widget.videoId,
            maxHeight: widget.maxHeight,
            maxWidth: widget.maxWidth,
            feedController: widget.feedController,
            onVideoEnd: widget.onVideoEnd,
            borderRadius: widget.borderRadius,
            autoPlay: widget.autoPlay,
            showControls: false,
            isReelsMode: true,
            disablePlayPause: true, // Disable play/pause
          ),

          // Mute button only (no reels button in reels mode)
          Positioned(
            bottom: 20, // Position above the progress bar
            left: 8,
            child: _buildControlButton(
              icon: widget.feedController.isMuted ? Icons.volume_off : Icons.volume_up,
              onTap: _toggleMute,
            ),
          ),
        ],
      );
    }

    // Regular mode - add tap handler for reels and control buttons
    return GestureDetector(
      onTap: widget.onReelsTap,
      child: Stack(
        children: [
          // Main video player
          FeedVideoPlayer(
            url: widget.url,
            videoId: widget.videoId,
            maxHeight: widget.maxHeight,
            maxWidth: widget.maxWidth,
            feedController: widget.feedController,
            onVideoEnd: widget.onVideoEnd,
            borderRadius: widget.borderRadius,
            autoPlay: widget.autoPlay,
            showControls: false,
            isReelsMode: false,
            disablePlayPause: true, // Disable play/pause
          ),

          // Mute button
          Positioned(
            bottom: 20, // Position above the progress bar
            left: 8,
            child: _buildControlButton(
              icon: widget.feedController.isMuted ? Icons.volume_off : Icons.volume_up,
              onTap: _toggleMute,
            ),
          ),

          // Fullscreen button
          Positioned(
            bottom: 20, // Position above the progress bar
            right: 8,
            child: _buildControlButton(
              icon: Icons.fullscreen,
              onTap: () => widget.onReelsTap?.call(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Important: Prevent tap propagation
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}