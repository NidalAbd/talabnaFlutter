import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneButtonWidget extends StatelessWidget {
  final String? phone;
  final double width;

  const PhoneButtonWidget({super.key, this.phone, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(16), // Adjust the radius as per your requirement
            ),
          ),
        ),
        onPressed: () async {
          if (phone != null) {
            final Uri phoneLaunchUri = Uri(
              scheme: 'tel',
              path: phone!,
            );
            if (await canLaunchUrl(phoneLaunchUri)) {
              await launchUrl(phoneLaunchUri);
            } else {
              throw 'Could not launch phone app.';
            }
          }
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(width: width),
              // Add a fixed width SizedBox before the icon
              Icon(Icons.phone),
              SizedBox(width: width),
              // Add some space between the icon and text
              Text(
                phone!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
