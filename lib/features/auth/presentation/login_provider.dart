import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/session_storage.dart';
import '../data/auth_repository.dart';
import '../domain/auth_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(authRepositoryProvider));
});

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(LoginController.new);

class LoginState {
  const LoginState({
    this.nick = '',
    this.password = '',
    this.channelName = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.session,
  });

  final String nick;
  final String password;
  final String channelName;
  final bool isSubmitting;
  final String? errorMessage;
  final ChannelSession? session;

  bool get isValid => nick.trim().isNotEmpty && password.isNotEmpty && channelName.trim().isNotEmpty;

  LoginState copyWith({
    String? nick,
    String? password,
    String? channelName,
    bool? isSubmitting,
    String? errorMessage,
    ChannelSession? session,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return LoginState(
      nick: nick ?? this.nick,
      password: password ?? this.password,
      channelName: channelName ?? this.channelName,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      session: clearSession ? null : session ?? this.session,
    );
  }
}

class LoginController extends Notifier<LoginState> {
  AuthService get _authService => ref.read(authServiceProvider);

  @override
  LoginState build() {
    return const LoginState();
  }

  void updateNick(String value) => state = state.copyWith(nick: value, clearError: true);
  void updatePassword(String value) => state = state.copyWith(password: value, clearError: true);
  void updateChannelName(String value) => state = state.copyWith(channelName: value, clearError: true);

  Future<void> submit() async {
    if (!state.isValid) {
      state = state.copyWith(errorMessage: 'Tüm alanları doldur', clearSession: true);
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final session = await _authService.joinChannel(
        channelName: state.channelName.trim(),
        nick: state.nick.trim(),
        password: state.password,
      );
      state = state.copyWith(isSubmitting: false, session: session, clearError: true);
    } catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.toString(), clearSession: true);
    }
  }

  Future<ChannelSession?> resumeLastSession() {
    return _authService.resumeLastSession();
  }

  Future<void> hydrateFromCache() async {
    final last = await SessionStorage.readLastCredentials();
    if (last == null) {
      return;
    }

    state = state.copyWith(
      nick: last.nick,
      channelName: last.channelName,
      password: last.password,
      clearError: true,
      clearSession: true,
    );
  }

  void clearTransientSession() {
    state = state.copyWith(clearSession: true, clearError: true);
  }
}