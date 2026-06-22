import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/domain/auth_service.dart';

class LastCredentials {
  const LastCredentials({
    required this.channelName,
    required this.nick,
    required this.password,
  });

  final String channelName;
  final String nick;
  final String password;
}

class SessionStorage {
  static String _key({required String channelName, required String nick}) {
    return 'session_${channelName.trim()}_${nick.trim()}';
  }

  static String _cleanupResultSeenKey({
    required String channelName,
    required String sessionId,
  }) {
    return 'cleanup_result_seen_${channelName.trim()}_${sessionId.trim()}';
  }

  static Future<String> readOrCreateSessionId({
    required String channelName,
    required String nick,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(channelName: channelName, nick: nick);
    final existing = prefs.getString(key);

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final sessionId = const Uuid().v4();
    await prefs.setString(key, sessionId);
    return sessionId;
  }

  static Future<void> saveSessionId({
    required String channelName,
    required String nick,
    required String sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(channelName: channelName, nick: nick), sessionId);
  }

  static Future<void> saveActiveSession(ChannelSession session, {String password = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'active_session',
      '${session.channelName}|${session.nick}|${session.sessionId}|${session.slotId}',
    );
    await saveLastCredentials(
      channelName: session.channelName,
      nick: session.nick,
      password: password,
    );
  }

  static Future<ChannelSession?> readActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('active_session');
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final parts = raw.split('|');
    if (parts.length != 4) {
      return null;
    }

    return ChannelSession(
      channelName: parts[0],
      nick: parts[1],
      sessionId: parts[2],
      slotId: parts[3],
    );
  }

  static Future<void> saveLastCredentials({
    required String channelName,
    required String nick,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_channel_name', channelName);
    await prefs.setString('last_nick', nick);
    await prefs.setString('last_password', password);
  }

  static Future<LastCredentials?> readLastCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final channelName = prefs.getString('last_channel_name') ?? '';
    final nick = prefs.getString('last_nick') ?? '';
    final password = prefs.getString('last_password') ?? '';

    if (channelName.isEmpty || nick.isEmpty || password.isEmpty) {
      return null;
    }

    return LastCredentials(
      channelName: channelName,
      nick: nick,
      password: password,
    );
  }

  static Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session');
  }

  static Future<void> saveLastShownCleanupResultId({
    required String channelName,
    required String sessionId,
    required String requestId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cleanupResultSeenKey(channelName: channelName, sessionId: sessionId),
      requestId,
    );
  }

  static Future<String?> readLastShownCleanupResultId({
    required String channelName,
    required String sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
      _cleanupResultSeenKey(channelName: channelName, sessionId: sessionId),
    );
  }
}