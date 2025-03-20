import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_event.dart';
import 'package:talabna/blocs/user_profile/user_profile_state.dart';
import 'package:talabna/core/deep_link_service.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/provider/language.dart';
import 'package:talabna/screens/reel/reels_screen.dart';
import '../../blocs/category/subcategory_bloc.dart';
import '../../blocs/category/subcategory_event.dart';
import '../../blocs/category/subcategory_state.dart';
import '../../blocs/service_post/service_post_event.dart';
import '../../core/home_screenI_initializer.dart';
import '../../core/service_locator.dart';
import '../../data/models/category_menu.dart';
import '../../data/repositories/categories_repository.dart';
import '../../data/datasources/local/local_category_data_source.dart';
import '../../routes.dart';
import '../../services/deep_link_service.dart';
import '../../utils/custom_routes.dart';
import '../../utils/debug_logger.dart';

/// Controller for the HomeScreen that handles all business logic
class HomeScreenController {
  final BuildContext context;
  final StatefulWidget widget;
  final State state;

  // BLoC and Repository instances
  late UserProfileBloc _userProfileBloc;
  late ServicePostBloc _servicePostBloc;
  late CategoriesRepository _categoryRepository;
  late SubcategoryBloc _subcategoryBloc;

  // UI State
  bool showSubcategoryGridView = false;
  int _selectedCategory = 1;
  List<CategoryMenu> _categories = [];
  bool isLoading = true;
  String currentLanguage = 'en';
  bool _justUpdated = false;
  bool _profileCompleted = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _disposed = false;

  final Language language = Language();

  HomeScreenController({
    required this.context,
    required this.widget,
    required this.state,
  });

  // Public getters
  Animation<double> get fadeAnimation => _fadeAnimation;

  List<CategoryMenu> get categories => _categories;

  int get selectedCategory => _selectedCategory;

  ServicePostBloc get servicePostBloc => _servicePostBloc;

