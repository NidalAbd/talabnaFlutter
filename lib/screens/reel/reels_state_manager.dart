import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/utils/debug_logger.dart';

/// An improved singleton class to manage the state of ReelsHomeScreen
/// that coordinates with the unified deep linking and navigation flow
class ReelsStateManager {
  static final ReelsStateManager _instance = ReelsStateManager._internal();

  factory ReelsStateManager() => _instance;

  ReelsStateManager._internal();

  // Track active screens by postId
  final Set<String> _activeScreens = {};

  // Track pending initializations to avoid race conditions
  final Set<String> _pendingInitializations = {};

  // Track processed deep links
  final Set<String> _processedDeepLinks = {};

  // Track valid post IDs
  final Set<String> _validPostIds = {};

  // Navigation lock management
  bool _isNavigationLocked = false;
  DateTime? _lastNavigationAttempt;
  static const int NAVIGATION_COOLDOWN_MS = 800;

  // Lock duration for various operations
  final Duration _lockDuration = Duration(seconds: 3);

  // Lock timers
  Timer? _navigationLockTimer;

  // Public getters
  bool get isNavigationLocked => _isNavigationLocked;

  Set<String> get activeScreenIds => Set.from(_activeScreens);

  bool get hasActiveScreen => _activeScreens.isNotEmpty;

  // Ensure we have a valid ID before operations
  String _sanitizeId(dynamic id) {
    if (id == null) return "unknown";
    return id.toString();
  }

  // Check if a screen with this post ID is already active
  bool isScreenActive(String postId) {
    postId = _sanitizeId(postId);
    final bool isActive = _activeScreens.contains(postId) ||
        _pendingInitializations.contains(postId);

    if (isActive) {
      DebugLogger.log('Detected duplicate navigation attempt for reel: $postId',
          category: 'REELS');
    }

    return isActive;
  }

  // Check if any reels screen is active
  bool hasAnyActiveScreens() {
    return _activeScreens.isNotEmpty || _pendingInitializations.isNotEmpty;
  }

  // Check if navigation is allowed
  bool canNavigate(String postId) {
    postId = _sanitizeId(postId);

    // Check if screen is already active
    if (isScreenActive(postId)) {
      DebugLogger.log('Screen already active for $postId, blocking navigation',
          category: 'REELS');
      return false;
    }

    // Check global navigation lock
    if (_isNavigationLocked) {
      DebugLogger.log(
          'Navigation already in progress, blocking navigation to $postId',
          category: 'REELS');
      return false;
    }

    // Check recent navigation cooldown
    if (_lastNavigationAttempt != null) {
      final timeSinceLastNav =
          DateTime.now().difference(_lastNavigationAttempt!).inMilliseconds;
      if (timeSinceLastNav < NAVIGATION_COOLDOWN_MS) {
        DebugLogger.log(
            'Navigation cooldown active ($timeSinceLastNav ms), blocking navigation to $postId',
            category: 'REELS');
        return false;
      }
    }

    // Record this attempt
    _lastNavigationAttempt = DateTime.now();
    return true;
  }

  // Mark a reel as active
  void markReelActive(String postId) {
    postId = _sanitizeId(postId);

    if (!_pendingInitializations.contains(postId)) {
      _pendingInitializations.add(postId);
      DebugLogger.log('Marked reel $postId as pending initialization',
          category: 'REELS');
    }

    // Schedule cleanup for pending status
    Timer(Duration(seconds: 5), () {
      if (_pendingInitializations.contains(postId) &&
          !_activeScreens.contains(postId)) {
        _pendingInitializations.remove(postId);
        DebugLogger.log('Auto-removed pending status for reel $postId',
            category: 'REELS');
      }
    });
  }

  // Mark a reel as inactive
  void markReelInactive(String postId) {
    postId = _sanitizeId(postId);

    _pendingInitializations.remove(postId);
    if (_activeScreens.remove(postId)) {
      DebugLogger.log('Marked reel $postId as inactive', category: 'REELS');
    }

    // Clear flag from SharedPreferences
    _clearReelFlags(postId);
  }

  // Mark a screen as fully initialized (active)
  void markScreenInitialized(String postId) {
    postId = _sanitizeId(postId);

    // Remove from pending initializations
    _pendingInitializations.remove(postId);

    // Add to active screens
    if (!_activeScreens.contains(postId)) {
      _activeScreens.add(postId);
      DebugLogger.log('Reels screen marked as initialized for $postId',
          category: 'REELS');

      // Also mark this post as valid for future reference
      _validPostIds.add(postId);
      _storeValidPostId(postId);
    } else {
      DebugLogger.log('Reels screen already initialized for $postId',
          category: 'REELS');
    }

    // Mark as processed deep link
    _processedDeepLinks.add(postId);
  }

  // Mark a screen as disposed
  void markScreenDisposed(String postId) {
    postId = _sanitizeId(postId);

    // Remove from active and pending sets
    if (_activeScreens.remove(postId)) {
      DebugLogger.log('Reels screen marked as disposed for $postId',
          category: 'REELS');
    }

    _pendingInitializations.remove(postId);

    // Clear from SharedPreferences
    _clearReelFlags(postId);
  }

