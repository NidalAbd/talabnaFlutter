import 'package:equatable/equatable.dart';
import 'package:talabna/data/models/point_transaction.dart';

abstract class PointTransactionState extends Equatable {
  const PointTransactionState();

  @override
  List<Object?> get props => [];
}

class PointTransactionInitial extends PointTransactionState {}

class PointTransactionLoading extends PointTransactionState {}

class PointTransactionLoaded extends PointTransactionState {
  final List<PointTransaction> transactions;

  const PointTransactionLoaded({required this.transactions});

  @override
  List<Object?> get props => [transactions];
}

class LastTransactionsLoaded extends PointTransactionState {
  final List<PointTransaction> transactions;

  const LastTransactionsLoaded({required this.transactions});

  @override
  List<Object?> get props => [transactions];
}

class TransactionsBetweenUsersLoaded extends PointTransactionState {
  final List<PointTransaction> transactions;
  final int fromUserId;
  final int toUserId;

  const TransactionsBetweenUsersLoaded({
    required this.transactions,
    required this.fromUserId,
    required this.toUserId,
  });

  @override
  List<Object?> get props => [transactions, fromUserId, toUserId];
}

class PointTransactionError extends PointTransactionState {
  final String message;

  const PointTransactionError({required this.message});

  @override
  List<Object?> get props => [message];
}