  // Theme colors helper
  Map<String, Color> getThemeColors() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return {
      'backgroundColor': isDarkMode ? AppTheme.darkPrimaryColor : Colors.white,
      'primaryColor':
          isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor,
      'textColor':
          isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor,
      'iconColor':
          isDarkMode ? AppTheme.darkIconColor : AppTheme.lightIconColor,
    };
  }

  void initialize() {
    // Initialize controllers first
    _initializeControllers();

    // Force immediate category loading - this is now our primary method
    _forceDirectCategoryLoading();

    // Rest of initialization
    _initializeScreen();

    DebugLogger.printAllLogs();

    try {
      // Create initializer to manage caching
      final initializer = HomeScreenInitializer(context);
      initializer.initialize();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setSystemUIOverlayStyle();

        // After UI is displayed, refresh data in background
        Future.delayed(const Duration(milliseconds: 500), () {
          initializer.refreshDataInBackground();
        });

        // Check if we need to navigate to a specific reel - with a delay to ensure categories are loaded
        Future.delayed(const Duration(milliseconds: 800), () {
          _checkPendingReelNavigation();
        });
      });
    } catch (e) {
      DebugLogger.log('Error in home screen initialization: $e',
          category: 'INIT_ERROR');
    }

    // Set up a periodic check for pending reel navigation
    Timer.periodic(Duration(seconds: 2), (timer) {
      if (!state.mounted) {
        timer.cancel();
        return;
      }

      // Only check if categories are loaded and user profile is loaded
      if (_categories.isNotEmpty &&
          _userProfileBloc.state is UserProfileLoadSuccess &&
          !isLoading) {
        _checkPendingReelNavigation();

        // After checking a few times, cancel the timer
        if (timer.tick > 5) {
          timer.cancel();
        }
      }
    });
  }

  void onDidChangeDependencies() {
    // Check if we already have categories but are still showing loading
    if (isLoading && _categories.isNotEmpty) {
      state.setState(() {
        isLoading = false;
      });
    }
  }

  void onDidUpdateWidget(StatefulWidget oldWidget) {
    // When returning to this screen, we should not show loading if we already have categories
    if (isLoading && _categories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (state.mounted) {
          state.setState(() {
            isLoading = false;
          });
        }
      });
    }
  }

  void onBuildStart() {
    // Additional safety check - always reset loading if we have categories
    if (isLoading && _categories.isNotEmpty) {
      state.setState(() {
        isLoading = false;
      });
    }

    // Set system UI style
    _setSystemUIOverlayStyle();
  }

  void onAppLifecycleStateChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed && state.mounted) {
      // On coming back to the app, clear loading state if categories exist
      if (isLoading && _categories.isNotEmpty) {
        state.setState(() {
          isLoading = false;
        });
      }
    }
  }

  void onUserProfileStateChange(UserProfileState profileState) {
    // Reset loading state after profile update
    if (profileState is UserProfileUpdateSuccess && state.mounted) {
      state.setState(() {
        isLoading = false;
      });
      _handleProfileUpdate();
    }

    // Always reset loading if we already have categories
    if (profileState is UserProfileLoadSuccess &&
        isLoading &&
        _categories.isNotEmpty) {
      state.setState(() {
        isLoading = false;
      });
    }

    // Only show loading indicator for empty categories
    if (profileState is UserProfileLoadInProgress && _categories.isEmpty) {
      state.setState(() {
        isLoading = true;
      });
    }
  }

  // Initialize everything
  Future<void> _initializeScreen() async {
    try {
      if (!state.mounted) return;

      await _loadLanguage();
      if (!state.mounted) return;

      // Use a cache-first strategy for initial data
      await _loadInitialDataFromCache();

      // Explicitly set loading to false if categories are already loaded
      if (_categories.isNotEmpty) {
        state.setState(() {
          isLoading = false;
        });
      }

      if (state.mounted) {
        _animationController.forward();
      }
    } catch (e, stackTrace) {
      DebugLogger.log('Initialization Error: $e\n$stackTrace',
          category: 'INIT');

      if (state.mounted) {
        state.setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Initialize controllers
  void _initializeControllers() {
    if (!state.mounted) return;

    _userProfileBloc = BlocProvider.of<UserProfileBloc>(context);
    _servicePostBloc = BlocProvider.of<ServicePostBloc>(context);
    _categoryRepository = serviceLocator<CategoriesRepository>();

    _animationController = AnimationController(
      vsync: state as TickerProvider,
      duration: const Duration(milliseconds: 50),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    final userId = (widget as dynamic).userId;
    _userProfileBloc.add(UserProfileRequested(id: userId));
  }

  // Apply consistent system UI colors
  void _setSystemUIOverlayStyle() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDarkMode ? AppTheme.darkPrimaryColor : Colors.white;
    final brightness = isDarkMode ? Brightness.light : Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: barColor,
      statusBarBrightness: brightness,
      statusBarIconBrightness: brightness,
      systemNavigationBarColor: barColor,
      systemNavigationBarIconBrightness: brightness,
    ));
  }

  // Handle force loading categories
  void _forceDirectCategoryLoading() {
    if (!state.mounted) return;

    // If categories are already loaded, don't show loading state
    if (_categories.isNotEmpty) {
      state.setState(() {
        isLoading = false;
      });
      return;
    }

    DebugLogger.log('Force-loading categories from storage first',
        category: 'CATEGORIES');

    // Show loading state temporarily
    state.setState(() {
      isLoading = true;
    });

    // Wait for controllers to be initialized
    Future.microtask(() async {
      try {
        _categoryRepository ??= serviceLocator<CategoriesRepository>();

        // Get the local data source
        final localDataSource = serviceLocator<LocalCategoryDataSource>();

        // FIRST: Try to load from local storage
        bool loadedFromCache = false;

        if (localDataSource.isCacheValid('cached_category_menu')) {
          try {
            final cachedCategories = await localDataSource.getCategoryMenu();

            if (cachedCategories.isNotEmpty && state.mounted) {
              // Filter out suspended categories
              final activeCategories = cachedCategories
                  .where((category) => !category.isSuspended)
                  .toList();
              final arrangedCategories = _arrangeCategories(activeCategories);

              state.setState(() {
                _categories = arrangedCategories;
                isLoading = false;

                // Auto-select first category if no category is selected
                if (_selectedCategory == 0 && _categories.isNotEmpty) {
                  _selectedCategory = _categories.first.id;
                }
              });

              loadedFromCache = true;
              DebugLogger.log(
                  'Successfully loaded ${cachedCategories.length} categories from storage',
                  category: 'CATEGORIES');

              // Load service posts for the selected category
              if (_servicePostBloc != null && _selectedCategory > 0) {
                _servicePostBloc.add(
                  GetServicePostsByCategoryEvent(
                    _selectedCategory,
                    1,
                    forceRefresh: true, // Always get fresh posts from API
                  ),
                );
              }

              // Also fetch subcategories for the selected category from storage
              _loadSubcategoriesFromStorage(_selectedCategory);
            }
          } catch (e) {
            DebugLogger.log('Error loading categories from storage: $e',
                category: 'CATEGORIES');
            // We'll try from API next
          }
        }

        // SECOND: If storage failed, try API
        if (!loadedFromCache) {
          // Load categories directly from repository
          final categories =
              await _categoryRepository.getCategoryMenu(forceRefresh: true);

          if (state.mounted && categories.isNotEmpty) {
            // Filter out suspended categories
            final activeCategories =
                categories.where((category) => !category.isSuspended).toList();
            final arrangedCategories = _arrangeCategories(activeCategories);

            state.setState(() {
              _categories = arrangedCategories;
              isLoading = false;

              // Auto-select first category if no category is selected
              if (_selectedCategory == 0 && _categories.isNotEmpty) {
                _selectedCategory = _categories.first.id;
              }
            });

            DebugLogger.log(
                'Successfully loaded ${categories.length} categories from API',
                category: 'CATEGORIES');

            // Load service posts for the selected category
            if (_servicePostBloc != null && _selectedCategory > 0) {
              _servicePostBloc.add(
                GetServicePostsByCategoryEvent(
                  _selectedCategory,
                  1,
                  forceRefresh: true, // Always get fresh posts from API
                ),
              );
            }
          } else {
            // If loading fails, ensure we're not stuck in loading state
            if (state.mounted) {
              state.setState(() {
                isLoading = false;
              });
            }
          }
        }

        // THIRD: Refresh categories in background if we showed cached data
        if (loadedFromCache && state.mounted) {
          _refreshCategoriesInBackground();
        }
      } catch (e) {
        DebugLogger.log('Error force-loading categories: $e',
            category: 'CATEGORIES');

        // Ensure we exit loading state
        if (state.mounted) {
          state.setState(() {
            isLoading = false;
          });
        }

        // Try one more fallback approach - use the bloc but only with FetchCategories
        if (state.mounted && _subcategoryBloc != null) {
          _subcategoryBloc.add(
            FetchCategories(
              showLoadingState: true,
              forceRefresh: true,
            ),
          );
        }
      }
    });

    // Safety timeout - no matter what, exit loading after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (state.mounted && isLoading) {
        state.setState(() {
          isLoading = false;
        });
      }
    });
  }

  // Check and handle pending reel navigation
  Future<void> _checkPendingReelNavigation() async {
    if (!state.mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingCategoryId = prefs.getInt('pending_select_category');
      final pendingReelId = prefs.getString('pending_reel_id');

      // If we don't have a pending category ID or reel ID, exit
      if (pendingCategoryId == null || pendingReelId == null) {
        return;
      }

      DebugLogger.log(
          'Found pending reel navigation: category=$pendingCategoryId, reelId=$pendingReelId',
          category: 'NAVIGATION');

      // Only proceed if user profile is loaded and categories are loaded
      if (_userProfileBloc.state is! UserProfileLoadSuccess) {
        DebugLogger.log(
            'Waiting for user profile to load before navigating to reel',
            category: 'NAVIGATION');
        return;
      }

      if (_categories.isEmpty) {
        DebugLogger.log(
            'Waiting for categories to load before navigating to reel',
            category: 'NAVIGATION');
        return;
      }

      // Get user from state
      final user = (_userProfileBloc.state as UserProfileLoadSuccess).user;

      // Clear the pending navigation flags BEFORE we start navigation
      // This helps prevent duplicate navigation attempts
      await prefs.remove('pending_select_category');
      await prefs.remove('pending_reel_id');

      // Use the direct navigation method which bypasses category selection
      DebugLogger.log('Directly navigating to specific reel ID: $pendingReelId',
          category: 'NAVIGATION');
      await _navigateToSpecificReel(context, user, pendingReelId);
    } catch (e, stackTrace) {
      DebugLogger.log('Error checking pending reel navigation: $e\n$stackTrace',
          category: 'NAVIGATION');

      // Reset any pending navigation - this prevents getting stuck in a loop
      if (state.mounted) {
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('pending_select_category');
          prefs.remove('pending_reel_id');
        });
      }
    }
  }

  // Navigate to a specific reel
  Future<void> _navigateToSpecificReel(
      BuildContext context, User user, String postId) async {
    // First, ensure we have the post data
    final servicePostBloc = context.read<ServicePostBloc>();

    // Request the post data
    servicePostBloc.add(GetServicePostByIdEvent(
      int.parse(postId),
      forceRefresh: true, // Always get fresh data for deep links
    ));

    // Show a quick loading indicator
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Loading video...'), duration: Duration(seconds: 1)));

    // Wait a moment for data to load
    await Future.delayed(Duration(milliseconds: 800));

    // Create a route directly to ReelsHomeScreen
    final route = MaterialPageRoute(
      settings: RouteSettings(name: '/reels', arguments: {'postId': postId}),
      builder: (context) => ReelsHomeScreen(
        userId: (widget as dynamic).userId,
        user: user,
        postId: postId,
      ),
    );

    // Navigate directly to the ReelsHomeScreen
    if (state.mounted && context.mounted) {
      Navigator.of(context).push(route);
    }
  }

  // Helper method to load subcategories from storage
  Future<void> _loadSubcategoriesFromStorage(int categoryId) async {
    if (!state.mounted) return;

    try {
      final localDataSource = serviceLocator<LocalCategoryDataSource>();

      if (localDataSource.isCacheValid('cached_subcategory_menu_$categoryId')) {
        final cachedSubcategories =
            await localDataSource.getSubCategoriesMenu(categoryId);

        if (cachedSubcategories.isNotEmpty) {
          DebugLogger.log(
              'Loaded ${cachedSubcategories.length} subcategories for category $categoryId from storage',
              category: 'SUBCATEGORIES');

          // Now that we have subcategories, tell the bloc about them
          if (_subcategoryBloc != null) {
            _subcategoryBloc.add(
              FetchSubcategories(
                  categoryId: categoryId,
                  showLoadingState: false,
                  forceRefresh: false),
            );
          }
        }
      }
    } catch (e) {
      DebugLogger.log('Error loading subcategories from storage: $e',
          category: 'SUBCATEGORIES');
    }
  }

  // Helper method to refresh categories in background
  void _refreshCategoriesInBackground() {
    if (!state.mounted) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        if (_categoryRepository != null && state.mounted) {
          _categoryRepository
              .getCategoryMenu(forceRefresh: true)
              .then((categories) {
            if (state.mounted && categories.isNotEmpty) {
              // Filter out suspended categories
              final activeCategories = categories
                  .where((category) => !category.isSuspended)
                  .toList();
              final arrangedCategories = _arrangeCategories(activeCategories);

              state.setState(() {
                _categories = arrangedCategories;
                // Don't change the selected category here - that would disrupt the user
              });

              DebugLogger.log(
                  'Refreshed ${categories.length} categories in background',
                  category: 'CATEGORIES');
            }
          }).catchError((error) {
            DebugLogger.log('Error refreshing categories in background: $error',
                category: 'CATEGORIES');
          });
        }
      } catch (e) {
        DebugLogger.log('Exception in _refreshCategoriesInBackground: $e',
            category: 'CATEGORIES');
      }
    });
  }

  Future<void> _loadInitialDataFromCache() async {
    if (!state.mounted) return;

    await _loadShowSubcategoryGridView();
    if (!state.mounted) return;

    // Get the Bloc instances
    _subcategoryBloc = BlocProvider.of<SubcategoryBloc>(context);
    _servicePostBloc = BlocProvider.of<ServicePostBloc>(context);

    // Trigger loading categories from cache with force refresh = false
    _subcategoryBloc.add(
      FetchCategories(
        showLoadingState: false, // Don't show loading indicator for cached data
        forceRefresh: false, // Use cache first
      ),
    );

    // Load service posts for default category DIRECTLY FROM API
    _servicePostBloc.add(
      GetServicePostsByCategoryEvent(
        _selectedCategory,
        1,
        forceRefresh: true, // Force API fetch
      ),
    );

    // Check if categories are already loaded
    if (_categories.isNotEmpty) {
      state.setState(() {
        isLoading = false;
      });
    } else {
      // Set a timeout to ensure loading state doesn't persist
      Future.delayed(const Duration(seconds: 2), () {
        if (state.mounted && isLoading) {
          state.setState(() {
            isLoading = false;
          });
        }
      });
    }
  }

  Future<void> _loadLanguage() async {
    if (!state.mounted) return;
    final lang = await language.getLanguage();
    if (state.mounted) {
      state.setState(() {
        currentLanguage = lang;
      });
    }
  }

  Future<void> _loadShowSubcategoryGridView() async {
    if (!state.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (state.mounted) {
      state.setState(() {
        showSubcategoryGridView =
            prefs.getBool('showSubcategoryGridView') ?? false;
      });
    }
  }

  Future<void> _saveShowSubcategoryGridView(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showSubcategoryGridView', value);
  }

  // Public methods that UI can call
  Future<void> toggleSubcategoryGridView({bool? canToggle}) async {
    if (!state.mounted) return;
    if (canToggle == null || canToggle) {
      state.setState(() {
        showSubcategoryGridView = !showSubcategoryGridView;
      });
      await _saveShowSubcategoryGridView(showSubcategoryGridView);
    }
  }

  IconData getCategoryIcon(int categoryId) {
    switch (categoryId) {
      case 1:
        return Icons.work_outline_rounded;
      case 2:
        return Icons.devices_rounded;
      case 3:
        return Icons.home_rounded;
      case 7:
        return Icons.play_circle_fill_rounded;
      case 4:
        return Icons.directions_car_rounded;
      case 5:
        return Icons.miscellaneous_services_rounded;
      case 6:
        return Icons.location_on_rounded;
      default:
        return Icons.work_outline_rounded;
    }
  }

  String getCategoryName(CategoryMenu category) {
    return category.name[currentLanguage] ?? category.name['en'] ?? 'Unknown';
  }

  void onCategorySelected(int categoryId, BuildContext context, User user) {
    if (!state.mounted) return;

    state.setState(() => _selectedCategory = categoryId);

    // Keep this condition - it prevents toggling for category 6 and 0
    if (categoryId == 6 || categoryId == 0) {
      toggleSubcategoryGridView(canToggle: false);

      // For category 6, we'll handle the service post loading in MainMenuPostScreen
      // So no additional code needed here, the component will handle it
    }

    if (categoryId == 7) {
      _navigateToReels(context, user);
    }

    // Load service posts for the selected category
    if (_servicePostBloc != null && categoryId != 7) {
      _servicePostBloc.add(
        GetServicePostsByCategoryEvent(
          categoryId,
          1,
          forceRefresh: true, // Always use fresh posts from API
        ),
      );

      // Also load subcategories
      if (_subcategoryBloc != null) {
        _subcategoryBloc.add(
          FetchSubcategories(
            categoryId: categoryId,
            showLoadingState: false,
            forceRefresh: false, // Try cache first, then API
          ),
        );
      }
    }
  }

  Future<void> _navigateToReels(BuildContext context, User user,
      [String? specificReelId]) async {
    // Save the current selected category before navigation
    final previousCategory = _selectedCategory;

    // Set the UI state to indicate Reels is selected
    state.setState(() => _selectedCategory = 7);

    try {
      // Log what we're doing
      if (specificReelId != null) {
        DebugLogger.log(
            'Navigating to reels with specific reel ID: $specificReelId',
            category: 'NAVIGATION');
      } else {
        DebugLogger.log('Navigating to general reels feed',
            category: 'NAVIGATION');
      }

      // Use the custom transition
      final route = ReelsRouteTransition(
        page: ReelsHomeScreen(
          userId: (widget as dynamic).userId,
          user: user,
          // Pass the specific reel ID if we have one
          postId: specificReelId,
        ),
      );

      // Push the route and wait for it to complete
      await Navigator.of(context).push(route);

      // After returning, restore the previous category (as backup in case onClose wasn't called)
      if (state.mounted) {
        state.setState(() =>
            _selectedCategory = previousCategory != 7 ? previousCategory : 1);
      }

      // Clear any pending deep links
      DeepLinkService().clearPendingDeepLinks();
    } catch (e) {
      DebugLogger.log('Error navigating to reels: $e', category: 'NAVIGATION');

      // If there's an error, reset to the previous category
      if (state.mounted) {
        state.setState(() =>
            _selectedCategory = previousCategory != 7 ? previousCategory : 1);
      }
    }
  }

  List<CategoryMenu> _arrangeCategories(List<CategoryMenu> categories) {
    if (categories.isEmpty) {
      return [];
    }

    // Find reels category (id 7) safely
    CategoryMenu? reelsCategory;
    try {
      reelsCategory = categories.firstWhere((category) => category.id == 7);
    } catch (e) {
      // No reels category found, that's okay
      reelsCategory = null;
    }

    // Filter categories that are not reels and sort them by ID
    final otherCategories = categories
        .where((category) => category.id != 7)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    // If reels category exists, insert it in the middle
    if (reelsCategory != null) {
      final middleIndex = otherCategories.length ~/ 2;

      // Log the arrangement
      DebugLogger.log(
          'Arranging ${otherCategories.length} categories with reels in middle (index $middleIndex)',
          category: 'CATEGORIES');

      return [
        ...otherCategories.sublist(0, middleIndex),
        reelsCategory,
        ...otherCategories.sublist(middleIndex),
      ];
    } else {
      return otherCategories;
    }
  }

  void _handleProfileUpdate() {
    if (!state.mounted) return;

    state.setState(() {
      _justUpdated = true;
      _profileCompleted = true; // Mark profile as completed when it's updated
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (state.mounted) {
        state.setState(() {
          _justUpdated = false;
        });
      }
    });

    _userProfileBloc.add(UserProfileRequested(id: (widget as dynamic).userId));
  }

  // Public methods for UI interactions
  void refreshCategories() {
    if (!state.mounted) return;

    // Try to fetch categories again, this time force refresh
    if (_subcategoryBloc != null) {
      _subcategoryBloc.add(
        FetchCategories(
          showLoadingState: true,
          forceRefresh: true,
        ),
      );
      state.setState(() {
        isLoading = true;
      });
    }
  }

  void retryUserProfileLoad() {
    _userProfileBloc.add(UserProfileRequested(id: (widget as dynamic).userId));
  }

  Future<void> printDebugLogs() async {
    // Show a loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Fetching logs...'),
          duration: Duration(milliseconds: 500)),
    );

    // Print logs
    await DebugLogger.printAllLogs();

    // Show confirmation
    if (state.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs printed to console')),
      );
    }
  }

  // Additional getters for UI
  bool get hasReelsCategory => _categories.any((c) => c.id == 7);

  CategoryMenu? getReelsCategory() {
    try {
      return _categories.firstWhere((c) => c.id == 7);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    _animationController.dispose();
  }
}
