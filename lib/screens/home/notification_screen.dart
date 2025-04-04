import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:talabna/blocs/notification/notifications_bloc.dart';
import 'package:talabna/blocs/notification/notifications_event.dart';
import 'package:talabna/blocs/notification/notifications_state.dart';
import 'package:talabna/data/models/notifications.dart';

// Import the shimmer widgets
import '../../blocs/service_post/service_post_bloc.dart';
import '../../blocs/service_post/service_post_event.dart';
import '../../blocs/service_post/service_post_state.dart';
import '../../data/models/service_post.dart';
import '../../data/models/user.dart';
import '../../main.dart';
import '../../provider/language.dart';
import '../../routes.dart';
import '../../services/service_post_deep_link_handler.dart';
import '../../utils/debug_logger.dart';
import '../../utils/premium_badge.dart';
import '../service_post/service_post_view.dart';
import '../widgets/shimmer_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.userID, required this.user});
  final User user;
  final int userID;

  @override
  NotificationsScreenState createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late talabnaNotificationBloc _talabnaNotificationBloc;
  late AnimationController _animationController;
  int _currentPage = 1;
  bool _hasReachedMax = false;
  List<Notifications> _notification = [];

  // Track read status separately to avoid modifying the immutable Notifications objects
  final Set<int> _locallyMarkedAsRead = {};
  final Language _language = Language();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _talabnaNotificationBloc =
        BlocProvider.of<talabnaNotificationBloc>(context);
    _talabnaNotificationBloc
        .add(FetchNotifications(page: _currentPage, userId: widget.userID));
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Initialize animation controller for item animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleNotificationTap(Notifications notification) {
    _handleNotificationMarkedAsRead(notification.id , showAlert: false);
    final int? postId = notification.extractPostId();
    if (postId != null) {
      DebugLogger.log(
          'Tapped notification with post ID: $postId',
          category: 'NOTIFICATION'
      );

      // Navigate directly to our simple post view
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NotificationPostView(
            postId: postId.toString(),
            userId: widget.userID, user: widget.user,
          ),
        ),
      );
    }
  }

  // Helper method to extract post ID from notification
  int? _extractPostIdFromNotification(Notifications notification) {
    try {
      // Get message text in preferred language
      String messageText = '';
      if (notification.message.containsKey(_language.getLanguage())) {
        messageText = notification.message[_language.getLanguage()]!;
      } else if (notification.message.containsKey('en')) {
        messageText = notification.message['en']!;
      } else if (notification.message.containsKey('ar')) {
        messageText = notification.message['ar']!;
      } else {
        return null;
      }

      // Use regular expression to find post ID pattern [post_id:123]
      final RegExp postIdRegex = RegExp(r'\[post_id:(\d+)\]');
      final match = postIdRegex.firstMatch(messageText);

      if (match != null && match.groupCount >= 1) {
        return int.parse(match.group(1)!);
      }

      return null;
    } catch (e) {
      DebugLogger.log(
          'Error extracting post ID from notification: $e',
          category: 'NOTIFICATION_ERROR'
      );
      return null;
    }
  }

