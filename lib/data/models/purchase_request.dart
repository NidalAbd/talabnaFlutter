class PurchaseRequest {
  final int? id;
  final int? userId;
  final int? pointsRequested;
  final double? pricePerPoint;
  final double? totalPrice;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PurchaseRequest({
    this.id,
    this.userId,
    this.pointsRequested,
    this.pricePerPoint,
    this.totalPrice,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory PurchaseRequest.fromJson(Map<String, dynamic> json) {
    return PurchaseRequest(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      userId: json['user_id'] is String ? int.parse(json['user_id']) : json['user_id'],
      pointsRequested: json['points_requested'] is String
          ? int.parse(json['points_requested'])
          : json['points_requested'],
      pricePerPoint: double.parse(json['price_per_point'].toString()),
      totalPrice: double.parse(json['total_price'].toString()),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'points_requested': pointsRequested,
      'price_per_point': pricePerPoint.toString(),
      'total_price': totalPrice.toString(),
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Fixed to handle null status
  String get normalizedStatus => status?.toLowerCase() ?? 'unknown';

  // Add a debug method to the PurchaseRequest class
  @override
  String toString() {
    return 'PurchaseRequest(id: $id, pointsRequested: $pointsRequested, totalPrice: $totalPrice, status: $status)';
  }

  // Fixed to handle null status
  String get statusDisplay {
    final lowercaseStatus = status?.toLowerCase() ?? 'unknown';
    if (lowercaseStatus == 'approved') return 'Approved';
    if (lowercaseStatus == 'cancelled') return 'Cancelled';
    return 'Pending';
  }
}