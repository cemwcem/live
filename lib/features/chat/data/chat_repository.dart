import 'package:firebase_database/firebase_database.dart';

import '../../../core/firebase/firebase_service.dart';
import '../../../core/models/channel_model.dart';
import '../../../core/models/cursor_presence_model.dart';
import '../../../core/models/message_model.dart';
import '../../../core/models/slot_model.dart';

abstract class ChatRepository {
  Stream<ChannelModel?> watchChannel({required String channelName});
  Stream<List<MessageModel>> watchMessages({
    required String channelName,
    int limit,
  });
  Future<List<MessageModel>> fetchMessagesPage({
    required String channelName,
    int? endAtTimestamp,
    int limit,
  });
  Stream<String?> watchTyping({
    required String channelName,
    required String slotId,
  });
  Stream<CursorPresenceModel?> watchCursor({
    required String channelName,
    required String slotId,
  });
  Stream<SlotModel?> watchSlot({
    required String channelName,
    required String slotId,
  });
  Stream<bool?> watchSlotOnline({
    required String channelName,
    required String slotId,
  });
  Future<void> sendMessage({
    required String channelName,
    required String slotId,
    required String nick,
    required String text,
  });
  Future<void> acknowledgeMessages({
    required String channelName,
    required String slotId,
    required List<String> messageIds,
    bool markRead,
  });
  Future<void> updateTyping({
    required String channelName,
    required String slotId,
    required String text,
  });
  Future<void> updateCursor({
    required String channelName,
    required String slotId,
    required String nick,
    required int offset,
  });
  Future<void> setOnline({
    required String channelName,
    required String slotId,
    required bool online,
  });
  Future<void> heartbeat({required String channelName, required String slotId});
}

class FirebaseChatRepository implements ChatRepository {
  DatabaseReference? _channelReference(String channelName) {
    return FirebaseService.channelReference(channelName);
  }

  @override
  Stream<ChannelModel?> watchChannel({required String channelName}) {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return Stream<ChannelModel?>.value(null);
    }

    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return null;
      }
      return ChannelModel.fromJson(channelName, value.cast<String, dynamic>());
    });
  }

  @override
  Stream<List<MessageModel>> watchMessages({
    required String channelName,
    int limit = 30,
  }) {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return Stream<List<MessageModel>>.value(const <MessageModel>[]);
    }

    return ref
        .child('messages')
        .orderByChild('timestamp')
        .limitToLast(limit)
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value is! Map) {
            return const <MessageModel>[];
          }

          final messages = <MessageModel>[];
          for (final entry in value.entries) {
            if (entry.value is Map) {
              messages.add(
                MessageModel.fromJson(
                  entry.key.toString(),
                  (entry.value as Map).cast<String, dynamic>(),
                ),
              );
            }
          }

          messages.sort(
            (left, right) => left.timestamp.compareTo(right.timestamp),
          );
          return messages;
        });
  }

  @override
  Future<List<MessageModel>> fetchMessagesPage({
    required String channelName,
    int? endAtTimestamp,
    int limit = 30,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return const <MessageModel>[];
    }

    Query query = ref.child('messages').orderByChild('timestamp');
    if (endAtTimestamp != null) {
      query = query.endAt(endAtTimestamp);
    }
    final snapshot = await query.limitToLast(limit).get();
    final value = snapshot.value;
    if (value is! Map) {
      return const <MessageModel>[];
    }

    final messages = <MessageModel>[];
    for (final entry in value.entries) {
      if (entry.value is Map) {
        messages.add(
          MessageModel.fromJson(
            entry.key.toString(),
            (entry.value as Map).cast<String, dynamic>(),
          ),
        );
      }
    }

    messages.sort((left, right) => left.timestamp.compareTo(right.timestamp));
    return messages;
  }

  @override
  Stream<String?> watchTyping({
    required String channelName,
    required String slotId,
  }) {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return Stream<String?>.value(null);
    }

    return ref.child('liveTyping/$slotId').onValue.map((event) {
      return event.snapshot.value?.toString();
    });
  }

  @override
  Stream<CursorPresenceModel?> watchCursor({
    required String channelName,
    required String slotId,
  }) {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return Stream<CursorPresenceModel?>.value(null);
    }

    return ref.child('liveCursor/$slotId').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return null;
      }
      return CursorPresenceModel.fromJson(value.cast<String, dynamic>());
    });
  }

  @override
  Stream<SlotModel?> watchSlot({
    required String channelName,
    required String slotId,
  }) {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return Stream<SlotModel?>.value(null);
    }

    return ref.child('slots/$slotId').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return null;
      }
      return SlotModel.fromJson(value.cast<String, dynamic>());
    });
  }

  @override
  Future<void> sendMessage({
    required String channelName,
    required String slotId,
    required String nick,
    required String text,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      throw StateError('Firebase is not configured yet.');
    }

    final messageRef = ref.child('messages').push();
    final now = DateTime.now().millisecondsSinceEpoch;
    await messageRef.set({
      'senderNick': nick,
      'senderSlotId': slotId,
      'text': text,
      'timestamp': now,
      'deliveredSlots': {slotId: true},
      'readSlots': {slotId: true},
    });
    await ref.child('liveTyping/$slotId').set('');
    await ref.child('slots/$slotId/lastSeen').set(now);
  }

  @override
  Future<void> acknowledgeMessages({
    required String channelName,
    required String slotId,
    required List<String> messageIds,
    bool markRead = true,
  }) async {
    if (messageIds.isEmpty) {
      return;
    }

    final ref = _channelReference(channelName);
    if (ref == null) {
      return;
    }

    final updates = <String, Object>{};
    for (final messageId in messageIds) {
      updates['messages/$messageId/deliveredSlots/$slotId'] = true;
      if (markRead) {
        updates['messages/$messageId/readSlots/$slotId'] = true;
      }
    }
    updates['slots/$slotId/lastSeen'] = DateTime.now().millisecondsSinceEpoch;

    await ref.update(updates);
  }

  @override
  Future<void> updateTyping({
    required String channelName,
    required String slotId,
    required String text,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return;
    }
    await ref.child('liveTyping/$slotId').set(text);
  }

  @override
  Future<void> updateCursor({
    required String channelName,
    required String slotId,
    required String nick,
    required int offset,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return;
    }

    await ref.child('liveCursor/$slotId').set({
      'nick': nick,
      'offset': offset,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> setOnline({
    required String channelName,
    required String slotId,
    required bool online,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return;
    }
    await ref.child('slots/$slotId').update({
      'online': online,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> heartbeat({
    required String channelName,
    required String slotId,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return;
    }
    await ref
        .child('slots/$slotId/lastSeen')
        .set(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Stream<bool?> watchSlotOnline({
    required String channelName,
    required String slotId,
  }) {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return Stream<bool?>.value(null);
    }

    return ref.child('slots/$slotId/online').onValue.map((event) {
      return event.snapshot.value as bool?;
    });
  }
}
