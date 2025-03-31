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
  final bool disablePlayPause;
  final bool isolateButtonTaps;

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
    this.disablePlayPause = false,
    this.isolateButtonTaps = false,
  }) : super(key: key);

  @override
  State<FeedVideoPlayerWrapper> createState() => _FeedVideoPlayerWrapperState();
}

class _FeedVideoPlayerWrapperState extends State<FeedVideoPlayerWrapper> {
  bool get isPlaying =>
      widget.feedController.currentlyPlayingId == widget.videoId &&
          widget.feedController.isVideoPlaying(widget.videoId);

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

  void _togglePlayPause() {
    if (isPlaying) {
      widget.feedController.pauseVideo(widget.videoId);
    } else {
      widget.feedController.playVideoById(widget.videoId);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // In reels mode
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
            disablePlayPause: true,
          ),

          // Mute button only (no reels button in reels mode)
          Positioned(
            bottom: 20,
            right: 8,
            width: 36,
            height: 36,
            child: _buildControlButton(
              icon: widget.feedController.isMuted ? Icons.volume_off : Icons.volume_up,
              onTap: _toggleMute,
              isolateTap: true,
            ),
          ),

          // Play/Pause button for reels mode
          Positioned(
            bottom: 20,
            right: 50,
            width: 36,
            height: 36,
            child: _buildControlButton(
              icon: isPlaying ? Icons.pause : Icons.play_arrow,
              onTap: _togglePlayPause,
              isolateTap: true,
            ),
          ),
        ],
      );
    }

    // Regular mode
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
          isReelsMode: false,
          disablePlayPause: widget.disablePlayPause,
        ),

        // Play/Pause button (new)
        Positioned(
          bottom: 20,
          right: 92,  // Position to the left of mute button
          width: 36,
          height: 36,
          child: _buildControlButton(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            onTap: _togglePlayPause,
            isolateTap: widget.isolateButtonTaps,
          ),
        ),

        // Mute button
        Positioned(
          bottom: 20,
          right: 50,
          width: 36,
          height: 36,
          child: _buildControlButton(
            icon: widget.feedController.isMuted ? Icons.volume_off : Icons.volume_up,
            onTap: _toggleMute,
            isolateTap: widget.isolateButtonTaps,
          ),
        ),

        // Fullscreen button
        Positioned(
          bottom: 20,
          right: 8,
          width: 36,
          height: 36,
          child: _buildControlButton(
            icon: Icons.fullscreen,
            onTap: () {
              if (widget.onReelsTap != null) {
                widget.onReelsTap!();
              }
            },
            isolateTap: widget.isolateButtonTaps,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isolateTap,
  }) {
    // Use a more reliable Material/InkWell combo with proper hitTest behavior
    Widget button = Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );

    // If we need to isolate this button's taps from parent gesture detectors
    if (isolateTap) {
      return IgnorePointer(
        ignoring: false, // Don't ignore this widget's own pointer events
        child: button,
      );
    } else {
      return button;
    }
  }
}