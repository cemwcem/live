import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/message_model.dart';
import '../../../core/utils/emoji_shortcodes.dart';
import '../../../core/utils/session_storage.dart';
import '../../auth/domain/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import 'emoji_help_screen.dart';
import 'chat_provider.dart';
import 'widgets/live_typing_box.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.session});

  final ChannelSession session;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _composerController = TextEditingController();
  final _peerTypingController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messageItems = [];
  final Set<String> _messageIds = {};
  Timer? _heartbeatTimer;
  bool _initialMessagesLoaded = false;
  bool _loadingOlderMessages = false;
  bool _isScreenActive = true;
  int? _oldestTimestamp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(chatServiceProvider).heartbeat(
            channelName: widget.session.channelName,
            slotId: widget.session.slotId,
          );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialMessages();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _scrollController.dispose();
    _peerTypingController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_isScreenActive == isActive) {
      return;
    }

    _isScreenActive = isActive;
    if (isActive) {
      unawaited(_acknowledgeIncomingMessages(_messageItems, markRead: true));
    }
  }

  Future<void> _loadInitialMessages() async {
    if (_initialMessagesLoaded) {
      return;
    }

    _initialMessagesLoaded = true;
    final messages = await ref.read(chatRepositoryProvider).fetchMessagesPage(
          channelName: widget.session.channelName,
          limit: 30,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _replaceMessages(messages);
    });
    unawaited(_acknowledgeIncomingMessages(messages, markRead: false));
    if (_isScreenActive) {
      unawaited(_acknowledgeIncomingMessages(messages, markRead: true));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _replaceMessages(List<MessageModel> messages) {
    _messageItems.clear();
    _messageIds.clear();
    for (final message in messages) {
      _messageItems.add(message);
      if (message.id != null) {
        _messageIds.add(message.id!);
      }
    }
    _oldestTimestamp = messages.isEmpty ? null : messages.first.timestamp;
  }

  void _mergeIncomingMessages(List<MessageModel> incomingMessages) {
    var changed = false;
    for (final message in incomingMessages) {
      final messageId = message.id;
      if (messageId != null && _messageIds.contains(messageId)) {
        final existingIndex = _messageItems.indexWhere((item) => item.id == messageId);
        if (existingIndex != -1) {
          final existingMessage = _messageItems[existingIndex];
          if (existingMessage.senderNick != message.senderNick ||
              existingMessage.senderSlotId != message.senderSlotId ||
              existingMessage.text != message.text ||
              existingMessage.timestamp != message.timestamp ||
              existingMessage.deliveredSlots.toString() != message.deliveredSlots.toString() ||
              existingMessage.readSlots.toString() != message.readSlots.toString()) {
            _messageItems[existingIndex] = message;
            changed = true;
          }
        }
        continue;
      }
      _messageItems.add(message);
      if (messageId != null) {
        _messageIds.add(messageId);
      }
      changed = true;
    }

    if (incomingMessages.isNotEmpty) {
      _oldestTimestamp ??= incomingMessages.first.timestamp;
    }

    if (changed) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final position = _scrollController.position;
          if (position.pixels > 120) {
            _jumpToBottom();
          }
        }
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _loadingOlderMessages) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    final oldestTimestamp = _oldestTimestamp;
    if (_loadingOlderMessages || oldestTimestamp == null) {
      return;
    }

    _loadingOlderMessages = true;
    setState(() {});

    final olderMessages = await ref.read(chatRepositoryProvider).fetchMessagesPage(
          channelName: widget.session.channelName,
          endAtTimestamp: oldestTimestamp - 1,
          limit: 30,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      if (olderMessages.isNotEmpty) {
        for (final message in olderMessages.reversed) {
          final messageId = message.id;
          if (messageId != null && _messageIds.contains(messageId)) {
            continue;
          }
          _messageItems.insert(0, message);
          if (messageId != null) {
            _messageIds.add(messageId);
          }
        }
        _oldestTimestamp = _messageItems.isEmpty ? null : _messageItems.first.timestamp;
      }
      _loadingOlderMessages = false;
    });
    unawaited(_acknowledgeIncomingMessages(olderMessages, markRead: false));
    if (_isScreenActive) {
      unawaited(_acknowledgeIncomingMessages(olderMessages, markRead: true));
    }
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(0);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDayHeader(DateTime date) {
    const monthNames = <int, String>{
      1: 'Ocak',
      2: 'Şubat',
      3: 'Mart',
      4: 'Nisan',
      5: 'Mayıs',
      6: 'Haziran',
      7: 'Temmuz',
      8: 'Ağustos',
      9: 'Eylül',
      10: 'Ekim',
      11: 'Kasım',
      12: 'Aralık',
    };
    const weekdayNames = <int, String>{
      DateTime.monday: 'Pazartesi',
      DateTime.tuesday: 'Salı',
      DateTime.wednesday: 'Çarşamba',
      DateTime.thursday: 'Perşembe',
      DateTime.friday: 'Cuma',
      DateTime.saturday: 'Cumartesi',
      DateTime.sunday: 'Pazar',
    };

    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'Bugün';
    }
    final month = monthNames[date.month] ?? '';
    final weekday = weekdayNames[date.weekday] ?? '';
    if (date.year == now.year) {
      return '${date.day} $month $weekday';
    }
    return '${date.day} $month ${date.year} $weekday';
  }

  String _formatTime24(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatLastSeenText(int? millis) {
    if (millis == null || millis <= 0) {
      return 'Son aktif: bilinmiyor';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    return 'Son aktif: ${_formatDayHeader(date)} ${_formatTime24(date)}';
  }

  IconData _statusIconForMessage({
    required MessageModel message,
    required String otherSlotId,
  }) {
    final isRead = message.readSlots[otherSlotId] == true;
    final isDelivered = message.deliveredSlots[otherSlotId] == true;
    if (isRead || isDelivered) {
      return Icons.done_all;
    }
    return Icons.done;
  }

  Color _statusColorForMessage({
    required MessageModel message,
    required String otherSlotId,
  }) {
    final isRead = message.readSlots[otherSlotId] == true;
    if (isRead) {
      return Colors.green;
    }
    return Colors.grey;
  }

  Future<void> _acknowledgeIncomingMessages(
    List<MessageModel> messages,
    {
    required bool markRead,
  }) async {
    final idsToAck = <String>[];
    for (final message in messages) {
      final id = message.id;
      if (id == null) {
        continue;
      }
      if (message.senderSlotId == widget.session.slotId) {
        continue;
      }
      final delivered = message.deliveredSlots[widget.session.slotId] == true;
      final read = message.readSlots[widget.session.slotId] == true;
      final needsAck = markRead ? (!delivered || !read) : !delivered;
      if (needsAck) {
        idsToAck.add(id);
      }
    }

    if (idsToAck.isEmpty) {
      return;
    }

    await ref.read(chatServiceProvider).acknowledgeMessages(
          channelName: widget.session.channelName,
          slotId: widget.session.slotId,
          messageIds: idsToAck,
          markRead: markRead,
        );
  }

  @override
  Widget build(BuildContext context) {
    final channelState = ref.watch(chatChannelProvider(widget.session));
    final channel = channelState.value;
    final otherSlotId = widget.session.slotId == 'slot1' ? 'slot2' : 'slot1';
    final ownTypingState = ref.watch(
      chatTypingProvider((
        channelName: widget.session.channelName,
        slotId: widget.session.slotId,
      )),
    );
    final otherOnlineState = ref.watch(
      chatOnlineProvider((
        channelName: widget.session.channelName,
        slotId: otherSlotId,
      )),
    );
    final otherSlotState = ref.watch(
      chatSlotProvider((
        channelName: widget.session.channelName,
        slotId: otherSlotId,
      )),
    );

    final otherNick = channel?.slots[otherSlotId]?.nick ?? 'Karşı taraf';
    final ownNick = widget.session.nick;
    final isOtherOnline = otherOnlineState.value ?? false;
    final otherLastSeen = otherSlotState.value?.lastSeen;

    ref.listen<AsyncValue<List<MessageModel>>>(
      chatMessagesProvider(widget.session),
      (previous, next) {
        final incoming = next.value;
        if (incoming != null && incoming.isNotEmpty) {
          _mergeIncomingMessages(incoming);
          unawaited(_acknowledgeIncomingMessages(incoming, markRead: false));
          if (_isScreenActive) {
            unawaited(_acknowledgeIncomingMessages(incoming, markRead: true));
          }
        }
      },
    );

    ref.listen<AsyncValue<String?>>(
      chatTypingProvider((
        channelName: widget.session.channelName,
        slotId: otherSlotId,
      )),
      (previous, next) {
        final text = next.value ?? '';
        if (_peerTypingController.text != text) {
          _peerTypingController.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      },
    );

    ref.listen<AsyncValue<String?>>(
      chatTypingProvider((
        channelName: widget.session.channelName,
        slotId: widget.session.slotId,
      )),
      (previous, next) {
        final text = next.value ?? '';
        if (_composerController.text != text) {
          _composerController.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('live • ${widget.session.nick}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(chatServiceProvider).setOnline(
                      channelName: widget.session.channelName,
                      slotId: widget.session.slotId,
                      online: false,
                    );
                await SessionStorage.clearActiveSession();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              } else if (value == 'emojis' && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const EmojiHelpScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'emojis', child: Text('Emojiler')),
              const PopupMenuItem(value: 'logout', child: Text('Main Page')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingOlderMessages) const LinearProgressIndicator(minHeight: 2),
          LiveTypingBox(
            label: '',
            badgeLabel: otherNick,
            badgeColor: widget.session.slotId == 'slot1' ? Colors.red : Colors.green,
            controller: _peerTypingController,
            enabled: true,
            readOnly: false,
            onChanged: (value) {
              ref.read(chatServiceProvider).updateTyping(
                    channelName: widget.session.channelName,
                    slotId: otherSlotId,
                    text: value,
                  );
            },
            textTransformer: EmojiShortcodes.emojify,
            onSend: null,
            sendEnabled: false,
            showSendButton: false,
            showHeader: true,
            helperText: 'Bu alanı sadece $otherNick gönderebilir',
            compact: true,
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messageItems.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _initialMessagesLoaded && _messageItems.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: Center(child: Text('Henüz mesaj yok')),
                        )
                      : const SizedBox(height: 8);
                }

                final message = _messageItems[_messageItems.length - index];
                final isMine = message.senderNick == widget.session.nick;
                final messageDate = DateTime.fromMillisecondsSinceEpoch(
                  message.timestamp,
                );
                final previousMessage = index < _messageItems.length
                    ? _messageItems[_messageItems.length - index - 1]
                    : null;
                final previousDate = previousMessage == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        previousMessage.timestamp,
                      );
                final showDayHeader =
                    previousDate == null || !_isSameDay(messageDate, previousDate);
                final timeText = _formatTime24(messageDate);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDayHeader)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text(
                              _formatDayHeader(messageDate),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
                    Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 520),
                        decoration: BoxDecoration(
                          color:
                              isMine ? const Color(0xFFD7F5E8) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.senderNick,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(EmojiShortcodes.emojify(message.text)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeText,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (isMine) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    _statusIconForMessage(
                                      message: message,
                                      otherSlotId: otherSlotId,
                                    ),
                                    size: 16,
                                    color: _statusColorForMessage(
                                      message: message,
                                      otherSlotId: otherSlotId,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          LiveTypingBox(
            label: '',
            badgeLabel: ownNick,
            badgeColor: widget.session.slotId == 'slot1' ? Colors.green : Colors.red,
            controller: _composerController,
            enabled: true,
            readOnly: false,
            onChanged: (value) {
              ref.read(chatServiceProvider).updateTyping(
                    channelName: widget.session.channelName,
                    slotId: widget.session.slotId,
                    text: value,
                  );
            },
            textTransformer: EmojiShortcodes.emojify,
            onSend: () async {
              final text = _composerController.text.trim();
              if (text.isEmpty) {
                return;
              }
              await ref.read(chatServiceProvider).sendMessage(
                    channelName: widget.session.channelName,
                    slotId: widget.session.slotId,
                    nick: widget.session.nick,
                    text: text,
                  );
              _composerController.clear();
            },
            sendEnabled: true,
            showHeader: true,
            helperText: 'Mesajı yalnızca kendi alanından gönderebilirsin',
            compact: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$otherNick: ${isOtherOnline ? '🟢 Online' : '🔴 Offline'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOtherOnline ? Colors.green : Colors.grey,
                      ),
                    ),
                    Text(
                      isOtherOnline
                          ? (otherLastSeen != null && otherLastSeen > 0
                                ? 'Şu an aktif (${_formatTime24(DateTime.fromMillisecondsSinceEpoch(otherLastSeen))})'
                                : 'Şu an aktif')
                          : _formatLastSeenText(otherLastSeen),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if ((ownTypingState.value ?? '').isNotEmpty)
                  Text(
                    '$ownNick yazıyor: ${(ownTypingState.value ?? '').length} karakter',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
