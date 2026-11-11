import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/slot_model.dart';
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
  bool _isSavingOnline = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidGmail(String value) {
    final normalized = value.trim().toLowerCase();
    return RegExp(r'^[^\s@]+@gmail\.com$').hasMatch(normalized);
  }

  Future<void> _saveEmail({String? overrideValue}) async {
    final value = overrideValue ?? _emailController.text.trim();
    if (value.isNotEmpty && !_isValidGmail(value)) {
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
          SnackBar(
            content: Text(
              value.isEmpty ? 'Bildirim adresi kaldırıldı.' : 'Bildirim adresi kaydedildi.',
            ),
          ),
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

  Future<void> _saveOnlineNotification(OnlineNotificationSettings settings) async {
    setState(() {
      _isSavingOnline = true;
    });
    try {
      await ref.read(chatServiceProvider).setOnlineNotification(
            channelName: widget.session.channelName,
            slotId: widget.session.slotId,
            settings: settings,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilemedi, tekrar deneyin.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingOnline = false;
        });
      }
    }
  }

  String _hoursLabel(int hours) => hours == 24 ? '24 saat (1 gün)' : '$hours saat';

  Widget _buildOnlineNotificationCard({
    required OnlineNotificationSettings settings,
    required bool hasEmail,
    required String otherNickHint,
  }) {
    final isTestChannel = _isTestChannel(widget.session.channelName);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: const EdgeInsets.only(left: 8),
              controlAffinity: ListTileControlAffinity.leading,
              value: settings.enabled,
              onChanged: _isSavingOnline
                  ? null
                  : (value) => _saveOnlineNotification(
                        OnlineNotificationSettings(
                          enabled: value ?? false,
                          hours: settings.hours,
                        ),
                      ),
              title: const Text('Karşı taraf çevrimiçi olunca bildir'),
              subtitle: Text(
                '$otherNickHint, seçtiğin süreden uzun süre çevrimdışı kaldıktan '
                'sonra çevrimiçi olursa bildirim adresine e-posta gönderilir.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  const Text('Çevrimdışı kalma süresi:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: settings.hours,
                    onChanged: !settings.enabled || _isSavingOnline
                        ? null
                        : (value) {
                            if (value == null) return;
                            _saveOnlineNotification(
                              OnlineNotificationSettings(
                                enabled: settings.enabled,
                                hours: value,
                              ),
                            );
                          },
                    items: [
                      for (final hours in OnlineNotificationSettings.allowedHours)
                        DropdownMenuItem(
                          value: hours,
                          child: Text(_hoursLabel(hours)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (settings.enabled && !hasEmail)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Text(
                  'Bildirim gitmesi için yukarıya gmail adresi kaydetmelisin.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (settings.enabled && isTestChannel)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Text(
                  'Test kanalı: süre $_onlineTestDivisor\'de birine kısaltılır '
                  '(${_formatTestDuration(settings.hours)}).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// functions/config.js → ONLINE_TEST_DIVISOR ile aynı tutulmalı.
  static const int _onlineTestDivisor = 100;

  String _formatTestDuration(int hours) {
    final totalSeconds = (hours * 3600 / _onlineTestDivisor).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) return '$seconds saniye';
    if (seconds == 0) return '$minutes dakika';
    return '$minutes dakika $seconds saniye';
  }

  /// functions/index.js → resolveChannelType ile aynı kural.
  bool _isTestChannel(String channelName) {
    final normalized = channelName.toLowerCase();
    return normalized.startsWith('deneme') || normalized.startsWith('test');
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
    // Ayar her zaman Firebase'deki slot verisinden okunur (elle yapılan
    // değişiklikler de anında yansır).
    final onlineSettings = slotState.value?.onlineNotification ??
        const OnlineNotificationSettings();
    final otherSlotId = widget.session.slotId == 'slot1' ? 'slot2' : 'slot1';
    final otherNick = ref
        .watch(
          chatSlotProvider((
            channelName: widget.session.channelName,
            slotId: otherSlotId,
          )),
        )
        .value
        ?.nick;
    final otherNickHint =
        otherNick == null || otherNick.isEmpty ? 'Karşı taraf' : otherNick;

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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (savedEmail != null && savedEmail.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => _saveEmail(overrideValue: ''),
                              child: const Text('Kaldır'),
                            ),
                          ),
                        FilledButton(
                          onPressed: _isSaving ? null : () => _saveEmail(),
                          child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildOnlineNotificationCard(
            settings: onlineSettings,
            hasEmail: savedEmail != null && savedEmail.isNotEmpty,
            otherNickHint: otherNickHint,
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
