import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/provider/language.dart';
import 'package:talabna/screens/home/search_screen.dart';
import 'package:talabna/screens/home/setting_screen.dart';
import 'package:talabna/screens/profile/profile_screen.dart';
import 'package:talabna/screens/profile/purchase_request_screen.dart';
import 'package:talabna/screens/service_post/create_service_post_form.dart';
import 'package:talabna/screens/service_post/favorite_post_screen.dart';
import '../../main.dart';
import '../../services/device_info_service.dart';
import '../../utils/constants.dart';
import '../../utils/photo_image_helper.dart';
import '../profile/profile_completion_service.dart';
import '../profile/profile_edit_screen.dart';
import 'notification_alert_widget.dart';

class VertIconAppBar extends StatefulWidget {
  const VertIconAppBar({
    super.key,
    required this.userId,
    required this.user,
    required this.showSubcategoryGridView,
    required this.toggleSubcategoryGridView,
    this.showMenuIcon = true, // Add this parameter with default true
  });

  final int userId;
  final User user;
  final bool showSubcategoryGridView;
  final Future<void> Function({required bool canToggle}) toggleSubcategoryGridView;
  final bool showMenuIcon; // New parameter

  // Add a static method to create drawer so it can be accessed without state
  static Widget buildDrawer(
      BuildContext context,
      int userId,
      User user,
      bool showSubcategoryGridView,
      Future<void> Function({required bool canToggle}) toggleSubcategoryGridView,
      bool isProfileComplete,
      Function() forceProfleCompletionCheck,
      ) {
    final language = Language();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;
    final backgroundColor = isDarkMode ? AppTheme.darkPrimaryColor : AppTheme.lightBackgroundColor;
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor;
    final accentColor = isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightSecondaryColor;
    final surfaceColor = isDarkMode ? AppTheme.darkPrimaryColor
        : AppTheme.lightBackgroundColor;
    final appInfoService = AppInfoService();
    String versionText = appInfoService.getFormattedVersion();

    // Function to navigate to service post
    void navigateToServicePost(BuildContext context) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServicePostFormScreen(
            userId: userId,
            user: user,
          ),
        ),
      );
    }

    // Function to handle add post
    Future<void> handleAddPost(BuildContext context) async {
      navigateToServicePost(context);
    }

    // Function to navigate to profile
    void navigateToProfile(BuildContext context) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
              fromUser: userId,
              toUser: userId,
              user: user),
        ),
      );
    }
    // Helper function to build drawer menu item
    Widget buildDrawerMenuItem({
      required String title,
      required IconData icon,
      required VoidCallback? onTap,
      bool isDisabled = false,
      required Color primaryColor,
      required Color textColor,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDisabled
                        ? primaryColor.withOpacity(0.1)
                        : primaryColor.withOpacity(0.1),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isDisabled ? Colors.grey : primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: GoogleFonts.poppins().fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDisabled ? textColor.withOpacity(0.5) : textColor,
                    ),
                  ),
                ),
                if (!isDisabled)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: textColor.withOpacity(0.3),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Function to navigate to favorites
    void navigateToFavorites(BuildContext context) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FavoritePostScreen(
            userID: user.id,
            user: user,
          ),
        ),
      );
    }

    // Function to navigate to update profile
    void navigateToUpdateProfile(BuildContext context) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UpdateUserProfile(
            userId: user.id,
            user: user,
          ),
        ),
      ).then((_) {
        forceProfleCompletionCheck();
      });
    }

    // Function to navigate to purchase
    void navigateToPurchase(BuildContext context) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchaseRequestScreen(
            userID: user.id,
          ),
        ),
      );
    }

    // Function to navigate to settings
    void navigateToSettings(BuildContext context) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingScreen(
            userId: userId,
            user: user,
          ),
        ),
      );
    }

    // Helper function to build drawer switch item
    Widget buildDrawerSwitchItem({
      required String title,
      required IconData icon,
      required bool value,
      required Function(bool)? onChanged,
      required Color primaryColor,
      required Color textColor,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.1),
              ),
              child: Icon(
                icon,
                size: 20,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: primaryColor,
            ),
          ],
        ),
      );
    }

    // Helper function to build drawer section
    Widget buildDrawerSection({
      required String title,
      required List<DrawerMenuItem> items,
      required Color primaryColor,
      required Color textColor,
      required Color surfaceColor,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: GoogleFonts.poppins().fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Menu items
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(items.length * 2 - 1, (index) {
                // Return divider for odd indices
                if (index.isOdd) {
                  return Divider(
                    height: 1,
                    thickness: 1,
                    indent: 56,
                    endIndent: 16,
                    color: textColor.withOpacity(0.05),
                  );
                }

                // Return menu item for even indices
                final itemIndex = index ~/ 2;
                final item = items[itemIndex];

                if (item.isSwitch) {
                  return buildDrawerSwitchItem(
                    title: item.title,
                    icon: item.icon,
                    value: item.switchValue ?? false,
                    onChanged: item.onSwitchChanged,
                    primaryColor: primaryColor,
                    textColor: textColor,
                  );
                }

                return buildDrawerMenuItem(
                  title: item.title,
                  icon: item.icon,
                  onTap: item.onTap,
                  isDisabled: item.isDisabled,
                  primaryColor: primaryColor,
                  textColor: textColor,
                );
              }),
            ),
          ),
        ],
      );
    }
    // Helper function to build drawer header
    Widget buildDrawerHeader(BuildContext context, Color primaryColor, Color accentColor, Color textColor) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          children: [
            // User avatar
            Hero(
              tag: 'drawerProfileAvatar${user.id}',
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (user.photos?.isNotEmpty ?? false)
                      ? NetworkImage(
                    ProfileImageHelper.getProfileImageUrl(user.photos?.first),
                  )
                      : null,
                  child: (user.photos?.isEmpty ?? true)
                      ? Icon(Icons.person, size: 40, color: Colors.grey[700])
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // User name
            Text(
              user.userName ?? 'User',
              style: TextStyle(
                fontFamily: GoogleFonts.poppins().fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // User email
            if (user.email != null)
              Text(
                user.email!,
                style: TextStyle(
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            // Edit profile button
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                navigateToUpdateProfile(context);
              },
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit,
                      size: 14,
                      color: accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontFamily: GoogleFonts.poppins().fontFamily,
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Helper function to build profile completion status
    Widget buildProfileCompletionStatus(BuildContext context, Color primaryColor, Color textColor) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isProfileComplete ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isProfileComplete ? Icons.check_circle_outline : Icons.info_outline,
              color: isProfileComplete ? Colors.green : Colors.amber,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isProfileComplete
                    ? language.tProfileCompleteText() ?? 'Your profile is complete'
                    : language.tProfileIncompleteText() ?? 'Complete your profile to access all features',
                style: TextStyle(
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  fontSize: 12,
                  color: isProfileComplete ? Colors.green : Colors.amber[800],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Drawer(
      backgroundColor: backgroundColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // User profile header
            buildDrawerHeader(context, primaryColor, accentColor, textColor),

            // Profile completion status indicator
            buildProfileCompletionStatus(context, primaryColor, textColor),

            const SizedBox(height: 16),

            // Menu items in a scrollable list
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    // Main menu section
                    buildDrawerSection(
                      title: language.tMainMenuText() ?? 'Main Menu',
                      items: [
                        DrawerMenuItem(
                          title: language.tSearchText() ?? 'Search',
                          icon: Icons.search,
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchScreen(
                                  userID: userId,
                                  user: user,
                                ),
                              ),
                            );
                          },
                          isDisabled: !isProfileComplete,
                        ),
                        DrawerMenuItem(
                          title: language.tAddPostText(),
                          icon: Icons.add_circle_outline_rounded,
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            if (isProfileComplete) {
                              handleAddPost(context);
                            } else {
                              navigateToUpdateProfile(context);
                            }
                          },
                          isDisabled: !isProfileComplete,
                        ),
                      ],
                      primaryColor: primaryColor,
                      textColor: textColor,
                      surfaceColor: surfaceColor,
                    ),

                    const SizedBox(height: 16),

                    // Profile section
                    buildDrawerSection(
                      title: language.tProfileText(),
                      items: [
                        DrawerMenuItem(
                          title: language.tProfileText(),
                          icon: Icons.person_outline_rounded,
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            navigateToProfile(context);
                          },
                        ),
                        DrawerMenuItem(
                          title: language.tUpdateInfoText(),
                          icon: Icons.edit_outlined,
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            navigateToUpdateProfile(context);
                          },
                        ),
                        DrawerMenuItem(
                          title: language.tFavoriteText(),
                          icon: Icons.favorite_border_rounded,
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            navigateToFavorites(context);
                          },
                        ),
                        DrawerMenuItem(
                          title: language.tPurchasePointsText(),
                          icon: Icons.account_balance_wallet_outlined,
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            navigateToPurchase(context);
                          },
                        ),
                      ],
                      primaryColor: primaryColor,
                      textColor: textColor,
                      surfaceColor: surfaceColor,
                    ),

                    const SizedBox(height: 16),

                    // Settings section
                    buildDrawerSection(
                      title: language.tSettingsText(),
                      items: [
                        DrawerMenuItem(
                          title: language.tSwitchSubcategoryList(),
                          icon: showSubcategoryGridView ? Icons.grid_view_rounded : Icons.list_rounded,
                          isSwitch: true,
                          switchValue: showSubcategoryGridView,
                          onSwitchChanged: (value) async {
                            Navigator.pop(context); // Close drawer
                            await toggleSubcategoryGridView(canToggle: true);
                          },
                        ),
                        DrawerMenuItem(
                          title: language.tSettingsText(),
                          icon: Icons.settings_outlined,
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            navigateToSettings(context);
                          },
                        ),
                      ],
                      primaryColor: primaryColor,
                      textColor: textColor,
                      surfaceColor: surfaceColor,
                    ),
                  ],
                ),
              ),
            ),

            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                String version = '1.0.0'; // Default fallback
                if (snapshot.hasData && snapshot.data != null) {
                  version = snapshot.data!.version;
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Talabna',
                        style: TextStyle(
                          fontFamily: GoogleFonts.poppins().fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 4),



                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          String version = '1.0.0'; // Default fallback
                          if (snapshot.hasData && snapshot.data != null) {
                            version = snapshot.data!.version;
                          }

                          return  Text(
                            versionText,
                            style: TextStyle(
                              fontFamily: GoogleFonts.poppins().fontFamily,
                              fontSize: 12,
                              color: textColor.withOpacity(0.6),
                            ),
                          );
                        },
                      )
                    ],
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  @override
  State<VertIconAppBar> createState() => _VertIconAppBarState();
}

