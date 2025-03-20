import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'internet_event.dart';
import 'internet_state.dart';

class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  late final StreamSubscription<InternetConnectionStatus> _subscription;
  final InternetConnectionChecker _internetChecker =
      InternetConnectionChecker.createInstance();

  NetworkBloc() : super(NetworkInitial()) {
    on<NetworkObserve>(_observe);
    on<NetworkNotify>(_notifyStatus);
  }

  void _observe(NetworkObserve event, Emitter<NetworkState> emit) async {
    final bool hasConnection = await _internetChecker.hasConnection;
    if (hasConnection) {
      emit(NetworkSuccess());
    } else {
      emit(NetworkFailure());
    }

    _subscription = _internetChecker.onStatusChange.listen((status) {
      add(NetworkNotify(
          isConnected: status == InternetConnectionStatus.connected));
    });
  }

  void _notifyStatus(NetworkNotify event, Emitter<NetworkState> emit) {
    emit(event.isConnected ? NetworkSuccess() : NetworkFailure());
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
