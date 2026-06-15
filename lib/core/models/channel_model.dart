import 'message_model.dart';
import 'slot_model.dart';

class ChannelMeta {
  const ChannelMeta({
    required this.passwordHash,
    required this.createdAt,
  });

  final String passwordHash;
  final int createdAt;

  factory ChannelMeta.fromJson(Map<String, dynamic> json) {
    return ChannelMeta(
      passwordHash: json['passwordHash'] as String? ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'passwordHash': passwordHash,
      'createdAt': createdAt,
    };
  }
}

class ChannelModel {
  const ChannelModel({
    required this.name,
    required this.meta,
    required this.slots,
    required this.liveTyping,
    required this.messages,
  });

  final String name;
  final ChannelMeta? meta;
  final Map<String, SlotModel> slots;
  final Map<String, String> liveTyping;
  final Map<String, MessageModel> messages;

  factory ChannelModel.fromJson(String name, Map<String, dynamic> json) {
    final slotJson = (json['slots'] as Map?)?.cast<String, dynamic>() ?? {};
    final typingJson = (json['liveTyping'] as Map?)?.cast<String, dynamic>() ?? {};
    final messageJson = (json['messages'] as Map?)?.cast<String, dynamic>() ?? {};

    return ChannelModel(
      name: name,
      meta: json['meta'] is Map
          ? ChannelMeta.fromJson((json['meta'] as Map).cast<String, dynamic>())
          : null,
      slots: slotJson.map(
        (key, value) => MapEntry(
          key,
          SlotModel.fromJson((value as Map).cast<String, dynamic>()),
        ),
      ),
      liveTyping: typingJson.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      messages: messageJson.map(
        (key, value) => MapEntry(
          key,
          MessageModel.fromJson(key, (value as Map).cast<String, dynamic>()),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meta': meta?.toJson(),
      'slots': slots.map((key, value) => MapEntry(key, value.toJson())),
      'liveTyping': liveTyping,
      'messages': messages.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}