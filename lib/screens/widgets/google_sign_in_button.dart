import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/blocs/authentication/authentication_bloc.dart';
import 'package:talabna/blocs/authentication/authentication_event.dart';
import 'package:talabna/blocs/authentication/authentication_state.dart';
import 'package:talabna/theme_cubit.dart';
import 'package:talabna/utils/debug_logger.dart';

class GoogleSignInButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const GoogleSignInButton({
    super.key,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isLoading = false;
  static bool _isGlobalSignInInProgress = false;
  DateTime? _lastClickTime;
  static const _debounceTime = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _isLoading = widget.isLoading;
  }

  @override
  void didUpdateWidget(GoogleSignInButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      setState(() {
        _isLoading = widget.isLoading;
      });
    }
  }

  void _handleSignIn() {
    // Prevent if already in progress globally
    if (_isGlobalSignInInProgress) {
      DebugLogger.log('Google Sign-In already in progress globally',
          category: 'AUTH');
      return;
    }

    // Prevent if already loading locally
    if (_isLoading) {
      DebugLogger.log('Button already in loading state', category: 'AUTH');
      return;
    }

    // Debounce rapid clicks
    final now = DateTime.now();
    if (_lastClickTime != null &&
        now.difference(_lastClickTime!).compareTo(_debounceTime) < 0) {
      DebugLogger.log('Ignoring rapid Google Sign-In click', category: 'AUTH');
      return;
    }

    _lastClickTime = now;
    _isGlobalSignInInProgress = true;

    setState(() {
      _isLoading = true;
    });

    // Safety timeout to reset loading state
    Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _isGlobalSignInInProgress = false;
      }
    });

    // Trigger sign-in
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      DebugLogger.log('Initiating Google Sign-In', category: 'AUTH');
      BlocProvider.of<AuthenticationBloc>(context).add(GoogleSignInRequest());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        // Reset loading state when auth completes or fails
        if (state is! AuthenticationInProgress && _isLoading) {
          setState(() {
            _isLoading = false;
          });
          _isGlobalSignInInProgress = false;
        }
      },
      child: BlocBuilder<ThemeCubit, ThemeData>(
        builder: (context, theme) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          final primaryColor = isDarkMode
              ? AppTheme.darkSecondaryColor
              : AppTheme.lightPrimaryColor;
          final backgroundColor = isDarkMode ? Colors.grey[800] : Colors.white;
          final textColor = isDarkMode ? Colors.white : Colors.black87;

          // Combine local and bloc loading state
          final isAuthInProgress = context.select((AuthenticationBloc bloc) =>
              bloc.state is AuthenticationInProgress);
          final shouldShowLoading = _isLoading || isAuthInProgress;

          return SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: shouldShowLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode ? Colors.white : primaryColor,
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/google_logo.png',
                      height: 24,
                      width: 24,
                    ),
              label: Text(
                shouldShowLoading ? 'Signing in...' : 'Sign in with Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: primaryColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                elevation: 2,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onPressed: shouldShowLoading ? null : _handleSignIn,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Reset global flag if this instance initiated the sign-in
    if (_isLoading) {
      _isGlobalSignInInProgress = false;
    }
    super.dispose();
  }
}
