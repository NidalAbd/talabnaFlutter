import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../../provider/language.dart';

class LocationPicker extends StatefulWidget {
  final Function(LatLng) onLocationPicked;

  const LocationPicker({super.key, required this.onLocationPicked});

  @override
  _LocationPickerState createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final Language _language = Language();
  bool _isMounted = true;
  bool _isLoading = false;
  final defaultLocation = LatLng(31.9539, 35.2376); // Default to Amman, Jordan

  @override
  void initState() {
    super.initState();
    _isMounted = true;

    // Automatically get location when the widget initializes
    // Use a small delay to ensure the widget is fully rendered
    Future.delayed(Duration(milliseconds: 100), () {
      _getCurrentLocation();
    });
  }

  Future<void> _getCurrentLocation() async {
    if (!_isMounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool serviceEnabled;
      PermissionStatus permissionGranted;
      LocationData locationData;

      // Check if location services are enabled
      serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          // If service not enabled, use default location
          _useDefaultLocation();
          return;
        }
      }

      // Check if location permissions are granted
      permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          // If permission denied, use default location
          _useDefaultLocation();
          return;
        }
      }

      // Get the current location
      locationData = await location.getLocation();

      // Check if widget is still mounted before updating state
      if (!_isMounted) return;

      final newLocation = LatLng(
          locationData.latitude!,
          locationData.longitude!
      );

      // Send location to parent
      widget.onLocationPicked(newLocation);

      setState(() {
        _isLoading = false;
      });

      // Show success message
      _showSuccessMessage(true);

    } catch (e) {
      print('Error getting location: $e');
      if (_isMounted) {
        _useDefaultLocation();
      }
    }
  }

  void _useDefaultLocation() {
    if (!_isMounted) return;

    // Use default location
    widget.onLocationPicked(defaultLocation);

    setState(() {
      _isLoading = false;
    });

    // Show default location message
    _showSuccessMessage(false);
  }

  void _showSuccessMessage(bool isActualLocation) {
    if (!_isMounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isActualLocation
                  ? (_language.getLanguage() == 'ar'
                  ? 'تم تحديد موقعك بنجاح'
                  : 'Your location has been successfully captured')
                  : (_language.getLanguage() == 'ar'
                  ? 'تم استخدام الموقع الافتراضي'
                  : 'Using default location')
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    // Return an absolutely invisible widget
    // This will ensure no space is taken and nothing is rendered
    return const SizedBox.shrink();
  }

  final Location location = Location();

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }
}