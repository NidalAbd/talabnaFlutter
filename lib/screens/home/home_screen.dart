import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/blocs/user_profile/user_profile_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_state.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/screens/home/home_screen_controller.dart';
import 'package:talabna/screens/home/home_screen_list_appBar_icon.dart';
import 'package:talabna/screens/service_post/main_post_menu.dart';
import 'package:talabna/widgets/reels_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.userId});

  final int userId;

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Controller that handles all the business logic
  late HomeScreenController _controller;

  // Auto-retry variables
  bool _isRetrying = false;
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the controller with the current context and widget
    _controller = HomeScreenController(
      context: context,
      widget: widget,
      state: this,
    );

    // Initialize everything through the controller
    _controller.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.onDidChangeDependencies();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.onDidUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.onAppLifecycleStateChange(state);
  }

  // Method to handle automatic retry logic
  void _handleAutomaticRetry() {
    if (!_isRetrying && _retryAttempts < _maxRetryAttempts) {
      setState(() {
        _isRetrying = true;
      });

      Future.delayed(_retryDelay, () {
        if (mounted) {
          _retryAttempts++;
          _controller.retryUserProfileLoad();
          setState(() {
            _isRetrying = false;
          });
        }
      });
    }
  }

  // Reset retry counter when successful load occurs
  void _resetRetryCounter() {
    _retryAttempts = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) return Container();

    // Let the controller update UI when needed
    _controller.onBuildStart();

    // Get theme colors from the AppTheme
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Theme colors
    final backgroundColor =
    isDarkMode ? AppTheme.darkPrimaryColor : Colors.white;
    final primaryColor =
    isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;
    final textColor =
    isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor;
    final iconColor =
    isDarkMode ? AppTheme.darkIconColor : AppTheme.lightIconColor;

    return BlocConsumer<UserProfileBloc, UserProfileState>(
      listener: (context, state) {
        _controller.onUserProfileStateChange(state);

        // Reset retry counter on success
        if (state is UserProfileLoadSuccess) {
          _resetRetryCounter();
        }

        // Trigger automatic retry on failure
        if (state is UserProfileLoadFailure) {
          _handleAutomaticRetry();
        }
      },
      builder: (context, state) {
        if (!mounted) return Container();

        // Use controller to determine which screen to show based on state
        if ((state is UserProfileLoadInProgress ||
            state is UserProfileInitial) &&
            _controller.categories.isEmpty) {
          return _buildLoadingScreen(backgroundColor, primaryColor);
        }

        if (state is UserProfileLoadFailure) {
          return _buildErrorScreen(state.error, backgroundColor, primaryColor);
        }

        if (state is UserProfileLoadSuccess) {
          final user = state.user;

          // Check if still loading categories
          if (_controller.isLoading && _controller.categories.isEmpty) {
            return _buildMainScreenWithLoading(
                user, backgroundColor, primaryColor, textColor);
          }

          return _buildMainScreen(
              user, backgroundColor, primaryColor, textColor, iconColor);
        }

        return _buildEmptyScreen(backgroundColor);
      },
    );
  }

  // UI Component Builders
  Widget _buildLoadingScreen(Color backgroundColor, Color primaryColor) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: CircularProgressIndicator(color: primaryColor),
      ),
    );
  }

  Widget _buildErrorScreen(
      String error, Color backgroundColor, Color primaryColor) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const SizedBox(height: 24),
            if (_isRetrying)
              Column(
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Retrying automatically... ($_retryAttempts/$_maxRetryAttempts)',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: () => _controller.retryUserProfileLoad(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retry Manually'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScreen(Color backgroundColor) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildMainScreenWithLoading(
      User user, Color backgroundColor, Color primaryColor, Color textColor) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen(User user, Color backgroundColor, Color primaryColor,
      Color textColor, Color iconColor) {
    if (!mounted) return Container();

    // If categories are still loading, show a loading UI
    if (_controller.isLoading) {
      return _buildMainScreenWithLoading(
          user, backgroundColor, primaryColor, textColor);
    }

    // Check if we have categories after loading
    if (_controller.categories.isEmpty) {
      return _buildEmptyCategoriesScreen(
          user, backgroundColor, primaryColor, textColor, iconColor);
    }

    return FadeTransition(
      opacity: _controller.fadeAnimation,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(user, backgroundColor, primaryColor, textColor),
        body: _buildBody(user, backgroundColor),
        bottomNavigationBar: _buildBottomNavBar(
            user, backgroundColor, primaryColor, textColor, iconColor),
      ),
    );
  }

  Widget _buildEmptyCategoriesScreen(User user, Color backgroundColor,
      Color primaryColor, Color textColor, Color iconColor) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(user, backgroundColor, primaryColor, textColor),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 60, color: iconColor),
            const SizedBox(height: 16),
            Text(
              'No categories available',
              style: TextStyle(fontSize: 18, color: textColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _controller.refreshCategories(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      User user, Color backgroundColor, Color primaryColor, Color textColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final fontFamily = GoogleFonts.poppins().fontFamily;

    // Use consistent accent color for logo
    final accentColor =
    isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightSecondaryColor;

    return AppBar(
      elevation: 0,
      backgroundColor: backgroundColor,
      centerTitle: false,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 0, 0),
        child: Row(
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Talabna',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Poppins',
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // IconButton(
        //   icon: const Icon(Icons.bug_report),
        //   tooltip: 'Print Debug Logs',
        //   onPressed: () => _controller.printDebugLogs(),
        // ),
        VertIconAppBar(
          userId: widget.userId,
          user: user,
          showSubcategoryGridView: _controller.showSubcategoryGridView,
          toggleSubcategoryGridView: _controller.toggleSubcategoryGridView,
        ),
      ],
    );
  }

  Widget _buildBody(User user, Color backgroundColor) {
    if (!mounted) return Container();

    if (_controller.selectedCategory == 7) {
      return Container();
    }

    return Container(
      decoration: BoxDecoration(color: backgroundColor),
      child: MainMenuPostScreen(
        key: ValueKey(_controller.selectedCategory),
        category: _controller.selectedCategory,
        userID: widget.userId,
        servicePostBloc: _controller.servicePostBloc,
        showSubcategoryGridView: _controller.showSubcategoryGridView,
        user: user,
      ),
    );
  }

  Widget _buildBottomNavBar(User user, Color backgroundColor,
      Color primaryColor, Color textColor, Color iconColor) {
    if (!mounted) return Container();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.06),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _controller.categories.map((category) {
                  if (category.id == 7) {
                    return const SizedBox(width: 50);
                  }

                  bool isSelected = _controller.selectedCategory == category.id;
                  return _buildNavItem(
                    category: category,
                    isSelected: isSelected,
                    user: user,
                    primaryColor: primaryColor,
                    iconColor: iconColor,
                    textColor: textColor,
                  );
                }).toList(),
              ),
            ),
            if (_controller.hasReelsCategory)
              Positioned(
                top: 5,
                child: ReelsButton(
                  reelsCategory: _controller.getReelsCategory()!,
                  user: user,
                  primaryColor: primaryColor,
                  onTap: () => _controller.onCategorySelected(7, context, user),
                ),
              ),
            if (_controller.hasReelsCategory)
              Positioned(
                bottom: 8,
                child: _buildReelsLabel(
                  reelsCategory: _controller.getReelsCategory()!,
                  primaryColor: primaryColor,
                  textColor: textColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required category,
    required bool isSelected,
    required User user,
    required Color primaryColor,
    required Color iconColor,
    required Color textColor,
  }) {
    if (!mounted) return Container();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _controller.onCategorySelected(category.id, context, user),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            decoration: isSelected
                ? BoxDecoration(
              color: primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            )
                : null,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            child: Icon(
              _controller.getCategoryIcon(category.id),
              size: 25,
              color: isSelected ? primaryColor : iconColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _controller.getCategoryName(category),
            style: TextStyle(
              color: isSelected ? primaryColor : textColor,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildReelsLabel({
    required reelsCategory,
    required Color primaryColor,
    required Color textColor,
  }) {
    if (!mounted) return Container();

    return AnimatedOpacity(
      opacity: _controller.selectedCategory == 7 ? 1.0 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Text(
        _controller.getCategoryName(reelsCategory),
        style: TextStyle(
          color: _controller.selectedCategory == 7 ? primaryColor : textColor,
          fontSize: 12,
          fontWeight: _controller.selectedCategory == 7
              ? FontWeight.w600
              : FontWeight.normal,
          fontFamily: GoogleFonts.poppins().fontFamily,
        ),
      ),
    );
  }
}