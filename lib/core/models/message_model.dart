class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderNick,
    required this.text,
    required this.timestamp,
  });

  final String? id;
  final String senderNick;
  final String text;
  final int timestamp;

  MessageModel copyWith({
    String? id,
    String? senderNick,
    String? text,
    int? timestamp,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderNick: senderNick ?? this.senderNick,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory MessageModel.fromJson(String id, Map<String, dynamic> json) {
    return MessageModel(
      id: id,
      senderNick: json['senderNick'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderNick': senderNick,
      'text': text,
      'timestamp': timestamp,
    };
  }
}