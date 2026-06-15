class SlotModel {
  const SlotModel({
    required this.nick,
    required this.sessionId,
    required this.online,
    required this.lastSeen,
  });

  final String nick;
  final String sessionId;
  final bool online;
  final int lastSeen;

  SlotModel copyWith({
    String? nick,
    String? sessionId,
    bool? online,
    int? lastSeen,
  }) {
    return SlotModel(
      nick: nick ?? this.nick,
      sessionId: sessionId ?? this.sessionId,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      nick: json['nick'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      online: json['online'] as bool? ?? false,
      lastSeen: (json['lastSeen'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nick': nick,
      'sessionId': sessionId,
      'online': online,
      'lastSeen': lastSeen,
    };
  }
}