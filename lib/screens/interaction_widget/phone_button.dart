import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneButtonWidget extends StatelessWidget {
  final String? phone;
  final double width;

  const PhoneButtonWidget({super.key, this.phone, required this.width});

  void _launchPhoneApp(BuildContext context) async {
    if (phone == null || phone!.isEmpty) {
      // Show a snackbar if phone is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final Uri phoneLaunchUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    try {
      if (await canLaunchUrl(phoneLaunchUri)) {
        await launchUrl(phoneLaunchUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch phone app'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final displayText = (phone != null && phone!.isNotEmpty) ? phone! : 'No phone number';

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
        onPressed: () => _launchPhoneApp(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(width: width),
              Icon(Icons.phone, color: isDarkMode ? Colors.grey.shade900 : Colors.white),
              SizedBox(width: width),
              Expanded(
                child: Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}