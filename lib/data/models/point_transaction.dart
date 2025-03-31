import 'package:talabna/data/models/user.dart';

class PointTransaction {
  final int id;
  final int? fromUserId;
  final int? toUserId;
  final String type;
  final int point;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Optional user objects that may be populated from relations
  final User? fromUser;
  final User? toUser;

  PointTransaction({
    required this.id,
    this.fromUserId,
    this.toUserId,
    required this.type,
    required this.point,
    this.createdAt,
    this.updatedAt,
    this.fromUser,
    this.toUser,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id'],
      fromUserId: json['from_user_id'],
      toUserId: json['to_user_id'],
      type: json['type'],
      point: json['point'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      fromUser: json['from_user'] != null ? User.fromJson(json['from_user']) : null,
      toUser: json['to_user'] != null ? User.fromJson(json['to_user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'type': type,
      'point': point,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      // We don't include the User objects in toJson as they're relations
    };
  }

  // Helper method to determine if the transaction is incoming for a given user
  bool isIncoming(int userId) {
    return toUserId == userId && fromUserId != userId;
  }

  // Helper method to determine if the transaction is outgoing for a given user
  bool isOutgoing(int userId) {
    return fromUserId == userId && toUserId != userId;
  }

  // Get the "other user" for display when showing a transaction (helps with UI)
  int? getOtherUserId(int currentUserId) {
    if (fromUserId == currentUserId) {
      return toUserId;
    } else if (toUserId == currentUserId) {
      return fromUserId;
    }
    return null;
  }

  // Get display name for transaction type
  String getTypeDisplayName() {
    switch (type) {
      case 'purchase':
        return 'Purchase';
      case 'transfer':
        return 'Transfer';
      case 'admin_grant':
        return 'Admin Grant';
      case 'used':
        return 'Used';
      default:
        return type;
    }
  }
}

// For use with BLoC state
class PointTransactionList {
  final List<PointTransaction> transactions;

  PointTransactionList({required this.transactions});
}