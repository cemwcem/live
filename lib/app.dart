import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/firebase_service.dart';
import 'features/auth/domain/auth_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/chat/presentation/chat_screen.dart';
import 'features/auth/presentation/login_provider.dart';

final firebaseBootstrapProvider = FutureProvider<bool>((ref) async {
  return FirebaseService.initialize();
});

final restoredSessionProvider = FutureProvider<ChannelSession?>((ref) async {
  final initialized = await ref.watch(firebaseBootstrapProvider.future);
  if (!initialized) {
    return null;
  }

  return ref.read(authServiceProvider).resumeLastSession();
});

class LiveChatApp extends ConsumerWidget {
  const LiveChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(firebaseBootstrapProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'live',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F8A70),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: bootstrapState.when(
        loading: () => const _SplashScreen(),
        error: (error, stackTrace) => _SetupRequiredScreen(error: error.toString()),
        data: (isConfigured) {
          if (!isConfigured) {
            return const _SetupRequiredScreen();
          }

          return ref.watch(restoredSessionProvider).when(
                loading: () => const _SplashScreen(),
                error: (error, stackTrace) => _SetupRequiredScreen(error: error.toString()),
                data: (session) {
                  if (session != null) {
                    return ChatScreen(session: session);
                  }
                  return const LoginScreen();
                },
              );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _SetupRequiredScreen extends StatelessWidget {
  const _SetupRequiredScreen({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firebase yapılandırması bekleniyor',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Proje iskeleti hazır. Uygulamayı çalıştırmak için FlutterFire ile Firebase seçeneklerini eklemen gerekiyor.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                const SizedBox(height: 24),
                const Text('Sonraki adımlar:'),
                const SizedBox(height: 8),
                const Text('1. firebase project oluştur'),
                const Text('2. flutterfire configure çalıştır'),
                const Text('3. Realtime Database ve Anonymous Auth aç'),
                const Text('4. database.rules.json dosyasını deploy et'),
                const Text('5. Uygulamayı yeniden başlat'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}