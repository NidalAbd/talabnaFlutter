// lib/blocs/category/subcategory_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/data/datasources/local/local_category_data_source.dart';
import 'package:talabna/data/models/categories_selected_menu.dart';
import 'package:talabna/data/models/category_menu.dart';
import 'package:talabna/data/repositories/categories_repository.dart';
import 'package:talabna/utils/debug_logger.dart';

import 'subcategory_event.dart';
import 'subcategory_state.dart';

class SubcategoryBloc extends Bloc<SubcategoryEvent, SubcategoryState> {
  final CategoriesRepository categoriesRepository;
  final LocalCategoryDataSource localDataSource;

  // Cache for subcategories by category ID
  final Map<int, List<SubCategoryMenu>> _subcategoryCache = {};

  // Cache for categories
  List<CategoryMenu>? _categoriesCache;

  // Track pending request categories to avoid duplicate requests
  final Set<int> _pendingCategories = {};

  // Flag to indicate if categories fetch is in progress
  bool _isFetchingCategories = false;
  static final Map<int, List<SubCategoryMenu>> _globalSubcategoryCache = {};
  static final Map<int, DateTime> _lastRefreshTimes = {};
  static const Duration _refreshThrottleTime = Duration(seconds: 10);


  SubcategoryBloc({
    required this.categoriesRepository,
    required this.localDataSource,
  }) : super(SubcategoryInitial()) {
    DebugLogger.log('SubcategoryBloc created: $hashCode', category: 'BLOC');

    on<FetchSubcategories>((event, emit) async {
      // First, check if we need to force refresh (skip memory cache)
      if (event.forceRefresh) {
        _lastRefreshTimes[event.categoryId] = DateTime.now();

        DebugLogger.log(
            'Force refreshing subcategories for category ${event.categoryId}',
            category: 'SUBCATEGORY_BLOC');

        // Show loading state if requested
        if (event.showLoadingState) {
          emit(SubcategoryLoading());
        }

        try {
          // Fetch from API directly
          final stopwatch = Stopwatch()..start();
          final apiItems = await categoriesRepository.getSubCategoriesMenu(
            event.categoryId,
            forceRefresh: true,
          );
          stopwatch.stop();

          // Update both memory caches - local and global
          _subcategoryCache[event.categoryId] = apiItems;
          _globalSubcategoryCache[event.categoryId] = apiItems;

          // Store in local storage
          await localDataSource.cacheSubCategoriesMenu(event.categoryId, apiItems);

          // Emit loaded state
          emit(SubcategoryLoaded(apiItems));

          DebugLogger.log(
              'Fetched ${apiItems.length} subcategories from API in ${stopwatch.elapsedMilliseconds}ms',
              category: 'SUBCATEGORY_BLOC'
          );
        } catch (e) {
          // Handle error
          DebugLogger.log('Error fetching subcategories: $e',
              category: 'SUBCATEGORY_BLOC');

          // If we have cached data, use it despite the error
          if (_globalSubcategoryCache.containsKey(event.categoryId)) {
            emit(SubcategoryLoaded(_globalSubcategoryCache[event.categoryId]!));
          } else if (_subcategoryCache.containsKey(event.categoryId)) {
            emit(SubcategoryLoaded(_subcategoryCache[event.categoryId]!));
          } else {
            emit(SubcategoryError(e.toString()));
          }
        }

        return;
      }

      // If not forcing refresh, first check global cache (which persists between navigations)
      if (_globalSubcategoryCache.containsKey(event.categoryId)) {
        DebugLogger.log(
            'Using global-cached subcategories for category ${event.categoryId}',
            category: 'SUBCATEGORY_BLOC');

        // Emit brief loading state if requested (for UI consistency)
        if (event.showLoadingState) {
          emit(SubcategoryLoading());
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // Sync local cache with global
        _subcategoryCache[event.categoryId] = _globalSubcategoryCache[event.categoryId]!;

        emit(SubcategoryLoaded(_globalSubcategoryCache[event.categoryId]!));

        // If not forcing refresh, still update in background
        if (!_pendingCategories.contains(event.categoryId)) {
          _fetchAndUpdateSubcategories(event.categoryId, emit, false);
        }

        return;
      }

      // Then check local memory cache
      if (_subcategoryCache.containsKey(event.categoryId)) {
        DebugLogger.log(
            'Using memory-cached subcategories for category ${event.categoryId}',
            category: 'SUBCATEGORY_BLOC');

        // Emit brief loading state if requested (for UI consistency)
        if (event.showLoadingState) {
          emit(SubcategoryLoading());
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // Sync global cache with local
        _globalSubcategoryCache[event.categoryId] = _subcategoryCache[event.categoryId]!;

        emit(SubcategoryLoaded(_subcategoryCache[event.categoryId]!));

        // If not forcing refresh, still update in background
        if (!_pendingCategories.contains(event.categoryId)) {
          _fetchAndUpdateSubcategories(event.categoryId, emit, false);
        }

        return;
      }

      // Not in memory cache or forcing refresh, check permanent storage
      try {
        // Check if we have valid cache in local storage
        if (localDataSource
            .isCacheValid('cached_subcategory_menu_${event.categoryId}')) {
          final cachedSubcategories =
          await localDataSource.getSubCategoriesMenu(event.categoryId);

          if (cachedSubcategories.isNotEmpty) {
            DebugLogger.log(
                'Using storage-cached subcategories for category ${event.categoryId}',
                category: 'SUBCATEGORY_BLOC');

            // Update both memory caches
            _subcategoryCache[event.categoryId] = cachedSubcategories;
            _globalSubcategoryCache[event.categoryId] = cachedSubcategories;

            // Emit brief loading state if requested (for UI consistency)
            if (event.showLoadingState) {
              emit(SubcategoryLoading());
              await Future.delayed(const Duration(milliseconds: 50));
            }

            emit(SubcategoryLoaded(cachedSubcategories));

            // If we're not already fetching, get fresh data in background
            if (!_pendingCategories.contains(event.categoryId)) {
              _fetchAndUpdateSubcategories(event.categoryId, emit, false);
            }

            return;
          }
        } else {
          DebugLogger.log(
              'No valid cache for subcategories category ${event.categoryId}',
              category: 'SUBCATEGORY_BLOC');
        }
      } catch (e) {
        // Error reading from local storage, we'll continue to fetch from API
        DebugLogger.log('Error reading subcategories from local storage: $e',
            category: 'SUBCATEGORY_BLOC');
      }

      // Check if we're already fetching this category
      if (_pendingCategories.contains(event.categoryId)) {
        DebugLogger.log(
            'Already fetching subcategories for category ${event.categoryId}',
            category: 'SUBCATEGORY_BLOC');
        return;
      }

      // Not in any cache, need to fetch
      if (event.showLoadingState) {
        emit(SubcategoryLoading());
      }

      // Fetch and update subcategories
      await _fetchAndUpdateSubcategories(event.categoryId, emit, true);
    });


    on<InitializeSubcategoryCache>((event, emit) async {
      try {
        DebugLogger.log('Initializing subcategory cache from local storage',
            category: 'SUBCATEGORY_BLOC');

        // Try to load categories from local storage
        if (localDataSource.isCacheValid('cached_category_menu')) {
          final cachedCategories = await localDataSource.getCategoryMenu();

          if (cachedCategories.isNotEmpty) {
            // Update memory cache
            _categoriesCache = cachedCategories;

            // Emit loaded state without loading indicator
            emit(CategoryLoaded(cachedCategories));

            DebugLogger.log(
                'Initialized categories from cache: ${cachedCategories.length} items',
                category: 'SUBCATEGORY_BLOC');
          }
        }
      } catch (e) {
        DebugLogger.log('Error initializing subcategory cache: $e',
            category: 'SUBCATEGORY_BLOC');
        // Don't emit error state, as this is just pre-loading
      }
    });

    on<FetchCategories>((event, emit) async {
      // First, check if we need to force refresh (skip memory cache)
      if (!event.forceRefresh) {
        // Check if we already have categories in memory cache
        if (_categoriesCache != null) {
          DebugLogger.log('Using memory-cached categories',
              category: 'SUBCATEGORY_BLOC');

          // Emit brief loading state if requested (for UI consistency)
          if (event.showLoadingState) {
            emit(SubcategoryLoading());
            await Future.delayed(const Duration(milliseconds: 50));
          }

          emit(CategoryLoaded(_categoriesCache!));
          return;
        }
      }

      // Not in memory cache or forcing refresh, check permanent storage
      if (!event.forceRefresh) {
        try {
          // Check if we have valid cache in local storage
          if (localDataSource.isCacheValid('cached_category_menu')) {
            final cachedCategories = await localDataSource.getCategoryMenu();

            if (cachedCategories.isNotEmpty) {
              DebugLogger.log('Using storage-cached categories',
                  category: 'SUBCATEGORY_BLOC');

              // Update memory cache
              _categoriesCache = cachedCategories;

              // Emit brief loading state if requested (for UI consistency)
              if (event.showLoadingState) {
                emit(SubcategoryLoading());
                await Future.delayed(const Duration(milliseconds: 50));
              }

              emit(CategoryLoaded(cachedCategories));

              // If we're not already fetching, get fresh data in background
              if (!_isFetchingCategories && !event.forceRefresh) {
                _fetchAndUpdateCategories(emit, false);
              }

              return;
            }
          }
        } catch (e) {
          // Error reading from local storage, we'll continue to fetch from API
          DebugLogger.log('Error reading categories from local storage: $e',
              category: 'SUBCATEGORY_BLOC');
        }
      }

      // Avoid duplicate requests
      if (_isFetchingCategories) {
        DebugLogger.log('Already fetching categories',
            category: 'SUBCATEGORY_BLOC');
        return;
      }

      if (event.showLoadingState) {
        emit(SubcategoryLoading());
      }

      await _fetchAndUpdateCategories(emit, event.showLoadingState);
    });

    on<ClearSubcategoryCache>((event, emit) async {
      if (event.categoryId != null) {
        // Clear specific category from memory cache
        _subcategoryCache.remove(event.categoryId);

        // Also clear from local storage
        try {
          final prefs = await localDataSource.sharedPreferences;
          prefs.remove('cached_subcategory_menu_${event.categoryId}');
          prefs.remove('cached_subcategory_menu_${event.categoryId}_timestamp');
        } catch (e) {
          DebugLogger.log('Error clearing subcategory cache from storage: $e',
              category: 'SUBCATEGORY_BLOC');
        }

        DebugLogger.log(
            'Cleared subcategory cache for category ${event.categoryId}',
            category: 'SUBCATEGORY_BLOC');
      } else {
        // Clear all cache from memory
        _subcategoryCache.clear();
        _categoriesCache = null;

        // Also clear from local storage
        try {
          final prefs = await localDataSource.sharedPreferences;
          // Find all subcategory keys
          final keys = prefs
              .getKeys()
              .where((key) =>
                  key.startsWith('cached_subcategory_menu_') ||
                  key.startsWith('cached_category_menu'))
              .toList();

          // Remove all those keys
          for (final key in keys) {
            prefs.remove(key);
          }
        } catch (e) {
          DebugLogger.log(
              'Error clearing all subcategory cache from storage: $e',
              category: 'SUBCATEGORY_BLOC');
        }

        DebugLogger.log('Cleared all subcategory cache',
            category: 'SUBCATEGORY_BLOC');
      }
    });

    on<PrefetchSubcategories>((event, emit) async {
      for (final categoryId in event.categoryIds) {
        // Skip if already in cache or being fetched
        if (_subcategoryCache.containsKey(categoryId) ||
            _pendingCategories.contains(categoryId)) {
          continue;
        }

        _pendingCategories.add(categoryId);

        try {
          DebugLogger.log('Prefetching subcategories for category $categoryId',
              category: 'SUBCATEGORY_BLOC');

          final subcategories =
              await categoriesRepository.getSubCategoriesMenu(categoryId);

          // Store in memory cache
          _subcategoryCache[categoryId] = subcategories;

          // Also store in local storage
          try {
            await localDataSource.cacheSubCategoriesMenu(
                categoryId, subcategories);
          } catch (e) {
            DebugLogger.log('Error caching subcategories to local storage: $e',
                category: 'SUBCATEGORY_BLOC');
          }

          _pendingCategories.remove(categoryId);

          DebugLogger.log(
              'Prefetched ${subcategories.length} subcategories for category $categoryId',
              category: 'SUBCATEGORY_BLOC');
        } catch (e) {
          _pendingCategories.remove(categoryId);
          DebugLogger.log(
              'Error prefetching subcategories for category $categoryId: $e',
              category: 'SUBCATEGORY_BLOC');
        }
      }
    });
  }

  Future<void> _fetchAndUpdateSubcategories(
      int categoryId, Emitter<SubcategoryState> emit, bool emitState,
      {bool forceRefresh = false}) async {
    _pendingCategories.add(categoryId);

    try {
      // Fetch from API if forcing refresh
      if (forceRefresh) {
        DebugLogger.log(
            'Fetching subcategories from API for category $categoryId (forceRefresh)',
            category: 'SUBCATEGORY_BLOC');

        final stopwatch = Stopwatch()..start();
        final List<SubCategoryMenu> apiItems =
        await categoriesRepository.getSubCategoriesMenu(categoryId, forceRefresh: true);
        stopwatch.stop();

        DebugLogger.log(
            'Fetched ${apiItems.length} subcategories from API in ${stopwatch.elapsedMilliseconds}ms',
            category: 'SUBCATEGORY_BLOC');

        // Update memory caches with new data
        _subcategoryCache[categoryId] = apiItems;
        _globalSubcategoryCache[categoryId] = apiItems;

        // Emit loaded state if needed
        if (emitState) {
          emit(SubcategoryLoaded(apiItems));
        }
      } else {
        // If not forcing refresh, try cache first
        if (_globalSubcategoryCache.containsKey(categoryId)) {
          DebugLogger.log(
              'Using global-cached subcategories for category $categoryId',
              category: 'SUBCATEGORY_BLOC');

          // Sync local cache with global
          _subcategoryCache[categoryId] = _globalSubcategoryCache[categoryId]!;

          if (emitState) {
            emit(SubcategoryLoaded(_globalSubcategoryCache[categoryId]!));
          }
        } else if (_subcategoryCache.containsKey(categoryId)) {
          DebugLogger.log(
              'Using memory-cached subcategories for category $categoryId',
              category: 'SUBCATEGORY_BLOC');

          // Sync global cache with local
          _globalSubcategoryCache[categoryId] = _subcategoryCache[categoryId]!;

          if (emitState) {
            emit(SubcategoryLoaded(_subcategoryCache[categoryId]!));
          }
        } else {
          // Nothing in memory, try storage or API
          try {
            final cachedItems = await localDataSource.getSubCategoriesMenu(categoryId);

            if (cachedItems.isNotEmpty) {
              // Update both memory caches
              _subcategoryCache[categoryId] = cachedItems;
              _globalSubcategoryCache[categoryId] = cachedItems;

              if (emitState) {
                emit(SubcategoryLoaded(cachedItems));
              }
            } else {
              // No cache, fetch from API
              final apiItems = await categoriesRepository.getSubCategoriesMenu(categoryId);

              // Update both memory caches
              _subcategoryCache[categoryId] = apiItems;
              _globalSubcategoryCache[categoryId] = apiItems;

              if (emitState) {
                emit(SubcategoryLoaded(apiItems));
              }
            }
          } catch (e) {
            // Error handling
            DebugLogger.log('Error fetching subcategories: $e',
                category: 'SUBCATEGORY_BLOC');

            if (emitState) {
              emit(SubcategoryError(e.toString()));
            }
          }
        }
      }
    } catch (e) {
      DebugLogger.log('Error in _fetchAndUpdateSubcategories: $e',
          category: 'SUBCATEGORY_BLOC');

      // Error handling...
    } finally {
      _pendingCategories.remove(categoryId);
    }
  }

// Helper to compare if subcategory lists are effectively the same
  bool listsAreEqual(List<SubCategoryMenu> list1, List<SubCategoryMenu> list2) {
    if (list1.length != list2.length) return false;

    // Create maps of ID -> count for comparison
    Map<int, int> counts1 = {for (var item in list1) item.id: item.servicePostsCount};
    Map<int, int> counts2 = {for (var item in list2) item.id: item.servicePostsCount};

    // Compare by IDs and counts
    for (var id in counts1.keys) {
      if (!counts2.containsKey(id) || counts1[id] != counts2[id]) {
        return false;
      }
    }

    return true;
  }

  void startBackgroundRefresh(int categoryId) {
    // Skip if already pending
    if (_pendingCategories.contains(categoryId)) {
      DebugLogger.log(
          'Skipping background refresh for category $categoryId: already in progress',
          category: 'SUBCATEGORY_BLOC');
      return;
    }

    // Check if we've refreshed this category recently
    if (_lastRefreshTimes.containsKey(categoryId)) {
      final lastRefresh = _lastRefreshTimes[categoryId]!;
      final timeSince = DateTime.now().difference(lastRefresh);

      if (timeSince < _refreshThrottleTime) {
        DebugLogger.log(
            'Skipping background refresh for category $categoryId: refreshed ${timeSince.inSeconds}s ago',
            category: 'SUBCATEGORY_BLOC');
        return;
      }
    }

    // Track this refresh time
    _lastRefreshTimes[categoryId] = DateTime.now();

    // Proceed with the refresh, but use the FetchSubcategories event instead
    // This will update the caches without showing loading state or emitting UI updates
    add(FetchSubcategories(
        categoryId: categoryId,
        showLoadingState: false,
        forceRefresh: true
    ));
  }

  // Helper method to fetch categories from API and update caches
  Future<void> _fetchAndUpdateCategories(
      Emitter<SubcategoryState> emit, bool emitState) async {
    _isFetchingCategories = true;

    try {
      final stopwatch = Stopwatch()..start();
      final List<CategoryMenu> categories =
          await categoriesRepository.getCategoryMenu();
      stopwatch.stop();

      DebugLogger.log(
          'Fetched ${categories.length} categories in ${stopwatch.elapsedMilliseconds}ms',
          category: 'SUBCATEGORY_BLOC');

      // Store in memory cache
      _categoriesCache = categories;

      // Also store in local storage
      try {
        await localDataSource.cacheCategoryMenu(categories);
      } catch (e) {
        DebugLogger.log('Error caching categories to local storage: $e',
            category: 'SUBCATEGORY_BLOC');
      }

      _isFetchingCategories = false;

      // Only emit if requested
      if (emitState) {
        emit(CategoryLoaded(categories));
      }
    } catch (e) {
      _isFetchingCategories = false;
      DebugLogger.log('Error fetching categories: $e',
          category: 'SUBCATEGORY_BLOC');

      // Only emit error if requested
      if (emitState) {
        emit(SubcategoryError(e.toString()));
      }
    }
  }

  // Public method to prefetch subcategories
  Future<void> prefetchSubcategories(List<int> categoryIds) async {
    add(PrefetchSubcategories(categoryIds));
  }

  @override
  Future<void> close() {
    DebugLogger.log('SubcategoryBloc closed: $hashCode', category: 'BLOC');
    return super.close();
  }
}
