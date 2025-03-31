import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/provider/language.dart';
import 'package:talabna/screens/service_post/service_post_card.dart';
import 'package:talabna/utils/debug_logger.dart';

import '../../utils/service_post_fillter.dart';
import '../widgets/shimmer_widgets.dart';

class ServicePostScreen extends StatefulWidget {
  final int category;
  final int userID;
  final bool showSubcategoryGridView;
  final ServicePostBloc servicePostBloc;
  final User user;
  final ScrollController? scrollController; // Add scroll controller parameter

  const ServicePostScreen({
    super.key,
    required this.category,
    required this.userID,
    required this.servicePostBloc,
    required this.showSubcategoryGridView,
    required this.user,
    this.scrollController, // Optional scroll controller
  });

  @override
  ServicePostScreenState createState() => ServicePostScreenState();
}

class ServicePostScreenState extends State<ServicePostScreen>
    with AutomaticKeepAliveClientMixin<ServicePostScreen> {
  @override
  bool get wantKeepAlive => true;

  late ScrollController _scrollController;

  // Pagination state
  int _currentPage = 1;
  bool _hasReachedMax = false;
  bool _isLoadingMore = false;

  // Track post IDs to prevent duplicates
  late Set<int> _loadedPostIds = {};

  // Content state
  List<ServicePost> _posts = [];
  bool _hasError = false;
  String _errorMessage = '';

  // Performance tracking
  final Stopwatch _loadStopwatch = Stopwatch();
  bool _isFirstLoad = true;
  bool _initialLoadComplete = false;

  // Prevent duplicate requests
  bool _isRefreshing = false;

  // Filter options
  FilterOptions _filterOptions = FilterOptions();

  // Language provider
  final language = Language();

  // Post deletion callback
  late Function onPostDeleted = (int postId) {
    if (mounted) {
      setState(() {
        _posts.removeWhere((post) => post.id == postId);
        _loadedPostIds.remove(postId);
      });
    }
  };

  @override
  void initState() {
    super.initState();

    // Use the provided scroll controller or create a new one
    _scrollController = widget.scrollController ?? ScrollController();

    _loadStopwatch.start();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void didUpdateWidget(ServicePostScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update scroll controller if it changed
    if (widget.scrollController != null &&
        widget.scrollController != _scrollController) {
      _scrollController.removeListener(_onScroll);
      _scrollController = widget.scrollController!;
      _scrollController.addListener(_onScroll);
    }

    // Reset state if category changes
    if (oldWidget.category != widget.category) {
      DebugLogger.log(
          'Category changed from ${oldWidget.category} to ${widget.category}, resetting state',
          category: 'SERVICE_POST_SCREEN');
      _resetState();
      _loadInitialData();
    }
    // If returning to same category with existing data, don't load again
    else if (_posts.isNotEmpty && _initialLoadComplete) {
      DebugLogger.log(
          'Returning to category ${widget.category} with existing data (${_posts.length} posts)',
          category: 'SERVICE_POST_SCREEN');

      if (_isLoadingMore || _isFirstLoad) {
        setState(() {
          _isLoadingMore = false;
          _isFirstLoad = false;
        });
      }
    }
    // If category is the same but we have no posts, try to load silently
    else if (_posts.isEmpty && !_isFirstLoad && !_isLoadingMore && !_isRefreshing) {
      _loadSilently();
    }
  }

  void _resetState() {
    if (mounted) {
      _currentPage = 1;
      _hasReachedMax = false;
      _isLoadingMore = false;
      _isRefreshing = false;
      _posts = []; // Don't use clear() to avoid UI flash
      _loadedPostIds.clear();
      _hasError = false;
      _errorMessage = '';
      _isFirstLoad = true;
      _initialLoadComplete = false;
      _filterOptions = FilterOptions(); // Reset filter options

      _loadStopwatch.reset();
      _loadStopwatch.start();
    }
  }

  void _loadInitialData() {
    DebugLogger.log(
        'Loading initial data for category ${widget.category}',
        category: 'SERVICE_POST_SCREEN');

    _loadFilteredPosts();
  }

  void _loadFilteredPosts() {
    // Get filter values
    final typeFilter = _filterOptions.typeFilter;
    final priceRange = _filterOptions.priceRangeFilter;

    widget.servicePostBloc.add(GetServicePostsByCategoryEvent(
      widget.category,
      _currentPage,
      forceRefresh: true,
      showLoadingState: _isFirstLoad || _posts.isEmpty,
      typeFilter: typeFilter,
      minPrice: priceRange?.start,
      maxPrice: priceRange?.end,
    ));
  }

  void _loadSilently() {
    DebugLogger.log(
        'Loading silently for category ${widget.category}',
        category: 'SERVICE_POST_SCREEN');

    _loadFilteredPosts();
  }

  void _applyFilters(FilterOptions filterOptions) {
    if (mounted) {
      setState(() {
        _filterOptions = filterOptions;
        _currentPage = 1;
        _hasReachedMax = false;
        _isLoadingMore = false;
        _posts = [];
        _loadedPostIds.clear();
        _isFirstLoad = true;
      });

      _loadFilteredPosts();
    }
  }

  void _onScroll() {
    // Skip if already loading or at the end
    if (_isLoadingMore || _hasReachedMax || _isRefreshing) {
      return;
    }

    // Preload when closer to the bottom (90% of the way there)
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // More aggressive loading trigger (90% instead of 70%)
    if (currentScroll >= maxScroll * 0.9) {
      if (mounted) {
        setState(() {
          _isLoadingMore = true;
        });
      }

      _currentPage++;

      DebugLogger.log(
          'Loading more posts for category ${widget.category}, page $_currentPage',
          category: 'SERVICE_POST_SCREEN');

      _loadFilteredPosts();
    }
  }

  Future<void> _handleRefresh() async {
    // Prevent duplicate refreshes
    if (_isRefreshing) return Future.value();

    _isRefreshing = true;

    DebugLogger.log(
        'Manual refresh for category ${widget.category}',
        category: 'SERVICE_POST_SCREEN');

    // Reset pagination
    _currentPage = 1;
    _hasReachedMax = false;
    _posts = [];
    _loadedPostIds.clear();

    // Trigger data load
    _loadFilteredPosts();

    // Complete the refresh after a reasonable delay
    return Future.delayed(const Duration(milliseconds: 800), () {
      _isRefreshing = false;
    });
  }

  void _handleLoadSuccess(List<ServicePost> servicePosts, bool hasReachedMax) {
    if (!mounted) return;

    if (_isFirstLoad) {
      _loadStopwatch.stop();
      _isFirstLoad = false;
      _initialLoadComplete = true;

      DebugLogger.log(
          'Initial load of ${servicePosts.length} posts for category ${widget.category} completed in ${_loadStopwatch.elapsedMilliseconds}ms',
          category: 'PERFORMANCE');
    }

    DebugLogger.log(
        'Handling success with ${servicePosts.length} posts on page $_currentPage, existing posts: ${_posts.length}',
        category: 'PAGINATION');

    // Handle first page (seamless replacement)
    if (_currentPage == 1) {
      // Create a new list with the updated posts
      final List<ServicePost> newPosts = List<ServicePost>.from(servicePosts);
      final Set<int> newPostIds = {};

      for (final post in servicePosts) {
        if (post.id != null) {
          newPostIds.add(post.id!);
        }
      }

      // Update state in one go to prevent flashing
      if (mounted) {
        setState(() {
          _posts = newPosts;
          _loadedPostIds = newPostIds;
          _hasReachedMax = hasReachedMax;
          _isLoadingMore = false;
          _isRefreshing = false;
          _hasError = false;
        });
      }

      DebugLogger.log(
          'Replaced posts list with ${servicePosts.length} posts for page 1',
          category: 'SERVICE_POST_SCREEN');
      return;
    }

    // Handle pagination (no UI update if no new posts)
    if (servicePosts.isEmpty) {
      if (mounted) {
        setState(() {
          _hasReachedMax = true;
          _isLoadingMore = false;
          _isRefreshing = false;
        });
      }
      return;
    }

    // Filter duplicates without creating intermediate collections
    final newPosts = <ServicePost>[];
    final newPostIds = <int>{};

    for (final post in servicePosts) {
      if (post.id != null && !_loadedPostIds.contains(post.id)) {
        newPosts.add(post);
        newPostIds.add(post.id!);
      }
    }

    // Only check if we've reached max if we got zero new posts
    // or if the explicit hasReachedMax flag is true
    final bool reachedMax = hasReachedMax || newPosts.isEmpty;

    if (newPosts.isNotEmpty) {
      if (mounted) {
        setState(() {
          // Add only the new posts
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPostIds);
          _hasReachedMax = reachedMax;
          _isLoadingMore = false;
          _isRefreshing = false;
        });
      }

      DebugLogger.log(
          'Added ${newPosts.length} new posts. Total: ${_posts.length}. HasReachedMax: $_hasReachedMax',
          category: 'SERVICE_POST_SCREEN');
    } else {
      if (mounted) {
        setState(() {
          _hasReachedMax = true;
          _isLoadingMore = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInToLinear,
      );

      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _loadStopwatch.stop();

    // Only dispose the controller if we created it
    if (widget.scrollController == null) {
      _scrollController.removeListener(_onScroll);
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }

    super.dispose();
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = language.getLanguage() == 'ar';

    return Center(
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
              (isArabic ? 'لا توجد منشورات' : 'No posts available'),
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
              isArabic ? 'لا توجد منشورات متاحة في هذه الفئة' : 'No posts available in this category',
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: BlocListener<ServicePostBloc, ServicePostState>(
        listenWhen: (previous, current) {
          if (current is ServicePostLoadSuccess) {
            return current.event.contains('GetServicePostsByCategoryEvent');
          }
          if (current is ServicePostLoadFailure) {
            return current.event.contains('GetServicePostsByCategoryEvent');
          }
          return false;
        },
        bloc: widget.servicePostBloc,
        listener: (context, state) {
          if (state is ServicePostLoadSuccess) {
            _handleLoadSuccess(state.servicePosts, state.hasReachedMax);
          } else if (state is ServicePostLoadFailure) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = state.errorMessage;
                _isLoadingMore = false;
                _isRefreshing = false;

                // If first page failed but we have existing posts, keep them
                if (_currentPage > 1 && _posts.isNotEmpty) {
                  _hasReachedMax = true;
                }
              });
            }
          }
        },
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    DebugLogger.log(
        'Building content - Posts: ${_posts.length}, HasError: $_hasError, IsFirstLoad: $_isFirstLoad, IsLoadingMore: $_isLoadingMore',
        category: 'SERVICE_POST_SCREEN');

    if (_posts.isNotEmpty) {
      return _buildPostsList();
    } else if (_isFirstLoad) {
      return const ServicePostScreenShimmer();
    } else if (_hasError) {
      return _buildErrorState();
    } else {
      return _buildEmptyState();
    }
  }

  Widget _buildPostsList() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Filter bar
          SliverToBoxAdapter(
            child: ServicePostFilterBar(
              posts: _posts,
              filterOptions: _filterOptions,
              onFilterChanged: _applyFilters,
              initiallyExpanded: false,
            ),
          ),

          // Posts list with animations
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                if (index >= _posts.length) {
                  return const SizedBox.shrink();
                }

                final post = _posts[index];

                // Determine if this is a newly loaded post for animation purposes
                final bool isNewlyLoaded = _isLoadingMore &&
                    index >= (_posts.length - 10) &&
                    _currentPage > 1;

                return AnimationConfiguration.staggeredList(
                  // Apply longer duration only for newly loaded items
                  duration: isNewlyLoaded
                      ? const Duration(milliseconds: 375)
                      : const Duration(milliseconds: 0),
                  position: index,
                  child: SlideAnimation(
                    verticalOffset: isNewlyLoaded ? 50.0 : 0.0,
                    child: FadeInAnimation(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: _buildPostCard(post),
                      ),
                    ),
                  ),
                );
              },
              childCount: _posts.length,
            ),
          ),

          // Loading indicator at the bottom for pagination
          SliverToBoxAdapter(
            child: Visibility(
              visible: _isLoadingMore,
              child: Container(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ),

          // End of list indicator
          SliverToBoxAdapter(
            child: Visibility(
              visible: _hasReachedMax && _posts.isNotEmpty,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    language.getLanguage() == 'ar' ? 'لقد وصلت إلى النهاية' : 'You\'ve reached the end',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(ServicePost post) {
    return ServicePostCard(
      key: ValueKey('post_${post.id}'),
      onPostDeleted: onPostDeleted,
      servicePost: post,
      canViewProfile: true,
      userProfileId: widget.userID,
      user: widget.user,
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _handleRefresh,
                  icon: const Icon(Icons.refresh, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage.contains('SocketException')
                      ? language.getLanguage() == 'ar'
                      ? 'لا يوجد اتصال بالإنترنت. اسحب لأسفل للتحديث.'
                      : 'No internet connection. Pull down to refresh.'
                      : language.getLanguage() == 'ar'
                      ? 'تعذر تحميل المنشورات. اسحب لأسفل للتحديث.'
                      : 'Could not load posts. Pull down to refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}