import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_provider.dart';
import '../../auth/domain/auth_service.dart';
import '../../chat/presentation/chat_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.session});

  final ChannelSession session;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _emailController = TextEditingController();
  bool _isSaving = false;
  bool _editedByUser = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidGmail(String value) {
    final normalized = value.trim().toLowerCase();
    return RegExp(r'^[^\s@]+@gmail\.com$').hasMatch(normalized);
  }

  Future<void> _saveEmail() async {
    final value = _emailController.text.trim();
    if (!_isValidGmail(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir gmail adresi girin (örn: ad@gmail.com).'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      await ref.read(chatServiceProvider).setNotificationEmail(
            channelName: widget.session.channelName,
            slotId: widget.session.slotId,
            email: value,
          );
      _editedByUser = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim adresi kaydedildi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilemedi, tekrar deneyin.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showNotificationHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bildirim nasıl çalışır?'),
          content: const Text(
            'Karşı taraf sana mesaj yazdığında, sen bir süre boyunca uygulamayı '
            'görüntülemezsen, burada kayıtlı gmail adresine bir bildirim e-postası '
            'gönderilir. Mevcut bildirim kuralları (bekleme süresi vb.) aynen geçerlidir; '
            'burada sadece bildirimin hangi adrese gideceğini belirlersin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final slotState = ref.watch(
      chatSlotProvider((
        channelName: widget.session.channelName,
        slotId: widget.session.slotId,
      )),
    );
    final savedEmail = slotState.value?.notificationEmail;

    if (!_editedByUser) {
      final text = savedEmail ?? '';
      if (_emailController.text != text) {
        _emailController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Bildirim',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 20),
                        tooltip: 'Bildirim nasıl çalışır?',
                        onPressed: _showNotificationHelp,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (savedEmail == null || savedEmail.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Bildirim için gmail adresi girebilirsiniz.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Kayıtlı bildirim adresi: $savedEmail'),
                    ),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Gmail adresi',
                      hintText: 'ad@gmail.com',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      _editedByUser = true;
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveEmail,
                      child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeModeProvider);
              final isDark = themeMode == ThemeMode.dark;
              return Card(
                child: ListTile(
                  leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                  title: const Text('Karanlık Tema'),
                  subtitle: Text(isDark ? 'Karanlık tema aktif' : 'Aydınlık tema aktif'),
                  trailing: FilledButton(
                    onPressed: () {
                      ref.read(themeModeProvider.notifier).toggleDarkMode();
                    },
                    child: Text(
                      isDark ? 'Aydınlık Temaya Geç' : 'Karanlık Temaya Geç',
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
