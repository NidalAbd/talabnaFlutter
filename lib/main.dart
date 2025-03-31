import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/blocs/authentication/authentication_bloc.dart';
import 'package:talabna/blocs/authentication/authentication_event.dart';
import 'package:talabna/blocs/category/subcategory_bloc.dart';
import 'package:talabna/blocs/category/subcategory_event.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/provider/language_change_notifier.dart';
import 'package:talabna/routes.dart';
import 'package:talabna/services/device_info_service.dart';
import 'package:talabna/theme_cubit.dart';
import 'package:talabna/utils/debug_logger.dart';
import 'package:talabna/utils/fcm_handler.dart';

import 'app.dart';
import 'core/app_bloc_providers.dart';
import 'core/app_repositories.dart';
import 'core/deep_link_service.dart';
import 'core/navigation_service.dart';
import 'core/service_locator.dart';
import 'data/repositories/categories_repository.dart';
import 'data/repositories/service_post_repository.dart';
import 'first_lunch_initializer.dart';
import 'screens/reel/reels_state_manager.dart';

// Default language
String language = 'ar';
String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

class AppInitializer {
  // Global navigator key for routing
  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  // Main app initialization
  static Future<void> initialize() async {

    try {
      // Keep splash screen visible during initialization
      final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

      DebugLogger.log('App initialization started', category: 'INIT');

      try {
        // Initialize core services - sequential for reliability
        await _initializeFoundationServices();

        // Set up dependency injection
        await setupServiceLocator();

        // Initialize navigation service with navigator key
        final navigationService = serviceLocator<NavigationService>();
        navigationService.initialize(navigatorKey);

        // Initialize deep link service with deep link check
        final deepLinkService = serviceLocator<DeepLinkService>();
        bool isFromDeepLink = await deepLinkService.initialize();

        // If opening from deep link, setup navigation stack
        if (isFromDeepLink) {
          DebugLogger.log('App initializing from deep link', category: 'INIT');
          navigationService.setupDeepLinkNavigationStack();
        }

        // Start preloading data in background
        _preloadAppDataInBackground();

        // Load app preferences
        final prefs = await SharedPreferences.getInstance();
        await _loadLanguageSettings(prefs);

        // Check authentication status - critical for startup flow
        final authResult = await _checkAuthenticationStatus(prefs);
        final isAuthenticated = authResult['isAuthenticated'] as bool;
        final userId = authResult['userId'] as int?;

        // Configure system UI appearance
        await _configureSystemUI(prefs.getBool('isDarkTheme') ?? true);

        // Request permissions in background (non-blocking)
        _requestPermissionsInBackground();
        final appInfoService = AppInfoService();
        await appInfoService.initialize();
        // Run the application with proper initialization
        await _runApplication(prefs, isAuthenticated, userId, isFromDeepLink);

        DebugLogger.log('App initialization completed successfully',
            category: 'INIT');
      } catch (e, stackTrace) {
        // Detailed error logging
        DebugLogger.log('Initialization error: $e\n$stackTrace',
            category: 'INIT_ERROR');
        _runFallbackApplication();
      }
    } catch (fatalError, stackTrace) {
      // Catch any unhandled errors
      debugPrint('Fatal app initialization error: $fatalError\n$stackTrace');
    } finally {
      // Always remove splash screen eventually
      FlutterNativeSplash.remove();
    }
  }