  // Clear reel flags from SharedPreferences
  void _clearReelFlags(String postId) {
    SharedPreferences.getInstance().then((prefs) {
      // Only clear if this matches the pending reel ID
      String? pendingReelId = prefs.getString('pending_reel_id');
      if (pendingReelId == postId) {
        prefs.remove('pending_reel_id');
        prefs.remove('pending_select_category');
        prefs.setBool('direct_deeplink_active', false);
        DebugLogger.log('Cleared pending reel data for $postId',
            category: 'REELS');
      }
    });
  }

  // Acquire navigation lock
  bool acquireNavigationLock() {
    if (_isNavigationLocked) {
      DebugLogger.log('Navigation lock acquisition failed - already locked',
          category: 'REELS');
      return false;
    }

    // Set lock
    _isNavigationLocked = true;

    // Set auto-release timer
    _navigationLockTimer?.cancel();
    _navigationLockTimer = Timer(_lockDuration, () {
      _isNavigationLocked = false;
      DebugLogger.log('Navigation lock auto-released after timeout',
          category: 'REELS');
    });

    DebugLogger.log('Navigation lock successfully acquired', category: 'REELS');
    return true;
  }

  // Release navigation lock
  void releaseNavigationLock() {
    _isNavigationLocked = false;
    _navigationLockTimer?.cancel();
    DebugLogger.log('Navigation lock manually released', category: 'REELS');
  }

  // Force release all locks
  void forceReleaseLocks() {
    // Keep a copy for logging
    final activeScreensCopy = Set<String>.from(_activeScreens);
    final pendingInitsCopy = Set<String>.from(_pendingInitializations);

    // Release all locks
    _isNavigationLocked = false;
    _navigationLockTimer?.cancel();
    _lastNavigationAttempt = null;
    _activeScreens.clear();
    _pendingInitializations.clear();

    // Log the released locks
    if (activeScreensCopy.isNotEmpty || pendingInitsCopy.isNotEmpty) {
      DebugLogger.log(
          'Forcing release of all reels locks - ${activeScreensCopy.length} active screens, ' +
              '${pendingInitsCopy.length} pending',
          category: 'REELS');
      DebugLogger.log(
          'Released locks for: ${activeScreensCopy.join(", ")} and pending: ${pendingInitsCopy.join(", ")}',
          category: 'REELS');
    }

    DebugLogger.log('All reels locks released', category: 'REELS');
  }

  // Mark a post ID as valid
  void markPostAsValid(String postId) {
    postId = _sanitizeId(postId);
    _validPostIds.add(postId);
    _storeValidPostId(postId);
  }

  // Store valid post ID in SharedPreferences
  void _storeValidPostId(String postId) {
    SharedPreferences.getInstance().then((prefs) {
      final validPosts = prefs.getStringList('cached_valid_posts') ?? [];
      if (!validPosts.contains(postId)) {
        validPosts.add(postId);
        prefs.setStringList('cached_valid_posts', validPosts);
        DebugLogger.log('Marked post $postId as valid in SharedPreferences',
            category: 'REELS');
      }
    });
  }

  // Check if a post ID is valid
  Future<bool> isPostValid(String postId) async {
    postId = _sanitizeId(postId);

    // Check memory cache first
    if (_validPostIds.contains(postId)) {
      return true;
    }

    // Then check SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final invalidLinks = prefs.getStringList('invalid_deep_links') ?? [];
      final validPosts = prefs.getStringList('cached_valid_posts') ?? [];

      // Check if in valid list
      if (validPosts.contains(postId)) {
        _validPostIds.add(postId); // Add to memory cache
        return true;
      }

      // Check if in invalid list
      if (invalidLinks.contains('reels/$postId')) {
        return false;
      }

      // Default to true if unknown
      return true;
    } catch (e) {
      DebugLogger.log('Error checking post validity: $e', category: 'REELS');
      return true; // Default to true on error
    }
  }

  // Mark a post as invalid
  Future<void> markPostAsInvalid(String postId) async {
    postId = _sanitizeId(postId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final invalidLinks = prefs.getStringList('invalid_deep_links') ?? [];

      if (!invalidLinks.contains('reels/$postId')) {
        invalidLinks.add('reels/$postId');
        await prefs.setStringList('invalid_deep_links', invalidLinks);
        DebugLogger.log('Marked post $postId as invalid', category: 'REELS');
      }
    } catch (e) {
      DebugLogger.log('Error marking post as invalid: $e', category: 'REELS');
    }
  }

  // Log the current state for debugging
  void logState() {
    DebugLogger.log('ReelsStateManager Status:', category: 'REELS_STATE');
    DebugLogger.log('- Active screens: ${_activeScreens.toString()}',
        category: 'REELS_STATE');
    DebugLogger.log(
        '- Pending initializations: ${_pendingInitializations.toString()}',
        category: 'REELS_STATE');
    DebugLogger.log('- Processed deep links: ${_processedDeepLinks.toString()}',
        category: 'REELS_STATE');
    DebugLogger.log('- Valid posts: ${_validPostIds.toString()}',
        category: 'REELS_STATE');
    DebugLogger.log('- Navigation locked: $_isNavigationLocked',
        category: 'REELS_STATE');
  }
}
