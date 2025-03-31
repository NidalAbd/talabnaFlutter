import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../utils/constants.dart';
import 'package:talabna/screens/widgets/video_feed_controller.dart';
import 'feed_video_player.dart';
import 'feed_video_player_wrapper.dart';

class ImageGrid extends StatefulWidget {
  final List<String> imageUrls;
  final Function(String)? onImageTap;
  final bool autoPlayVideos;
  final bool showFullscreenOption;
  final String uniqueId; // Add a unique identifier for this instance
  final double maxHeight;
  final bool isReelsMode; // New flag for reels mode
  final Function(String)? onVideoReelsTap; // New callback for opening video in reels mode

  const ImageGrid({
    super.key,
    required this.imageUrls,
    this.onImageTap,
    this.autoPlayVideos = true,
    this.showFullscreenOption = true,
    this.uniqueId = '',
    this.maxHeight = 400.0,
    this.isReelsMode = false, // Default to regular feed mode
    this.onVideoReelsTap, // Optional callback for opening in reels
  });

  @override
  State<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends State<ImageGrid> with RouteAware {
  late PageController _pageController;
  int _currentIndex = 0;
  late RouteObserver<PageRoute> routeObserver;

  // Global feed controller for all videos
  final VideoFeedController _videoFeedController = VideoFeedController();

  // Used to detect when the user is manually scrolling
  bool _isUserScrolling = false;

  // Track if the grid is visible on screen
  bool _isVisible = false;
  bool _isPaused = false;

  // Track auto-scrolling for videos that finish
  Timer? _autoScrollTimer;

  // Unique key for visibility detector
  late final String _visibilityKey;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Create a unique key for this instance's visibility detector
    _visibilityKey = widget.uniqueId.isNotEmpty
        ? 'image_grid_${widget.uniqueId}'
        : 'image_grid_${hashCode}';

    // Add scroll listener to detect user interaction
    _pageController.addListener(_handleScroll);
  }

  void _handleScroll() {
    // This helps us determine if the user is manually scrolling
    if (_pageController.page != _currentIndex.toDouble()) {
      _isUserScrolling = true;
      // Reset after short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isUserScrolling = false;
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      routeObserver = ModalRoute.of(context)
          ?.navigator
          ?.widget
          .observers
          .firstWhere((observer) => observer is RouteObserver<PageRoute>,
          orElse: () => RouteObserver<PageRoute>())
      as RouteObserver<PageRoute>;
      routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    } catch (e) {
      // Handle the case where route observer is not available
      print('Warning: Could not register route observer: $e');
    }
  }

  @override
  void didPopNext() {
    _resumeCurrentVideoIfVisible();
  }

  @override
  void didPush() => _pauseAllVideos();

  @override
  void didPop() => _pauseAllVideos();

  @override
  void didPushNext() {
    _pauseAllVideos();
    _isPaused = true;
  }

  void _pauseAllVideos() {
    _videoFeedController.pauseAll();
  }

  void _resumeCurrentVideoIfVisible() {
    // Resume is now handled by the VideoFeedController
    _isPaused = false;
  }

