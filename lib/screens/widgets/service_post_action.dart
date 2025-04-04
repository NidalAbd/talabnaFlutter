import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/screens/interaction_widget/report_tile.dart';
import 'package:talabna/screens/service_post/change_badge.dart';
import 'package:talabna/screens/service_post/change_category_subcategory.dart';
import 'package:talabna/screens/service_post/update_service_post_form.dart';

import '../../data/models/user.dart';
import '../../provider/language.dart';

class ServicePostAction extends StatefulWidget {
  const ServicePostAction({
    super.key,
    required this.servicePostUserId,
    this.userProfileId,
    this.servicePostId,
    required this.onPostDeleted,
    required this.servicePost,
    required this.user,
  });

  final ServicePost servicePost;
  final User user;
  final int? servicePostUserId;
  final int? servicePostId;
  final int? userProfileId;
  final Function onPostDeleted;

  @override
  State<ServicePostAction> createState() => _ServicePostActionState();
}

class _ServicePostActionState extends State<ServicePostAction>
    with SingleTickerProviderStateMixin {
  late int? currentUserId;
  late bool isOwnPost = false;
  final Language language = Language();

  @override
  void initState() {
    super.initState();
    initializeUserId();
  }

  void initializeUserId() {
    getUserId().then((userId) {
      setState(() {
        currentUserId = userId;
        if (currentUserId == widget.servicePostUserId) {
          isOwnPost = true;
        } else {
          isOwnPost = false;
        }
      });
    });
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  void _deletePost(BuildContext context) async {
    BlocProvider.of<ServicePostBloc>(context)
        .add(DeleteServicePostEvent(servicePostId: widget.servicePostId!));
    Navigator.pop(context); // Navigate back after dispatching the event
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ServicePostBloc, ServicePostState>(
      listenWhen: (previous, current) {
        return current is ServicePostDeletingSuccess &&
            current.servicePostId == widget.servicePostId;
      },
      listener: (context, state) {
        if (state is ServicePostDeletingSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service Post Operation Success'),
            ),
          );
          setState(() {});
          widget.onPostDeleted(state.servicePostId);
          Navigator.pop(context); // Navigate back to the previous screen
        } else if (state is ServicePostOperationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Service Post Operation Error: ${state.errorMessage}'),
            ),
          );
        }
      },
      child: BlocBuilder<ServicePostBloc, ServicePostState>(
          builder: (context, state) {
        return IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (BuildContext context) {
                return Wrap(
                  children: [
                    Visibility(
                      visible: isOwnPost,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title:  Text(language.tEditText(),),
                            onTap: () {
                              Navigator.pop(
                                  context); // Dismiss the bottom sheet
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => UpdatePostScreen(
                                    userId: currentUserId!,
                                    servicePostId: widget.servicePostId!,
                                    servicePost: widget.servicePost,
                                    user: widget.user,
                                  ),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.category),
                            title:  Text(language.tChangeCategoryText(),),
                            onTap: () {
                              Navigator.pop(
                                  context); // Dismiss the bottom sheet
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) => ChangeCategoryScreen(
                                          userId: currentUserId!,
                                          servicePostId: widget.servicePostId!,
                                          category: widget.servicePost.category,
                                          subCategory:
                                              widget.servicePost.subCategory,
                                        )),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.star),
                            title:  Text(language.tChangeBadgeText(),),
                            onTap: () {
                              Navigator.pop(
                                  context); // Dismiss the bottom sheet
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ChangeBadge(
                                    userId: currentUserId!,
                                    servicePostId: widget.servicePostId!,
                                    haveBadge: widget.servicePost.haveBadge,
                                    badgeDuration:
                                        widget.servicePost.badgeDuration,
                                  ),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title:  Text(language.tDeleteText(),),
                            onTap: () async {
                              bool? result = await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error),
                                      const SizedBox(width: 8),
                                      Text(
                                          language.tDeleteText(),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    language.getDeleteConfirmationText(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text(
                                        language.cancel(),
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deletePost(
                                            context); // Call the _deletePost method
                                      },
                                      child:  Text(
                                        language.tDeleteText(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                        leading: const Icon(
                          Icons.report,
                        ),
                        title:  Text(   language.tReportText(),),
                        onTap: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                              context: context,
                              builder: (BuildContext context) {
                                return ReportTile(
                                  type: 'service_post',
                                  userId: widget.servicePostId!,
                                );
                              });
                        })
                  ],
                );
              },
            );
          },
        );
      }),
    );
  }
}
