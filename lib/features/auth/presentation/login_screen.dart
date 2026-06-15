import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/presentation/chat_screen.dart';
import 'login_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nickController = TextEditingController();
  final _passwordController = TextEditingController();
  final _channelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(loginControllerProvider.notifier);
      controller.clearTransientSession();
      await controller.hydrateFromCache();
      final current = ref.read(loginControllerProvider);
      if (!mounted) {
        return;
      }
      _nickController.text = current.nick;
      _channelController.text = current.channelName;
      _passwordController.text = current.password;
    });
  }

  @override
  void dispose() {
    _nickController.dispose();
    _passwordController.dispose();
    _channelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LoginState>(loginControllerProvider, (previous, next) {
      final hasNewSession = next.session != null &&
          (previous?.session?.sessionId != next.session?.sessionId ||
              previous?.session?.slotId != next.session?.slotId ||
              previous?.session?.channelName != next.session?.channelName);
      if (hasNewSession) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => ChatScreen(session: next.session!)),
        );
      }
    });

    final state = ref.watch(loginControllerProvider);
    final controller = ref.read(loginControllerProvider.notifier);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('live', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('User, channel, password'),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nickController,
                      decoration: const InputDecoration(labelText: 'User'),
                      onChanged: controller.updateNick,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _channelController,
                      decoration: const InputDecoration(labelText: 'Channel'),
                      onChanged: controller.updateChannelName,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      onChanged: controller.updatePassword,
                    ),
                    const SizedBox(height: 16),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    FilledButton(
                      onPressed: state.isSubmitting ? null : controller.submit,
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Giriş Yap'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}