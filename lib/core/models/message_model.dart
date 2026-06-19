class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderNick,
    required this.senderSlotId,
    required this.text,
    required this.timestamp,
    required this.deliveredSlots,
    required this.readSlots,
    this.replyToMessageId,
    this.replyToSenderNick,
    this.replyToText,
  });

  final String? id;
  final String senderNick;
  final String senderSlotId;
  final String text;
  final int timestamp;
  final Map<String, bool> deliveredSlots;
  final Map<String, bool> readSlots;
  final String? replyToMessageId;
  final String? replyToSenderNick;
  final String? replyToText;

  MessageModel copyWith({
    String? id,
    String? senderNick,
    String? senderSlotId,
    String? text,
    int? timestamp,
    Map<String, bool>? deliveredSlots,
    Map<String, bool>? readSlots,
    String? replyToMessageId,
    String? replyToSenderNick,
    String? replyToText,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderNick: senderNick ?? this.senderNick,
      senderSlotId: senderSlotId ?? this.senderSlotId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      deliveredSlots: deliveredSlots ?? this.deliveredSlots,
      readSlots: readSlots ?? this.readSlots,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderNick: replyToSenderNick ?? this.replyToSenderNick,
      replyToText: replyToText ?? this.replyToText,
    );
  }

  static Map<String, bool> _boolMapFromJson(dynamic value) {
    if (value is! Map) {
      return const <String, bool>{};
    }
    final result = <String, bool>{};
    for (final entry in value.entries) {
      result[entry.key.toString()] = entry.value == true;
    }
    return result;
  }

  factory MessageModel.fromJson(String id, Map<String, dynamic> json) {
    return MessageModel(
      id: id,
      senderNick: json['senderNick'] as String? ?? '',
      senderSlotId: json['senderSlotId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      deliveredSlots: _boolMapFromJson(json['deliveredSlots']),
      readSlots: _boolMapFromJson(json['readSlots']),
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToSenderNick: json['replyToSenderNick'] as String?,
      replyToText: json['replyToText'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderNick': senderNick,
      'senderSlotId': senderSlotId,
      'text': text,
      'timestamp': timestamp,
      'deliveredSlots': deliveredSlots,
      'readSlots': readSlots,
      ...?replyToMessageId == null
          ? null
          : {'replyToMessageId': replyToMessageId},
      ...?replyToSenderNick == null
          ? null
          : {'replyToSenderNick': replyToSenderNick},
      ...?replyToText == null ? null : {'replyToText': replyToText},
    };
  }
}