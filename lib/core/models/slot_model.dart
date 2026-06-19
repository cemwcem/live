class SlotModel {
  const SlotModel({
    required this.nick,
    required this.sessionId,
    required this.online,
    required this.lastSeen,
    this.clientInfo,
  });

  final String nick;
  final String sessionId;
  final bool online;
  final int lastSeen;
  final Map<String, dynamic>? clientInfo;

  SlotModel copyWith({
    String? nick,
    String? sessionId,
    bool? online,
    int? lastSeen,
    Map<String, dynamic>? clientInfo,
  }) {
    return SlotModel(
      nick: nick ?? this.nick,
      sessionId: sessionId ?? this.sessionId,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
      clientInfo: clientInfo ?? this.clientInfo,
    );
  }

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      nick: json['nick'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      online: json['online'] as bool? ?? false,
      lastSeen: (json['lastSeen'] as num?)?.toInt() ?? 0,
      clientInfo: json['clientInfo'] is Map
          ? (json['clientInfo'] as Map).cast<String, dynamic>()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nick': nick,
      'sessionId': sessionId,
      'online': online,
      'lastSeen': lastSeen,
      'clientInfo': clientInfo,
    };
  }
}