import 'package:flutter/material.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/blocs/user_profile/user_profile_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_event.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/screens/interaction_widget/email_icon_button.dart';
import 'package:talabna/screens/interaction_widget/location_Icon_button.dart';
import 'package:talabna/screens/interaction_widget/phone_Icon_button.dart';
import 'package:talabna/screens/interaction_widget/report_tile.dart';
import 'package:talabna/screens/interaction_widget/watsapp_icon_button.dart';

class ContactModalBottomSheet extends StatefulWidget {
  final double iconSize;
  final int userId;
  final UserProfileBloc userProfileBloc;
  final ServicePost servicePost;

  const ContactModalBottomSheet({
    super.key,
    required this.iconSize,
    required this.userId,
    required this.userProfileBloc,
    required this.servicePost,
  });

  @override
  State<ContactModalBottomSheet> createState() =>
      _ContactModalBottomSheetState();
}

class _ContactModalBottomSheetState extends State<ContactModalBottomSheet> {
  @override
  void initState() {
    super.initState();
    widget.userProfileBloc.add(UserProfileRequested(id: widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            return Container(
              height: MediaQuery.of(context).size.height *
                  2 /
                  8, // Set the height to 2/3 of the screen height
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkBackgroundColor
                  : AppTheme.lightBackgroundColor,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header
                  const Text(
                    'Contact Me',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 5,
                      // Number of columns you want in the grid
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Center(
                              child: IconButton(
                                onPressed: () {
                                  Navigator.pop(context);

                                  showModalBottomSheet(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return ReportTile(
                                        type: 'service_post',
                                        userId: widget.servicePost.id!,
                                      );
                                    },
                                  );
                                },
                                icon: Icon(
                                  Icons.flag,
                                  size: 30,
                                ),
                              ),
                            ),
                            const Text('Report',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Center(
                              child: EmailIconButton(
                                email: widget.servicePost.email!,
                                width: 50,
                                onDismiss: () => Navigator.pop(context),
                              ),
                            ),
                            const Text('Email', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Center(
                              child: WhatsAppIconButtonWidget(
                                width: 30,
                                whatsAppNumber: widget.servicePost.watsNumber,
                                onDismiss: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            const Text('Chat',
                                style: TextStyle(
                                  fontSize: 14,
                                )),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Center(
                              child: PhoneIconButtonWidget(
                                width: 50,
                                phone: widget.servicePost.phones,
                                onDismiss: () => Navigator.pop(context),
                              ),
                            ),
                            const Text('Call', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LocationIconButtonWidget(
                              locationLatitudes:
                                  widget.servicePost.locationLatitudes!,
                              locationLongitudes:
                                  widget.servicePost.locationLongitudes!,
                              onDismiss: () => Navigator.pop(context),
                              width: 50,
                            ),
                            Text(widget.servicePost.distance.toString(),
                                style: const TextStyle(fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      icon: Icon(
        Icons.contacts,
        size: widget.iconSize,
        color: Colors.white,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(1), // Shadow color
            offset: const Offset(0, 0),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
