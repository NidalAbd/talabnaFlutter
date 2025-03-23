import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/service_post_repository.dart';

class DataSaverService {
  static const String _dataSaverKey = 'data_saver_enabled';
  static final ServicePostRepository _repository = ServicePostRepository();

  // Get the current data saver status from SharedPreferences
  static Future<bool> getDataSaverStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_dataSaverKey);
      print('CURRENT DATA SAVER STATUS FROM PREFS: $value (default: false)');
      return value ?? false;
    } catch (e) {
      debugPrint('Error getting data saver status: $e');
      return false;
    }
  }

  // Directly set data saver status (bypassing toggle logic)
  static Future<bool> setDataSaverStatus(bool newStatus) async {
    try {
      print('Setting data saver status DIRECTLY to: $newStatus');

      // Update server
      await _repository.updateDataSaverPreference(newStatus);

      // Update local prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dataSaverKey, newStatus);

      return newStatus;
    } catch (e) {
      debugPrint('Error setting data saver status: $e');
      rethrow;
    }
  }

  // Toggle data saver mode and sync with backend
  static Future<bool> toggleDataSaver() async {
    try {
      // Clear SharedPreferences first to avoid any issues
      final prefs = await SharedPreferences.getInstance();
      final currentStatus = prefs.getBool(_dataSaverKey) ?? false;

      // Toggle it
      final newStatus = !currentStatus;

      print('DIRECT TOGGLE: $currentStatus -> $newStatus');

      // Set new status in preferences immediately
      await prefs.setBool(_dataSaverKey, newStatus);

      // Update server
      try {
        await _repository.updateDataSaverPreference(newStatus);
        return newStatus;
      } catch (e) {
        // If server update fails, revert local setting
        await prefs.setBool(_dataSaverKey, currentStatus);
        throw e;
      }
    } catch (e) {
      debugPrint('Error toggling data saver: $e');
      rethrow;
    }
  }

  // Initialize data saver status from user model when logging in
  static Future<void> initializeFromUser(bool userDataSaverEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dataSaverKey, userDataSaverEnabled);
  }

  // Check if images should be loaded based on current data saver setting
  static Future<bool> shouldLoadImages() async {
    final dataSaverEnabled = await getDataSaverStatus();
    return !dataSaverEnabled;
  }
}