// Helper to check if notification is related to a post
  bool _isPostNotification(Notifications notification) {
    return notification.type == 'post' ||
        notification.type == 'badge' ||
        _extractPostIdFromNotification(notification) != null;
  }
  void _onScroll() {
    if (!_hasReachedMax &&
        _scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      _currentPage++;
      _talabnaNotificationBloc
          .add(FetchNotifications(page: _currentPage, userId: widget.userID));
    }
  }

  Future<void> _handleRefresh() async {
    _currentPage = 1;
    _hasReachedMax = false;
    _notification.clear();
    _locallyMarkedAsRead
        .clear(); // Clear locally tracked read status on refresh
    _talabnaNotificationBloc
        .add(FetchNotifications(page: _currentPage, userId: widget.userID));
    return Future.delayed(const Duration(milliseconds: 500));
  }

  void _handleNotificationsLoadSuccess(
      List<Notifications> notifications, bool hasReachedMax) {
    setState(() {
      _isLoading = false;
      _hasReachedMax = hasReachedMax;
      _notification = [..._notification, ...notifications];
      // Reset animation to play for new items
      _animationController.reset();
      _animationController.forward();
    });
  }

  // Check if a notification is read (either from server or locally)
  bool _isNotificationRead(Notifications notification) {
    return notification.read || _locallyMarkedAsRead.contains(notification.id);
  }

  // Handle individual notification being marked as read
  bool _handleNotificationMarkedAsRead(int notificationId , {bool showAlert = true}) {
    // Update local tracking immediately for UI response
    setState(() {
      _locallyMarkedAsRead.add(notificationId);
    });

    // Send event to server in background
    _talabnaNotificationBloc.add(
      MarkNotificationAsRead(
        notificationId: notificationId,
        userId: widget.userID,
      ),
    );

    if(showAlert){
      // Show status update to user with a subtle snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Marked as read'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 1),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.05,
            left: 20,
            right: 20,
          ),
        ),
      );
    }
    else{

    }


    return true;
  }

  // Handle all notifications being marked as read
  void _handleAllNotificationsMarkedAsRead() {
    // Update local tracking for all notifications
    setState(() {
      for (var notification in _notification) {
        _locallyMarkedAsRead.add(notification.id);
      }
    });

    // Send the event to mark all as read on the server
    _talabnaNotificationBloc
        .add(MarkALlNotificationAsRead(userId: widget.userID));
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          _language.getNotificationText(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode
                  ? Colors.grey[800]!.withOpacity(0.5)
                  : Colors.grey[200]!.withOpacity(0.5),
            ),
            child: IconButton(
              onPressed: _handleAllNotificationsMarkedAsRead,
              icon: const Icon(Icons.mark_email_read_rounded),
              tooltip: 'Mark all as read',
            ),
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: _onWillPop,
        child: BlocListener<talabnaNotificationBloc, talabnaNotificationState>(
          bloc: _talabnaNotificationBloc,
          listener: (context, state) {
            if (state is NotificationLoaded) {
              _handleNotificationsLoadSuccess(
                  state.notifications, state.hasReachedMax);
            } else if (state is AllNotificationMarkedRead) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('All notifications marked as read'),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Colors.green.shade800,
                  duration: const Duration(seconds: 2),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.05,
                    left: 20,
                    right: 20,
                  ),
                ),
              );
            }
          },
          child: BlocBuilder<talabnaNotificationBloc, talabnaNotificationState>(
            bloc: _talabnaNotificationBloc,
            builder: (context, state) {
              if (state is NotificationLoading && _isLoading) {
                // Replace loading indicator with shimmer effect
                return const NotificationShimmerList();
              } else if (_notification.isNotEmpty) {
                // Show list of notifications with improved design
                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.cardColor,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    itemCount: _hasReachedMax
                        ? _notification.length
                        : _notification.length + 1,
                    itemBuilder: (context, index) {
                      if (index >= _notification.length) {
                        // Use shimmer for loading more items at the bottom
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }

                      // Calculate animation delay based on index
                      final animationDelay = index * 0.05;
                      final itemAnimation =
                          Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            animationDelay.clamp(0.0, 0.9),
                            (animationDelay + 0.1).clamp(0.0, 1.0),
                            curve: Curves.easeOut,
                          ),
                        ),
                      );

                      final notification = _notification[index];
                      final isRead = _isNotificationRead(notification);

                      // Wrap the Card with Dismissible for swipe actions
                      return FadeTransition(
                        opacity: itemAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.5, 0),
                            end: Offset.zero,
                          ).animate(itemAnimation),
                          child: Dismissible(
                            key: Key('notification_${notification.id}'),
                            // Allow swipe from both directions
                            direction: DismissDirection.horizontal,
                            // Background for right to left swipe (start to end)
                            background: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              decoration: BoxDecoration(
                                color: Colors.green.shade400,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            // Background for left to right swipe (end to start)
                            secondaryBackground: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.green.shade400,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            // Handle swipe confirmation - mark as read
                            confirmDismiss: (direction) async {
                              if (!isRead) {
                                _handleNotificationMarkedAsRead(
                                    notification.id);
                                // Don't actually dismiss the item
                                return false;
                              }
                              // If already read, show a different message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.info_outline,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 10),
                                      Text('Already marked as read'),
                                    ],
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: theme.colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  duration: const Duration(seconds: 1),
                                  margin: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).size.height *
                                        0.05,
                                    left: 20,
                                    right: 20,
                                  ),
                                ),
                              );
                              return false;
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              elevation: isRead ? 0 : 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: isRead
                                    ? BorderSide(
                                        color: Colors.grey.withOpacity(0.2),
                                        width: 1)
                                    : BorderSide.none,
                              ),
                              color: isRead
                                  ? (isDarkMode
                                      ? Colors.grey[850]
                                      : Colors.white)
                                  : (isDarkMode
                                      ? theme.cardColor.withOpacity(0.9)
                                      : theme.cardColor),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: notification
                                            .getIconColor()
                                            .withOpacity(0.15),
                                        child: Icon(
                                          notification.getIconData(),
                                          color: notification.getIconColor(),
                                          size: 26,
                                          semanticLabel: notification.type,
                                        ),
                                      ),
                                      if (!isRead)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: theme
                                                      .scaffoldBackgroundColor,
                                                  width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    notification.getMessage(language),
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: theme
                                                .textTheme.bodySmall?.color
                                                ?.withOpacity(0.7),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('yyyy-MM-dd | HH:mm')
                                                .format(notification.createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .textTheme.bodySmall?.color
                                                  ?.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: !isRead
                                      ? Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.grey[800]!.withOpacity(0.5)
                                          : Colors.grey[200]!.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: notification.isPostRelated()
                                          ? Icon(
                                        Icons.article_outlined,
                                        size: 18,
                                        color: theme.colorScheme.secondary,
                                      )
                                          : Icon(
                                        Icons.check,
                                        size: 18,
                                        color: theme.textTheme.bodyMedium?.color,
                                      ),
                                      onPressed: () => notification.isPostRelated()
                                          ? _handleNotificationTap(notification)
                                          : _handleNotificationMarkedAsRead(notification.id),
                                      tooltip: notification.isPostRelated()
                                          ? 'View post'
                                          : 'Mark as read',
                                      padding: EdgeInsets.zero,
                                    ),
                                  )
                                      : notification.isPostRelated()
                                      ? Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.grey[800]!.withOpacity(0.5)
                                          : Colors.grey[200]!.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.article_outlined,
                                        size: 18,
                                        color: theme.colorScheme.secondary,
                                      ),
                                      onPressed: () => _handleNotificationTap(notification),
                                      tooltip: 'View post',
                                      padding: EdgeInsets.zero,
                                    ),
                                  )
                                      : null,
                                  onTap: () => _handleNotificationTap(notification),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              } else if (state is NotificationError) {
                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: theme.colorScheme.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.red.shade900.withOpacity(0.2)
                                      : Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.error_outline,
                                  size: 60,
                                  color: Colors.red[400],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Oops! Something went wrong',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  state.message,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton.icon(
                                onPressed: _handleRefresh,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // Show shimmer for empty state while initial loading is happening
                return _isLoading
                    ? const NotificationShimmerList()
                    : RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: theme.colorScheme.primary,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(30),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? theme.colorScheme.primary
                                                .withOpacity(0.1)
                                            : theme.colorScheme.primary
                                                .withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.notifications_off_outlined,
                                        size: 70,
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    Text(
                                      'No Notifications Yet',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: theme.textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 40),
                                      child: Text(
                                        'You don\'t have any notifications at the moment. Check back later!',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: theme
                                              .textTheme.bodyMedium?.color
                                              ?.withOpacity(0.7),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    ElevatedButton.icon(
                                      onPressed: _handleRefresh,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Refresh'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
              }
            },
          ),
        ),
      ),
    );
  }
}

