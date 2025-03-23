// Add this utility class to your project:

import 'dart:async';
import 'dart:collection';

class RateLimitManager {
  // Singleton instance
  static final RateLimitManager _instance = RateLimitManager._internal();
  factory RateLimitManager() => _instance;
  RateLimitManager._internal();

  // Track API calls by endpoint
  final Map<String, Queue<DateTime>> _requestTimestamps = {};

  // Default rate limit: 10 requests per 10 seconds per endpoint
  final int _maxRequestsPerWindow = 10;
  final Duration _windowDuration = Duration(seconds: 10);

  // Backoff times for different endpoints
  final Map<String, DateTime> _backoffUntil = {};

  // Check if a request can be made without hitting rate limits
  bool canMakeRequest(String endpoint) {
    final now = DateTime.now();

    // Check if this endpoint is in backoff mode
    if (_backoffUntil.containsKey(endpoint)) {
      if (now.isBefore(_backoffUntil[endpoint]!)) {
        // Still in backoff period
        return false;
      } else {
        // Backoff period expired
        _backoffUntil.remove(endpoint);
      }
    }

    // Initialize the queue if needed
    if (!_requestTimestamps.containsKey(endpoint)) {
      _requestTimestamps[endpoint] = Queue<DateTime>();
      return true;
    }

    // Remove timestamps older than the window
    final windowStart = now.subtract(_windowDuration);
    while (_requestTimestamps[endpoint]!.isNotEmpty &&
        _requestTimestamps[endpoint]!.first.isBefore(windowStart)) {
      _requestTimestamps[endpoint]!.removeFirst();
    }

    // Check if we've reached the maximum requests in this window
    return _requestTimestamps[endpoint]!.length < _maxRequestsPerWindow;
  }

  // Record that a request was made
  void recordRequest(String endpoint) {
    if (!_requestTimestamps.containsKey(endpoint)) {
      _requestTimestamps[endpoint] = Queue<DateTime>();
    }

    _requestTimestamps[endpoint]!.add(DateTime.now());
  }

  // Handle rate limit error (429) with exponential backoff
  void applyBackoff(String endpoint, int attempt) {
    // Exponential backoff formula: 2^attempt * baseDelay
    final backoffSeconds = (1 << attempt) * 2; // 2, 4, 8, 16, 32... seconds
    final until = DateTime.now().add(Duration(seconds: backoffSeconds));

    _backoffUntil[endpoint] = until;

    // Also clear the request queue for this endpoint
    _requestTimestamps[endpoint]?.clear();
  }

  // Get time remaining until next request is allowed
  Duration timeUntilNextAllowed(String endpoint) {
    final now = DateTime.now();

    // If in backoff mode, return time until backoff expires
    if (_backoffUntil.containsKey(endpoint) && now.isBefore(_backoffUntil[endpoint]!)) {
      return _backoffUntil[endpoint]!.difference(now);
    }

    // If no requests have been made, allow immediately
    if (!_requestTimestamps.containsKey(endpoint) || _requestTimestamps[endpoint]!.isEmpty) {
      return Duration.zero;
    }

    // If under the limit, allow immediately
    if (_requestTimestamps[endpoint]!.length < _maxRequestsPerWindow) {
      return Duration.zero;
    }

    // Calculate when the oldest request will expire from the window
    final oldestTimestamp = _requestTimestamps[endpoint]!.first;
    final windowExpiry = oldestTimestamp.add(_windowDuration);
    return windowExpiry.difference(now);
  }
}