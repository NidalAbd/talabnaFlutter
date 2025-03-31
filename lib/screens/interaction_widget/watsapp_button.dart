import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppButtonWidget extends StatelessWidget {
  final String? whatsAppNumber;
  final String username;
  final double width;

  const WhatsAppButtonWidget({
    super.key,
    this.whatsAppNumber,
    required this.username,
    required this.width,
  });

  String formatWhatsAppNumber(String number) {
    // Remove leading '00'
    return number.replaceFirst(RegExp(r'^00'), '');
  }

  void launchWhatsApp(BuildContext context) async {
    if (whatsAppNumber == null || whatsAppNumber!.isEmpty) {
      // Show a snackbar if WhatsApp number is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No WhatsApp number available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final formattedNumber = formatWhatsAppNumber(whatsAppNumber!);
    final whatsAppUrl = 'https://wa.me/$formattedNumber';

    try {
      if (await canLaunch(whatsAppUrl)) {
        await launch(whatsAppUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch WhatsApp'),
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
    final displayText = (whatsAppNumber != null && whatsAppNumber!.isNotEmpty)
        ? whatsAppNumber!
        : 'No WhatsApp number';

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
        onPressed: () => launchWhatsApp(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(width: width),
              Image.asset(
                'assets/WhatsApp_logo.png',
                width: 25,
                height: 25,
              ),
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