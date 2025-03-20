import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/authentication/authentication_bloc.dart';
import 'package:talabna/blocs/category/subcategory_bloc.dart';
import 'package:talabna/blocs/comments/comment_bloc.dart';
import 'package:talabna/blocs/internet/internet_bloc.dart';
import 'package:talabna/blocs/internet/internet_event.dart';
import 'package:talabna/blocs/notification/notifications_bloc.dart';
import 'package:talabna/blocs/other_users/user_profile_bloc.dart';
import 'package:talabna/blocs/purchase_request/purchase_request_bloc.dart';
import 'package:talabna/blocs/report/report_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/user_action/user_action_bloc.dart';
import 'package:talabna/blocs/user_contact/user_contact_bloc.dart';
import 'package:talabna/blocs/user_follow/user_follow_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_bloc.dart';
import 'package:talabna/core/service_locator.dart';
import 'package:talabna/theme_cubit.dart';

import '../blocs/service_post/service_post_event.dart';

class AppBlocProviders {
  static List<BlocProvider> getProviders() {
    return [
      // Network Observer
      BlocProvider<NetworkBloc>(
        create: (context) =>
            serviceLocator<NetworkBloc>()..add(NetworkObserve()),
      ),

      // Authentication
      BlocProvider<AuthenticationBloc>(
        create: (context) => serviceLocator<AuthenticationBloc>(),
      ),

      // User Profiles
      BlocProvider<UserProfileBloc>(
        create: (context) => serviceLocator<UserProfileBloc>(),
      ),
      BlocProvider<OtherUserProfileBloc>(
        create: (context) => serviceLocator<OtherUserProfileBloc>(),
      ),
      BlocProvider<ServicePostBloc>(
        create: (context) {
          final bloc = serviceLocator<ServicePostBloc>();
          // Initialize tracking structures
          bloc.add(InitializeCachesEvent());
          return bloc;
        },
      ),
      BlocProvider<PurchaseRequestBloc>(
        create: (context) => serviceLocator<PurchaseRequestBloc>(),
      ),

      // Social Interactions
      BlocProvider<UserFollowBloc>(
        create: (context) => serviceLocator<UserFollowBloc>(),
      ),
      BlocProvider<UserActionBloc>(
        create: (context) => serviceLocator<UserActionBloc>(),
      ),
      BlocProvider<UserContactBloc>(
        create: (context) => serviceLocator<UserContactBloc>(),
      ),

      // Content Related
      BlocProvider<CommentBloc>(
        create: (context) => serviceLocator<CommentBloc>(),
      ),
      BlocProvider<SubcategoryBloc>(
        create: (context) => serviceLocator<SubcategoryBloc>(),
      ),
      BlocProvider<ReportBloc>(
        create: (context) => serviceLocator<ReportBloc>(),
      ),

      // Notifications
      BlocProvider<talabnaNotificationBloc>(
        create: (context) => serviceLocator<talabnaNotificationBloc>(),
      ),

      // Theme Management
      BlocProvider<ThemeCubit>(
        create: (context) => serviceLocator<ThemeCubit>()..loadTheme(),
      ),
    ];
  }
}
