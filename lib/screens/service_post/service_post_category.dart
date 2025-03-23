import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/screens/service_post/service_post_card.dart';
import 'package:talabna/utils/debug_logger.dart';

import '../widgets/shimmer_widgets.dart';

class ServicePostScreen extends StatefulWidget {
  final int category;
  final int userID;
  final bool showSubcategoryGridView;
  final ServicePostBloc servicePostBloc;
  final User user;

  const ServicePostScreen({
    super.key,
    required this.category,
    required this.userID,
    required this.servicePostBloc,
    required this.showSubcategoryGridView,
    required this.user,
  });

  @override
  ServicePostScreenState createState() => ServicePostScreenState();
}

class ServicePostScreenState extends State<ServicePostScreen>
    with AutomaticKeepAliveClientMixin<ServicePostScreen> {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();

  // Pagination state
  int _currentPage = 1;
  bool _hasReachedMax = false;
  bool _isLoadingMore = false;

  // Track post IDs to prevent duplicates
  late  Set<int> _loadedPostIds = {};

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
    _loadStopwatch.start();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void didUpdateWidget(ServicePostScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

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
      _posts = [];  // Don't use clear() to avoid UI flash
      _loadedPostIds.clear();
      _hasError = false;
      _errorMessage = '';
      _isFirstLoad = true;
      _initialLoadComplete = false;

      _loadStopwatch.reset();
      _loadStopwatch.start();
    }
  }

  void _loadInitialData() {
    DebugLogger.log(
        'Loading initial data for category ${widget.category}',
        category: 'SERVICE_POST_SCREEN');

    widget.servicePostBloc.add(GetServicePostsByCategoryEvent(
      widget.category,
      1, // Always start with page 1 for initial load
      forceRefresh: true,
      showLoadingState: true,
    ));
  }

  void _loadSilently() {
    DebugLogger.log(
        'Loading silently for category ${widget.category}',
        category: 'SERVICE_POST_SCREEN');

    widget.servicePostBloc.add(GetServicePostsByCategoryEvent(
      widget.category,
      1,
      forceRefresh: true,
      showLoadingState: false,
    ));
  }

  void _onScroll() {
    // Skip if already loading or at the end
    if (_isLoadingMore || _hasReachedMax || _isRefreshing) {
      return;
    }

    // Preload when approaching the bottom (70% of the way there)
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll * 0.7) {
      if (mounted) {
        setState(() {
          _isLoadingMore = true;
        });
      }

      _currentPage++;

      DebugLogger.log(
          'Loading more posts for category ${widget.category}, page $_currentPage',
          category: 'SERVICE_POST_SCREEN');

      widget.servicePostBloc.add(GetServicePostsByCategoryEvent(
        widget.category,
        _currentPage,
        forceRefresh: true,
        showLoadingState: false,
      ));
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

    // Trigger data load without clearing existing posts yet
    // This prevents the screen from flickering during refresh
    widget.servicePostBloc.add(GetServicePostsByCategoryEvent(
      widget.category,
      _currentPage,
      forceRefresh: true,
      showLoadingState: false,
    ));

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

    if (newPosts.isNotEmpty) {
      if (mounted) {
        setState(() {
          // Add only the new posts
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPostIds);
          _hasReachedMax = hasReachedMax || newPosts.length < servicePosts.length;
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
      return const ServicePostScreenShimmer();
    }
  }

  Widget _buildPostsList() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _hasReachedMax ? _posts.length : _posts.length + 1,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          // Loading indicator at the end
          if (index >= _posts.length) {
            return Visibility(
              visible: _isLoadingMore,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
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
            );
          }

          final post = _posts[index];

          // Only animate new items at the end (not the entire list)
          final isNewlyLoadedItem = _isLoadingMore &&
              index >= (_posts.length - 10) &&
              _currentPage > 1;

          if (isNewlyLoadedItem) {
            final delay = index % 5 * 20;
            return FadeTransition(
              opacity: AlwaysStoppedAnimation(1.0), // No fade animation - prevents blinking
              child: _buildPostCard(post),
            );
          }

          // Regular posts without animation
          return _buildPostCard(post);
        },
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
                      ? 'No internet connection. Pull down to refresh.'
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