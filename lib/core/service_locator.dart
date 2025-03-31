import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/blocs/authentication/authentication_bloc.dart';
// Blocs
import 'package:talabna/blocs/category/subcategory_bloc.dart';
import 'package:talabna/blocs/comments/comment_bloc.dart';
import 'package:talabna/blocs/internet/internet_bloc.dart';
import 'package:talabna/blocs/notification/notifications_bloc.dart';
import 'package:talabna/blocs/other_users/user_profile_bloc.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_bloc.dart'; // Add this import
import 'package:talabna/blocs/purchase_request/purchase_request_bloc.dart';
import 'package:talabna/blocs/report/report_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/user_action/user_action_bloc.dart';
import 'package:talabna/blocs/user_contact/user_contact_bloc.dart';
import 'package:talabna/blocs/user_follow/user_follow_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_bloc.dart';
import 'package:talabna/data/datasources/local/local_category_data_source.dart';
import 'package:talabna/data/datasources/remote/remote_category_data_source.dart';
import 'package:talabna/data/repositories/authentication_repository.dart';
// Repositories
import 'package:talabna/data/repositories/categories_repository.dart';
import 'package:talabna/data/repositories/comment_repository.dart';
import 'package:talabna/data/repositories/notification_repository.dart';
import 'package:talabna/data/repositories/point_transaction_repository.dart'; // Add this import
import 'package:talabna/data/repositories/purchase_request_repository.dart';
import 'package:talabna/data/repositories/report_repository.dart';
import 'package:talabna/data/repositories/service_post_repository.dart';
import 'package:talabna/data/repositories/user_contact_repository.dart';
import 'package:talabna/data/repositories/user_follow_repository.dart';
import 'package:talabna/data/repositories/user_profile_repository.dart';
// Utilities
import 'package:talabna/theme_cubit.dart';
import 'package:talabna/utils/debug_logger.dart';

import '../blocs/font_size/font_size_bloc.dart';
import '../blocs/font_size/font_size_event.dart';
import '../services/font_size_service.dart';
import 'deep_link_service.dart';
import 'navigation_service.dart';

final GetIt serviceLocator = GetIt.instance;

/// **Registers all services, repositories, and blocs**
Future<void> setupServiceLocator() async {
  DebugLogger.log('Setting up service locator', category: 'INIT');

  // 🌍 External Dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  serviceLocator.registerSingleton<SharedPreferences>(sharedPreferences);
  serviceLocator.registerLazySingleton<http.Client>(() => http.Client());
  serviceLocator.registerFactory<FontSizeBloc>(
        () => FontSizeBloc()..add(FontSizeInitialized()),
  );

  // 🚀 Services
  serviceLocator
      .registerLazySingleton<NavigationService>(() => NavigationService());
  serviceLocator
      .registerLazySingleton<DeepLinkService>(() => DeepLinkService());

  // 🗂 Data Sources
  serviceLocator.registerLazySingleton<RemoteCategoryDataSource>(
        () => RemoteCategoryDataSource(),
  );
  serviceLocator.registerLazySingleton<LocalCategoryDataSource>(
        () => LocalCategoryDataSource(
        sharedPreferences: serviceLocator<SharedPreferences>()),
  );

  // 📦 Repositories
  serviceLocator.registerLazySingleton<CategoriesRepository>(
        () => CategoriesRepository(
      remoteDataSource: serviceLocator<RemoteCategoryDataSource>(),
      localDataSource: serviceLocator<LocalCategoryDataSource>(),
    ),
  );

  serviceLocator.registerLazySingleton<ServicePostRepository>(
        () => ServicePostRepository(),
  );

  serviceLocator.registerLazySingleton<AuthenticationRepository>(
        () => AuthenticationRepository(),
  );

  serviceLocator.registerLazySingleton<UserProfileRepository>(
        () => UserProfileRepository(),
  );

  serviceLocator.registerFactory<NetworkBloc>(
        () => NetworkBloc(),
  );

  serviceLocator.registerLazySingleton<PurchaseRequestRepository>(
        () => PurchaseRequestRepository(),
  );

  // Register Point Transaction Repository
  serviceLocator.registerLazySingleton<PointTransactionRepository>(
        () => PointTransactionRepository(),
  );

  serviceLocator.registerLazySingleton<UserFollowRepository>(
        () => UserFollowRepository(),
  );

  serviceLocator.registerLazySingleton<UserContactRepository>(
        () => UserContactRepository(),
  );

  serviceLocator.registerLazySingleton<CommentRepository>(
        () => CommentRepository(),
  );

  serviceLocator.registerLazySingleton<ReportRepository>(
        () => ReportRepository(),
  );

  serviceLocator.registerLazySingleton<NotificationRepository>(
        () => NotificationRepository(),
  );

  // 📌 Blocs
  serviceLocator.registerFactory<SubcategoryBloc>(
        () => SubcategoryBloc(
      categoriesRepository: serviceLocator<CategoriesRepository>(),
      localDataSource: serviceLocator<LocalCategoryDataSource>(),
    ),
  );

  serviceLocator.registerFactory<ServicePostBloc>(
        () => ServicePostBloc(
      servicePostRepository: serviceLocator<ServicePostRepository>(),
    ),
  );

  serviceLocator.registerFactory<AuthenticationBloc>(
        () => AuthenticationBloc(
      authenticationRepository: serviceLocator<AuthenticationRepository>(),
    ),
  );

  serviceLocator.registerFactory<UserProfileBloc>(
        () => UserProfileBloc(
      repository: serviceLocator<UserProfileRepository>(),
    ),
  );

  serviceLocator.registerFactory<OtherUserProfileBloc>(
        () => OtherUserProfileBloc(
      repository: serviceLocator<UserProfileRepository>(),
    ),
  );

  serviceLocator.registerFactory<PurchaseRequestBloc>(
        () => PurchaseRequestBloc(
      repository: serviceLocator<PurchaseRequestRepository>(),
    ),
  );

  // Register Point Transaction Bloc
  serviceLocator.registerFactory<PointTransactionBloc>(
        () => PointTransactionBloc(
      repository: serviceLocator<PointTransactionRepository>(),
    ),
  );

  serviceLocator.registerFactory<UserFollowBloc>(
        () => UserFollowBloc(
      repository: serviceLocator<UserFollowRepository>(),
    ),
  );

  serviceLocator.registerFactory<UserActionBloc>(
        () => UserActionBloc(
      repository: serviceLocator<UserFollowRepository>(),
    ),
  );

  serviceLocator.registerFactory<UserContactBloc>(
        () => UserContactBloc(
      repository: serviceLocator<UserContactRepository>(),
    ),
  );

  serviceLocator.registerFactory<CommentBloc>(
        () => CommentBloc(
      commentRepository: serviceLocator<CommentRepository>(),
    ),
  );

  serviceLocator.registerFactory<ReportBloc>(
        () => ReportBloc(
      repository: serviceLocator<ReportRepository>(),
    ),
  );

  serviceLocator.registerFactory<talabnaNotificationBloc>(
        () => talabnaNotificationBloc(
      notificationRepository: serviceLocator<NotificationRepository>(),
    ),
  );

  // 🎨 Theme Management
  serviceLocator.registerSingleton<ThemeCubit>(
    ThemeCubit()..loadTheme(),
  );

  DebugLogger.log('Service locator setup complete', category: 'INIT');
}