// Helper class for drawer menu items (now public)
class DrawerMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isSwitch;
  final bool? switchValue;
  final Function(bool)? onSwitchChanged;
  final bool isDisabled;

  DrawerMenuItem({
    required this.title,
    required this.icon,
    this.onTap,
    this.isSwitch = false,
    this.switchValue,
    this.onSwitchChanged,
    this.isDisabled = false,
  });
}

class _VertIconAppBarState extends State<VertIconAppBar> {
  bool _isProfileComplete = false;
  bool _isLoading = true;
  final language = Language();
  final _profileCompletionService = ProfileCompletionService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkProfileCompletion();

    // Listen for changes in profile completion status
    _profileCompletionService.profileCompletionNotifier
        .addListener(_onProfileStatusChanged);
  }

  @override
  void dispose() {
    _profileCompletionService.profileCompletionNotifier
        .removeListener(_onProfileStatusChanged);
    super.dispose();
  }

  void _onProfileStatusChanged() {
    if (mounted) {
      setState(() {
        _isProfileComplete =
            _profileCompletionService.profileCompletionNotifier.value;
        _isLoading = false;
      });
    }
  }

  void _forceProfleCompletionCheck() async {
    // Clear the cache to ensure we get the latest value
    _profileCompletionService.clearCache();

    // Check profile completion status
    final isComplete = await _profileCompletionService.isProfileComplete();

    if (mounted) {
      setState(() {
        _isProfileComplete = isComplete;
        _isLoading = false;
      });

      // Trigger a global update for other widgets that might be listening
      _profileCompletionService.updateProfileCompletionStatus();
    }
  }

  Future<void> _checkProfileCompletion() async {
    final isComplete = await _profileCompletionService.isProfileComplete();

    if (mounted) {
      setState(() {
        _isProfileComplete = isComplete;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
    isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;
    final iconColor =
    isDarkMode ? AppTheme.darkIconColor : AppTheme.lightIconColor;
    final disabledColor = isDarkMode ? Colors.grey[700] : Colors.grey[400];

    if (_isLoading) {
      return SizedBox(
        width: 166, // Give it a reasonable width
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.grey[300],
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
      );
    }

    // Pass scaffoldKey to your parent Scaffold
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.findAncestorWidgetOfExactType<Scaffold>() != null) {
        final scaffold = Scaffold.of(context);
        _openDrawer() => scaffold.openDrawer();
      }
    });

    return SizedBox(
      width: 160, // Give it a reasonable width
      child: Row(
        children: [
          // Menu Button to open drawer
          if (widget.showMenuIcon)
            _buildIconButton(
              context: context,
              icon: Icons.menu,
              color: iconColor,
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              tooltip: language.tMoreOptionsText(),
            ),
Spacer(),

          // Major actions
          _isProfileComplete
              ? NotificationsAlert(userID: widget.userId, user: widget.user,)
              : Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.notifications,
              color: disabledColor,
              size: 24,
            ),
          ),
          Spacer(),



          GestureDetector(
            onTap: () => _isProfileComplete
                ? _navigateToProfile(context)
                : _navigateToUpdateProfile(context),
            child: Hero(
              tag: 'profileAvatar${widget.user.id}',
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.grey[300],
                backgroundImage: (widget.user.photos?.isNotEmpty ?? false)
                    ? NetworkImage(
                  ProfileImageHelper.getProfileImageUrl(
                      widget.user.photos?.first),
                )
                    : null,
                child: (widget.user.photos?.isEmpty ?? true)
                    ? Icon(Icons.person, size: 18, color: Colors.grey[700])
                    : null,
              ),
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.hardEdge,
          child: IconButton(
            icon: Icon(icon, size: 26),
            color: color,
            onPressed: onPressed,
            splashRadius: 24,
            padding: const EdgeInsets.all(8),
          ),
        ),
      ),
    );
  }

  // Keep all your existing navigation methods...
  Future<void> _handleAddPost(BuildContext context) async {
    _navigateToServicePost(context);
  }

  void _navigateToServicePost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServicePostFormScreen(
          userId: widget.userId,
          user: widget.user,
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
            fromUser: widget.userId,
            toUser: widget.userId,
            user: widget.user),
      ),
    );
  }

  void _navigateToFavorites(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritePostScreen(
          userID: widget.user.id,
          user: widget.user,
        ),
      ),
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
      _forceProfleCompletionCheck();
    });
  }

  void _navigateToPurchase(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseRequestScreen(
          userID: widget.user.id,
        ),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingScreen(
          userId: widget.userId,
          user: widget.user,
        ),
      ),
    );
  }

  // Expose a method to get profile completion status
  bool getProfileCompletionStatus() {
    return _isProfileComplete;
  }
}