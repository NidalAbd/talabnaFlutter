import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/service_post/service_post_bloc.dart';
import '../blocs/service_post/service_post_event.dart';
import '../blocs/service_post/service_post_state.dart';
import '../screens/home/app_data_clear_service.dart';
import '../utils/debug_logger.dart';

class ServicePostDataSaverHandler {
  // Notify the ServicePostBloc about data saver changes
  static void notifyDataSaverChange(BuildContext context, bool enabled) {
    try {
      if (context.mounted) {
        context.read<ServicePostBloc>().add(DataSaverToggleEvent(enabled: enabled));
        DebugLogger.log('Notified ServicePostBloc of data saver change: $enabled',
            category: 'DATA_SAVER');
      }
    } catch (e) {
      DebugLogger.log('Error notifying ServicePostBloc: $e',
          category: 'DATA_SAVER');
    }
  }

  // Clear service post caches when data saver is toggled
  static void clearServicePostCaches(BuildContext context) {
    try {
      if (context.mounted) {
        context.read<ServicePostBloc>().add(const ClearServicePostCacheEvent());
        DebugLogger.log('Cleared service post caches after data saver toggle',
            category: 'DATA_SAVER');
      }
    } catch (e) {
      DebugLogger.log('Error clearing service post caches: $e',
          category: 'DATA_SAVER');
    }
  }

  // Toggle data saver and handle all necessary side effects
  static Future<bool> toggleDataSaver(BuildContext context) async {
    try {
      // Toggle data saver status
      final newStatus = await DataSaverService.toggleDataSaver();

      // Notify the ServicePostBloc
      notifyDataSaverChange(context, newStatus);

      // Clear caches to force reload with new data saver setting
      clearServicePostCaches(context);

      return newStatus;
    } catch (e) {
      DebugLogger.log('Error in toggleDataSaver: $e', category: 'DATA_SAVER');
      rethrow;
    }
  }

  // Initialize data saver state in the bloc
  static Future<void> initializeBloc(BuildContext context) async {
    try {
      final currentValue = await DataSaverService.getDataSaverStatus();

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