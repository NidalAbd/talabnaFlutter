import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/core/service_locator.dart';
import 'package:talabna/routes.dart';
import 'package:talabna/screens/auth/welcome_screen.dart';
import 'package:talabna/screens/home/home_screen.dart';
import 'package:talabna/theme_cubit.dart';
import 'package:talabna/utils/constants.dart';
import 'package:talabna/utils/debug_logger.dart';

import 'blocs/authentication/authentication_bloc.dart';
import 'blocs/authentication/authentication_event.dart';
import 'blocs/authentication/authentication_state.dart';
import 'core/navigation_service.dart';
import 'data/repositories/authentication_repository.dart';
import 'screens/reel/reels_state_manager.dart';
import 'widgets/splash_transition.dart';

class MyApp extends StatefulWidget {
  final AuthenticationRepository authenticationRepository;
  final bool isDarkTheme;
  final GlobalKey<NavigatorState> navigatorKey;
  final bool autoAuthenticated;
  final String initialRoute;
  final Map<String, dynamic>? initialRouteArgs;
  const MyApp({
    super.key,
    required this.authenticationRepository,
    required this.isDarkTheme,
    required this.navigatorKey,
    this.autoAuthenticated = false,
    this.initialRoute = Routes.initial,
    this.initialRouteArgs,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // State tracking
  bool _isInitialized = false;
  Timer? _initTimer;
  bool _appReadyNotified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start initialization sequence
    _initializeApp();

    // Reset navigation state
    Routes.resetNavigationState();

    // Set initialization timeout
    _initTimer = Timer(Duration(seconds: 5), () {
      if (mounted && !_isInitialized) {
        setState(() => _isInitialized = true);
        DebugLogger.log('App initialization forced by timeout',
            category: 'APP');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      DebugLogger.log('App resumed from background', category: 'APP');

      // Force release any locks when app resumes
      ReelsStateManager().forceReleaseLocks();

      // Get navigation service
      final navigationService = serviceLocator<NavigationService>();
      navigationService.forceReleaseLocks();

      // Check for deep links when app resumes
      _notifyAppReady();
    }
  }

  // Initialize app
  Future<void> _initializeApp() async {
    try {
      // Simpler initialization with minimal delay - uses native splash screen instead
      await Future.delayed(Duration(milliseconds: 300));

      if (mounted) {
        setState(() => _isInitialized = true);
      }

      // Notify the navigation service that the app is ready
      _notifyAppReady();
    } catch (e) {
      DebugLogger.log('Error in app initialization: $e', category: 'APP');

      if (mounted) {
        setState(
                () => _isInitialized = true); // Initialize anyway to avoid stuck UI
      }
    }
  }

  // Notify that app is ready
  void _notifyAppReady() {
    if (_appReadyNotified) return;

    _appReadyNotified = true;

    // Mark app as ready for navigation
    final navigationService = serviceLocator<NavigationService>();
    navigationService.setAppReady();

    DebugLogger.log('App marked as ready', category: 'APP');
  }

  // Build screen based on authentication state
  Widget _buildScreenForState(BuildContext context, AuthenticationState state,
      SharedPreferences prefs) {
    final String? token = prefs.getString('auth_token');
    final int? userId = prefs.getInt('userId');

    // Handle authenticated state
    if (state is AuthenticationSuccess) {
      // Ensure app is marked ready for deep links when authentication succeeds
      _notifyAppReady();

      return AppLoadingTransition(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: HomeScreen(userId: state.userId!),
      );
    }

    // Check for existing token
    if (token != null && token.isNotEmpty && userId != null) {
      return FutureBuilder<bool>(
        future: widget.authenticationRepository.checkTokenValidity(token),
        builder: (context, validitySnapshot) {
          if (!validitySnapshot.hasData) {
            // Show nothing during check, maintaining splash screen
            return Container(color: Theme.of(context).scaffoldBackgroundColor);
          }

          if (validitySnapshot.data!) {
            if (state is! AuthenticationSuccess) {
              // Auto-login with valid token
              BlocProvider.of<AuthenticationBloc>(context)
                  .add(LoggedIn(token: token));

              // Set pre-authenticated user ID in navigation service
              final navigationService = serviceLocator<NavigationService>();
              navigationService.setPreAuthenticated(userId);
            }

            // Show nothing during authentication
            return Container(color: Theme.of(context).scaffoldBackgroundColor);
          }

          // Token invalid, show welcome screen
          return AppLoadingTransition(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            child: const WelcomeScreen(),
          );
        },
      );
    }

    // No authentication, show welcome
    return AppLoadingTransition(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: const WelcomeScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeData>(
      builder: (context, theme) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: Constants.appName,
            theme: theme,
            navigatorKey: widget.navigatorKey,
            onGenerateRoute: Routes.generateRoute,
            initialRoute: widget.initialRoute,
            // Remove the home property and onGenerateInitialRoutes
            // Instead, pass initial arguments through the standard route generator
            routes: {
              // Make sure we have a default route that handles initial arguments
              widget.initialRoute: (context) {
                if (!_isInitialized) {
                  // Show loading during initialization
                  return Container(color: theme.scaffoldBackgroundColor);
                }

                return FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Container(color: theme.scaffoldBackgroundColor);
                    }

                    final prefs = snapshot.data!;
                    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
                      listenWhen: (previous, current) => current is AuthenticationSuccess,
                      listener: (context, state) {
                        if (state is AuthenticationSuccess) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _notifyAppReady();
                            final navigationService = serviceLocator<NavigationService>();
                            Future.delayed(Duration(milliseconds: 500), () {
                              if (!navigationService.isProcessingDeepLink) {
                                navigationService.navigateToHome(context, state.userId!);
                              }
                            });
                          });
                        }
                      },
                      builder: (context, state) {
                        return _buildScreenForState(context, state, prefs);
                      },
                    );
                  },
                );
              },
            },
          ),
        );
      },
    );
  }}