  void _handleVideoEnd() {
    // If this is not the last item, auto-advance after video ends
    if (_currentIndex < widget.imageUrls.length - 1) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && !_isUserScrolling) {
          _pageController.animateToPage(
            _currentIndex + 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }
  void _handleVideoTap(String url) {
    // Add debugging print statements
    print("_handleVideoTap called with URL: $url");
    print("isReelsMode: ${widget.isReelsMode}");
    print("onVideoReelsTap is null: ${widget.onVideoReelsTap == null}");

    // If we're already in reels mode, do nothing
    if (widget.isReelsMode) {
      print("Already in reels mode, ignoring tap");
      return;
    }

    // If we have a callback to open in reels mode, use it
    if (widget.onVideoReelsTap != null) {
      // Pause current video
      print("Pausing all videos and calling onVideoReelsTap");
      _pauseAllVideos();

      // Call the callback with the URL to open in reels mode
      widget.onVideoReelsTap!(url);
    } else {
      print("onVideoReelsTap callback is null, cannot open reels");
    }
  }
  // Updated build method to move page indicator
  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final currentUrl = widget.imageUrls[_currentIndex];

    // Calculate appropriate height based on mode
    double effectiveHeight = widget.isReelsMode
        ? MediaQuery.of(context).size.height
        : widget.maxHeight;

    // Wrap the entire widget with a visibility detector
    return VisibilityDetector(
      key: Key(_visibilityKey),
      onVisibilityChanged: (info) {
        final isVisible = info.visibleFraction > 0.1;

        if (mounted && isVisible != _isVisible) {
          setState(() {
            _isVisible = isVisible;
          });

          if (!isVisible) {
            _pauseAllVideos();
          }
        }
      },
      child: Container(
        width: screenWidth,
        height: effectiveHeight,
        decoration: BoxDecoration(
          borderRadius: widget.isReelsMode
              ? BorderRadius.zero
              : BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Main content area
            Expanded(
              child: Stack(
                children: [
                  // Render content
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.imageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _isUserScrolling = false;
                      });
                    },
                    itemBuilder: (context, index) {
                      final url = widget.imageUrls[index];
                      final isVideoMedia = url.toLowerCase().endsWith('.mp4');
                      final videoId = '${widget.uniqueId}_${index}_${url.hashCode}';

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: widget.isReelsMode
                              ? BorderRadius.zero
                              : BorderRadius.circular(8),
                          color: Colors.black,
                        ),
                        child: ClipRRect(
                          borderRadius: widget.isReelsMode
                              ? BorderRadius.zero
                              : BorderRadius.circular(8),
                          child: isVideoMedia
                              ? _buildVideoItem(url, videoId, effectiveHeight, screenWidth, index)
                              : _buildImageItem(url, effectiveHeight),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Page indicator below content
            if (widget.imageUrls.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: widget.imageUrls.length,
                  effect: WormEffect(
                    dotWidth: 6,
                    dotHeight: 6,
                    activeDotColor: Colors.white,
                    dotColor: Colors.white.withOpacity(0.5),
                    radius: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoItem(String url, String videoId, double height, double width, int index) {
    if (widget.isReelsMode) {
      // In reels mode, just show the video player
      return FeedVideoPlayerWrapper(
        url: '${Constants.apiBaseUrl}/$url',
        videoId: videoId,
        maxHeight: height,
        maxWidth: width,
        feedController: _videoFeedController,
        onVideoEnd: _handleVideoEnd,
        autoPlay: widget.autoPlayVideos && _currentIndex == index && _isVisible && !_isPaused,
        borderRadius: BorderRadius.zero,
        isReelsMode: true,
        disablePlayPause: true,
      );
    } else {
      // In regular mode, wrap in a GestureDetector to handle taps on the video area
      return Stack(
        children: [
          // 1. Video player at the bottom layer
          FeedVideoPlayerWrapper(
            url: '${Constants.apiBaseUrl}/$url',
            videoId: videoId,
            maxHeight: height,
            maxWidth: width,
            feedController: _videoFeedController,
            onVideoEnd: _handleVideoEnd,
            autoPlay: widget.autoPlayVideos && _currentIndex == index && _isVisible && !_isPaused,
            borderRadius: BorderRadius.circular(8),
            isReelsMode: false,
            // This callback only gets called by the fullscreen button
            onReelsTap: () {
              if (widget.onVideoReelsTap != null) {
                _pauseAllVideos();
                widget.onVideoReelsTap!(url);
              }
            },
            // Disable the video player's tap-to-pause functionality
            disablePlayPause: true,
            // Pass true to indicate we want the buttons to handle their own taps
            isolateButtonTaps: true,
          ),

          // 2. Add an overlay for the main video area tap (excluding control buttons)
          // This ensures taps on the main video area go to reels
          Positioned.fill(
            child: IgnorePointer(
              // This is critical - it will ignore taps on areas where control buttons are
              ignoringSemantics: false,
              child: GestureDetector(
                onTap: () {
                  print("Main video area tapped, opening reels: $url");
                  if (widget.onVideoReelsTap != null) {
                    _pauseAllVideos();
                    widget.onVideoReelsTap!(url);
                  } else {
                    print("ERROR: onVideoReelsTap callback is null");
                  }
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }


  // Build image item
  Widget _buildImageItem(String url, double height) {
    return GestureDetector(
      onTap: widget.onImageTap != null
          ? () => widget.onImageTap!(url)
          : null,
      child: ImageContainer(
        url: url,
        maxHeight: height,
        isReelsMode: widget.isReelsMode,
      ),
    );
  }

  // Helper to check if any videos are in the list
  bool _videoIsPresent() {
    return widget.imageUrls.any((url) => url.toLowerCase().endsWith('.mp4'));
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.removeListener(_handleScroll);
    _pageController.dispose();

    try {
      routeObserver.unsubscribe(this);
    } catch (e) {
      // Handle the case where unsubscribe fails
      print('Warning: Could not unsubscribe from route observer: $e');
    }
    super.dispose();
  }
}

class ImageContainer extends StatelessWidget {
  final String url;
  final double maxHeight;
  final bool isReelsMode;

  const ImageContainer({
    super.key,
    required this.url,
    required this.maxHeight,
    this.isReelsMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageUrl = url.startsWith('http')
            ? url
            : '${Constants.apiBaseUrl}/$url';

        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: isReelsMode ? BoxFit.cover : BoxFit.contain,
          imageBuilder: (context, imageProvider) {
            return Image(
              image: imageProvider,
              fit: isReelsMode ? BoxFit.cover : BoxFit.contain,
              height: maxHeight,
              width: constraints.maxWidth,
            );
          },
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.black,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.grey[400],
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}