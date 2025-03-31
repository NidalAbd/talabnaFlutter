import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/blocs/user_action/user_action_bloc.dart';
import 'package:talabna/blocs/user_action/user_action_event.dart';
import 'package:talabna/blocs/user_action/user_action_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/provider/language.dart';
import 'package:talabna/screens/profile/profile_check_builder.dart';
import 'package:talabna/screens/service_post/service_post_card.dart';
// Import the new filter widget

import '../../blocs/user_profile/user_profile_bloc.dart';
import '../../utils/service_post_fillter.dart';
import '../profile/profile_completion_service.dart';
import '../service_post/create_service_post_form.dart';

class SubCategoryPostScreen extends StatefulWidget {
  const SubCategoryPostScreen({
    super.key,
    required this.userID,
    required this.categoryId,
    required this.subcategoryId,
    required this.servicePostBloc,
    required this.userProfileBloc,
    required this.user,
    required this.titleSubcategory,
  });

  final int userID;
  final User user;
  final int categoryId;
  final int subcategoryId;
  final String titleSubcategory;
  final ServicePostBloc servicePostBloc;
  final UserProfileBloc userProfileBloc;

  @override
  SubCategoryPostScreenState createState() => SubCategoryPostScreenState();
}

class SubCategoryPostScreenState extends State<SubCategoryPostScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _currentPage = 1;
  bool _hasReachedMax = false;
  bool isFollowing = false;
  bool _isRefreshing = false;
  List<ServicePost> _posts = [];
  final _profileCompletionService = ProfileCompletionService();
  final language = Language();

  // Filter options
  FilterOptions _filterOptions = FilterOptions();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _loadInitialData();
    _animationController.forward();
  }

  Future<void> _handleAddPost(BuildContext context) async {
    context.performWithProfileCheck(
      action: () {
        _navigateToServicePost(context);
      },
      user: widget.user,
      userId: widget.userID,
    );
  }

  void _navigateToServicePost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServicePostFormScreen(
          userId: widget.userID,
          user: widget.user,
        ),
      ),
    ).then((_) => _handleRefresh()); // Refresh after returning from post creation
  }

  void _loadInitialData() {
    context
        .read<UserActionBloc>()
        .add(GetUserFollowSubcategories(subCategoryId: widget.subcategoryId));

    _loadFilteredPosts();
  }

  void _loadFilteredPosts() {
    // Get filter values
    final typeFilter = _filterOptions.typeFilter;
    final priceRange = _filterOptions.priceRangeFilter;

    // Request data with filters
    widget.servicePostBloc.add(
        GetServicePostsByCategorySubCategoryEvent(
          category: widget.categoryId,
          subCategory: widget.subcategoryId,
          page: _currentPage,
          typeFilter: typeFilter,
          minPrice: priceRange?.start,
          maxPrice: priceRange?.end,
        )
    );
  }

  void _onScroll() {
    if (!_hasReachedMax &&
        _scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange) {
      _currentPage++;
      _loadFilteredPosts();
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
      _currentPage = 1;
      _hasReachedMax = false;
      _posts.clear();
    });

    _loadInitialData();

    setState(() => _isRefreshing = false);
  }

  void _applyFilters(FilterOptions filterOptions) {
    setState(() {
      _filterOptions = filterOptions;
      _posts.clear();
      _currentPage = 1;
      _hasReachedMax = false;
      _loadFilteredPosts();
    });
  }

  Widget _buildFollowButton() {
    return BlocConsumer<UserActionBloc, UserActionState>(
      listener: (context, state) {
        if (state is UserMakeFollowSubcategoriesSuccess) {
          isFollowing = state.followSuccess;

          final message = state.followSuccess
              ? language.getFollowingText(widget.titleSubcategory)
              : language.getUnfollowedText(widget.titleSubcategory);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    state.followSuccess
                        ? Icons.check_circle
                        : Icons.info_outline,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(message),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: state.followSuccess
                  ? Colors.green.shade700
                  : Colors.blueGrey.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is GetFollowSubcategoriesSuccess) {
          isFollowing = state.followSuccess;
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        // Dark mode specific colors for better contrast
        final Color buttonColor = isFollowing
            ? (isDark
            ? theme.colorScheme.primary.withOpacity(0.3)
            : Colors.white.withOpacity(0.3))
            : (isDark
            ? theme.colorScheme.primary
            : Colors.white);

        final Color textColor = isFollowing
            ? (isDark
            ? theme.colorScheme.primary
            : Colors.white)
            : (isDark
            ? Colors.black
            : theme.colorScheme.primary);

        final Color borderColor = isDark
            ? theme.colorScheme.primary
            : Colors.white.withOpacity(0.5);

        // Icon color adjusted for both modes
        final Color iconColor = isFollowing
            ? (isDark
            ? theme.colorScheme.primary
            : Colors.white)
            : (isDark
            ? Colors.black
            : theme.colorScheme.primary);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: ElevatedButton(
            onPressed: () {
              context.performWithProfileCheck(
                action: () {
                  context.read<UserActionBloc>().add(
                      UserMakeFollowSubcategories(
                          subCategoryId: widget.subcategoryId));
                },
                user: widget.user,
                userId: widget.userID,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: textColor,
              elevation: isFollowing ? 0 : 2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isFollowing ? borderColor : Colors.transparent,
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFollowing ? Icons.check : Icons.add,
                  size: 18,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isFollowing
                      ? language.getFollowingButtonText()
                      : language.getFollowButtonText(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostCard(ServicePost post, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = language.getLanguage() == 'ar';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ClipRRect(
        child: ServicePostCard(
          key: ValueKey('post_${post.id}'),
          servicePost: post,
          onPostDeleted: (postId) {
            setState(() {
              _posts.removeWhere((p) => p.id == postId);
            });
          },
          canViewProfile: false,
          userProfileId: widget.userID,
          user: widget.user,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              language.getLoadingText() ?? "Loading...",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = language.getLanguage() == 'ar';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
                child: Icon(
                  _filterOptions.hasActiveFilters ? Icons.filter_alt_off : Icons.article_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _filterOptions.hasActiveFilters ?
                (isArabic ? 'لا توجد منشورات تطابق الفلترة' : 'No posts match the filter criteria') :
                language.getNoPostsText(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _filterOptions.hasActiveFilters ?
              Text(
                isArabic ? 'حاول إعادة ضبط المرشحات أو تغييرها' : 'Try resetting or changing the filters',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                ),
              ) :
              Text(
                language.getBeFirstToPostText(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              if (_filterOptions.hasActiveFilters)
                OutlinedButton.icon(
                  onPressed: () => _applyFilters(FilterOptions()),
                  icon: const Icon(Icons.filter_alt_off),
                  label: Text(isArabic ? 'إعادة ضبط الفلترة' : 'Reset Filters'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _handleAddPost(context),
                  icon: const Icon(Icons.add),
                  label: Text(language.getCreatePostText()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                language.tTryAgainText() ?? "There was a problem loading the content. Please try again.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _handleRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(language.getTryAgainText()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dark mode specific colors for better contrast
    final Color headerStartColor = isDark
        ? HSLColor.fromColor(theme.colorScheme.primary).withLightness(0.4).toColor()
        : theme.colorScheme.primary;

    final Color headerEndColor = isDark
        ? HSLColor.fromColor(theme.colorScheme.primary).withLightness(0.25).toColor()
        : HSLColor.fromColor(theme.colorScheme.primary).withLightness(0.4).toColor();

    // Decorative circle colors - more visible in dark mode
    final Color decorativeCircleColor = isDark
        ? theme.colorScheme.primary.withOpacity(0.2)
        : Colors.white.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            headerStartColor,
            headerEndColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: headerEndColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative elements
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: decorativeCircleColor,
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: decorativeCircleColor,
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.titleSubcategory,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              language.getNotificationFollowingText(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildFollowButton(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Divider - more visible in dark mode
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: isDark
                        ? theme.colorScheme.primary.withOpacity(0.5)
                        : Colors.white.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 20,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            language.getLatestPostsText(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.colorScheme.primary.withOpacity(0.3)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          language.getPostsCountText(_posts.length),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = language.getLanguage() == 'ar';

    return Scaffold(
      backgroundColor: isDark
          ? Color(0xFF121212) // Darker background for better contrast in dark mode
          : Color(0xFFF9FAFC), // Light gray background for better readability in light mode
      floatingActionButton: _posts.isNotEmpty ? FloatingActionButton(
        onPressed: () => _handleAddPost(context),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        child: const Icon(Icons.add),
      ) : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: true,
              elevation: innerBoxIsScrolled ? 4 : 0,
              shadowColor: Colors.black.withOpacity(0.1),
              backgroundColor: isDark
                  ? theme.appBarTheme.backgroundColor
                  : theme.colorScheme.background,
              title: Text(
                widget.titleSubcategory,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _handleRefresh,
                  tooltip: language.retryText(),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ];
        },
        body: BlocConsumer<ServicePostBloc, ServicePostState>(
          bloc: widget.servicePostBloc,
          listener: (context, state) {
            if (state is ServicePostLoadSuccess) {
              setState(() {
                if (_currentPage == 1) {
                  _posts = state.servicePosts;
                } else {
                  _posts = [..._posts, ...state.servicePosts];
                }
                _hasReachedMax = state.hasReachedMax;
              });
            }
          },
          builder: (context, state) {
            if (_posts.isEmpty && state is ServicePostLoading) {
              return _buildLoadingIndicator();
            }

            if (state is ServicePostLoadFailure) {
              return _buildErrorState(state.errorMessage);
            }

            if (_posts.isEmpty && !(state is ServicePostLoading)) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              color: theme.colorScheme.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildCategoryHeader(),
                  ),

                  // Filter bar
                  SliverToBoxAdapter(
                    child: ServicePostFilterBar(
                      posts: _posts,
                      filterOptions: _filterOptions,
                      onFilterChanged: _applyFilters,
                      initiallyExpanded: false,
                    ),
                  ),

                  // Posts list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        if (index >= _posts.length) {
                          return state is ServicePostLoading ? _buildLoadingIndicator() : SizedBox(height: 80);
                        }

                        return AnimatedOpacity(
                          opacity: _isRefreshing ? 0.5 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: _buildPostCard(_posts[index], index),
                        );
                      },
                      childCount: _posts.length + (_hasReachedMax ? 0 : 1),
                    ),
                  ),

                  // Add bottom padding
                  SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _posts.clear();
    super.dispose();
  }
}