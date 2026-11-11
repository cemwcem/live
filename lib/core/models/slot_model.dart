/// "Karşı taraf belli bir süre sonra çevrimiçi olunca mail at" ayarı.
/// Firebase: channels/{kanal}/slots/{slotId}/onlineNotification
///   { enabled: bool, hours: 1 | 2 | 4 | 8 | 24 }
/// Elle düzenlenebilir; Cloud Function (functions/index.js) buradan okur.
class OnlineNotificationSettings {
  const OnlineNotificationSettings({
    this.enabled = false,
    this.hours = defaultHours,
  });

  static const List<int> allowedHours = [1, 2, 4, 8, 24];
  static const int defaultHours = 1;

  final bool enabled;
  final int hours;

  factory OnlineNotificationSettings.fromJson(dynamic json) {
    if (json is! Map) {
      return const OnlineNotificationSettings();
    }
    final hours = (json['hours'] as num?)?.toInt();
    return OnlineNotificationSettings(
      enabled: json['enabled'] == true,
      hours: allowedHours.contains(hours) ? hours! : defaultHours,
    );
  }

  Map<String, dynamic> toJson() => {'enabled': enabled, 'hours': hours};
}

class SlotModel {
  const SlotModel({
    required this.nick,
    required this.sessionId,
    required this.online,
    required this.lastSeen,
    this.clientInfo,
    this.notificationEmail,
    this.onlineNotification = const OnlineNotificationSettings(),
  });

  final String nick;
  final String sessionId;
  final bool online;
  final int lastSeen;
  final Map<String, dynamic>? clientInfo;
  final String? notificationEmail;
  final OnlineNotificationSettings onlineNotification;

  SlotModel copyWith({
    String? nick,
    String? sessionId,
    bool? online,
    int? lastSeen,
    Map<String, dynamic>? clientInfo,
    String? notificationEmail,
    OnlineNotificationSettings? onlineNotification,
  }) {
    return SlotModel(
      nick: nick ?? this.nick,
      sessionId: sessionId ?? this.sessionId,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
      clientInfo: clientInfo ?? this.clientInfo,
      notificationEmail: notificationEmail ?? this.notificationEmail,
      onlineNotification: onlineNotification ?? this.onlineNotification,
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
      notificationEmail: json['notificationEmail'] as String?,
      onlineNotification: OnlineNotificationSettings.fromJson(
        json['onlineNotification'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nick': nick,
      'sessionId': sessionId,
      'online': online,
      'lastSeen': lastSeen,
      'clientInfo': clientInfo,
      'notificationEmail': notificationEmail,
      'onlineNotification': onlineNotification.toJson(),
    };
  }
}
