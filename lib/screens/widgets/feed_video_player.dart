import 'package:flutter/material.dart';
import 'package:talabna/screens/widgets/video_feed_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';

import '../../utils/constants.dart';

class FeedVideoPlayer extends StatefulWidget {
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
  final bool disablePlayPause; // New property to disable play/pause

  const FeedVideoPlayer({
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
    this.disablePlayPause = false, // Default to allowing play/pause
  }) : super(key: key);

  @override
  _FeedVideoPlayerState createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isBuffering = false;
  bool _isVisible = false;
  bool _hasError = false;
  Timer? _controlsTimer;
  bool _showControls = false;
  bool _isUserInteracting = false;
  final ValueNotifier<Duration> _videoProgress = ValueNotifier(Duration.zero);
  late AnimationController _animationController;
  bool _isDisposed = false;

  double _visibilityPercentage = 0.0;
  static const double _VISIBILITY_THRESHOLD = 0.7;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _initializeController();
  }

  Future<void> _initializeController() async {
    final fullUrl = widget.url.startsWith('http')
        ? widget.url
        : '${Constants.apiBaseUrl}/${widget.url}';

    _controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));

    try {
      setState(() {
        _isBuffering = true;
      });

      await _controller.initialize();

      if (_isDisposed) return;

      _controller.setLooping(true);
      _controller.setVolume(widget.feedController.isMuted ? 0.0 : 1.0);

      widget.feedController.registerController(widget.videoId, _controller);

      _controller.addListener(_videoListener);

      setState(() {
        _isInitialized = true;
        _isBuffering = false;
      });

      if (_isVisible && widget.autoPlay && _visibilityPercentage >= _VISIBILITY_THRESHOLD) {
        _attemptAutoPlay();
      }

    } catch (e) {
      print('Error initializing video: $e');
      print('Video URL: $fullUrl');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isBuffering = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_isDisposed) return;

    if (_controller.value.isBuffering != _isBuffering) {
      if (mounted) {
        setState(() {
          _isBuffering = _controller.value.isBuffering;
        });
      }
    }

    if (!_isUserInteracting) {
      _videoProgress.value = _controller.value.position;
    }

    final shouldBeMuted = widget.feedController.isMuted;
    if ((shouldBeMuted && _controller.value.volume > 0) ||
        (!shouldBeMuted && _controller.value.volume == 0)) {
      _controller.setVolume(shouldBeMuted ? 0.0 : 1.0);
    }

    if (!_controller.value.isLooping &&
        _controller.value.position >= _controller.value.duration &&
        _controller.value.duration.inMilliseconds > 0) {
      widget.onVideoEnd?.call();
    }
  }

  void _attemptAutoPlay() {
    if (_isInitialized && !_hasError && _isVisible &&
        _visibilityPercentage >= _VISIBILITY_THRESHOLD) {
      widget.feedController.playVideo(widget.videoId, _controller);
    }
  }

  void _togglePlayPause() {
    // Don't do anything if play/pause is disabled
    if (widget.disablePlayPause) return;

    if (!_isInitialized) return;

    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() {});
    } else {
      widget.feedController.playVideo(widget.videoId, _controller);
    }
  }

  void _seekTo(Duration position) {
    if (_isInitialized && _controller.value.isInitialized) {
      _controller.seekTo(position);
    }
  }

  @override
  void didUpdateWidget(FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _controller.removeListener(_videoListener);
      widget.feedController.unregisterController(oldWidget.videoId);
      _controller.dispose();

      _isInitialized = false;
      _hasError = false;
      _initializeController();
    }

    if (oldWidget.autoPlay != widget.autoPlay && widget.autoPlay && _isVisible) {
      _attemptAutoPlay();
    }

    if (_isInitialized && _controller.value.isInitialized) {
      final shouldBeMuted = widget.feedController.isMuted;
      final currentVolume = _controller.value.volume;

      if ((shouldBeMuted && currentVolume > 0) || (!shouldBeMuted && currentVolume == 0)) {
        _controller.setVolume(shouldBeMuted ? 0.0 : 1.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('feed_video_${widget.videoId}'),
      onVisibilityChanged: (visibilityInfo) {
        if (!mounted) return;

        final visiblePercentage = visibilityInfo.visibleFraction;
        _visibilityPercentage = visiblePercentage;

        if (visiblePercentage >= _VISIBILITY_THRESHOLD) {
          if (!_isVisible) {
            if (mounted) {
              setState(() {
                _isVisible = true;
              });

              widget.feedController.markVideoVisible(widget.videoId);

              if (widget.autoPlay && _isInitialized) {
                _attemptAutoPlay();
              }
            }
          }
        } else if (visiblePercentage < 0.2) {
          if (_isVisible) {
            if (mounted) {
              setState(() {
                _isVisible = false;
              });

              widget.feedController.markVideoInvisible(widget.videoId);
            }
          }
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          double finalWidth = constraints.maxWidth;
          double finalHeight = widget.maxHeight;

          if (_isInitialized) {
            final videoWidth = _controller.value.size.width;
            final videoHeight = _controller.value.size.height;

            if (videoWidth > 0 && videoHeight > 0) {
              final videoAspectRatio = videoWidth / videoHeight;

              if (widget.isReelsMode) {
                finalWidth = constraints.maxWidth;
                finalHeight = widget.maxHeight;
              } else {
                double calculatedHeight = finalWidth / videoAspectRatio;

                if (calculatedHeight > widget.maxHeight) {
                  if (calculatedHeight > widget.maxHeight * 1.5) {
                    finalHeight = widget.maxHeight;
                    finalWidth = constraints.maxWidth;
                  } else {
                    finalHeight = widget.maxHeight;
                    finalWidth = finalHeight * videoAspectRatio;

                    if (finalWidth > constraints.maxWidth) {
                      finalWidth = constraints.maxWidth;
                    }
                  }
                } else {
                  finalHeight = calculatedHeight;
                }
              }
            }
          }

          finalHeight = finalHeight < 200 ? 200 : finalHeight;

          return Container(
            width: finalWidth,
            height: finalHeight,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: widget.borderRadius ?? BorderRadius.zero,
            ),
            child: Stack(
              children: [
                // Video content
                if (_isInitialized)
                  Center(
                    child: widget.isReelsMode ||
                        (_controller.value.size.height > widget.maxHeight * 1.5)
                        ? _buildCoverModeVideo()
                        : _buildContainModeVideo(),
                  ),

                // Loading indicator
                if (!_isInitialized || _isBuffering)
                  Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  ),

                // Error indicator
                if (_hasError)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.white, size: 42),
                        SizedBox(height: 8),
                        Text(
                          'Error loading video',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _hasError = false;
                                _isInitialized = false;
                              });
                              _initializeController();
                            }
                          },
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),

                // Progress bar (always visible) with interactive dragging
                if (_isInitialized)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildInteractiveProgressBar(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoverModeVideo() {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }

  Widget _buildContainModeVideo() {
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }

  Widget _buildInteractiveProgressBar() {
    return ValueListenableBuilder(
      valueListenable: _videoProgress,
      builder: (context, Duration value, _) {
        final maxDuration = _controller.value.duration.inMilliseconds > 0
            ? _controller.value.duration.inMilliseconds.toDouble()
            : 1.0;
        final current = value.inMilliseconds.toDouble().clamp(0.0, maxDuration);

        return GestureDetector(
          onHorizontalDragStart: (details) {
            _isUserInteracting = true;
            if (_controller.value.isPlaying) {
              _controller.pause();
            }
          },
          onHorizontalDragUpdate: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset localPosition = box.globalToLocal(details.globalPosition);
            final double width = box.size.width;
            final double position = localPosition.dx.clamp(0.0, width);
            final double percentage = position / width;
            final Duration newPosition = Duration(
                milliseconds: (percentage * maxDuration).round()
            );
            _videoProgress.value = newPosition;
          },
          onHorizontalDragEnd: (details) {
            _seekTo(_videoProgress.value);
            _isUserInteracting = false;
            _controller.play();
          },
          onTapDown: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset localPosition = box.globalToLocal(details.globalPosition);
            final double width = box.size.width;
            final double position = localPosition.dx.clamp(0.0, width);
            final double percentage = position / width;
            final Duration newPosition = Duration(
                milliseconds: (percentage * maxDuration).round()
            );
            _videoProgress.value = newPosition;
            _seekTo(newPosition);
          },
          child: Container(
            height: 20,
            padding: EdgeInsets.symmetric(vertical: 8),
            color: Colors.transparent,
            child: Stack(
              children: [
                // Background track
                Container(
                  height: 4,
                  width: double.infinity,
                  color: Colors.white.withOpacity(0.3),
                ),
                // Progress track
                FractionallySizedBox(
                  widthFactor: maxDuration > 0 ? current / maxDuration : 0,
                  child: Container(
                    height: 4,
                    color: Colors.white,
                  ),
                ),
                // Drag handle
                Positioned(
                  left: (current / maxDuration) * (MediaQuery.of(context).size.width - 12),
                  top: -4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 0),
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
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controlsTimer?.cancel();
    _animationController.dispose();

    if (_isInitialized) {
      _controller.removeListener(_videoListener);
      widget.feedController.unregisterController(widget.videoId);
      _controller.dispose();
    }
    super.dispose();
  }
}