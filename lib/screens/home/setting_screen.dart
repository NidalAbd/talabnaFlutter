import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/provider/language.dart';
import 'package:talabna/screens/home/privacy_policy_screen.dart';
import 'package:talabna/screens/profile/change_email_screen.dart';
import 'package:talabna/screens/profile/change_password_screen.dart';

import '../../blocs/authentication/authentication_bloc.dart';
import '../../blocs/authentication/authentication_event.dart';
import '../../blocs/font_size/font_size_bloc.dart';
import '../../blocs/font_size/font_size_event.dart';
import '../../blocs/font_size/font_size_state.dart';
import '../../blocs/service_post/service_post_bloc.dart';
import '../../blocs/service_post/service_post_event.dart';
import '../../core/service_post_data_saver_handler.dart';
import '../../provider/language_theme_selector.dart';
import '../../services/font_size_service.dart';
import '../../utils/data_saver_synchronizer.dart';
import '../../utils/photo_image_helper.dart';
import '../profile/profile_edit_screen.dart';
import 'about_screen.dart';
import 'app_data_clear_service.dart';
import 'help_center_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key, required this.userId, required this.user});

  final int userId;
  final User user;

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen>
    with SingleTickerProviderStateMixin {
  final Language _language = Language();
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  bool _dataSaverEnabled = false;
  final _appDataClearService = AppDataClearService();
  late  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double _currentFontSize = 14.0; // Default font size

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    // Initialize settings asynchronously
    _initializeSettings();

    // Create a scaffold key if it doesn't exist
    _scaffoldKey = GlobalKey<ScaffoldState>();
  }

  Future<void> _loadFontSize() async {
    final fontSize = await FontSizeService.getDescriptionFontSize();
    if (mounted) {
      setState(() {
        _currentFontSize = fontSize;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeSettings() async {
    try {
      // Get notification setting
      final notificationStatus = await NotificationService.getNotificationStatus();

      // Get data saver setting from DataSaverService
      final dataSaverStatus = await DataSaverService.getDataSaverStatus();

      // Initialize the ServicePostBloc with current data saver status
      if (context.mounted) {
        ServicePostDataSaverHandler.initializeBloc(context);
      }

      if (mounted) {
        setState(() {
          _notificationsEnabled = notificationStatus;
          _dataSaverEnabled = dataSaverStatus;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();
      }
    }
  }

  // Handle language change callback
  void _onLanguageChanged() {
    // Force a rebuild of the screen with the new language
    setState(() {
      // No need to clear _welcomeContent as it doesn't exist in this class
    });

    // Restart animation if needed
    _animationController.reset();
    _animationController.forward();

    // Show a confirmation toast/snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_language.getLanguage() == 'ar'
            ? 'تم تغيير اللغة بنجاح'
            : 'Language changed successfully'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

// Modify the _toggleDataSaver method in your SettingScreen class
  Future<void> _toggleDataSaver() async {
    try {
      // Toggle data saver status and wait for the result
      final newStatus = await DataSaverService.toggleDataSaver();

      // Update UI state
      setState(() {
        _dataSaverEnabled = newStatus;
      });

      // Notify the ServicePostBloc
      if (context.mounted) {
        context.read<ServicePostBloc>().add(DataSaverToggleEvent(enabled: newStatus));
      }

      // Clear ServicePostBloc caches to force reload with new setting
      if (context.mounted) {
        context.read<ServicePostBloc>().add(const ClearServicePostCacheEvent());
      }

      // Show a snackbar to provide feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus
                ? _language.getLanguage() == 'ar'
                ? 'تم تفعيل وضع توفير البيانات'
                : 'Data Saver Mode Enabled'
                : _language.getLanguage() == 'ar'
                ? 'تم تعطيل وضع توفير البيانات'
                : 'Data Saver Mode Disabled'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Handle any errors that might occur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_language.getLanguage() == 'ar'
                ? 'خطأ في تحديث وضع توفير البيانات: $e'
                : 'Error updating data saver mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _toggleNotifications() async {
    try {
      // Toggle notification status
      final newStatus = await NotificationService.toggleNotifications();

      setState(() {
        _notificationsEnabled = newStatus;
      });

      // Show a snackbar to provide feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus
              ? _language.tNotificationsEnabledText()
              : _language.tNotificationsDisabledText()),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Handle any errors that might occur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? primaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.withOpacity(0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeSettings() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;

    return BlocBuilder<FontSizeBloc, FontSizeState>(
      builder: (context, state) {
        double currentFontSize = FontSizeService.defaultDescriptionFontSize;

        if (state is FontSizeLoaded) {
          currentFontSize = state.descriptionFontSize;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.text_fields_outlined,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _language.getLanguage() == 'ar'
                            ? 'حجم خط الوصف'
                            : 'Description Font Size',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${currentFontSize.toInt()}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _language.getLanguage() == 'ar' ? 'صغير' : 'Small',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      _language.getLanguage() == 'ar' ? 'كبير' : 'Large',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: primaryColor,
                    overlayColor: primaryColor.withOpacity(0.2),
                    valueIndicatorColor: primaryColor,
                    showValueIndicator: ShowValueIndicator.always,
                  ),
                  child: Slider(
                    min: FontSizeService.minFontSize,
                    max: FontSizeService.maxFontSize,
                    divisions: (FontSizeService.maxFontSize - FontSizeService.minFontSize).toInt(),
                    value: currentFontSize,
                    label: currentFontSize.toInt().toString(),
                    onChanged: (value) {
                      context.read<FontSizeBloc>().add(FontSizeChanged(value));
                    },
                  ),
                ),

                // Reset button
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      context.read<FontSizeBloc>().add(FontSizeReset());

                      // Show feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_language.getLanguage() == 'ar'
                              ? 'تمت إعادة تعيين حجم الخط'
                              : 'Font size reset to default'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: Icon(Icons.restore, color: primaryColor, size: 16),
                    label: Text(
                      _language.getLanguage() == 'ar' ? 'إعادة تعيين' : 'Reset',
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;

    // Store the navigator context to ensure it's available throughout the function
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    final BuildContext outerContext = context;

    // Show confirmation dialog
    showDialog(
      context: outerContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _language.tConfirmLogoutText(),
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(_language.tConfirmLogoutDescText()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              _language.tCancelText(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close dialog first using the dialog context
              Navigator.of(dialogContext).pop();

              // Reference to loading dialog context
              BuildContext? loadingDialogContext;

              try {
                // Show loading indicator with its own BuildContext
                showDialog(
                  context: outerContext,
                  barrierDismissible: false,
                  builder: (context) {
                    loadingDialogContext = context;
                    return WillPopScope(
                      onWillPop: () async => false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      ),
                    );
                  },
                );

                // Dispatch LoggedOut event to authentication bloc
                if (mounted) {
                  BlocProvider.of<AuthenticationBloc>(outerContext)
                      .add(LoggedOut());
                }

                // Clear all app data
                await _appDataClearService.clearAllData();

                // Close loading dialog using its own context
                if (loadingDialogContext != null && mounted) {
                  Navigator.of(loadingDialogContext!).pop();
                  loadingDialogContext = null;
                }

                // Navigate to login screen using the outer context
                if (mounted) {
                  Navigator.of(outerContext).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              } catch (e) {
                // Close loading dialog using its own context if there's an error
                if (loadingDialogContext != null && mounted) {
                  Navigator.of(loadingDialogContext!).pop();
                  loadingDialogContext = null;
                }

                // Show error if widget is still mounted
                if (mounted) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    SnackBar(
                      content: Text(_language.getLanguage() == 'ar'
                          ? 'حدث خطأ أثناء تسجيل الخروج: $e'
                          : 'Error during logout: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(_language.tLogoutText()),
          ),
        ],
      ),
    );
  }

  // Add this method if it doesn't already exist in your _SettingScreenState class

  // Add these helper methods to your _SettingScreenState class

// Helper method to build statistics item
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkSecondaryColor
              : AppTheme.lightPrimaryColor,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

// Helper method to build vertical divider
  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }

  void _navigateToUpdateProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateUserProfile(
          userId: widget.user.id,
          user: widget.user,
        ),
      ),
    ).then((_) {
      // Force a refresh when returning from the profile update screen
      setState(() {
        // Refresh user data if needed
        // You might want to fetch updated user data here
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.lightBackgroundColor;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(
            _language.tSettingsText(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Profile avatar text or fallback
    String avatarText = '';
    if (widget.user.name != null && widget.user.name!.isNotEmpty) {
      avatarText = widget.user.name!.substring(0, 1).toUpperCase();
    } else {
      avatarText = 'U';
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _language.tSettingsText(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      // Avoid using FadeTransition directly on the body
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeInAnimation.value,
            child: child,
          );
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Profile section
// Replace the existing profile section in the build method of SettingScreen with this enhanced version

// Profile section
// Modern Profile Container for SettingScreen
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      children: [
                        // Background gradient header
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(0.8),
                                primaryColor.withOpacity(0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(40),
                              bottomRight: Radius.circular(40),
                            ),
                          ),
                        ),

                        // User info with overlapping avatar
                        Transform.translate(
                          offset: const Offset(0, -50),
                          child: Column(
                            children: [
                              // Profile image with stacked edit button
                              Stack(
                                children: [
                                  // Outer decoration circle
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                                    ),
                                    child: Hero(
                                      tag: 'profileAvatar${widget.user.id}',
                                      child: Container(
                                        height: 100,
                                        width: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDarkMode ? Colors.black : Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withOpacity(0.3),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: (widget.user.photos?.isNotEmpty ?? false)
                                              ? Image.network(
                                            ProfileImageHelper.getProfileImageUrl(
                                                widget.user.photos?.first
                                            ),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return CircleAvatar(
                                                radius: 50,
                                                backgroundColor: primaryColor.withOpacity(0.2),
                                                child: Text(
                                                  avatarText,
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              );
                                            },
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return CircleAvatar(
                                                radius: 50,
                                                backgroundColor: primaryColor.withOpacity(0.1),
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                      : null,
                                                  strokeWidth: 2,
                                                  color: primaryColor,
                                                ),
                                              );
                                            },
                                          )
                                              : CircleAvatar(
                                            radius: 50,
                                            backgroundColor: primaryColor.withOpacity(0.2),
                                            child: Text(
                                              avatarText,
                                              style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Edit button
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: () => _navigateToUpdateProfile(context),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // User info with animations
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildSectionTitle(_language.tPreferencesText()),

                // Using the new LanguageThemeSelector widget
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LanguageThemeSelector(
                    compactMode: false,
                    showThemeToggle: true,
                    showConfirmationDialog: true,
                    // Show confirmation before changing
                    onLanguageChanged: _onLanguageChanged,
                  ),
                ),
                _buildFontSizeSettings(),

                _buildSectionTitle(_language.tAccountText()),

                _buildSettingCard(
                  icon: Icons.email_outlined,
                  title: _language.tChangeEmailText(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            ChangeEmailScreen(userId: widget.user.id),
                      ),
                    );
                  },
                ),


                _buildSettingCard(
                  icon: Icons.lock_outline,
                  title: _language.tChangePasswordText(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            ChangePasswordScreen(userId: widget.user.id),
                      ),
                    );
                  },
                ),

                _buildSettingCard(
                  icon: Icons.notifications_outlined,
                  title: _language.tNotificationsText(),
                  onTap: () => _toggleNotifications(),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      _toggleNotifications();
                    },
                    activeColor: primaryColor,
                    activeTrackColor: primaryColor.withOpacity(0.5),
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: Colors.grey[300],
                  ),
                ),

                _buildSettingCard(
                  icon: Icons.data_saver_on_outlined,
                  title: _language.getLanguage() == 'ar'
                      ? 'وضع توفير البيانات'
                      : 'Data Saver Mode',
                  onTap: () {}, // Empty since the Switch handles it
                  trailing: Switch(
                    value: _dataSaverEnabled,
                    onChanged: (value) async {
                      try {
                        // Use the value from the switch directly instead of toggling
                        print('Switch changed to: $value');

                        // Update state immediately for responsive UI
                        setState(() {
                          _dataSaverEnabled = value;
                        });

                        // Set the value directly instead of toggling
                        await DataSaverService.setDataSaverStatus(value);

                        // Notify blocs
                        if (context.mounted) {
                          context.read<ServicePostBloc>().add(DataSaverToggleEvent(enabled: value));
                          context.read<ServicePostBloc>().add(const ClearServicePostCacheEvent());
                        }

                        // Feedback
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value
                                  ? _language.getLanguage() == 'ar'
                                  ? 'تم تفعيل وضع توفير البيانات'
                                  : 'Data Saver Mode Enabled'
                                  : _language.getLanguage() == 'ar'
                                  ? 'تم تعطيل وضع توفير البيانات'
                                  : 'Data Saver Mode Disabled'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        // Revert UI on error
                        setState(() {
                          _dataSaverEnabled = !value;
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating data saver mode: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    activeColor: primaryColor,
                  ),
                ),

                _buildSectionTitle(_language.tSupportText()),

                _buildSettingCard(
                  icon: Icons.help_outline,
                  title: _language.tHelpCenterText(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const HelpCenterScreen(),
                      ),
                    );
                  },
                ),

                _buildSettingCard(
                  icon: Icons.privacy_tip_outlined,
                  title: _language.tPrivacyPolicyText(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),

                _buildSettingCard(
                  icon: Icons.info_outline,
                  title: _language.tAboutText(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    );
                  },
                ),

                _buildSectionTitle(_language.tOtherText()),

                _buildSettingCard(
                  icon: Icons.logout,
                  title: _language.tLogoutText(),
                  onTap: _handleLogout,
                  iconColor: Colors.redAccent,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
