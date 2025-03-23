import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/utils/debug_logger.dart';

/// A utility class to synchronize data saver settings between the app and the ServicePostBloc
class DataSaverSynchronizer {
  /// Updates the data saver setting in both SharedPreferences and ServicePostBloc
  static Future<bool> toggleDataSaver(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentValue = prefs.getBool('data_saver_enabled') ?? false;
      final newValue = !currentValue;

      // Update SharedPreferences
      await prefs.setBool('data_saver_enabled', newValue);

      // Update the ServicePostBloc
      if (context.mounted) {
        context.read<ServicePostBloc>().add(DataSaverToggleEvent(enabled: newValue));
      }

      DebugLogger.log('Data saver toggled to: $newValue', category: 'DATA_SAVER');
      return newValue;
    } catch (e) {
      DebugLogger.log('Error toggling data saver: $e', category: 'DATA_SAVER');
      rethrow;
    }
  }

  /// Retrieves the current data saver status
  static Future<bool> getDataSaverStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('data_saver_enabled') ?? false;
    } catch (e) {
      DebugLogger.log('Error getting data saver status: $e', category: 'DATA_SAVER');
      return false;
    }
  }

  /// Initializes the ServicePostBloc with the current data saver status
  static Future<void> initializeBloc(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentValue = prefs.getBool('data_saver_enabled') ?? false;

      // Notify the ServicePostBloc of the current data saver status
      if (context.mounted) {
        context.read<ServicePostBloc>().add(DataSaverStatusChangedEvent(enabled: currentValue));
      }

      DebugLogger.log('ServicePostBloc initialized with data saver: $currentValue',
          category: 'DATA_SAVER');
    } catch (e) {
      DebugLogger.log('Error initializing ServicePostBloc with data saver status: $e',
          category: 'DATA_SAVER');
    }
  }
}