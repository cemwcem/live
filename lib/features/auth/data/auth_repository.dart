import 'package:firebase_database/firebase_database.dart';

import '../../../core/firebase/firebase_service.dart';
import '../../../core/utils/hash_utils.dart';
import '../../../core/utils/client_info.dart';
import '../domain/auth_service.dart';

abstract class AuthRepository {
  Future<ChannelSession> joinChannel({
    required String channelName,
    required String nick,
    required String password,
    required String sessionId,
  });

  Future<ChannelSession> resumeSession(ChannelSession session);
}

class FirebaseAuthRepository implements AuthRepository {
  @override
  Future<ChannelSession> joinChannel({
    required String channelName,
    required String nick,
    required String password,
    required String sessionId,
  }) async {
    if (!FirebaseService.isInitialized) {
      throw StateError('Firebase is not configured yet.');
    }

    final channelRef = FirebaseService.channelReference(channelName);
    if (channelRef == null) {
      throw StateError('Channel reference is unavailable.');
    }

    final metaSnapshot = await channelRef.child('meta').get();
    final passwordHash = HashUtils.sha256Hex(password);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!metaSnapshot.exists) {
      await channelRef.update({
        'meta': {
          'passwordHash': passwordHash,
          'createdAt': now,
        },
        'slots/slot1': {
          'nick': nick,
          'sessionId': sessionId,
          'online': true,
          'lastSeen': now,
        },
        'liveTyping/slot1': '',
        'liveTyping/slot2': '',
      });
      _registerDisconnect(channelRef, 'slot1');
      return ChannelSession(
        channelName: channelName,
        nick: nick,
        sessionId: sessionId,
        slotId: 'slot1',
      );
    }

    final meta = (metaSnapshot.value as Map?)?.cast<String, dynamic>() ?? {};
    final storedHash = meta['passwordHash'] as String? ?? '';
    if (storedHash != passwordHash) {
      throw StateError('Yanlış şifre');
    }

    final slot1Snapshot = await channelRef.child('slots/slot1').get();
    final slot2Snapshot = await channelRef.child('slots/slot2').get();

    final slot1 = _slotFromSnapshot(slot1Snapshot);
    final slot2 = _slotFromSnapshot(slot2Snapshot);

    final existingSlot = _matchingSlot(
      slot1: slot1,
      slot2: slot2,
      nick: nick,
      sessionId: sessionId,
    );
    if (existingSlot != null) {
      await _occupySlot(channelRef, existingSlot, nick, sessionId, now);
      _registerDisconnect(channelRef, existingSlot);
      return ChannelSession(
        channelName: channelName,
        nick: nick,
        sessionId: sessionId,
        slotId: existingSlot,
      );
    }

    final targetSlot = _availableSlot(slot1: slot1, slot2: slot2);
    if (targetSlot == null) {
      throw StateError('Kanal dolu');
    }

    await _occupySlot(channelRef, targetSlot, nick, sessionId, now);
    _registerDisconnect(channelRef, targetSlot);

    return ChannelSession(
      channelName: channelName,
      nick: nick,
      sessionId: sessionId,
      slotId: targetSlot,
    );
  }

  @override
  Future<ChannelSession> resumeSession(ChannelSession session) async {
    if (!FirebaseService.isInitialized) {
      throw StateError('Firebase is not configured yet.');
    }

    final channelRef = FirebaseService.channelReference(session.channelName);
    if (channelRef == null) {
      throw StateError('Channel reference is unavailable.');
    }

    final slotSnapshot = await channelRef.child('slots/${session.slotId}').get();
    final slot = _slotFromSnapshot(slotSnapshot);
    if (slot == null) {
      throw StateError('Oturum bulunamadı');
    }

    if (slot.sessionId != session.sessionId || slot.nick != session.nick) {
      throw StateError('Oturum eşleşmedi');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await _occupySlot(channelRef, session.slotId, session.nick, session.sessionId, now);
    _registerDisconnect(channelRef, session.slotId);

    return session;
  }

  SlotSnapshot? _slotFromSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final json = (snapshot.value as Map).cast<String, dynamic>();
    return SlotSnapshot(
      nick: json['nick'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      online: json['online'] as bool? ?? false,
    );
  }

  String? _matchingSlot({
    required SlotSnapshot? slot1,
    required SlotSnapshot? slot2,
    required String nick,
    required String sessionId,
  }) {
    if (slot1 != null && (slot1.nick == nick || slot1.sessionId == sessionId)) {
      return 'slot1';
    }
    if (slot2 != null && (slot2.nick == nick || slot2.sessionId == sessionId)) {
      return 'slot2';
    }
    return null;
  }

  String? _availableSlot({
    required SlotSnapshot? slot1,
    required SlotSnapshot? slot2,
  }) {
    if (slot1 == null) {
      return 'slot1';
    }
    if (slot2 == null) {
      return 'slot2';
    }
    return null;
  }

  Future<void> _occupySlot(
    DatabaseReference channelRef,
    String slotId,
    String nick,
    String sessionId,
    int now,
  ) async {
    final clientInfo = await ClientInfo.collect();
    await channelRef.child('slots/$slotId').set({
      'nick': nick,
      'sessionId': sessionId,
      'online': true,
      'lastSeen': now,
      'clientInfo': clientInfo,
    });
  }

  void _registerDisconnect(DatabaseReference channelRef, String slotId) {
    channelRef.child('slots/$slotId').onDisconnect().update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }
}

class SlotSnapshot {
  const SlotSnapshot({
    required this.nick,
    required this.sessionId,
    required this.online,
  });

  final String nick;
  final String sessionId;
  final bool online;
}