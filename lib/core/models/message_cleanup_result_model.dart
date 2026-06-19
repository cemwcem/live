class MessageCleanupResultModel {
  const MessageCleanupResultModel({
    required this.requestId,
    required this.requesterSessionId,
    required this.requesterNick,
    required this.responderNick,
    required this.status,
    required this.completedAt,
    this.deletedCount,
  });

  final String requestId;
  final String requesterSessionId;
  final String requesterNick;
  final String responderNick;
  final String status;
  final int completedAt;
  final int? deletedCount;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory MessageCleanupResultModel.fromJson(Map<String, dynamic> json) {
    return MessageCleanupResultModel(
      requestId: json['requestId'] as String? ?? '',
      requesterSessionId: json['requesterSessionId'] as String? ?? '',
      requesterNick: json['requesterNick'] as String? ?? '',
      responderNick: json['responderNick'] as String? ?? '',
      status: json['status'] as String? ?? '',
      completedAt: (json['completedAt'] as num?)?.toInt() ?? 0,
      deletedCount: (json['deletedCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'requesterSessionId': requesterSessionId,
      'requesterNick': requesterNick,
      'responderNick': responderNick,
      'status': status,
      'completedAt': completedAt,
      'deletedCount': deletedCount,
    };
  }
}