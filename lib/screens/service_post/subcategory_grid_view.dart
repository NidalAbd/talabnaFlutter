import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/blocs/category/subcategory_bloc.dart';
import 'package:talabna/blocs/category/subcategory_event.dart';
import 'package:talabna/blocs/category/subcategory_state.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_bloc.dart';
import 'package:talabna/data/models/categories_selected_menu.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/main.dart';
import 'package:talabna/screens/service_post/subcategory_post_screen.dart';
import 'package:talabna/utils/constants.dart';
import 'package:talabna/utils/debug_logger.dart';

import '../widgets/shimmer_widgets.dart';

class SubcategoryListView extends StatefulWidget {
  final int categoryId;
  final int userId;
  final User user;
  final ServicePostBloc servicePostBloc;
  final UserProfileBloc userProfileBloc;

  const SubcategoryListView({
    super.key,
    required this.categoryId,
    required this.userId,
    required this.servicePostBloc,
    required this.userProfileBloc,
    required this.user,
  });

  @override
  _SubcategoryListViewState createState() => _SubcategoryListViewState();
}

class _SubcategoryListViewState extends State<SubcategoryListView>
    with AutomaticKeepAliveClientMixin<SubcategoryListView> {
  @override
  bool get wantKeepAlive => true;

  late SubcategoryBloc _subcategoryBloc;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  // Performance tracking
  final Stopwatch _loadStopwatch = Stopwatch();

  // Cached subcategories
  List<SubCategoryMenu>? _cachedSubcategories;

  // Track if we've already requested subcategories
  bool _hasRequestedSubcategories = false;

  // Map to track which subcategory counts are being updated
  final Map<int, bool> _updatingCounts = {};

  @override
  void initState() {
    super.initState();

    // Start performance tracking
    _loadStopwatch.start();

    _subcategoryBloc = BlocProvider.of<SubcategoryBloc>(context);

    // Load subcategories if not already cached
    _loadSubcategories();
  }

  @override
  void didUpdateWidget(SubcategoryListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If category changed, load from fresh data
    if (oldWidget.categoryId != widget.categoryId) {
      _loadStopwatch.reset();
      _loadStopwatch.start();
      _hasRequestedSubcategories = false;
      _cachedSubcategories = null;
      _updatingCounts.clear();
      _loadSubcategories();

      // Reset the refresh controller
      _refreshController.resetNoData();
    }
  }

  void _loadSubcategories() {
    if (!_hasRequestedSubcategories) {
      _subcategoryBloc.add(FetchSubcategories(
        categoryId: widget.categoryId,
      ));
      _hasRequestedSubcategories = true;
    }
  }

  void _onRefresh() {
    DebugLogger.log(
        'Pull-to-refresh triggered for category ${widget.categoryId}',
        category: 'SUBCATEGORY_LIST');

    // Force a refresh without showing loading indicators
    _subcategoryBloc.add(FetchSubcategories(
      categoryId: widget.categoryId,
      showLoadingState: false,
      forceRefresh: true,
    ));
  }

  void _navigateToSubcategory(SubCategoryMenu subcategory) {
    // Check if subcategory is suspended before navigating
    if (!subcategory.isSuspended) {
      DebugLogger.log(
          'Navigating to subcategory ${subcategory.id} (${subcategory.name[language] ?? subcategory.name['en'] ?? 'Unknown'})',
          category: 'NAVIGATION');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SubCategoryPostScreen(
            userID: widget.userId,
            categoryId: subcategory.categoriesId,
            subcategoryId: subcategory.id,
            servicePostBloc: widget.servicePostBloc,
            userProfileBloc: widget.userProfileBloc,
            user: widget.user,
            titleSubcategory: subcategory.name[language] ??
                subcategory.name['en'] ??
                'Unknown',
          ),
        ),
      );
    } else {
      // Show a dialog or snackbar indicating the subcategory is suspended
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This subcategory is currently suspended',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.lightBackgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor;

    return BlocConsumer<SubcategoryBloc, SubcategoryState>(
      listener: (context, state) {
        if (state is SubcategoryLoaded) {
          _refreshController.refreshCompleted();

          // Set cached subcategories
          if (_cachedSubcategories == null) {
            _cachedSubcategories = state.subcategories;
          } else {
            // Just update the counts if subcategories already exist
            final Map<int, int> newCounts = {
              for (var item in state.subcategories)
                item.id: item.servicePostsCount
            };

            // Only trigger setState if any counts changed
            bool countsChanged = false;

            // Update the counts in the cached list
            for (int i = 0; i < _cachedSubcategories!.length; i++) {
              final item = _cachedSubcategories![i];
              if (newCounts.containsKey(item.id) &&
                  newCounts[item.id] != item.servicePostsCount) {
                _updatingCounts[item.id] = true;

                // Create a new item with updated count
                _cachedSubcategories![i] = SubCategoryMenu(
                  id: item.id,
                  name: item.name,
                  categoriesId: item.categoriesId,
                  createdAt: item.createdAt,
                  updatedAt: item.updatedAt,
                  servicePostsCount: newCounts[item.id]!,
                  photos: item.photos,
                  isSuspended: item.isSuspended,
                );

                countsChanged = true;

                // Schedule reset of updating flag
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) {
                    setState(() {
                      _updatingCounts[item.id] = false;
                    });
                  }
                });
              }
            }

            // Only setState if counts actually changed
            if (countsChanged) {
              setState(() {});
              DebugLogger.log('Updated counts for some subcategories',
                  category: 'SUBCATEGORY_LIST');
            }
          }

          _loadStopwatch.stop();
          DebugLogger.log(
              'Loaded ${state.subcategories.length} subcategories for category ${widget.categoryId} in ${_loadStopwatch.elapsedMilliseconds}ms',
              category: 'PERFORMANCE');
        } else if (state is SubcategoryError) {
          _refreshController.refreshFailed();
        }
      },
      builder: (context, state) {
        // Use cached subcategories if available
        if (_cachedSubcategories != null) {
          return SmartRefresher(
            enablePullDown: true,
            header: ClassicHeader(
              refreshStyle: RefreshStyle.Follow,
              idleText: "Pull to refresh",
              refreshingText: "Loading...",
              completeText: "Updated",
              failedText: "Refresh failed",
              releaseText: "Release to refresh",
              textStyle: TextStyle(color: textColor),
              completeIcon: Icon(Icons.done, color: primaryColor),
              failedIcon: Icon(Icons.error, color: Colors.red),
              iconPos: IconPosition.left,
            ),
            controller: _refreshController,
            onRefresh: _onRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _cachedSubcategories!.length,
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final subcategory = _cachedSubcategories![index];
                return _buildSubcategoryCard(
                  subcategory,
                  isDarkMode,
                  primaryColor,
                  backgroundColor,
                  textColor,
                  index,
                  _updatingCounts[subcategory.id] == true,
                );
              },
            ),
          );
        }

        // Show loading state
        if (state is SubcategoryLoading) {
          return const SubcategoryListViewShimmer();
        } else if (state is SubcategoryLoaded) {
          if (state.subcategories.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          return SmartRefresher(
            enablePullDown: true,
            header: ClassicHeader(
              refreshStyle: RefreshStyle.Follow,
              idleText: "Pull to refresh",
              refreshingText: "Loading...",
              completeText: "Updated",
              failedText: "Refresh failed",
              releaseText: "Release to refresh",
              textStyle: TextStyle(color: textColor),
              completeIcon: Icon(Icons.done, color: primaryColor),
              failedIcon: Icon(Icons.error, color: Colors.red),
              iconPos: IconPosition.left,
            ),
            controller: _refreshController,
            onRefresh: _onRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: state.subcategories.length,
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final subcategory = state.subcategories[index];
                return _buildSubcategoryCard(
                  subcategory,
                  isDarkMode,
                  primaryColor,
                  backgroundColor,
                  textColor,
                  index,
                  false,
                );
              },
            ),
          );
        } else if (state is SubcategoryError) {
          return _buildErrorState(state.message, isDarkMode, primaryColor);
        }

        return const SizedBox.shrink();
      },
    );
  }

  // Updated to show a transition when count is updating
  Widget _buildSubcategoryCard(
    SubCategoryMenu subcategory,
    bool isDarkMode,
    Color primaryColor,
    Color backgroundColor,
    Color textColor,
    int index,
    bool isUpdatingCount,
  ) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToSubcategory(subcategory),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF0C0C0C) : Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Opacity(
                  opacity: subcategory.isSuspended ? 0.5 : 1.0,
                  child: Row(children: [
                    Hero(
                      tag: 'subcategory_${subcategory.id}',
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: primaryColor.withOpacity(0.1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: subcategory.photos.isNotEmpty
                              ? Image.network(
                                  '${Constants.apiBaseUrl}/${subcategory.photos[0].src}',
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.image_not_supported_outlined,
                                      color: primaryColor.withOpacity(0.5),
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.category_outlined,
                                  color: primaryColor.withOpacity(0.5),
                                  size: 30,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subcategory.name[language] ??
                                subcategory.name['en'] ??
                                'Unknown',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor
                                      .withOpacity(isUpdatingCount ? 0.3 : 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Total: ${formatNumber(subcategory.servicePostsCount)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              if (subcategory.isSuspended) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Suspended',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: primaryColor
                          .withOpacity(subcategory.isSuspended ? 0.2 : 0.5),
                      size: 20,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ));
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            color: isDarkMode
                ? AppTheme.darkDisabledColor
                : AppTheme.lightDisabledColor,
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            "No subcategories available",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color:
                  isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try checking back later",
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? AppTheme.darkDisabledColor
                  : AppTheme.lightDisabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, bool isDarkMode, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppTheme.lightErrorColor,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color:
                  isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Reset the cached data and request again
              _cachedSubcategories = null;
              _hasRequestedSubcategories = false;
              _loadStopwatch.reset();
              _loadStopwatch.start();
              _loadSubcategories();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String formatNumber(int number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}
