import '../../../core/utils/session_storage.dart';
import '../data/auth_repository.dart';

class ChannelSession {
  const ChannelSession({
    required this.channelName,
    required this.nick,
    required this.sessionId,
    required this.slotId,
  });

  final String channelName;
  final String nick;
  final String sessionId;
  final String slotId;
}

class AuthService {
  AuthService(this._repository);

  final AuthRepository _repository;

  Future<ChannelSession> joinChannel({
    required String channelName,
    required String nick,
    required String password,
  }) async {
    final sessionId = await SessionStorage.readOrCreateSessionId(
      channelName: channelName,
      nick: nick,
    );

    final session = await _repository.joinChannel(
      channelName: channelName,
      nick: nick,
      password: password,
      sessionId: sessionId,
    );

    await SessionStorage.saveSessionId(
      channelName: channelName,
      nick: nick,
      sessionId: session.sessionId,
    );
    await SessionStorage.saveActiveSession(session, password: password);

    return session;
  }

  Future<ChannelSession?> resumeLastSession() async {
    final storedSession = await SessionStorage.readActiveSession();
    if (storedSession == null) {
      return null;
    }

    final resumed = await _repository.resumeSession(storedSession);
    await SessionStorage.saveActiveSession(resumed);
    return resumed;
  }
}