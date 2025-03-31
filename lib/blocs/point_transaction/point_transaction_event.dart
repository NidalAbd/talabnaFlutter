import 'package:equatable/equatable.dart';

abstract class PointTransactionEvent extends Equatable {
  const PointTransactionEvent();

  @override
  List<Object?> get props => [];
}

class FetchUserTransactions extends PointTransactionEvent {
  final int userId;

  const FetchUserTransactions({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class FetchTransactionsBetweenUsers extends PointTransactionEvent {
  final int fromUserId;
  final int toUserId;

  const FetchTransactionsBetweenUsers({
    required this.fromUserId,
    required this.toUserId,
  });

  @override
  List<Object?> get props => [fromUserId, toUserId];
}

class FetchLastTransactions extends PointTransactionEvent {
  final int userId;
  final int limit;

  const FetchLastTransactions({required this.userId, this.limit = 5});

  @override
  List<Object?> get props => [userId, limit];
}

class ClearTransactions extends PointTransactionEvent {}