import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_service.dart';
import 'chat_provider.dart';

class MessageCleanupScreen extends ConsumerStatefulWidget {
  MessageCleanupScreen({
    super.key,
    required this.session,
    String? channelName,
  }) : channelName = channelName ?? session.channelName;

  final ChannelSession session;
  final String channelName;

  @override
  ConsumerState<MessageCleanupScreen> createState() =>
      _MessageCleanupScreenState();
}

class _MessageCleanupScreenState extends ConsumerState<MessageCleanupScreen> {
  bool _isDeleting = false;

  Future<_RecentWindowInput?> _askRecentWindowInput() async {
    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '0');
    String? errorText;

    final result = await showDialog<_RecentWindowInput>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Son süre içindekileri sil'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hoursController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Saat'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Dakika'),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () {
                    final hours = int.tryParse(hoursController.text) ?? 0;
                    final minutes = int.tryParse(minutesController.text) ?? 0;
                    if (hours <= 0 && minutes <= 0) {
                      setDialogState(() {
                        errorText = 'En az bir değer 0\'dan büyük olmalı.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(
                      _RecentWindowInput(hours: hours, minutes: minutes),
                    );
                  },
                  child: const Text('Devam'),
                ),
              ],
            );
          },
        );
      },
    );

    hoursController.dispose();
    minutesController.dispose();
    return result;
  }

  String _formatWindowLabel(Duration within) {
    final hours = within.inHours;
    final minutes = within.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '$hours saat $minutes dakika';
    }
    if (hours > 0) {
      return '$hours saat';
    }
    return '$minutes dakika';
  }

  Future<void> _runRecentWindowCleanupRequest() async {
    final input = await _askRecentWindowInput();
    if (input == null || !mounted) {
      return;
    }

    final within = Duration(hours: input.hours, minutes: input.minutes);
    final label = _formatWindowLabel(within);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mesajlar silinsin mi?'),
          content: Text(
            'Son $label içindeki mesajlar silinecek.\n\nBu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await ref
          .read(chatServiceProvider)
          .createMessageCleanupRequest(
            channelName: widget.channelName,
            requesterSessionId: widget.session.sessionId,
            requesterSlotId: widget.session.slotId,
            requesterNick: widget.session.nick,
            keepDuration: within,
            deleteWithinWindow: true,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop({'type': 'request'});
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Talep gönderilemedi.')));
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _runCleanup(_CleanupOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mesajlar silinsin mi?'),
          content: Text(
            '${option.confirmationText}\n\nBu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await ref
          .read(chatServiceProvider)
          .createMessageCleanupRequest(
            channelName: widget.channelName,
            requesterSessionId: widget.session.sessionId,
            requesterSlotId: widget.session.slotId,
            requesterNick: widget.session.nick,
            keepDuration: option.keepDuration,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop({'type': 'request'});
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Talep gönderilemedi.')));
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = <_CleanupOption>[
      const _CleanupOption(
        title: 'Son 1 saat kalsın',
        subtitle: '1 saatten eski mesajlar silinir',
        keepDuration: Duration(hours: 1),
      ),
      const _CleanupOption(
        title: 'Son 6 saat kalsın',
        subtitle: '6 saatten eski mesajlar silinir',
        keepDuration: Duration(hours: 6),
      ),
      const _CleanupOption(
        title: 'Son 24 saat kalsın',
        subtitle: '24 saatten eski mesajlar silinir',
        keepDuration: Duration(hours: 24),
      ),
      const _CleanupOption(
        title: 'Son 7 gün kalsın',
        subtitle: '7 günden eski mesajlar silinir',
        keepDuration: Duration(days: 7),
      ),
      const _CleanupOption(
        title: 'Hepsi silinsin',
        subtitle: 'Bu kanaldaki tüm mesajlar silinir',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mesajları Temizle')),
      body: AbsorbPointer(
        absorbing: _isDeleting,
        child: Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemBuilder: (context, index) {
                final option = options[index];
                return Card(
                  child: ListTile(
                    title: Text(option.title),
                    subtitle: Text(option.subtitle),
                    trailing: const Icon(Icons.delete_outline),
                    onTap: () => _runCleanup(option),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemCount: options.length,
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                child: ListTile(
                  title: const Text('Son ... saat/dakika içindekileri sil'),
                  subtitle: const Text(
                    'Karşı taraf onayı ile silme talebi gönderilir',
                  ),
                  trailing: const Icon(Icons.timer_outlined),
                  onTap: _runRecentWindowCleanupRequest,
                ),
              ),
            ),
            if (_isDeleting)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x88000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CleanupOption {
  const _CleanupOption({
    required this.title,
    required this.subtitle,
    this.keepDuration,
  });

  final String title;
  final String subtitle;
  final Duration? keepDuration;

  String get confirmationText {
    if (keepDuration == null) {
      return 'Tüm mesajlar silinecek. Emin misiniz?';
    }
    return '$title seçeneği uygulanacak. Emin misiniz?';
  }
}

class _RecentWindowInput {
  const _RecentWindowInput({required this.hours, required this.minutes});

  final int hours;
  final int minutes;
}