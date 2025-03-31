import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/user_action/user_action_bloc.dart';
import 'package:talabna/blocs/user_action/user_action_event.dart';
import 'package:talabna/blocs/user_action/user_action_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/screens/profile/user_card.dart';
import 'package:talabna/screens/service_post/service_post_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.userID, required this.user});

  final int userID;
  final User user;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  late UserActionBloc _userActionBloc;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  int _currentPage = 1;
  bool _isSearching = false;
  bool _userHasReachedMax = false;
  bool _postHasReachedMax = false;

  List<User> users = <User>[];
  List<ServicePost> servicePosts = <ServicePost>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _userActionBloc = context.read<UserActionBloc>();
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final bool shouldLoadMore =
      _tabController.index == 0 ? !_userHasReachedMax : !_postHasReachedMax;

      if (shouldLoadMore) {
        _currentPage++;
        _userActionBloc
            .add(UserSearchAction(search: _searchQuery, page: _currentPage));
      }
    }
  }

  void _handleSearch(String query) {
    // Only search if query has 3 or more characters
    if (query.isEmpty || query.length < 3) {
      if (_isSearching) {
        setState(() {
          _isSearching = false;
          users.clear();
          servicePosts.clear();
        });
      }
      return;
    }

    setState(() {
      _searchQuery = query;
      _currentPage = 1;
      _isSearching = true;
      _userHasReachedMax = false;
      _postHasReachedMax = false;
      users.clear();
      servicePosts.clear();
    });

    _userActionBloc.add(UserSearchAction(search: query, page: 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.iconTheme.color,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Search',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            height: 56,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                if (!isDarkMode)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search users, posts, and more...',
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.primaryColor,
                  size: 26,
                ),
                suffixIcon: _isSearching
                    ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      users.clear();
                      servicePosts.clear();
                    });
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: _handleSearch,
              onChanged: (value) {
                // Will handle empty checks inside _handleSearch method
                _handleSearch(value);
              },
            ),
          ),
          Expanded(
            child: BlocConsumer<UserActionBloc, UserActionState>(
              listener: (context, state) {
                if (state is UserSearchActionResult) {
                  setState(() {
                    if (_currentPage == 1) {
                      users = List.from(state.users);
                      servicePosts = List.from(state.servicePosts);
                    } else {
                      users.addAll(state.users);
                      servicePosts.addAll(state.servicePosts);
                    }
                    _userHasReachedMax = state.usersHasReachedMax;
                    _postHasReachedMax = state.servicePostsHasReachedMax;
                  });
                } else if (state is UserActionFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(state.error),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: theme.colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(10),
                  ));
                }
              },
              builder: (context, state) {
                if (state is UserActionInProgress && _currentPage == 1) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: theme.primaryColor,
                    ),
                  );
                }

                if (!_isSearching) {
                  return _buildEmptySearchState(
                      theme,
                      Icons.search_rounded,
                      'Search for users or posts'
                  );
                }

                if (users.isEmpty && servicePosts.isEmpty) {
                  return _buildEmptySearchState(
                      theme,
                      Icons.search_off_rounded,
                      'No results found'
                  );
                }

                return Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode
                                ? Colors.black.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: isDarkMode
                            ? Colors.white
                            : theme.primaryColor,
                        unselectedLabelColor: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        indicatorColor: theme.primaryColor,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: theme.textTheme.titleMedium,
                        tabs: [
                          Tab(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_alt_rounded, size: 20),
                                  const SizedBox(width: 6),
                                  Text('Users (${users.length})'),
                                ],
                              ),
                            ),
                          ),
                          Tab(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.description_rounded, size: 20),
                                  const SizedBox(width: 6),
                                  Text('Posts (${servicePosts.length})'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUsersList(theme),
                          _buildPostsList(theme),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState(ThemeData theme, IconData icon, String message) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 72,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearching
                ? 'Try different keywords or refine your search'
                : 'Type in the search field to find users and posts',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: users.length + (_userHasReachedMax ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == users.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: theme.primaryColor,
              ),
            ),
          );
        }

        return UserCard(
          follower: users[index],
          userActionBloc: _userActionBloc,
          userId: widget.userID,
          user: widget.user,
        );
      },
    );
  }

  Widget _buildPostsList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: servicePosts.length + (_postHasReachedMax ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == servicePosts.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: theme.primaryColor,
              ),
            ),
          );
        }

        return ServicePostCard(
          onPostDeleted: (int postId) {
            setState(() {
              servicePosts.removeWhere((post) => post.id == postId);
            });
          },
          servicePost: servicePosts[index],
          canViewProfile: true,
          userProfileId: widget.userID,
          user: widget.user,
        );
      },
    );
  }
}