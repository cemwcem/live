class MessageCleanupRequestModel {
  static const String modeDeleteOlderThan = 'delete_older_than';
  static const String modeDeleteWithin = 'delete_within';

  const MessageCleanupRequestModel({
    required this.requestId,
    required this.requesterSessionId,
    required this.requesterSlotId,
    required this.requesterNick,
    required this.requestedAt,
    required this.keepDurationMs,
    required this.cleanupMode,
  });

  final String requestId;
  final String requesterSessionId;
  final String requesterSlotId;
  final String requesterNick;
  final int requestedAt;
  final int? keepDurationMs;
  final String cleanupMode;

  Duration? get keepDuration {
    final value = keepDurationMs;
    if (value == null || value <= 0) {
      return null;
    }
    return Duration(milliseconds: value);
  }

  bool get deleteWithinWindow => cleanupMode == modeDeleteWithin;

  factory MessageCleanupRequestModel.fromJson(Map<String, dynamic> json) {
    return MessageCleanupRequestModel(
      requestId: json['requestId'] as String? ?? '',
      requesterSessionId: json['requesterSessionId'] as String? ?? '',
      requesterSlotId: json['requesterSlotId'] as String? ?? '',
      requesterNick: json['requesterNick'] as String? ?? '',
      requestedAt: (json['requestedAt'] as num?)?.toInt() ?? 0,
      keepDurationMs: (json['keepDurationMs'] as num?)?.toInt(),
      cleanupMode:
          json['cleanupMode'] as String? ?? modeDeleteOlderThan,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'requesterSessionId': requesterSessionId,
      'requesterSlotId': requesterSlotId,
      'requesterNick': requesterNick,
      'requestedAt': requestedAt,
      'keepDurationMs': keepDurationMs,
      'cleanupMode': cleanupMode,
    };
  }
}