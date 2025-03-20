import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/category/subcategory_bloc.dart';
import 'package:talabna/blocs/category/subcategory_event.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/data/datasources/local/local_category_data_source.dart';
import 'package:talabna/data/repositories/categories_repository.dart';
import 'package:talabna/utils/debug_logger.dart';

import 'service_locator.dart';

/// Optimized helper class to manage initialization of home screen data
/// Ensures cached data is loaded first, then refreshed in background
class HomeScreenInitializer {
  final BuildContext context;
  bool _isDisposed = false;
  bool _initialized = false;

  // Track initialization state
  static bool _categoriesPreloaded = false;

  HomeScreenInitializer(this.context);

  /// Initialize data for home screen with emphasis on loading categories first
  Future<void> initialize() async {
    if (_initialized || _isDisposed) return;
    _initialized = true;

    final stopwatch = Stopwatch()..start();

    try {
      // Get necessary blocs
      final subcategoryBloc = BlocProvider.of<SubcategoryBloc>(context);

      // OPTIMIZATION 1: Direct access to speed up loading
      await _preloadCategoriesDirectly();

      // OPTIMIZATION 2: Also request through bloc as backup
      _loadCategoriesFromBloc(subcategoryBloc);

      // OPTIMIZATION 3: Preload subcategories for common categories in parallel
      _preloadCommonSubcategories(subcategoryBloc);

      stopwatch.stop();
      DebugLogger.log(
          'HomeScreenInitializer completed in ${stopwatch.elapsedMilliseconds}ms',
          category: 'INIT');
    } catch (e, stacktrace) {
      DebugLogger.log('Error initializing home screen: $e\n$stacktrace',
          category: 'INIT_ERROR');
    }
  }

  /// Preload categories directly from repository
  Future<void> _preloadCategoriesDirectly() async {
    if (_isDisposed) return;

    // Skip if already preloaded
    if (HomeScreenInitializer._categoriesPreloaded) {
      return;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Get data sources and repositories
      final repository = serviceLocator<CategoriesRepository>();
      final localDataSource = serviceLocator<LocalCategoryDataSource>();

      // First, try to preload from memory cache
      await localDataSource.preloadCommonCaches();

      // Then trigger repository to cache categories
      await repository.getCategoryMenu(forceRefresh: false);

      // Mark as preloaded
      HomeScreenInitializer._categoriesPreloaded = true;

      stopwatch.stop();
      DebugLogger.log(
          'Directly preloaded categories in ${stopwatch.elapsedMilliseconds}ms',
          category: 'INIT');
    } catch (e) {
      DebugLogger.log('Error preloading categories directly: $e',
          category: 'INIT_ERROR');
    }
  }

  /// Load categories through the bloc
  Future<void> _loadCategoriesFromBloc(SubcategoryBloc subcategoryBloc) async {
    if (_isDisposed) return;

    try {
      // Try to load from cache with high priority
      subcategoryBloc.add(FetchCategories(
        showLoadingState: false, // Don't show loading indicator
        forceRefresh: false, // Use cache first
      ));

      DebugLogger.log('Requested categories from bloc', category: 'INIT');
    } catch (e) {
      DebugLogger.log('Error requesting categories from bloc: $e',
          category: 'INIT_ERROR');
    }
  }

  /// Preload subcategories for common categories
  void _preloadCommonSubcategories(SubcategoryBloc subcategoryBloc) {
    if (_isDisposed) return;

    try {
      // Preload subcategories for the most common categories (1-5) in parallel
      subcategoryBloc.prefetchSubcategories([1, 2, 3, 4, 5]);

      DebugLogger.log('Started preloading subcategories for common categories',
          category: 'INIT');
    } catch (e) {
      DebugLogger.log('Error preloading subcategories: $e',
          category: 'INIT_ERROR');
    }
  }

  /// Refresh data in background after UI is visible
  Future<void> refreshDataInBackground() async {
    try {
      if (_isDisposed) return;

      // Get necessary blocs
      final subcategoryBloc = BlocProvider.of<SubcategoryBloc>(context);
      final servicePostBloc = BlocProvider.of<ServicePostBloc>(context);

      // Refresh categories in background
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isDisposed) return;

        // Refresh categories without showing loading state
        subcategoryBloc.add(FetchCategories(
          showLoadingState: false,
          forceRefresh: true, // Force refresh from API
        ));

        // For better UX, make sure we refresh service posts too
        final selectedCategory = getSelectedCategory();
        if (selectedCategory > 0) {
          servicePostBloc.add(
            GetServicePostsByCategoryEvent(
              selectedCategory,
              1,
              forceRefresh: true,
            ),
          );
        }
      });

      DebugLogger.log('Started background refresh of data',
          category: 'BACKGROUND_REFRESH');
    } catch (e) {
      DebugLogger.log('Error refreshing data in background: $e',
          category: 'BACKGROUND_REFRESH_ERROR');
    }
  }

  /// Get currently selected category
  int getSelectedCategory() {
    try {
      // This is a simple approach - your actual implementation may vary
      // depending on how you store the selected category
      return 1; // Default to first category
    } catch (e) {
      return 1; // Default on error
    }
  }

  void dispose() {
    _isDisposed = true;
  }
}
