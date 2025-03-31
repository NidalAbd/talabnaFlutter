import 'dart:async';
import 'dart:collection';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/repositories/service_post_repository.dart';
import 'package:talabna/utils/debug_logger.dart';

import '../../core/network_connectivity.dart';
import '../../utils/rate_limit_manager.dart';

class ServicePostBloc extends Bloc<ServicePostEvent, ServicePostState> {
  final ServicePostRepository servicePostRepository;

  // Caches for different types of service post requests
  final Map<int, List<ServicePost>> _categoryPostsCache = {};
  final Map<int, List<ServicePost>> _subcategoryPostsCache = {};
  final Map<int, List<ServicePost>> _userPostsCache = {};
  final Map<int, List<ServicePost>> _userFavoritePostsCache = {};
  final Map<int, ServicePost> _postByIdCache = {};
  final List<ServicePost> _realsPostsCache = [];
  final Map<String, int> _lastLoadedPages = {};
  final NetworkConnectivity connectivity = NetworkConnectivity();

  // Cache page information to support pagination
  final Map<int, ServicePost> _postDetailsCache = {};

  // Track pending requests to avoid duplicates
  final Set<String> _pendingRequests = {};

  // LRU tracking for category access
  final LinkedHashMap<int, DateTime> _recentlyAccessedCategories =
  LinkedHashMap<int, DateTime>();
  final int _maxCachedCategories = 3; // Keep at most 3 categories in memory

  // Set to store deleted post IDs for consistent UI updates
  final Set<int> _deletedPostIds = {};

  // Flag indicating if cache has been initialized
  bool _isCacheInitialized = false;
  final Map<String, bool> _requestsInProgress = {};

  bool _dataSaverEnabled = false;

// Add this method to initialize data saver mode
  Future<void> _initializeDataSaverMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dataSaverEnabled = prefs.getBool('data_saver_enabled') ?? false;
      DebugLogger.log('Data saver mode initialized: $_dataSaverEnabled',
          category: 'SERVICE_POST_BLOC');
    } catch (e) {
      DebugLogger.log('Error initializing data saver mode: $e',
          category: 'SERVICE_POST_BLOC');
    }
  }

  ServicePostBloc({
    required this.servicePostRepository,
  }) : super(ServicePostInitial()) {
    on<GetServicePostsByCategoryEvent>(_handleGetServicePostsByCategoryEvent);
    on<GetServicePostByIdEvent>(_handleGetServicePostByIdEvent);
    on<LoadOldOrNewFormEvent>(_handleLoadOldOrNewFormEvent);
    on<GetServicePostsByUserFavouriteEvent>(
        _handleGetServicePostsByUserFavouriteEvent);
    on<GetServicePostsRealsEvent>(_handleGetServicePostsRealsEvent);
    on<GetServicePostsByCategorySubCategoryEvent>(
        _handleGetServicePostsByCategorySubCategoryEvent);
    on<GetServicePostsByUserIdEvent>(_handleGetServicePostsByUserIdEvent);
    on<CreateServicePostEvent>(_handleCreateServicePostEvent);
    on<UpdateServicePostEvent>(_handleUpdateServicePostEvent);
    on<UpdatePhotoServicePostEvent>(_handleUpdatePhotoServicePostEvent);
    on<ServicePostCategoryUpdateEvent>(_handleServicePostCategoryUpdateEvent);
    on<ServicePostBadgeUpdateEvent>(_handleServicePostBadgeUpdateEvent);
    on<DeleteServicePostEvent>(_handleDeleteServicePostEvent);
    on<ViewIncrementServicePostEvent>(_handleViewIncrementServicePostEvent);
    on<ToggleFavoriteServicePostEvent>(_handleToggleFavoriteServicePostEvent);
    on<InitializeFavoriteServicePostEvent>(
        _handleInitializeFavoriteServicePostEvent);
    on<DeleteServicePostImageEvent>(_handleDeleteServicePostImageEvent);
    on<ClearServicePostCacheEvent>(_handleClearServicePostCacheEvent);
    on<GetAllServicePostsEvent>(_handleGetAllServicePostsEvent);
    on<InitializeCachesEvent>(_handleInitializeCachesEvent);
    // Add data saver event handlers
    on<DataSaverToggleEvent>(_handleDataSaverToggleEvent);
    on<DataSaverStatusChangedEvent>(_handleDataSaverStatusChangedEvent);
    _setupConnectivityListener();
    _initializeDataSaverMode();
  }

  void _setupConnectivityListener() {
    connectivity.connectivityStream.listen((isConnected) {
      if (isConnected) {
        DebugLogger.log('Network connected, refreshing data in background',
            category: 'CONNECTIVITY');
        // Refresh most recently used categories when connection is restored
        _refreshRecentlyUsedCategories();
      } else {
        DebugLogger.log('Network disconnected, operating in offline mode',
            category: 'CONNECTIVITY');
      }
    });
  }

  Future<void> _handleInitializeCachesEvent(
      InitializeCachesEvent event, Emitter<ServicePostState> emit) async {
    try {
      DebugLogger.log('Initializing service post caches', category: 'INIT');
      // We're just initializing tracking structures, not actual content caches
      _pendingRequests.clear();
      _deletedPostIds.clear();
      DebugLogger.log('Service post tracking structures initialized',
          category: 'INIT');
    } catch (e) {
      DebugLogger.log('Error initializing service post structures: $e',
          category: 'INIT_ERROR');
    }
  }

  // Refresh recently used categories when connection is restored
  Future<void> _refreshRecentlyUsedCategories() async {
    final categories = List<int>.from(_recentlyAccessedCategories.keys);

    for (final categoryId in categories) {
      try {
        add(GetServicePostsByCategoryEvent(
          categoryId,
          1,
          forceRefresh: true,
        ));

        DebugLogger.log(
            'Refreshing category $categoryId after connection restored',
            category: 'SERVICE_POST_BLOC');
      } catch (e) {
        DebugLogger.log('Error refreshing category $categoryId: $e',
            category: 'SERVICE_POST_BLOC');
      }
    }
  }

