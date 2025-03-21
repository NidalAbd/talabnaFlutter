import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/data/repositories/notification_repository.dart';

import 'notifications_event.dart';
import 'notifications_state.dart';

class talabnaNotificationBloc
    extends Bloc<talabnaNotificationEvent, talabnaNotificationState> {
  final NotificationRepository notificationRepository;

  talabnaNotificationBloc({required this.notificationRepository})
      : super(NotificationInitial()) {
    on<FetchNotifications>((event, emit) async {
      emit(NotificationLoading());
      try {
        final notifications = await notificationRepository.getUserNotifications(
            userId: event.userId, page: event.page);
        bool hasReachedMax = notifications.length <
            10; // Assuming 10 is the maximum number of items you fetch in one request
        emit(NotificationLoaded(
            notifications: notifications, hasReachedMax: hasReachedMax));
      } catch (e) {
        emit(NotificationError(message: e.toString()));
      }
    });
    on<MarkNotificationAsRead>((event, emit) async {
      emit(NotificationLoading());
      try {
        await notificationRepository.markNotificationAsRead(
            notificationId: event.notificationId, userId: event.userId);

        emit(OneNotificationRead(notifications: event.notificationId));
      } catch (e) {
        emit(NotificationError(message: e.toString()));
      }
    });
    on<MarkALlNotificationAsRead>((event, emit) async {
      emit(NotificationLoading());
      try {
        await notificationRepository.markAllNotificationAsRead(
            userId: event.userId);
        emit(AllNotificationMarkedRead());
      } catch (e) {
        emit(NotificationError(message: e.toString()));
      }
    });
    on<CountNotificationEvent>((event, emit) async {
      emit(NotificationLoading());
      try {
        final countNotification = await notificationRepository
            .countNotification(userId: event.userId);
        emit(CountNotificationState(countNotification: countNotification));
      } catch (e) {
        emit(NotificationError(message: e.toString()));
      }
    });
  }
}
