import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/notification/notifications_bloc.dart';
import 'package:talabna/blocs/notification/notifications_event.dart';
import 'package:talabna/blocs/notification/notifications_state.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/data/models/user.dart';

import 'notification_screen.dart';

class NotificationsAlert extends StatefulWidget {
  const NotificationsAlert({super.key, required this.userID, required this.user});
  final User user;
  final int userID;

  @override
  State<NotificationsAlert> createState() => _NotificationsAlertState();
}

class _NotificationsAlertState extends State<NotificationsAlert> with SingleTickerProviderStateMixin {
  late talabnaNotificationBloc _talabnaNotificationBloc;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Color?> _colorAnimation;

  bool _hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    _talabnaNotificationBloc = BlocProvider.of<talabnaNotificationBloc>(context);
    _talabnaNotificationBloc.add(CountNotificationEvent(userId: widget.userID));

    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Scale animation: Bell pulsing effect
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Rotation animation: Bell shaking effect
    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.15),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.15, end: -0.15),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.0),
        weight: 20,
      ),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // We'll initialize the color animation in didChangeDependencies
    // to avoid accessing Theme during initState

    // Start repeat animation if there are notifications
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Add delay before repeating animation
        Future.delayed(const Duration(seconds: 1), () {
          if (_hasUnreadNotifications && mounted) {
            _animationController.reset();
            _animationController.forward();
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize color animation here since we can safely access Theme now
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;

    _colorAnimation = ColorTween(
      begin: Colors.red,
      end: primaryColor, // Use your app's theme color as end color
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<talabnaNotificationBloc, talabnaNotificationState>(
      bloc: _talabnaNotificationBloc,
      builder: (context, state) {
        int countNotifications = 0;

        if (state is CountNotificationState) {
          countNotifications = state.countNotification;
          _hasUnreadNotifications = countNotifications > 0;

          // Start animation if there are unread notifications
          if (_hasUnreadNotifications && !_animationController.isAnimating) {
            _animationController.reset();
            _animationController.forward();
          }
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NotificationsScreen(userID: widget.userID, user: widget.user,),
                  ),
                );
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Transform.scale(
                    scale: _hasUnreadNotifications ? _scaleAnimation.value : 1.0,
                    child: Transform.rotate(
                      angle: _hasUnreadNotifications ? _rotateAnimation.value : 0.0,
                      child: const Icon(Icons.notifications),
                    ),
                  ),
                  if (_hasUnreadNotifications)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.elasticOut,
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _colorAnimation.value,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_colorAnimation.value ?? Colors.red).withOpacity(0.5),
                                    blurRadius: 4.0,
                                    spreadRadius: 1.0,
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                countNotifications.toString(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}