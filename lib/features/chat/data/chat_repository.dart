import 'package:firebase_database/firebase_database.dart';

import '../../../core/firebase/firebase_service.dart';
import '../../../core/models/channel_model.dart';
import '../../../core/models/cursor_presence_model.dart';
import '../../../core/models/message_model.dart';
import '../../../core/models/message_cleanup_request_model.dart';
import '../../../core/models/message_cleanup_result_model.dart';
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
  Future<int> deleteMessagesByRetention({
    required String channelName,
    Duration? keepDuration,
    int? referenceTimestamp,
  });
  Future<int> deleteRecentMessagesWithin({
    required String channelName,
    required Duration within,
    int? referenceTimestamp,
  });
  Stream<MessageCleanupRequestModel?> watchMessageCleanupRequest({
    required String channelName,
  });
  Future<void> createMessageCleanupRequest({
    required String channelName,
    required String requesterSessionId,
    required String requesterSlotId,
    required String requesterNick,
    Duration? keepDuration,
    bool deleteWithinWindow,
  });
  Stream<MessageCleanupResultModel?> watchMessageCleanupResult({
    required String channelName,
  });
  Future<int?> respondMessageCleanupRequest({
    required String channelName,
    required String requestId,
    required String responderSlotId,
    required String responderNick,
    required bool approve,
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

  Future<void> _touchPresence({
    required DatabaseReference ref,
    required String slotId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await ref.child('slots/$slotId').update({
      'online': true,
      'lastSeen': now,
    });
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
  Future<int> deleteMessagesByRetention({
    required String channelName,
    Duration? keepDuration,
    int? referenceTimestamp,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return 0;
    }
    final effectiveReference =
        referenceTimestamp ?? DateTime.now().millisecondsSinceEpoch;

    final messagesRef = ref.child('messages');
    if (keepDuration == null) {
      final snapshot = await messagesRef
          .orderByChild('timestamp')
          .endAt(effectiveReference)
          .get();
      final value = snapshot.value;
      if (value is! Map) {
        return 0;
      }

      final updates = <String, Object?>{};
      for (final entry in value.entries) {
        updates['messages/${entry.key}'] = null;
      }
      if (updates.isNotEmpty) {
        await ref.update(updates);
      }
      return updates.length;
    }

    final cutoff = effectiveReference - keepDuration.inMilliseconds;
    final snapshot = await messagesRef
        .orderByChild('timestamp')
        .endAt(cutoff)
        .get();
    final value = snapshot.value;
    if (value is! Map) {
      return 0;
    }

    final updates = <String, Object?>{};
    for (final entry in value.entries) {
      updates['messages/${entry.key}'] = null;
    }

    if (updates.isNotEmpty) {
      await ref.update(updates);
    }
    return updates.length;
  }

  @override
  Future<int> deleteRecentMessagesWithin({
    required String channelName,
    required Duration within,
    int? referenceTimestamp,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return 0;
    }
    if (within.inMilliseconds <= 0) {
      return 0;
    }

    final messagesRef = ref.child('messages');
    final effectiveReference =
        referenceTimestamp ?? DateTime.now().millisecondsSinceEpoch;
    final threshold = effectiveReference - within.inMilliseconds;
    final snapshot = await messagesRef
        .orderByChild('timestamp')
        .startAt(threshold)
        .endAt(effectiveReference)
        .get();
    final value = snapshot.value;
    if (value is! Map) {
      return 0;
    }

    final updates = <String, Object?>{};
    for (final entry in value.entries) {
      updates['messages/${entry.key}'] = null;
    }

    if (updates.isNotEmpty) {
      await ref.update(updates);
    }
    return updates.length;
  }

  @override
  Stream<MessageCleanupRequestModel?> watchMessageCleanupRequest({
    required String channelName,
  }) {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return Stream<MessageCleanupRequestModel?>.value(null);
    }

    return ref.child('messageCleanupRequest').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return null;
      }
      final model = MessageCleanupRequestModel.fromJson(
        value.cast<String, dynamic>(),
      );
      if (model.requestId.isEmpty || model.requesterSlotId.isEmpty) {
        return null;
      }
      return model;
    });
  }

  @override
  Future<void> createMessageCleanupRequest({
    required String channelName,
    required String requesterSessionId,
    required String requesterSlotId,
    required String requesterNick,
    Duration? keepDuration,
    bool deleteWithinWindow = false,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      throw StateError('Firebase is not configured yet.');
    }

    final requestRef = ref.child('messageCleanupRequest');
    final existingSnapshot = await requestRef.get();
    if (existingSnapshot.value is Map) {
      throw StateError('Bekleyen bir silme talebi zaten var.');
    }

    final requestId = ref.push().key ?? DateTime.now().millisecondsSinceEpoch.toString();
    final payload = MessageCleanupRequestModel(
      requestId: requestId,
      requesterSessionId: requesterSessionId,
      requesterSlotId: requesterSlotId,
      requesterNick: requesterNick,
      requestedAt: DateTime.now().millisecondsSinceEpoch,
      keepDurationMs: keepDuration?.inMilliseconds,
      cleanupMode: deleteWithinWindow
          ? MessageCleanupRequestModel.modeDeleteWithin
          : MessageCleanupRequestModel.modeDeleteOlderThan,
    );

    await ref.update({
      'messageCleanupResult': null,
      'messageCleanupRequest': payload.toJson(),
    });
  }

  @override
  Stream<MessageCleanupResultModel?> watchMessageCleanupResult({
    required String channelName,
  }) {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return Stream<MessageCleanupResultModel?>.value(null);
    }

    return ref.child('messageCleanupResult').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return null;
      }

      final model = MessageCleanupResultModel.fromJson(
        value.cast<String, dynamic>(),
      );
      if (model.requestId.isEmpty || model.requesterSessionId.isEmpty) {
        return null;
      }
      return model;
    });
  }

  @override
  Future<int?> respondMessageCleanupRequest({
    required String channelName,
    required String requestId,
    required String responderSlotId,
    required String responderNick,
    required bool approve,
  }) async {
    final ref = _channelReference(channelName);
    if (ref == null) {
      return null;
    }

    final requestRef = ref.child('messageCleanupRequest');
    final snapshot = await requestRef.get();
    final value = snapshot.value;
    if (value is! Map) {
      return null;
    }

    final request = MessageCleanupRequestModel.fromJson(
      value.cast<String, dynamic>(),
    );
    if (request.requestId != requestId) {
      return null;
    }
    if (request.requesterSlotId == responderSlotId) {
      return null;
    }

    if (!approve) {
      await ref.update({
        'messageCleanupRequest': null,
        'messageCleanupResult': {
          'requestId': request.requestId,
          'requesterSessionId': request.requesterSessionId,
          'requesterNick': request.requesterNick,
          'responderNick': responderNick,
          'status': 'rejected',
          'completedAt': DateTime.now().millisecondsSinceEpoch,
          'deletedCount': 0,
        },
      });
      return null;
    }

    final referenceTimestamp = request.requestedAt > 0
        ? request.requestedAt
        : DateTime.now().millisecondsSinceEpoch;

    final deletedCount = request.deleteWithinWindow
        ? await deleteRecentMessagesWithin(
            channelName: channelName,
            within: request.keepDuration ?? Duration.zero,
            referenceTimestamp: referenceTimestamp,
          )
        : await deleteMessagesByRetention(
            channelName: channelName,
            keepDuration: request.keepDuration,
            referenceTimestamp: referenceTimestamp,
          );
    await ref.update({
      'messageCleanupRequest': null,
      'messageCleanupResult': {
        'requestId': request.requestId,
        'requesterSessionId': request.requesterSessionId,
        'requesterNick': request.requesterNick,
        'responderNick': responderNick,
        'status': 'approved',
        'completedAt': DateTime.now().millisecondsSinceEpoch,
        'deletedCount': deletedCount,
      },
    });
    return deletedCount;
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
    await _touchPresence(ref: ref, slotId: slotId);
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
    updates['slots/$slotId/online'] = true;
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
    await _touchPresence(ref: ref, slotId: slotId);
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
    await _touchPresence(ref: ref, slotId: slotId);
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
    await _touchPresence(ref: ref, slotId: slotId);
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