  // Fallback for critical errors
  static void _runFallbackApplication() {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Unable to initialize the app'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => AppInitializer.initialize(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Initialize core services
  static Future<void> _initializeFoundationServices() async {
    DebugLogger.log('Initializing foundation services', category: 'INIT');

    // Initialize Firebase first
    await Firebase.initializeApp();

    // Initialize FCM for notifications
    await FCMHandler().initializeFCM();

    DebugLogger.log('Foundation services initialized', category: 'INIT');
  }

  // Preload app data in background (non-blocking)
  static void _preloadAppDataInBackground() {
    try {
      DebugLogger.log('Starting background data preload', category: 'INIT');

      // Get repository from service locator
      final categoriesRepository = serviceLocator<CategoriesRepository>();

      // Load categories in background - non-blocking
      categoriesRepository
          .getCategoryMenu(forceRefresh: false)
          .then((categories) {
        DebugLogger.log(
            'Preloaded ${categories.length} categories in background',
            category: 'INIT');
      }).catchError((e) {
        DebugLogger.log('Error preloading categories: $e',
            category: 'INIT_ERROR');
      });

      // Load category menu in background - non-blocking
      categoriesRepository.getCategoryMenu(forceRefresh: false).then((menu) {
        DebugLogger.log(
            'Preloaded ${menu.length} category menu items in background',
            category: 'INIT');
      }).catchError((e) {
        DebugLogger.log('Error w preloading menu: $e', category: 'INIT_ERROR');
      });
    } catch (e) {
      DebugLogger.log('Error in background data preload: $e',
          category: 'INIT_ERROR');
    }
  }

  // Load language settings
  static Future<void> _loadLanguageSettings(SharedPreferences prefs) async {
    try {
      // Get saved language or default to Arabic
      language = prefs.getString('language') ?? 'ar';
      DebugLogger.log('Language set to: $language', category: 'LANGUAGE');
    } catch (e) {
      DebugLogger.log('Error loading language: $e', category: 'LANGUAGE');
      language = 'ar'; // Fallback
    }
  }

  // Check authentication status
  static Future<Map<String, dynamic>> _checkAuthenticationStatus(
      SharedPreferences prefs) async {
    final String? token = prefs.getString('auth_token');
    final int? userId = prefs.getInt('userId');

    if (token == null || token.isEmpty || userId == null) {
      DebugLogger.log('No valid authentication token found', category: 'INIT');

      // Clean up any pending deep links if not authenticated
      final navigationService = serviceLocator<NavigationService>();
      await navigationService.clearPendingDeepLinks();

      return {'isAuthenticated': false, 'userId': null};
    }

    try {
      // Initialize repositories
      final repositories = await AppRepositories.initialize();
      final authRepository = repositories.authenticationRepository;

      // Get repositories from service locator
      final categoriesRepository = serviceLocator<CategoriesRepository>();
      final servicePostRepository = serviceLocator<ServicePostRepository>();

      // Check first-time initialization
      final firstLaunchInitializer = FirstLaunchInitializer(
        prefs: prefs,
        categoriesRepository: categoriesRepository,
        servicePostRepository: servicePostRepository,
      );

      if (firstLaunchInitializer.needsInitialization()) {
        await _performFirstTimeInitialization(firstLaunchInitializer);
      }

      // Validate token
      final bool isValid = await authRepository.checkTokenValidity(token);

      if (isValid) {
        DebugLogger.log('Token validated for user ID: $userId',
            category: 'INIT');

        // Set pre-authenticated user ID in navigation service
        final navigationService = serviceLocator<NavigationService>();
        navigationService.setPreAuthenticated(userId);

        return {'isAuthenticated': true, 'userId': userId};
      } else {
        DebugLogger.log('Token invalid, clearing credentials',
            category: 'INIT');
        await prefs.remove('auth_token');
        await prefs.remove('userId');

        // Clear pending deep links
        final navigationService = serviceLocator<NavigationService>();
        await navigationService.clearPendingDeepLinks();

        return {'isAuthenticated': false, 'userId': null};
      }
    } catch (e) {
      DebugLogger.log('Authentication check error: $e', category: 'INIT_ERROR');
      return {'isAuthenticated': false, 'userId': null};
    }
  }

  // Initialize first-time app data
  static Future<void> _performFirstTimeInitialization(
      FirstLaunchInitializer initializer) async {
    try {
      await initializer.initializeAppData();
      DebugLogger.log('First launch initialization completed',
          category: 'INIT');
    } catch (e) {
      DebugLogger.log('First launch initialization failed: $e',
          category: 'INIT_ERROR');
      await initializer.resetInitializationState();
    }
  }

  // Configure system UI appearance
  static Future<void> _configureSystemUI(bool isDarkTheme) async {
    // Set orientation restrictions
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system bar colors
    final brightness = isDarkTheme ? Brightness.dark : Brightness.light;
    AppTheme.setSystemBarColors(
      brightness,
      isDarkTheme ? AppTheme.darkPrimaryColor : AppTheme.lightPrimaryColor,
      isDarkTheme ? AppTheme.darkPrimaryColor : AppTheme.lightPrimaryColor,
    );

    // Set navigation bar appearance
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor:
      isDarkTheme ? AppTheme.darkPrimaryColor : AppTheme.lightPrimaryColor,
      systemNavigationBarIconBrightness:
      isDarkTheme ? Brightness.light : Brightness.dark,
    ));

