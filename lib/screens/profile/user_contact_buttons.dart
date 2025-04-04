import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/user_contact/user_contact_bloc.dart';
import 'package:talabna/blocs/user_contact/user_contact_state.dart';
import 'package:talabna/screens/interaction_widget/email_button.dart';
import 'package:talabna/screens/interaction_widget/phone_button.dart';
import 'package:talabna/screens/interaction_widget/watsapp_button.dart';

class UserContactButtons extends StatefulWidget {
  final int userId;
  final ServicePostBloc servicePostBloc;
  final UserContactBloc userContactBloc;

  const UserContactButtons(
      {super.key,
      required this.userId,
      required this.servicePostBloc,
      required this.userContactBloc});

  @override
  State<UserContactButtons> createState() => _UserContactButtonsState();
}

class _UserContactButtonsState extends State<UserContactButtons> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder(
      bloc: widget.userContactBloc,
      builder: (context, state) {
        if (state is UserContactLoadSuccess) {
          final user = state.user;
          return Column(
            children: [
              EmailButton(
                email: user.email,
                width: 15,
              ),
              const SizedBox(height: 10),
              PhoneButtonWidget(
                phone: user.phones,
                width: 15,
              ),
              const SizedBox(height: 10),
              WhatsAppButtonWidget(
                  whatsAppNumber: user.watsNumber,
                  username: user.userName!,
                  width: 15),
            ],
          );
        } else {
          // Return a Visibility widget to make the row invisible while preserving its layout space
          return Container();
        }
      },
    );
  }
}
