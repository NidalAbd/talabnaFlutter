import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_event.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_state.dart';
import 'package:talabna/data/repositories/point_transaction_repository.dart';

class PointTransactionBloc extends Bloc<PointTransactionEvent, PointTransactionState> {
  final PointTransactionRepository repository;

  PointTransactionBloc({required this.repository}) : super(PointTransactionInitial()) {
    on<FetchUserTransactions>(_onFetchUserTransactions);
    on<FetchTransactionsBetweenUsers>(_onFetchTransactionsBetweenUsers);
    on<FetchLastTransactions>(_onFetchLastTransactions);
    on<ClearTransactions>(_onClearTransactions);
  }

  void _onFetchUserTransactions(
      FetchUserTransactions event,
      Emitter<PointTransactionState> emit,
      ) async {
    emit(PointTransactionLoading());
    try {
      final transactions = await repository.getUserTransactions(event.userId);
      emit(PointTransactionLoaded(transactions: transactions));
    } catch (e) {
      emit(PointTransactionError(message: e.toString()));
    }
  }

  void _onFetchTransactionsBetweenUsers(
      FetchTransactionsBetweenUsers event,
      Emitter<PointTransactionState> emit,
      ) async {
    // Always emit loading to show progress and clear previous state
    emit(PointTransactionLoading());

    try {
      print('Fetching transactions between ${event.fromUserId} and ${event.toUserId}');
      final transactions = await repository.getTransactionsBetweenUsers(
        event.fromUserId,
        event.toUserId,
      );

      // Always emit the new state to ensure UI updates
      emit(TransactionsBetweenUsersLoaded(
        transactions: transactions,
        fromUserId: event.fromUserId,
        toUserId: event.toUserId,
      ));

      print('Loaded ${transactions.length} transactions between users');
    } catch (e) {
      print('Error fetching transactions between users: $e');
      emit(PointTransactionError(message: e.toString()));
    }
  }

  void _onFetchLastTransactions(
      FetchLastTransactions event,
      Emitter<PointTransactionState> emit,
      ) async {
    // Always emit loading to show progress and clear previous state
    emit(PointTransactionLoading());

    try {
      print('Fetching last ${event.limit} transactions for user ${event.userId}');
      final transactions = await repository.getLastTransactions(
        event.userId,
        event.limit,
      );

      // Always emit the new state to ensure UI updates
      emit(LastTransactionsLoaded(transactions: transactions));

      print('Loaded ${transactions.length} last transactions');
    } catch (e) {
      print('Error fetching last transactions: $e');
      emit(PointTransactionError(message: e.toString()));
    }
  }

  void _onClearTransactions(
      ClearTransactions event,
      Emitter<PointTransactionState> emit,
      ) {
    // Reset to initial state
    emit(PointTransactionInitial());
  }
}