    DebugLogger.log(
        'System UI configured for ${isDarkTheme ? "dark" : "light"} theme',
        category: 'INIT');
  }

  // Request permissions in background
  static Future<void> _requestPermissionsInBackground() async {
    try {
      final permissions = [
        Permission.location,
        Permission.storage,
        Permission.photos,
        Permission.notification,
      ];

      // Request sequentially with small delays
      for (final permission in permissions) {
        await permission.request();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      DebugLogger.log('Background permission requests completed',
          category: 'PERMISSIONS');
    } catch (e) {
      DebugLogger.log('Permission request error: $e', category: 'PERMISSIONS');
    }
  }

  static Future<void> _runApplication(
      SharedPreferences prefs,
      bool isAuthenticated,
      int? userId,
      bool isFromDeepLink) async {
    final isDarkTheme = prefs.getBool('isDarkTheme') ?? true;

    // Initialize repositories
    final repositories = await AppRepositories.initialize();

    // Get bloc providers
    final appBlocProviders = AppBlocProviders.getProviders();

    // Reset ReelsStateManager
    ReelsStateManager().forceReleaseLocks();

    // Check for any pending deep links before creating the app
    final pendingDeepLinkType = prefs.getString('pending_deep_link_type');
    final pendingDeepLinkId = prefs.getString('pending_deep_link_id');

    // Set initial route for MaterialApp based on deep link
    String initialRoute = Routes.initial;

    // Pass the deep link state to Routes for better back navigation handling
    if (isFromDeepLink) {
      Routes.setOpeningFromDeepLink(true);
    }

    // Handle any pending deep links
    if (isAuthenticated && userId != null && pendingDeepLinkType != null && pendingDeepLinkId != null) {
      if (pendingDeepLinkType == DeepLinkService.TYPE_REELS) {
        initialRoute = Routes.reels;
        // Store deep link arguments for the route generator
        Routes.setInitialRouteArgs({'postId': pendingDeepLinkId, 'userId': userId});
        DebugLogger.log('Starting app with reel deep link: $pendingDeepLinkId', category: 'INIT');
      } else if (pendingDeepLinkType == DeepLinkService.TYPE_SERVICE_POST) {
        initialRoute = Routes.servicePost;
        Routes.setInitialRouteArgs({'postId': pendingDeepLinkId});
        DebugLogger.log('Starting app with service post deep link: $pendingDeepLinkId', category: 'INIT');
      }
    }

    // Run the app
    runApp(
      MultiBlocProvider(
        providers: appBlocProviders,
        child: Builder(builder: (context) {
          // Auto-login if authenticated
          if (isAuthenticated && userId != null) {
            DebugLogger.log('Auto-logging in user: $userId', category: 'INIT');
            final token = prefs.getString('auth_token');
            BlocProvider.of<AuthenticationBloc>(context)
                .add(LoggedIn(token: token!));
          }

          // Initialize bloc caches for better performance
          _initializeBlocCaches(context);

          // Mark app as ready for deep links
          final navigationService = serviceLocator<NavigationService>();
          navigationService.setAppReady();

          return MyApp(
            authenticationRepository: repositories.authenticationRepository,
            isDarkTheme: isDarkTheme,
            navigatorKey: navigatorKey,
            autoAuthenticated: isAuthenticated,
            initialRoute: initialRoute,
          );
        }),
      ),
    );
  }
  // Initialize bloc caches
  static void _initializeBlocCaches(BuildContext context) {
    try {
      // Initialize service post cache
      final servicePostBloc = BlocProvider.of<ServicePostBloc>(context);
      servicePostBloc.add(const InitializeCachesEvent());

      // Initialize category/subcategory cache
      final subcategoryBloc = BlocProvider.of<SubcategoryBloc>(context);
      subcategoryBloc.add(InitializeSubcategoryCache());

      DebugLogger.log('Bloc caches initialized', category: 'INIT');
    } catch (e) {
      DebugLogger.log('Error initializing bloc caches: $e',
          category: 'INIT_ERROR');
    }
  }
}

// Application entry point
Future<void> main() async {
  await AppInitializer.initialize();
}

// Helper class for language changes
class AppWrapper extends StatelessWidget {
  final Widget child;

  const AppWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ThemeCubit(),
      child: LanguageChangeBuilder(
        builder: (context) => child,
      ),
    );
  }
}