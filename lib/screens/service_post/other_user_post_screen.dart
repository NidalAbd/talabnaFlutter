import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/screens/service_post/service_post_card.dart';

class OtherUserPostScreen extends StatefulWidget {
  const OtherUserPostScreen({
    super.key,
    required this.userID,
    required this.user,
    this.primary = true,
  });

  final int userID;
  final User user;
  final bool primary;

  @override
  OtherUserPostScreenState createState() => OtherUserPostScreenState();
}

class OtherUserPostScreenState extends State<OtherUserPostScreen> {
  ScrollController? _scrollUserController;
  late ServicePostBloc _servicePostBloc;
  int _currentPage = 1;
  bool _hasReachedMax = false;
  List<ServicePost> _servicePostsUser = [];
  late Function onPostDeleted = (int postId) {
    setState(() {
      _servicePostsUser.removeWhere((post) => post.id == postId);
    });
  };

  @override
  void initState() {
    super.initState();

    // Only create a controller if primary is false
    if (!widget.primary) {
      _scrollUserController = ScrollController();
      _scrollUserController!.addListener(_onScrollUserPost);
    }

    _servicePostBloc = BlocProvider.of<ServicePostBloc>(context);
    _servicePostBloc.add(GetServicePostsByUserIdEvent(
        userId: widget.userID, page: _currentPage));
  }

  void _onScrollUserPost() {
    if (!_hasReachedMax &&
        _scrollUserController != null &&
        _scrollUserController!.hasClients &&
        _scrollUserController!.offset >=
            _scrollUserController!.position.maxScrollExtent - 200 &&
        !_scrollUserController!.position.outOfRange) {
      _currentPage++;
      _servicePostBloc.add(GetServicePostsByUserIdEvent(
          userId: widget.userID, page: _currentPage));
    }
  }

  Future<void> _handleUserPostRefresh() async {
    _currentPage = 1;
    _hasReachedMax = false;
    _servicePostsUser.clear();
    _servicePostBloc.add(GetServicePostsByUserIdEvent(
        userId: widget.userID, page: _currentPage));
    return Future.value();
  }

  void _handleUserPostLoadSuccess(
      List<ServicePost> servicePosts, bool hasReachedMax) {
    setState(() {
      _hasReachedMax = hasReachedMax;
      _servicePostsUser = [..._servicePostsUser, ...servicePosts];
    });
  }

  Future<bool> _onWillPopUserPost() async {
    if (_scrollUserController != null &&
        _scrollUserController!.hasClients &&
        _scrollUserController!.offset > 0) {
      _scrollUserController!.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInToLinear,
      );
      // Wait for the duration of the scrolling animation before refreshing
      await Future.delayed(const Duration(milliseconds: 1000));
      // Trigger a refresh after reaching the top
      _handleUserPostRefresh();
      return false;
    } else {
      return true;
    }
  }

  @override
  void dispose() {
    if (_scrollUserController != null) {
      _scrollUserController!.removeListener(_onScrollUserPost);
      _scrollUserController!.dispose();
    }
    _servicePostsUser.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPopUserPost,
      child: Scaffold(
        body: BlocListener<ServicePostBloc, ServicePostState>(
          bloc: _servicePostBloc,
          listener: (context, state) {
            if (state is ServicePostLoadSuccess) {
              _handleUserPostLoadSuccess(state.servicePosts, state.hasReachedMax);
            }
          },
          child: BlocBuilder<ServicePostBloc, ServicePostState>(
            bloc: _servicePostBloc,
            builder: (context, state) {
              if (state is ServicePostLoading && _servicePostsUser.isEmpty) {
                // show loading indicator
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } else if (_servicePostsUser.isNotEmpty) {
                // show list of service posts
                return RefreshIndicator(
                    onRefresh: _handleUserPostRefresh,
                    child: ListView.builder(
                      // Here is the key fix: Only set either primary OR controller, not both
                      primary: widget.primary,
                      controller: widget.primary ? null : _scrollUserController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _hasReachedMax
                          ? _servicePostsUser.length
                          : _servicePostsUser.length + 1,
                      itemBuilder: (context, index) {
                        if (index >= _servicePostsUser.length) {
                          return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: CircularProgressIndicator(),
                              )
                          );
                        }
                        final servicePost = _servicePostsUser[index];
                        return AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                          child: ServicePostCard(
                            key: Key('servicePost_${servicePost.id}'),
                            onPostDeleted: onPostDeleted,
                            userProfileId: widget.userID,
                            servicePost: servicePost,
                            canViewProfile: false,
                            user: widget.user,
                          ),
                        );
                      },
                    )
                );
              } else if (state is ServicePostLoadFailure) {
                return Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _handleUserPostRefresh,
                        icon: const Icon(Icons.refresh),
                      ),
                      const Text('Some error happened, press refresh button'),
                    ],
                  ),
                );
              } else {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.post_add,
                        size: 80,
                        color: Theme.of(context).disabledColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No service posts found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This user hasn\'t created any posts yet.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
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