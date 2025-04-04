import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationButtonWidget extends StatelessWidget {
  final double locationLatitudes;
  final double locationLongitudes;
  final double width;

  const LocationButtonWidget({
    super.key,
    required this.locationLatitudes,
    required this.locationLongitudes,
    required this.width,
  });

  Future<void> launchGoogleMap() async {
    final url =
        'geo:$locationLatitudes,$locationLongitudes?q=$locationLatitudes,$locationLongitudes';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(16),
            ),
          ),
        ),
        onPressed: launchGoogleMap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(width: width),
              // Add a fixed width SizedBox before the icon
              Icon(Icons.location_on_outlined, size: 25
              ,    color: isDarkMode ? Colors.grey.shade900 : Colors.white,

              ),
              SizedBox(width: width),
              // Add some space between the icon and text
              Text(
                'view google map',
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