class NotificationPostView extends StatefulWidget {
  final String postId;
  final int userId;
  final User user;

  const NotificationPostView({
    Key? key,
    required this.postId,
    required this.userId,
    required this.user,

  }) : super(key: key);

  @override
  _NotificationPostViewState createState() => _NotificationPostViewState();
}

class _NotificationPostViewState extends State<NotificationPostView> {
  @override
  void initState() {
    super.initState();
    // Load the service post data
    DebugLogger.log(
        'NotificationPostView loading post ID: ${widget.postId}',
        category: 'NOTIFICATION'
    );

    context.read<ServicePostBloc>().add(
      GetServicePostByIdEvent(
        int.parse(widget.postId),
        forceRefresh: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back navigation - go back to notifications
        Navigator.of(context).pop();
        return false;
      },
      child: BlocBuilder<ServicePostBloc, ServicePostState>(
        builder: (context, state) {
          print('we have this state now : $state');
          // Success state with post data
          if (state is ServicePostLoadSuccess) {
            // Try to find the post
            ServicePost? post;
            try {
              post = state.servicePosts.firstWhere(
                    (p) => p.id == int.parse(widget.postId),
              );
            } catch (_) {
              // Post not found in state
              post = null;
            }

            // If post found, show post view
            if (post != null) {
              final user = User(
                id: widget.userId,
                name: '', // These fields will be populated by the view
                userName: '',
                email: '',
              );

              final isDarkMode = Theme.of(context).brightness == Brightness.dark;

              return Scaffold(
                appBar: AppBar(
                  elevation: 0,
                  backgroundColor: isDarkMode ? Colors.black : Colors.white,
                  scrolledUnderElevation: 1,
                  centerTitle: false,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.title ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Show premium badge if applicable
                      if (post.haveBadge != 'عادي')
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: PremiumBadge(
                            badgeType: post.haveBadge ?? 'عادي',
                            size: 22,
                            userID: widget.userId,
                          ),
                        ),
                    ],
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                body: ServicePostCardView(
                  userProfileId: widget.userId,
                  servicePost: post,
                  canViewProfile: true,
                  user: user,
                  onPostDeleted: () => Navigator.of(context).pop(),
                  noAppBar: true, // Ensure no duplicate app bar
                ),
              );
            }
          }
          else {
            if(state is ServicePostOperationFailure){
              print('this state from ServicePostOperationFailure $state');
              print('this state from ServicePostOperationFailure ${state.errorMessage}');
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Error'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                        },
                        child: const Text('Try Again'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            }else{
              print('this state from ServicePostOperationFailure $state');
            }
            return Scaffold(
              appBar: AppBar(
                title: const Text('loading'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                      },
                      child: const Text('Try Again'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          return SizedBox.shrink();

        },
      ),
    );
  }
}