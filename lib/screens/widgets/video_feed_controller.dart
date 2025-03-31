import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Manages all videos in a feed to ensure proper playback control
class VideoFeedController extends ChangeNotifier {
  // Singleton instance
  static final VideoFeedController _instance = VideoFeedController._internal();
  factory VideoFeedController() => _instance;
  VideoFeedController._internal() {
    print("VideoFeedController initialized with mute state: $_isMuted");
  }

  // Currently playing video ID (can be post ID or video URL hash)
  String? _currentlyPlayingId;
  String? get currentlyPlayingId => _currentlyPlayingId;

  // Global mute state
  bool _isMuted = true;
  bool get isMuted => _isMuted;

  // Map of active controllers
  final Map<String, VideoPlayerController> _controllers = {};

  // Track visible videos
  final Set<String> _visibleVideoIds = {};

  // Check if a specific video is currently playing
  bool isVideoPlaying(String videoId) {
    final controller = _controllers[videoId];
    return controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying;
  }

  // Play a specific video by ID
  void playVideoById(String videoId) {
    final controller = _controllers[videoId];
    if (controller != null) {
      playVideo(videoId, controller);
    } else {
      print("Cannot play video $videoId: controller not found");
    }
  }

  // Pause a specific video by ID
  void pauseVideo(String videoId) {
    final controller = _controllers[videoId];
    if (controller != null && controller.value.isInitialized && controller.value.isPlaying) {
      controller.pause();
      print("Paused video: $videoId");

      // If this was the currently playing video, clear current ID
      if (_currentlyPlayingId == videoId) {
        _currentlyPlayingId = null;
      }

      notifyListeners();
    }
  }

  // Pause any previously playing videos and play the new one
  void playVideo(String videoId, VideoPlayerController controller) {
    print("Playing video: $videoId, muted: $_isMuted");

    // If this is the same video already playing, don't do anything
    if (_currentlyPlayingId == videoId && controller.value.isPlaying) {
      return;
    }

    // Pause any currently playing video
    if (_currentlyPlayingId != null && _currentlyPlayingId != videoId) {
      pauseCurrentVideo();
    }

    // Set the new currently playing video
    _currentlyPlayingId = videoId;

    // Play the new video (ensuring it's initialized first)
    if (controller.value.isInitialized) {
      controller.play();
      controller.setVolume(_isMuted ? 0.0 : 1.0);
      print("Video started playing with volume: ${_isMuted ? 0.0 : 1.0}");
    }

    notifyListeners();
  }

  // Register a controller
  void registerController(String videoId, VideoPlayerController controller) {
    _controllers[videoId] = controller;

    // Apply current mute setting to new controller
    if (controller.value.isInitialized) {
      controller.setVolume(_isMuted ? 0.0 : 1.0);
      print("Registered video $videoId with volume: ${_isMuted ? 0.0 : 1.0}");
    }
  }

  // Unregister a controller
  void unregisterController(String videoId) {
    _controllers.remove(videoId);
    _visibleVideoIds.remove(videoId);

    // If this was the currently playing video, clear it
    if (_currentlyPlayingId == videoId) {
      _currentlyPlayingId = null;

      // Try to play the next visible video if any
      if (_visibleVideoIds.isNotEmpty) {
        final nextVideoId = _visibleVideoIds.first;
        final nextController = _controllers[nextVideoId];
        if (nextController != null) {
          playVideo(nextVideoId, nextController);
        }
      }
    }
  }

  // Pause the currently playing video
  void pauseCurrentVideo() {
    if (_currentlyPlayingId != null) {
      final controller = _controllers[_currentlyPlayingId];
      if (controller != null && controller.value.isPlaying) {
        controller.pause();
        print("Paused current video: $_currentlyPlayingId");
      }
    }
  }

  // Toggle global mute state
  void toggleMute() {
    print("Toggling mute state from $_isMuted to ${!_isMuted}");
    _isMuted = !_isMuted;

    final newVolume = _isMuted ? 0.0 : 1.0;
    print("Setting all videos to volume: $newVolume");

    // Apply to all active controllers
    for (final entry in _controllers.entries) {
      final controller = entry.value;
      if (controller.value.isInitialized) {
        controller.setVolume(newVolume);
        print("Set video ${entry.key} volume to $newVolume");
      }
    }

    notifyListeners();
    print("Notified listeners of mute state change");
  }

  // Set specific mute state
  void setMuted(bool muted) {
    if (_isMuted != muted) {
      print("Setting mute state from $_isMuted to $muted");
      _isMuted = muted;

      final newVolume = _isMuted ? 0.0 : 1.0;

      // Apply to all active controllers
      for (final controller in _controllers.values) {
        if (controller.value.isInitialized) {
          controller.setVolume(newVolume);
        }
      }

      notifyListeners();
    }
  }

  // Mark a video as visible in the viewport
  void markVideoVisible(String videoId) {
    _visibleVideoIds.add(videoId);
    print("Marked video visible: $videoId");

    // Auto-play first visible video if nothing is playing
    if (_currentlyPlayingId == null && _visibleVideoIds.isNotEmpty) {
      final controller = _controllers[videoId];
      if (controller != null && controller.value.isInitialized) {
        playVideo(videoId, controller);
      }
    }
  }

  // Mark a video as no longer visible
  void markVideoInvisible(String videoId) {
    _visibleVideoIds.remove(videoId);
    print("Marked video invisible: $videoId");

    // If this was the playing video, pause it
    if (_currentlyPlayingId == videoId) {
      pauseCurrentVideo();

      // Try to play the next visible video if any
      if (_visibleVideoIds.isNotEmpty) {
        final nextVideoId = _visibleVideoIds.first;
        final nextController = _controllers[nextVideoId];
        if (nextController != null) {
          playVideo(nextVideoId, nextController);
        }
      } else {
        _currentlyPlayingId = null;
      }
    }
  }

  // When user leaves screen, pause all
  void pauseAll() {
    print("Pausing all videos");
    for (final entry in _controllers.entries) {
      final controller = entry.value;
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
        print("Paused video: ${entry.key}");
      }
    }
    _currentlyPlayingId = null;
  }

  // For cleanup
  @override
  void dispose() {
    _controllers.clear();
    _visibleVideoIds.clear();
    _currentlyPlayingId = null;
    super.dispose();
    print("VideoFeedController disposed");
  }
}