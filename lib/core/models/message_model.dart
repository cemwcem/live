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
    this.attachmentUrl,
    this.attachmentStoragePath,
    this.attachmentFileName,
    this.attachmentMimeType,
    this.isViewOnce = false,
    this.isViewed = false,
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

  // Ek dosya (resim/dosya) alanları — voice message gibi gelecekteki ek
  // türleri de aynı attachmentUrl/attachmentStoragePath/attachmentMimeType
  // üçlüsünü kullanabilir.
  final String? attachmentUrl;
  final String? attachmentStoragePath;
  final String? attachmentFileName;
  final String? attachmentMimeType;
  final bool isViewOnce;
  final bool isViewed;

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImageAttachment =>
      attachmentMimeType != null && attachmentMimeType!.startsWith('image/');

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
    String? attachmentUrl,
    String? attachmentStoragePath,
    String? attachmentFileName,
    String? attachmentMimeType,
    bool? isViewOnce,
    bool? isViewed,
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
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentStoragePath: attachmentStoragePath ?? this.attachmentStoragePath,
      attachmentFileName: attachmentFileName ?? this.attachmentFileName,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      isViewed: isViewed ?? this.isViewed,
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
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentStoragePath: json['attachmentStoragePath'] as String?,
      attachmentFileName: json['attachmentFileName'] as String?,
      attachmentMimeType: json['attachmentMimeType'] as String?,
      isViewOnce: json['isViewOnce'] as bool? ?? false,
      isViewed: json['isViewed'] as bool? ?? false,
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
      'isViewOnce': isViewOnce,
      'isViewed': isViewed,
      ...?replyToMessageId == null
          ? null
          : {'replyToMessageId': replyToMessageId},
      ...?replyToSenderNick == null
          ? null
          : {'replyToSenderNick': replyToSenderNick},
      ...?replyToText == null ? null : {'replyToText': replyToText},
      ...?attachmentUrl == null ? null : {'attachmentUrl': attachmentUrl},
      ...?attachmentStoragePath == null
          ? null
          : {'attachmentStoragePath': attachmentStoragePath},
      ...?attachmentFileName == null
          ? null
          : {'attachmentFileName': attachmentFileName},
      ...?attachmentMimeType == null
          ? null
          : {'attachmentMimeType': attachmentMimeType},
    };
  }
}