// Helper to manage cached categories (LRU)
  void _updateRecentlyAccessedCategories(int categoryId) {
    // Remove and re-add to update access time
    _recentlyAccessedCategories.remove(categoryId);
    _recentlyAccessedCategories[categoryId] = DateTime.now();

    // Enforce cache size limit
    if (_recentlyAccessedCategories.length > _maxCachedCategories) {
      // Find oldest entry
      int? oldestCategory;
      DateTime? oldestTime;

      for (final entry in _recentlyAccessedCategories.entries) {
        if (oldestTime == null || entry.value.isBefore(oldestTime)) {
          oldestCategory = entry.key;
          oldestTime = entry.value;
        }
      }

      if (oldestCategory != null) {
        _recentlyAccessedCategories.remove(oldestCategory);
        _categoryPostsCache.remove(oldestCategory);
        DebugLogger.log(
            'Removed least recently used category $oldestCategory from cache',
            category: 'SERVICE_POST_BLOC');
      }
    }
  }

  // Handler for GetAllServicePostsEvent
  Future<void> _handleGetAllServicePostsEvent(
      GetAllServicePostsEvent event, Emitter<ServicePostState> emit) async {
    // Ensure cache is initialized

    emit( ServicePostLoading(event: 'GetAllServicePostsEvent'));

    if (state is ServicePostLoadSuccess &&
        (state as ServicePostLoadSuccess).hasReachedMax) {
      return;
    }

    final cacheKey = 'all_posts';

    // Check if a similar request is already in progress
    if (_pendingRequests.contains(cacheKey)) {
      DebugLogger.log('Skipping duplicate GetAllServicePosts request',
          category: 'SERVICE_POST_BLOC');
      return;
    }

    _pendingRequests.add(cacheKey);

    try {
      if (state is! ServicePostLoadSuccess) {
        final servicePosts = await servicePostRepository.getAllServicePosts();
        _pendingRequests.remove(cacheKey);

        // Remove deleted posts from results
        final filteredPosts = servicePosts
            .where((post) => !_deletedPostIds.contains(post.id))
            .toList();

        emit(ServicePostLoadSuccess(
            servicePosts: filteredPosts,
            hasReachedMax: filteredPosts.length < 10,
            event: 'GetAllServicePostsEvent'));
      } else {
        final currentState = state as ServicePostLoadSuccess;
        final servicePosts = await servicePostRepository.getAllServicePosts();
        _pendingRequests.remove(cacheKey);

        // Remove deleted posts from results
        final filteredPosts = servicePosts
            .where((post) => !_deletedPostIds.contains(post.id))
            .toList();

        if (filteredPosts.isEmpty) {
          emit(currentState.copyWith(hasReachedMax: true));
        } else {
          emit(currentState.copyWith(
            servicePosts: currentState.servicePosts + filteredPosts,
            hasReachedMax: false,
          ));
        }
      }
    } catch (e) {
      _pendingRequests.remove(cacheKey);
      emit(ServicePostLoadFailure(
          errorMessage: e.toString(), event: 'GetAllServicePostsEvent'));
    }
  }

  Future<void> _handleGetServicePostByIdEvent(
      GetServicePostByIdEvent event, Emitter<ServicePostState> emit) async {

    final cacheKey = 'post_${event.id}';

    // Check if a similar request is already in progress
    if (_pendingRequests.contains(cacheKey)) {
      DebugLogger.log(
          'Skipping duplicate GetServicePostById request: ${event.id}',
          category: 'SERVICE_POST_BLOC');
      return;
    }

    _pendingRequests.add(cacheKey);

    try {
      // Always fetch from API
      final ServicePost servicePost =
      await servicePostRepository.getServicePostById(event.id);

      // Mark post as valid for deep links
      if (servicePost.id != null) {
        markPostAsValid(servicePost.id!);
      }

      _pendingRequests.remove(cacheKey);

      emit(ServicePostLoadSuccess(
          servicePosts: [servicePost],
          hasReachedMax: true,
          event: 'GetServicePostByIdEvent'));
    } catch (e) {
      _pendingRequests.remove(cacheKey);

      emit(ServicePostLoadFailure(
          errorMessage: e.toString(), event: 'GetServicePostByIdEvent'));
    }
  }

  // Background fetch and update for service post by ID
  Future<void> _fetchAndUpdateServicePostById(int postId) async {
    final cacheKey = 'post_${postId}_background';

    if (_pendingRequests.contains(cacheKey)) {
      return;
    }

    _pendingRequests.add(cacheKey);

    try {
      final post = await servicePostRepository.getServicePostById(postId);

      // Update memory cache
      if (post.id != null) {
        _postByIdCache[post.id!] = post;
        markPostAsValid(post.id!);
      }
    } catch (e) {
      DebugLogger.log('Error in background fetch for post $postId: $e',
          category: 'SERVICE_POST_BLOC');
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }

  // Handler for LoadOldOrNewFormEvent
  Future<void> _handleLoadOldOrNewFormEvent(
      LoadOldOrNewFormEvent event, Emitter<ServicePostState> emit) async {
    emit( ServicePostLoading(event: 'LoadOldOrNewForm'));

    try {
      ServicePost? servicePost;
      if (event.servicePostId != null) {
        // Check cache first
        if (_postByIdCache.containsKey(event.servicePostId)) {
          servicePost = _postByIdCache[event.servicePostId];
        } else {}
      }
      emit(ServicePostFormLoadSuccess(servicePost: servicePost));
    } catch (e) {
      emit(ServicePostLoadFailure(
          errorMessage: e.toString(), event: 'LoadOldOrNewForm'));
    }
  }

  Future<void> _handleGetServicePostsByUserFavouriteEvent(
      GetServicePostsByUserFavouriteEvent event,
      Emitter<ServicePostState> emit) async {
    // Ensure cache is initialized

    emit( ServicePostLoading(event: 'GetServicePostByFavouriteEvent'));

    final userId = event.userId;
    final page = event.page;

    // Don't fetch if we've reached the max
    if (state is ServicePostLoadSuccess &&
        (state as ServicePostLoadSuccess).hasReachedMax) {
      return;
    }

    final cacheKey = 'favorite_${userId}_page${page}';

    // Check if we have this page in cache and not forcing refresh
    if (page == 1 &&
        !event.forceRefresh &&
        _userFavoritePostsCache.containsKey(userId)) {
      DebugLogger.log('Using cached favorite posts for user $userId',
          category: 'SERVICE_POST_BLOC');

      final cachedPosts = _userFavoritePostsCache[userId]!;
      emit(ServicePostLoadSuccess(
          servicePosts: cachedPosts,
          hasReachedMax: cachedPosts.length < 10,
          event: 'GetServicePostByFavouriteEvent'));

      // If not forcing refresh, still update in background
      if (!event.forceRefresh && !_pendingRequests.contains(cacheKey)) {
        _fetchAndUpdateUserFavoritePosts(userId, page);
      }
      return;
    }

    // Check if a similar request is already in progress
    if (_pendingRequests.contains(cacheKey)) {
      DebugLogger.log(
          'Skipping duplicate GetServicePostsByUserFavourite request',
          category: 'SERVICE_POST_BLOC');
      return;
    }

    _pendingRequests.add(cacheKey);

    try {
      if (state is! ServicePostLoadSuccess || page == 1) {
        final servicePosts =
        await servicePostRepository.getServicePostsByUserFavourite(
          page: page,
          userId: userId,
        );

        _pendingRequests.remove(cacheKey);

        // Cache first page results
        if (page == 1) {
          _userFavoritePostsCache[userId] = servicePosts;
        }

        // Filter out deleted posts
        final filteredPosts = servicePosts
            .where((post) => !_deletedPostIds.contains(post.id))
            .toList();

        emit(ServicePostLoadSuccess(
            servicePosts: filteredPosts,
            hasReachedMax: filteredPosts.length < 10,
            event: 'GetServicePostByFavouriteEvent'));
      } else {
        final currentState = state as ServicePostLoadSuccess;
        final servicePosts =
        await servicePostRepository.getServicePostsByUserFavourite(
          page: page,
          userId: userId,
        );

        _pendingRequests.remove(cacheKey);

        // Filter out deleted posts
        final filteredPosts = servicePosts
            .where((post) => !_deletedPostIds.contains(post.id))
            .toList();

        if (filteredPosts.isEmpty) {
          emit(currentState.copyWith(hasReachedMax: true));
        } else {
          emit(currentState.copyWith(
            servicePosts: currentState.servicePosts + filteredPosts,
            hasReachedMax: false,
          ));
        }
      }
    } catch (e) {
      _pendingRequests.remove(cacheKey);
      emit(ServicePostLoadFailure(
          errorMessage: e.toString(), event: 'GetServicePostByFavouriteEvent'));
    }
  }

  // Background fetch and update for user favorite posts
  Future<void> _fetchAndUpdateUserFavoritePosts(int userId, int page) async {
    final cacheKey = 'favorite_${userId}_page${page}_background';

    if (_pendingRequests.contains(cacheKey)) {
      return;
    }

    _pendingRequests.add(cacheKey);

    try {
      final posts = await servicePostRepository.getServicePostsByUserFavourite(
        page: page,
        userId: userId,
      );

      // Update memory cache
      if (page == 1) {
        _userFavoritePostsCache[userId] = posts;
      }

      // Cache individual posts
      for (final post in posts) {
        if (post.id != null) {
          _postByIdCache[post.id!] = post;
        }
      }
    } catch (e) {
      DebugLogger.log('Error in background fetch for user favorites: $e',
          category: 'SERVICE_POST_BLOC');
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }



// Then update the handler method in ServicePostBloc
  Future<void> _handleGetServicePostsByCategoryEvent(
      GetServicePostsByCategoryEvent event, Emitter<ServicePostState> emit) async {

    // Only show loading for the first page if showLoadingState is true
    if (event.page == 1 && event.showLoadingState) {
      emit( ServicePostLoading(event: 'GetServicePostsByCategoryEvent'));
    }

    // Create a unique request key that includes all relevant parameters
    final filterParam = event.typeFilter != null ? '_type_${event.typeFilter}' : '';
    final priceParam = (event.minPrice != null && event.maxPrice != null)
        ? '_price_${event.minPrice!.toInt()}_${event.maxPrice!.toInt()}'
        : '';
    final cacheKey = 'category_${event.category}_page${event.page}${filterParam}${priceParam}_${event.forceRefresh}';

    // Check if this exact request is already in progress
    if (_requestsInProgress[cacheKey] == true) {
      DebugLogger.log(
          'Request already in progress for category ${event.category} page ${event.page}',
          category: 'SERVICE_POST_BLOC');
      return; // Skip this request
    }

    // Mark this request as in progress
    _requestsInProgress[cacheKey] = true;

    try {
      // Always fetch from API for fresh data with filters
      final stopwatch = Stopwatch()..start();

      final servicePosts =
      await servicePostRepository.getServicePostsByCategory(
        categories: event.category,
        page: event.page,
        type: event.typeFilter,
        minPrice: event.minPrice,
        maxPrice: event.maxPrice,
      );

      stopwatch.stop();
      DebugLogger.log(
          'Fetched ${servicePosts.length} posts for category ${event.category} in ${stopwatch.elapsedMilliseconds}ms',
          category: 'SERVICE_POST_BLOC');

      // Cache first page results with filter parameters in the key
      if (event.page == 1) {
        final cacheName = 'category_${event.category}${filterParam}${priceParam}';
        _filteredPostsCache[cacheName] = servicePosts;

        // If no filters, also cache in the traditional category cache
        if (event.typeFilter == null && event.minPrice == null && event.maxPrice == null) {
          _categoryPostsCache[event.category] = servicePosts;
        }

        // Update LRU tracking
        _updateRecentlyAccessedCategories(event.category);
      }

      final filteredPosts = servicePosts
          .where((post) => !_deletedPostIds.contains(post.id))
          .toList();

      // Changed: Only mark as reached max if we received an empty list from the server
      // This allows pagination to continue as long as the server returns posts
      final bool hasReachedMax = filteredPosts.isEmpty;

      DebugLogger.log(
          'Emitting state with ${filteredPosts.length} posts for category ${event.category} page ${event.page}, hasReachedMax: $hasReachedMax',
          category: 'SERVICE_POST_BLOC');

      // For first page, always replace existing posts
      if (event.page == 1) {
        emit(ServicePostLoadSuccess(
            servicePosts: filteredPosts,
            hasReachedMax: hasReachedMax,
            event: 'GetServicePostsByCategoryEvent'));
      }
      // For pagination, append posts to existing list
      else if (state is ServicePostLoadSuccess) {
        final currentState = state as ServicePostLoadSuccess;

        if (filteredPosts.isEmpty) {
          emit(currentState.copyWith(hasReachedMax: true));
        } else {
          // Get the current posts
          final currentPosts = List<ServicePost>.from(currentState.servicePosts);

          // Append the new posts
          currentPosts.addAll(filteredPosts);

          // Emit the updated state
          emit(ServicePostLoadSuccess(
            servicePosts: currentPosts,
            hasReachedMax: hasReachedMax,
            event: 'GetServicePostsByCategoryEvent',
          ));
        }
      } else {
        // Fallback case
        emit(ServicePostLoadSuccess(
            servicePosts: filteredPosts,
            hasReachedMax: hasReachedMax,
            event: 'GetServicePostsByCategoryEvent'));
      }
    } catch (e) {
      DebugLogger.log('Error fetching service posts: $e',
          category: 'SERVICE_POST_BLOC');

      // If we have cached data for this category with the same filters, use it despite the error
      if (event.page == 1) {
        final cacheKey = 'category_${event.category}${filterParam}${priceParam}';

        if (_filteredPostsCache.containsKey(cacheKey)) {
          final cachedPosts = _filteredPostsCache[cacheKey]!;
          final filteredPosts = cachedPosts
              .where((post) => !_deletedPostIds.contains(post.id))
              .toList();

          DebugLogger.log('Using cached posts after API error',
              category: 'SERVICE_POST_BLOC');

          emit(ServicePostLoadSuccess(
            servicePosts: filteredPosts,
            hasReachedMax: true, // Mark as reached max when using fallback cache
            event: 'GetServicePostsByCategoryEvent',
          ));
          return;
        }

        // If no filtered cache exists but we have a regular category cache, use that
        if (_categoryPostsCache.containsKey(event.category) &&
            event.typeFilter == null && event.minPrice == null && event.maxPrice == null) {

          final cachedPosts = _categoryPostsCache[event.category]!;
          final filteredPosts = cachedPosts
              .where((post) => !_deletedPostIds.contains(post.id))
              .toList();

          DebugLogger.log('Using category cache after API error',
              category: 'SERVICE_POST_BLOC');

          emit(ServicePostLoadSuccess(
            servicePosts: filteredPosts,
            hasReachedMax: true, // Mark as reached max when using fallback cache
            event: 'GetServicePostsByCategoryEvent',
          ));
          return;
        }
      }

      emit(ServicePostLoadFailure(
          errorMessage: e.toString(),
          event: 'GetServicePostsByCategoryEvent'));
    } finally {
      // Always mark the request as completed
      _requestsInProgress[cacheKey] = false;
    }
  }
// Helper method for fetching and updating category posts
  Future<void> _fetchAndUpdateCategoryPosts(int category, int page,
      Emitter<ServicePostState> emit, bool emitState) async {
    final cacheKey = 'category_${category}_page${page}';

    // Skip if already being fetched
    if (_pendingRequests.contains(cacheKey)) {
      return;
    }

    _pendingRequests.add(cacheKey);

    try {
      final stopwatch = Stopwatch()..start();

      // Always get fresh data from API
      final servicePosts =
      await servicePostRepository.getServicePostsByCategory(
        page: page,
        categories: category,
      );

      stopwatch.stop();
      DebugLogger.log(
          'Fetched ${servicePosts.length} posts for category $category (page $page) in ${stopwatch.elapsedMilliseconds}ms',
          category: 'SERVICE_POST_BLOC');

      _pendingRequests.remove(cacheKey);

      // Cache first page results - replace existing cache
      if (page == 1) {
        _categoryPostsCache[category] = servicePosts;
      } else if (_categoryPostsCache.containsKey(category)) {
        // For pagination, append to existing cache
        final existingIds = _categoryPostsCache[category]!
            .map((post) => post.id)
            .whereType<int>()
            .toSet();

        // Only add posts that don't already exist in the cache
        final newPosts = servicePosts
            .where((post) => post.id != null && !existingIds.contains(post.id))
            .toList();

        _categoryPostsCache[category]!.addAll(newPosts);
      } else {
        // If no cache exists yet, create one
        _categoryPostsCache[category] = servicePosts;
      }

      // Update last loaded page
      _lastLoadedPages[cacheKey] = page;

      // Filter out deleted posts
      final filteredPosts = servicePosts
          .where((post) => !_deletedPostIds.contains(post.id))
          .toList();

      // Cache individual posts by ID
      for (final post in filteredPosts) {
        if (post.id != null) {
          _postByIdCache[post.id!] = post;
        }
      }

      // Only emit if requested
      if (emitState) {
        // For page 1, replace the entire state
        if (page == 1 || state is! ServicePostLoadSuccess) {
          emit(ServicePostLoadSuccess(
              servicePosts: filteredPosts,
              hasReachedMax: filteredPosts.length < 10,
              event: 'GetServicePostsByCategoryEvent'));
        } else {
          // For pagination, add to existing posts
          final currentState = state as ServicePostLoadSuccess;

          if (filteredPosts.isEmpty) {
            // If no new posts, we've reached the max
            emit(currentState.copyWith(hasReachedMax: true));
          } else {
            // Add new posts to existing list
            emit(ServicePostLoadSuccess(
              servicePosts: filteredPosts,
              hasReachedMax: filteredPosts.length < 10,
              event: 'GetServicePostsByCategoryEvent',
            ));
          }
        }
      }
    } catch (e) {
      _pendingRequests.remove(cacheKey);

      if (emitState) {
        // If we have cached data for page 1, use it despite the error
        if (page == 1 && _categoryPostsCache.containsKey(category)) {
          final cachedPosts = _categoryPostsCache[category]!;
          final filteredPosts = cachedPosts
              .where((post) => !_deletedPostIds.contains(post.id))
              .toList();

          emit(ServicePostLoadSuccess(
            servicePosts: filteredPosts,
            hasReachedMax: true,
            event: 'GetServicePostsByCategoryEvent',
          ));
        } else {
          emit(ServicePostLoadFailure(
              errorMessage: e.toString(),
              event: 'GetServicePostsByCategoryEvent'));
        }
      }
    }
  }

  Future<void> _handleGetServicePostsRealsEvent(
      GetServicePostsRealsEvent event, Emitter<ServicePostState> emit) async {
    // Always show loading for first page (unless preload)
    if (event.page == 1 && !event.preloadOnly) {
      emit( ServicePostLoading(event: 'GetServicePostsForReals'));
    }

    final cacheKey = 'reals_page${event.page}';
    final endpoint = 'reels';

    // Skip duplicate requests
    if (_pendingRequests.contains(cacheKey)) {
      DebugLogger.log(
          'Request already in progress for reels page ${event.page}',
          category: 'SERVICE_POST_BLOC');
      return;
    }

    // Check if rate limited
    final rateLimitManager = RateLimitManager();
    if (!rateLimitManager.canMakeRequest(endpoint) && !event.bypassRateLimit) {
      final waitTime = rateLimitManager.timeUntilNextAllowed(endpoint);

      // If this is a preload request, just skip it (no need to show errors)
      if (event.preloadOnly) {
        DebugLogger.log(
            'Skipping preload of reels page ${event.page} due to rate limiting (retry in ${waitTime.inSeconds}s)',
            category: 'SERVICE_POST_BLOC');
        return;
      }

      // For real requests, emit an appropriate state
      if (event.page > 1) {
        // If we're loading more data, just mark as reached max temporarily
        if (state is ServicePostLoadSuccess) {
          emit((state as ServicePostLoadSuccess).copyWith(hasReachedMax: true));
        }
      } else {
        // For first page, show proper error
        emit(ServicePostLoadFailure(
            errorMessage:
            'Rate limit reached. Please try again in ${waitTime.inSeconds} seconds.',
            event: 'GetServicePostsForReals'));
      }

      // Schedule retry if wait time is reasonable
      if (waitTime.inSeconds < 30) {
        Future.delayed(waitTime, () {
          // Only retry if this is still needed (user hasn't navigated away)
          if (!_pendingRequests.contains(cacheKey)) {
            add(GetServicePostsRealsEvent(
                page: event.page,
                preloadOnly: event.preloadOnly,
                bypassRateLimit: true // Bypass rate limit check for retry
            ));
          }
        });
      }

      return;
    }

    _pendingRequests.add(cacheKey);

    try {
      DebugLogger.log('Fetching reels from API: page=${event.page}',
          category: 'SERVICE_POST_BLOC');

      final servicePosts = await servicePostRepository.getServicePostsForReals(
        page: event.page,
        bypassRateLimit: event.bypassRateLimit,
      );

      _pendingRequests.remove(cacheKey);

      // Important: Set hasReachedMax when page is empty or has fewer items than expected
      final bool hasReachedMax =
          servicePosts.isEmpty || servicePosts.length < 10;

      if (hasReachedMax) {
        DebugLogger.log('Reached maximum reels at page ${event.page}',
            category: 'SERVICE_POST_BLOC');
      }

      // Filter out deleted posts
      final filteredPosts = servicePosts
          .where((post) => !_deletedPostIds.contains(post.id))
          .toList();

      // Add to reels cache
      final existingIds = _realsPostsCache.map((p) => p.id).toSet();
      _realsPostsCache.addAll(filteredPosts
          .where((post) => post.id != null && !existingIds.contains(post.id)));

      // Check if this is a preload request (should not update UI)
      if (event.preloadOnly) {
        // Just add to cache but don't update UI
        DebugLogger.log(
            'Preloaded ${filteredPosts.length} posts for page ${event.page}',
            category: 'SERVICE_POST_BLOC');
        return;
      }

      // Update state
      if (state is! ServicePostLoadSuccess || event.page == 1) {
        emit(ServicePostLoadSuccess(
            servicePosts: filteredPosts,
            hasReachedMax: hasReachedMax,
            preloadOnly: event.preloadOnly,
            event: 'GetServicePostsForReals'));
      } else {
        final currentState = state as ServicePostLoadSuccess;

        if (filteredPosts.isEmpty) {
          emit(currentState.copyWith(hasReachedMax: true));
        } else {
          // For subsequent pages, append unique posts
          final currentPostIds =
          currentState.servicePosts.map((p) => p.id).toSet();
          final uniqueNewPosts = filteredPosts
              .where((post) =>
          post.id != null && !currentPostIds.contains(post.id))
              .toList();

          if (uniqueNewPosts.isEmpty) {
            // If no new unique posts, we've reached max
            emit(currentState.copyWith(hasReachedMax: true));
          } else {
            emit(ServicePostLoadSuccess(
                servicePosts: [...currentState.servicePosts, ...uniqueNewPosts],
                hasReachedMax: hasReachedMax,
                preloadOnly: event.preloadOnly,
                event: 'GetServicePostsForReals'));
          }
        }
      }

      // If we loaded this page successfully and we're not at max, preload next page
      if (!hasReachedMax && !event.preloadOnly && event.page < 5) {
        // Wait a bit before preloading the next page
        Future.delayed(Duration(seconds: 1), () {
          add(GetServicePostsRealsEvent(
            page: event.page + 1,
            preloadOnly: true,
          ));
        });
      }
    } catch (e) {
      _pendingRequests.remove(cacheKey);

      DebugLogger.log('Error loading reels: $e', category: 'SERVICE_POST_BLOC');

      // Handle rate limiting errors
      if (e.toString().contains('429') ||
          e.toString().contains('Too Many Requests')) {
        // Apply backoff for this endpoint
        rateLimitManager.applyBackoff(endpoint, event.page > 1 ? 1 : 0);

        // Only emit error for non-preload requests
        if (!event.preloadOnly) {
          // For pagination errors (not first page), just mark as reached max but keep existing posts
          if (event.page > 1 && state is ServicePostLoadSuccess) {
            emit((state as ServicePostLoadSuccess)
                .copyWith(hasReachedMax: true));
          } else {
            // Get wait time for better error message
            final waitTime = rateLimitManager.timeUntilNextAllowed(endpoint);
            final waitSeconds = waitTime.inSeconds;

            emit(ServicePostLoadFailure(
                errorMessage: waitSeconds > 0
                    ? 'Rate limit exceeded. Please try again in $waitSeconds seconds.'
                    : 'Rate limit exceeded. Please try again in a moment.',
                event: 'GetServicePostsForReals'));
          }
        }

        // Schedule a retry after backoff if needed
        final waitTime = rateLimitManager.timeUntilNextAllowed(endpoint);
        if (waitTime.inSeconds < 30 && !event.preloadOnly) {
          Future.delayed(waitTime + Duration(seconds: 1), () {
            // Only retry if this is still needed (user hasn't navigated away)
            if (!_pendingRequests.contains(cacheKey)) {
              add(GetServicePostsRealsEvent(
                  page: event.page,
                  preloadOnly: event.preloadOnly,
                  bypassRateLimit: true // Bypass rate limit check for retry
              ));
            }
          });
        }
      } else {
        // Handle other errors
        if (!event.preloadOnly) {
          // For pagination errors (not first page), just mark as reached max but keep existing posts
          if (event.page > 1 && state is ServicePostLoadSuccess) {
            emit((state as ServicePostLoadSuccess)
                .copyWith(hasReachedMax: true));
          } else {
            emit(ServicePostLoadFailure(
                errorMessage:
                'Failed to load reels. Please check your connection and try again.',
                event: 'GetServicePostsForReals'));
          }
        }
      }
    }
  }

  List<ServicePost> _getUniquePostsForReels(
      List<ServicePost> existingPosts, List<ServicePost> newPosts) {
    // Create a set of existing IDs for O(1) lookup
    final existingIds = existingPosts.map((p) => p.id).toSet();

    // Get only posts that don't exist in current list
    final uniqueNewPosts = newPosts
        .where((post) => post.id != null && !existingIds.contains(post.id))
        .toList();

    // If we have unique posts, append them
    if (uniqueNewPosts.isNotEmpty) {
      return [...existingPosts, ...uniqueNewPosts];
    } else {
      return existingPosts;
    }
  }

// Add this to ServicePostBloc to properly handle duplication in reels
  void _handleServicePostReelsStateUpdate(List<ServicePost> newPosts,
      bool hasReachedMax, Emitter<ServicePostState> emit) {
    if (state is ServicePostLoadSuccess) {
      final currentState = state as ServicePostLoadSuccess;
      final currentPosts = currentState.servicePosts;

      // Check if we have any new posts that aren't already in the state
      final Set<int> existingIds =
      currentPosts.map((post) => post.id).whereType<int>().toSet();

      final List<ServicePost> uniqueNewPosts = newPosts
          .where((post) => post.id != null && !existingIds.contains(post.id))
          .toList();

      // If we didn't get any new unique posts, we've reached max
      if (uniqueNewPosts.isEmpty && newPosts.isNotEmpty) {
        emit(currentState.copyWith(hasReachedMax: true));
        DebugLogger.log('No new unique reels found, marking as reached max',
            category: 'SERVICE_POST_BLOC');
        return;
      }

      // Combine existing and new posts
      final combinedPosts = [...currentPosts, ...uniqueNewPosts];

      emit(ServicePostLoadSuccess(
          servicePosts: combinedPosts,
          hasReachedMax: hasReachedMax || uniqueNewPosts.isEmpty,
          event: 'GetServicePostsForReals'));
    } else {
      // First load
      emit(ServicePostLoadSuccess(
          servicePosts: newPosts,
          hasReachedMax: hasReachedMax,
          event: 'GetServicePostsForReals'));
    }
  }

// Define a cache structure that uses string keys
// Add this in the ServicePostBloc class declaration
  final Map<String, List<ServicePost>> _filteredPostsCache = {};

// Then update the helper method:
  Future<void> _fetchAndUpdateSubcategoryPosts(
      int category,
      int subCategory,
      int page,
      Emitter<ServicePostState> emit,
      bool emitState,
      String? typeFilter,
      double? minPrice,
      double? maxPrice) async {

    // Create a unique cache key that includes filter params
    final filterParam = typeFilter != null ? '_type_${typeFilter}' : '';
    final priceParam = (minPrice != null && maxPrice != null)
        ? '_price_${minPrice.toInt()}_${maxPrice.toInt()}'
        : '';
    final cacheKey = 'category_${category}_subcategory_${subCategory}_page${page}${filterParam}${priceParam}';

    _pendingRequests.add(cacheKey);

    try {
      final stopwatch = Stopwatch()..start();

      final servicePosts =
      await servicePostRepository.getServicePostsByCategorySubCategory(
        categories: category,
        subCategories: subCategory,
        page: page,
        type: typeFilter,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );

      stopwatch.stop();
      DebugLogger.log(
          'Fetched ${servicePosts.length} posts for subcategory $subCategory with filters in ${stopwatch.elapsedMilliseconds}ms',
          category: 'SERVICE_POST_BLOC');

      _pendingRequests.remove(cacheKey);

      // Cache first page results - use the string-based cache map
      if (page == 1) {
        _filteredPostsCache[cacheKey] = servicePosts;

        // For backward compatibility, also cache in the subcategory cache
        // if no filters are applied
        if (typeFilter == null && minPrice == null && maxPrice == null) {
          _subcategoryPostsCache[subCategory] = servicePosts;
        }
      }

      // Filter out deleted posts
      final filteredPosts = servicePosts
          .where((post) => !_deletedPostIds.contains(post.id))
          .toList();

      // Cache individual posts by ID
      for (final post in filteredPosts) {
        if (post.id != null) {
          _postByIdCache[post.id!] = post;
        }
      }

      // Only emit if requested
      if (emitState) {
        if (state is! ServicePostLoadSuccess || page == 1) {
          emit(ServicePostLoadSuccess(
              servicePosts: filteredPosts,
              hasReachedMax: filteredPosts.length < 10,
              event: 'GetServicePostsByCategorySubCategory'));
        } else {
          final currentState = state as ServicePostLoadSuccess;

          if (filteredPosts.isEmpty) {
            emit(currentState.copyWith(hasReachedMax: true));
          } else {
            emit(currentState.copyWith(
              servicePosts: currentState.servicePosts + filteredPosts,
              hasReachedMax: false,
            ));
          }
        }
      }
    } catch (e) {
      _pendingRequests.remove(cacheKey);

      if (emitState) {
        emit(ServicePostLoadFailure(
            errorMessage: e.toString(),
            event: 'GetServicePostsByCategorySubCategory'));
      }
    }
  }

// Also update the handler method to use the new cache
  Future<void> _handleGetServicePostsByCategorySubCategoryEvent(
      GetServicePostsByCategorySubCategoryEvent event,
      Emitter<ServicePostState> emit) async {
    final category = event.category;
    final subCategory = event.subCategory;
    final page = event.page;
    final forceRefresh = event.forceRefresh;
    final typeFilter = event.typeFilter;
    final minPrice = event.minPrice;
    final maxPrice = event.maxPrice;

    // Only show loading for non-background refreshes
    if (!forceRefresh) {
      emit( ServicePostLoading(
          event: 'GetServicePostsByCategorySubCategory'));
    }

    // Don't fetch if we've reached the max
    if (state is ServicePostLoadSuccess &&
        (state as ServicePostLoadSuccess).hasReachedMax &&
        (state as ServicePostLoadSuccess).event ==
            'GetServicePostsByCategorySubCategory') {
      return;
    }

    // Create a unique cache key that includes filter params
    final filterParam = typeFilter != null ? '_type_${typeFilter}' : '';
    final priceParam = (minPrice != null && maxPrice != null)
        ? '_price_${minPrice.toInt()}_${maxPrice.toInt()}'
        : '';
    final cacheKey = 'category_${category}_subcategory_${subCategory}_page${page}${filterParam}${priceParam}';

    // Use cache for first page if available and not forcing refresh
    if (page == 1 &&
        !forceRefresh &&
        _filteredPostsCache.containsKey(cacheKey)) {
      DebugLogger.log('Using cached posts for subcategory $subCategory with filters',
          category: 'SERVICE_POST_BLOC');

      // Filter out deleted posts
      final filteredPosts = _filteredPostsCache[cacheKey]!
          .where((post) => !_deletedPostIds.contains(post.id))
          .toList();

      emit(ServicePostLoadSuccess(
          servicePosts: filteredPosts,
          hasReachedMax: filteredPosts.length < 10,
          event: 'GetServicePostsByCategorySubCategory'));

      // If not forcing refresh, still update in background
      if (!_pendingRequests.contains(cacheKey)) {
        _fetchAndUpdateSubcategoryPosts(
            category, subCategory, page, emit, false, typeFilter, minPrice, maxPrice);
      }

      return;
    }

    // Check if a similar request is already in progress
    if (_pendingRequests.contains(cacheKey)) {
      DebugLogger.log(
          'Skipping duplicate GetServicePostsByCategorySubCategory request',
          category: 'SERVICE_POST_BLOC');
      return;
    }

    await _fetchAndUpdateSubcategoryPosts(
        category, subCategory, page, emit, true, typeFilter, minPrice, maxPrice);
  }

  // Handler for GetServicePostsByUserIdEvent
  Future<void> _handleGetServicePostsByUserIdEvent(
      GetServicePostsByUserIdEvent event,
      Emitter<ServicePostState> emit) async {
    final userId = event.userId;
    final page = event.page;
    final forceRefresh = event.forceRefresh;

    // Only show loading for non-background refreshes
    if (!forceRefresh) {
      emit( ServicePostLoading(event: 'GetServicePostsByUserIdEvent'));
    }

    // Don't fetch if we've reached the max
    if (state is ServicePostLoadSuccess &&
        (state as ServicePostLoadSuccess).hasReachedMax &&
        (state as ServicePostLoadSuccess).event ==
            'GetServicePostsByUserIdEvent') {
      return;
    }

    final cacheKey = 'user_${userId}_page${page}';

    // Use cache for first page if available
    if (page == 1 && !forceRefresh && _userPostsCache.containsKey(userId)) {
      DebugLogger.log('Using cached posts for user $userId',
          category: 'SERVICE_POST_BLOC');

      // Filter out deleted posts
      final filteredPosts = _userPostsCache[userId]!
          .where((post) => !_deletedPostIds.contains(post.id))
          .toList();

      emit(ServicePostLoadSuccess(
          servicePosts: filteredPosts,
          hasReachedMax: filteredPosts.length < 10,
          event: 'GetServicePostsByUserIdEvent'));

      // If not forcing refresh, still update in background
      if (!_pendingRequests.contains(cacheKey)) {
        _fetchAndUpdateUserPosts(userId, page, emit, false);
      }

      return;
    }

    // Check if a similar request is already in progress
    if (_pendingRequests.contains(cacheKey)) {
      DebugLogger.log('Skipping duplicate GetServicePostsByUserId request',
          category: 'SERVICE_POST_BLOC');
      return;
    }

    await _fetchAndUpdateUserPosts(userId, page, emit, true);
  }

  // Helper method for fetching and updating user posts
  Future<void> _fetchAndUpdateUserPosts(int userId, int page,
      Emitter<ServicePostState> emit, bool emitState) async {
    final cacheKey = 'user_${userId}_page${page}';
    _pendingRequests.add(cacheKey);

    try {
      final servicePosts = await servicePostRepository.getServicePostsByUserId(
        userId: userId,
        page: page,
      );

      _pendingRequests.remove(cacheKey);

      // Cache first page results
      if (page == 1) {
        _userPostsCache[userId] = servicePosts;
      }

      // Filter out deleted posts
      final filteredPosts = servicePosts
          .where((post) => !_deletedPostIds.contains(post.id))
          .toList();

      // Cache individual posts by ID
      for (final post in filteredPosts) {
        if (post.id != null) {
          _postByIdCache[post.id!] = post;
        }
      }

      // Only emit if requested
      if (emitState) {
        if (state is! ServicePostLoadSuccess || page == 1) {
          emit(ServicePostLoadSuccess(
              servicePosts: filteredPosts,
              hasReachedMax: filteredPosts.length < 10,
              event: 'GetServicePostsByUserIdEvent'));
        } else {
          final currentState = state as ServicePostLoadSuccess;

          if (filteredPosts.isEmpty) {
            emit(currentState.copyWith(hasReachedMax: true));
          } else {
            emit(currentState.copyWith(
              servicePosts: currentState.servicePosts + filteredPosts,
              hasReachedMax: false,
            ));
          }
        }
      }
    } catch (e) {
      _pendingRequests.remove(cacheKey);

      if (emitState) {
        emit(ServicePostLoadFailure(
            errorMessage: e.toString(), event: 'GetServicePostsByUserIdEvent'));
      }
    }
  }

  // Handler for CreateServicePostEvent
  Future<void> _handleCreateServicePostEvent(
      CreateServicePostEvent event, Emitter<ServicePostState> emit) async {
    emit( ServicePostLoading(event: 'CreateServicePostEvent'));

    try {
      final servicePost = await servicePostRepository.createServicePost(
        event.servicePost,
        event.imageFiles,
      );

      // Update cache
      if (servicePost.id != null) {
        _postByIdCache[servicePost.id!] = servicePost;
      }

      // Clear cache for related categories to force refresh
      if (event.servicePost.category != null) {
        final categoryId = event.servicePost.category!.id;
        _categoryPostsCache.remove(categoryId);

        // Clear subcategory cache if applicable
        if (event.servicePost.subCategory != null) {
          final subcategoryId = event.servicePost.subCategory!.id;
          _subcategoryPostsCache.remove(subcategoryId);
        }
      }

      emit(ServicePostOperationSuccess(
          servicePost: true, event: 'CreateServicePostEvent'));
    } catch (e) {
      emit(ServicePostOperationFailure(
          errorMessage: e.toString(), event: 'CreateServicePostEvent'));
    }
  }

  // Handler for UpdateServicePostEvent
  Future<void> _handleUpdateServicePostEvent(
      UpdateServicePostEvent event,
      Emitter<ServicePostState> emit,
      ) async {
    emit( ServicePostLoading(event: 'UpdateServicePostEvent'));

    try {
      final bool success = await servicePostRepository.updateServicePost(
        event.servicePost,
        event.imageFiles, // Pass the image files here
      );

      // Only update caches if the operation was successful
      if (success && event.servicePost.id != null) {
        // Fetch the updated post to keep cache consistent
        try {
          final updatedPost = await servicePostRepository
              .getServicePostById(event.servicePost.id!);

          // Update cache with fetched post
          _postByIdCache[event.servicePost.id!] = updatedPost;

          // Update category cache if needed
          if (event.servicePost.category != null) {
            final categoryId = event.servicePost.category!.id;
            if (_categoryPostsCache.containsKey(categoryId)) {
              final index = _categoryPostsCache[categoryId]!
                  .indexWhere((post) => post.id == event.servicePost.id);

              if (index != -1) {
                _categoryPostsCache[categoryId]![index] = updatedPost;
              }
            }
          }

          // Update subcategory cache if needed
          if (event.servicePost.subCategory != null) {
            final subcategoryId = event.servicePost.subCategory!.id;
            if (_subcategoryPostsCache.containsKey(subcategoryId)) {
              final index = _subcategoryPostsCache[subcategoryId]!
                  .indexWhere((post) => post.id == event.servicePost.id);

              if (index != -1) {
                _subcategoryPostsCache[subcategoryId]![index] = updatedPost;
              }
            }
          }
        } catch (e) {
          // Log error but continue with success response
          DebugLogger.log('Error fetching updated post for cache: $e',
              category: 'SERVICE_POST_BLOC');
        }
      }

      // Use the boolean result directly
      emit(ServicePostOperationSuccess(
          servicePost: success, event: 'UpdateServicePostEvent'));
    } catch (e) {
      emit(ServicePostOperationFailure(
          errorMessage: e.toString(), event: 'UpdateServicePostEvent'));
    }
  }

  bool hasPostInCache(int postId) {
    // Check in the current loaded posts
    final currentState = state;
    if (currentState is ServicePostLoadSuccess) {
      return currentState.servicePosts.any((post) => post.id == postId);
    }
    return false;
  }

  void markPostAsValid(int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPostIds = prefs.getStringList('cached_valid_posts') ?? [];
      final postIdStr = postId.toString();

      if (!cachedPostIds.contains(postIdStr)) {
        cachedPostIds.add(postIdStr);
        await prefs.setStringList('cached_valid_posts', cachedPostIds);
        DebugLogger.log('Marked post $postId as valid for future deeplinks',
            category: 'SERVICE_POST');
      }
    } catch (e) {
      // Ignore errors in this helper method
    }
  }

  // Handler for UpdatePhotoServicePostEvent
  Future<void> _handleUpdatePhotoServicePostEvent(
      UpdatePhotoServicePostEvent event, Emitter<ServicePostState> emit) async {
    emit( ServicePostLoading(event: 'UpdateServicePostEvent'));

    try {
      final result = await servicePostRepository.updateServicePostImage(
        event.imageFiles,
        servicePostImageId: event.servicePost,
      );

      // Clear post from cache to force a refresh
      if (result) {
        try {
          // Fetch the updated post to replace in cache
          final post =
          await servicePostRepository.getServicePostById(event.servicePost);
          if (post.id != null) {
            _postByIdCache[post.id!] = post;
          }
        } catch (e) {
          // Just log the error but don't fail the operation
          DebugLogger.log('Error refreshing post cache after photo update: $e',
              category: 'SERVICE_POST_BLOC');
        }
      }

      emit(ServicePostImageUpdatingSuccess(imageUpdated: result));
    } catch (e) {
      emit(ServicePostOperationFailure(
          errorMessage: e.toString(), event: 'UpdateServicePostEvent'));
    }
  }

  // Handler for ServicePostCategoryUpdateEvent
  Future<void> _handleServicePostCategoryUpdateEvent(
      ServicePostCategoryUpdateEvent event,
      Emitter<ServicePostState> emit) async {
    emit( ServicePostLoading(event: 'ServicePostCategoryUpdateEvent'));

    try {
      await servicePostRepository.updateServicePostCategory(
        event.servicePost,
        event.servicePostID,
      );

      // Clear related caches
      _postByIdCache.remove(event.servicePostID);

      // Clear category caches that might contain this post
      for (final categoryId in _categoryPostsCache.keys) {
        final index = _categoryPostsCache[categoryId]!
            .indexWhere((post) => post.id == event.servicePostID);

        if (index != -1) {
          _categoryPostsCache[categoryId]!.removeAt(index);
        }
      }

      // Clear subcategory caches that might contain this post
      for (final subcategoryId in _subcategoryPostsCache.keys) {
        final index = _subcategoryPostsCache[subcategoryId]!
            .indexWhere((post) => post.id == event.servicePostID);

        if (index != -1) {
          _subcategoryPostsCache[subcategoryId]!.removeAt(index);
        }
      }

      emit(ServicePostOperationSuccess(
          servicePost: true, event: 'ServicePostCategoryUpdateEvent'));
    } catch (e) {
      emit(ServicePostOperationFailure(
          errorMessage: e.toString(), event: 'ServicePostCategoryUpdateEvent'));
    }
  }

  // Handler for ServicePostBadgeUpdateEvent
  Future<void> _handleServicePostBadgeUpdateEvent(
      ServicePostBadgeUpdateEvent event, Emitter<ServicePostState> emit) async {
    emit( ServicePostLoading(event: 'ServicePostBadgeUpdateEvent'));

    try {
      await servicePostRepository.updateServicePostBadge(
        event.servicePost,
        event.servicePostID,
      );

      // Update cache
      if (_postByIdCache.containsKey(event.servicePostID)) {
        try {
          final post = await servicePostRepository
              .getServicePostById(event.servicePostID);
          if (post.id != null) {
            _postByIdCache[post.id!] = post;
          }
        } catch (e) {
          // Just log the error but don't fail the operation
          DebugLogger.log('Error refreshing post cache after badge update: $e',
              category: 'SERVICE_POST_BLOC');
        }
      }

      emit(ServicePostOperationSuccess(
          servicePost: true, event: 'ServicePostBadgeUpdateEvent'));
    } catch (e) {
      emit(ServicePostOperationFailure(
          errorMessage: e.toString(), event: 'ServicePostBadgeUpdateEvent'));
    }
  }

  Future<void> _handleDeleteServicePostEvent(
      DeleteServicePostEvent event, Emitter<ServicePostState> emit) async {
    emit( ServicePostLoading(event: 'DeleteServicePostEvent'));

    try {
      await servicePostRepository.deleteServicePost(
          servicePostId: event.servicePostId);

      // Add to deleted posts set for UI consistency
      _deletedPostIds.add(event.servicePostId);

      emit(ServicePostDeletingSuccess(servicePostId: event.servicePostId));
    } catch (e) {
      emit(ServicePostOperationFailure(
          errorMessage: e.toString(), event: 'DeleteServicePostEvent'));
    }
  }

  // Handler for ViewIncrementServicePostEvent
  Future<void> _handleViewIncrementServicePostEvent(
      ViewIncrementServicePostEvent event,
      Emitter<ServicePostState> emit) async {

    try {
      await servicePostRepository.viewIncrementServicePost(
          servicePostId: event.servicePostId);

      // Update cache if post exists
      if (_postByIdCache.containsKey(event.servicePostId)) {
        final post = _postByIdCache[event.servicePostId]!;

        // Create a new updated post with incremented views
        final updatedPost = ServicePost(
          id: post.id,
          userId: post.userId,
          userName: post.userName,
          userPhoto: post.userPhoto,
          email: post.email,
          phones: post.phones,
          watsNumber: post.watsNumber,
          title: post.title,
          description: post.description,
          category: post.category,
          subCategory: post.subCategory,
          country: post.country,
          price: post.price,
          locationLatitudes: post.locationLatitudes,
          locationLongitudes: post.locationLongitudes,
          distance: post.distance,
          type: post.type,
          haveBadge: post.haveBadge,
          badgeDuration: post.badgeDuration,
          favoritesCount: post.favoritesCount,
          commentsCount: post.commentsCount,
          reportCount: post.reportCount,
          viewCount: (post.viewCount ?? 0) + 1,
          isFavorited: post.isFavorited,
          isFollowed: post.isFollowed,
          state: post.state,
          categoriesId: post.categoriesId,
          subCategoriesId: post.subCategoriesId,
          createdAt: post.createdAt,
          updatedAt: post.updatedAt,
          photos: post.photos,
        );

        // Update the cache with the new post
        _postByIdCache[event.servicePostId] = updatedPost;
      }

      emit(ServicePostViewIncrementSuccess(servicePostId: event.servicePostId));
    } catch (e) {
      emit(ServicePostOperationFailure(
          errorMessage: e.toString(), event: 'ViewIncrementServicePostEvent'));
    }
  }

  // Handler for ToggleFavoriteServicePostEvent
  Future<void> _handleToggleFavoriteServicePostEvent(
      ToggleFavoriteServicePostEvent event,
      Emitter<ServicePostState> emit) async {
    emit( ServicePostLoading(event: 'ToggleFavoriteServicePostEvent'));

    try {
      bool newFavoriteStatus = await servicePostRepository
          .toggleFavoriteServicePost(servicePostId: event.servicePostId);

      // Update post in cache if it exists
      if (_postByIdCache.containsKey(event.servicePostId)) {
        final post = _postByIdCache[event.servicePostId]!;

        // Create updated post with new favorite state
        final updatedPost = ServicePost(
          id: post.id,
          userId: post.userId,
          userName: post.userName,
          userPhoto: post.userPhoto,
          email: post.email,
          phones: post.phones,
          watsNumber: post.watsNumber,
          title: post.title,
          description: post.description,
          category: post.category,
          subCategory: post.subCategory,
          country: post.country,
          price: post.price,
          locationLatitudes: post.locationLatitudes,
          locationLongitudes: post.locationLongitudes,
          distance: post.distance,
          type: post.type,
          haveBadge: post.haveBadge,
          badgeDuration: post.badgeDuration,
          favoritesCount: newFavoriteStatus
              ? (post.favoritesCount ?? 0) + 1
              : (post.favoritesCount ?? 1) - 1,
          commentsCount: post.commentsCount,
          reportCount: post.reportCount,
          viewCount: post.viewCount,
          isFavorited: newFavoriteStatus,
          isFollowed: post.isFollowed,
          state: post.state,
          categoriesId: post.categoriesId,
          subCategoriesId: post.subCategoriesId,
          createdAt: post.createdAt,
          updatedAt: post.updatedAt,
          photos: post.photos,
        );

        // Update memory cache
        _postByIdCache[event.servicePostId] = updatedPost;

        for (final categoryId in _categoryPostsCache.keys) {
          final index = _categoryPostsCache[categoryId]!
              .indexWhere((post) => post.id == event.servicePostId);

          if (index != -1) {
            _categoryPostsCache[categoryId]![index] = updatedPost;
          }
        }

        // Update in subcategory caches
        for (final subcategoryId in _subcategoryPostsCache.keys) {
          final index = _subcategoryPostsCache[subcategoryId]!
              .indexWhere((post) => post.id == event.servicePostId);

          if (index != -1) {
            _subcategoryPostsCache[subcategoryId]![index] = updatedPost;
          }
        }
      }

      emit(ServicePostFavoriteToggled(
          servicePostId: event.servicePostId, isFavorite: newFavoriteStatus));
    } catch (e) {
      emit(ServicePostOperationFailure(
          errorMessage: e.toString(), event: 'ToggleFavoriteServicePostEvent'));
    }
  }

  // Handler for InitializeFavoriteServicePostEvent
  Future<void> _handleInitializeFavoriteServicePostEvent(
      InitializeFavoriteServicePostEvent event,
      Emitter<ServicePostState> emit) async {
    try {
      bool isFavorite = await servicePostRepository.getFavourite(
          servicePostId: event.servicePostId);

      // Update post in cache if it exists
      if (_postByIdCache.containsKey(event.servicePostId)) {
        final post = _postByIdCache[event.servicePostId]!;

        // Only update if favorite status changed
        if (post.isFavorited != isFavorite) {
          // Create updated post with new favorite state
          // Handler for InitializeFavoriteServicePostEvent (continued)
          // Create updated post with new favorite state
          final updatedPost = ServicePost(
            id: post.id,
            userId: post.userId,
            userName: post.userName,
            userPhoto: post.userPhoto,
            email: post.email,
            phones: post.phones,
            watsNumber: post.watsNumber,
            title: post.title,
            description: post.description,
            category: post.category,
            subCategory: post.subCategory,
            country: post.country,
            price: post.price,
            locationLatitudes: post.locationLatitudes,
            locationLongitudes: post.locationLongitudes,
            distance: post.distance,
            type: post.type,
            haveBadge: post.haveBadge,
            badgeDuration: post.badgeDuration,
            favoritesCount: post.favoritesCount,
            commentsCount: post.commentsCount,
            reportCount: post.reportCount,
            viewCount: post.viewCount,
            isFavorited: isFavorite,
            isFollowed: post.isFollowed,
            state: post.state,
            categoriesId: post.categoriesId,
            subCategoriesId: post.subCategoriesId,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt,
            photos: post.photos,
          );

          // Update memory cache
          _postByIdCache[event.servicePostId] = updatedPost;
        }
      }

      emit(ServicePostFavoriteInitialized(
          servicePostId: event.servicePostId, isFavorite: isFavorite));
    } catch (e) {
      // Just log error, don't emit failure state
      DebugLogger.log('Error initializing favorite status: $e',
          category: 'SERVICE_POST_BLOC');
    }
  }

  // Handler for DeleteServicePostImageEvent
  Future<void> _handleDeleteServicePostImageEvent(
      DeleteServicePostImageEvent event, Emitter<ServicePostState> emit) async {
    emit( ServicePostLoading(event: 'DeleteServicePostImageEvent'));

    try {
      await servicePostRepository.deleteServicePostImage(
          servicePostImageId: event.servicePostImageId);

      // Update post cache if needed after image deletion by removing it from cache
      // This will force a refresh when the post is requested next time
      for (final postId in _postByIdCache.keys.toList()) {
        final post = _postByIdCache[postId]!;
        if (post.photos != null &&
            post.photos!.any((photo) => photo.id == event.servicePostImageId)) {
          _postByIdCache.remove(postId);
        }
      }

      emit(ServicePostImageDeletingSuccess(
          servicePostImageId: event.servicePostImageId));
    } catch (e) {
      emit(ServicePostOperationFailure(
          errorMessage: e.toString(), event: 'DeleteServicePostImageEvent'));
    }
  }

  // Handler for ClearServicePostCacheEvent
  Future<void> _handleClearServicePostCacheEvent(
      ClearServicePostCacheEvent event, Emitter<ServicePostState> emit) async {
    try {
      if (event.categoryId != null) {
        // Clear specific category cache from memory
        _categoryPostsCache.remove(event.categoryId);

        DebugLogger.log(
            'Cleared service post cache for category ${event.categoryId}',
            category: 'SERVICE_POST_BLOC');
      } else if (event.subcategoryId != null) {
        // Clear specific subcategory cache from memory
        _subcategoryPostsCache.remove(event.subcategoryId);
        DebugLogger.log(
            'Cleared service post cache for subcategory ${event.subcategoryId}',
            category: 'SERVICE_POST_BLOC');
      } else if (event.userId != null) {
        // Clear specific user cache from memory
        _userPostsCache.remove(event.userId);
        _userFavoritePostsCache.remove(event.userId);
        DebugLogger.log('Cleared service post cache for user ${event.userId}',
            category: 'SERVICE_POST_BLOC');
      } else if (event.postId != null) {
        // Clear specific post cache from memory
        _postByIdCache.remove(event.postId);

        DebugLogger.log('Cleared cache for post ${event.postId}',
            category: 'SERVICE_POST_BLOC');
      } else {
        // Clear all caches from memory
        _categoryPostsCache.clear();
        _subcategoryPostsCache.clear();
        _userPostsCache.clear();
        _userFavoritePostsCache.clear();
        _postByIdCache.clear();
        _realsPostsCache.clear();
        _lastLoadedPages.clear();
        _pendingRequests.clear();
        _recentlyAccessedCategories.clear();

        DebugLogger.log('Cleared all service post caches',
            category: 'SERVICE_POST_BLOC');
      }

      // Emit the event for cache cleared
      emit(const ServicePostCacheCleared());
    } catch (e) {
      DebugLogger.log('Error clearing service post cache: $e',
          category: 'SERVICE_POST_BLOC');
    }
  }

  // Public method to prefetch a category to improve user experience
  Future<void> prefetchCategory(int categoryId) async {
    // Skip if already in cache or being fetched
    final cacheKey = 'category_${categoryId}_page1';
    if (_categoryPostsCache.containsKey(categoryId) ||
        _pendingRequests.contains(cacheKey)) {
      return;
    }

    final hasNetwork = await connectivity.checkConnection();
    if (!hasNetwork) {
      DebugLogger.log(
          'Skipping prefetch for category $categoryId due to no network',
          category: 'SERVICE_POST_BLOC');
      return;
    }

    DebugLogger.log('Prefetching posts for category $categoryId',
        category: 'SERVICE_POST_BLOC');

    _pendingRequests.add(cacheKey);

    try {
      final stopwatch = Stopwatch()..start();
      final servicePosts =
      await servicePostRepository.getServicePostsByCategory(
        page: 1,
        categories: categoryId,
      );
      stopwatch.stop();

      // Cache the results in memory
      _categoryPostsCache[categoryId] = servicePosts;
      _lastLoadedPages[cacheKey] = 1;

      // Update LRU tracking
      _updateRecentlyAccessedCategories(categoryId);

      // Cache individual posts by ID
      for (final post in servicePosts) {
        if (post.id != null) {
          _postByIdCache[post.id!] = post;
        }
      }

      DebugLogger.log(
          'Prefetched ${servicePosts.length} posts for category $categoryId in ${stopwatch.elapsedMilliseconds}ms',
          category: 'SERVICE_POST_BLOC');
    } catch (e) {
      DebugLogger.log('Error prefetching category $categoryId: $e',
          category: 'SERVICE_POST_BLOC');
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }

  Future<void> prefetchPopularSubcategories(List<int> subcategoryIds) async {
    final hasNetwork = await connectivity.checkConnection();
    if (!hasNetwork) {
      DebugLogger.log('Skipping prefetch for subcategories due to no network',
          category: 'SERVICE_POST_BLOC');
      return;
    }

    for (final subcategoryId in subcategoryIds) {
      // Skip if already in cache
      if (_subcategoryPostsCache.containsKey(subcategoryId)) {
        continue;
      }

      // Skip if already being fetched
      final cacheKey = 'subcategory_${subcategoryId}_prefetch';
      if (_pendingRequests.contains(cacheKey)) {
        continue;
      }

      _pendingRequests.add(cacheKey);

      try {
        // We need category ID for the API call, so let's fetch a single post to determine it
        // This is a bit inefficient but works if we don't have the category mapping
        final posts =
        await servicePostRepository.getServicePostsByCategorySubCategory(
          categories:
          1, // Use a default, will be ignored by API if subcategory is found
          subCategories: subcategoryId,
          page: 1,
        );

        if (posts.isNotEmpty) {
          // Cache the posts
          _subcategoryPostsCache[subcategoryId] = posts;

          // Cache individual posts
          for (final post in posts) {
            if (post.id != null) {
              _postByIdCache[post.id!] = post;
            }
          }

          DebugLogger.log(
              'Prefetched ${posts.length} posts for subcategory $subcategoryId',
              category: 'SERVICE_POST_BLOC');
        }
      } catch (e) {
        DebugLogger.log('Error prefetching subcategory $subcategoryId: $e',
            category: 'SERVICE_POST_BLOC');
      } finally {
        _pendingRequests.remove(cacheKey);
      }
    }
  }

  // Fixed version of the _handleDataSaverToggleEvent method:

  Future<void> _handleDataSaverToggleEvent(
      DataSaverToggleEvent event, Emitter<ServicePostState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('data_saver_enabled', event.enabled);
      _dataSaverEnabled = event.enabled;

      DebugLogger.log('Data saver mode toggled: $_dataSaverEnabled',
          category: 'SERVICE_POST_BLOC');

      // Update server preference in background - FIXED ERROR HANDLING
      try {
        await servicePostRepository.updateDataSaverPreference(event.enabled);
      } catch (e) {
        DebugLogger.log('Failed to sync data saver preference with server: $e',
            category: 'SERVICE_POST_BLOC');
        // Error is caught here and not propagated
      }

      // Update current state if it's a success state
      if (state is ServicePostLoadSuccess) {
        final currentState = state as ServicePostLoadSuccess;
        emit(ServicePostLoadSuccess(
          servicePosts: currentState.servicePosts,
          hasReachedMax: currentState.hasReachedMax,
          event: '${currentState.event}_DataSaverToggled',
          dataSaverEnabled: _dataSaverEnabled,
        ));
      }
    } catch (e) {
      DebugLogger.log('Error updating data saver mode: $e',
          category: 'SERVICE_POST_BLOC');
    }
  }

  Future<void> _handleDataSaverStatusChangedEvent(
      DataSaverStatusChangedEvent event, Emitter<ServicePostState> emit) async {
    // Just update internal state
    _dataSaverEnabled = event.enabled;

    DebugLogger.log('Data saver status updated: $_dataSaverEnabled',
        category: 'SERVICE_POST_BLOC');

    // Update current state if it's a success state
    if (state is ServicePostLoadSuccess) {
      final currentState = state as ServicePostLoadSuccess;
      emit(ServicePostLoadSuccess(
        servicePosts: currentState.servicePosts,
        hasReachedMax: currentState.hasReachedMax,
        event: currentState.event,
        dataSaverEnabled: _dataSaverEnabled,
      ));
    }
  }

// Helper method to determine if photos should be loaded
  bool _shouldLoadPhotos() {
    return !_dataSaverEnabled;
  }

  @override
  Future<void> close() {
    DebugLogger.log('ServicePostBloc closed', category: 'SERVICE_POST_BLOC');
    return super.close();
  }
}