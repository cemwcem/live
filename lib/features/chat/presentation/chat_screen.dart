import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/session_storage.dart';
import '../../auth/domain/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import 'chat_provider.dart';
import 'widgets/live_typing_box.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.session});

  final ChannelSession session;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composerController = TextEditingController();
  final _peerTypingController = TextEditingController();
  final _scrollController = ScrollController();
  final List<dynamic> _messageItems = [];
  final Set<String> _messageIds = {};
  Timer? _heartbeatTimer;
  bool _initialMessagesLoaded = false;
  bool _loadingOlderMessages = false;
  int? _oldestTimestamp;

  @override
  void initState() {
    super.initState();
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
    _heartbeatTimer?.cancel();
    _scrollController.dispose();
    _peerTypingController.dispose();
    _composerController.dispose();
    super.dispose();
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
    _jumpToBottom();
  }

  void _replaceMessages(List<dynamic> messages) {
    _messageItems.clear();
    _messageIds.clear();
    for (final message in messages) {
      _messageItems.add(message);
      if (message.id != null) {
        _messageIds.add(message.id as String);
      }
    }
    _oldestTimestamp = messages.isEmpty ? null : messages.first.timestamp;
  }

  void _mergeIncomingMessages(List<dynamic> incomingMessages) {
    var changed = false;
    for (final message in incomingMessages) {
      final messageId = message.id as String?;
      if (messageId != null && _messageIds.contains(messageId)) {
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
      if (!_scrollController.hasClients || _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
        _jumpToBottom();
      }
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _loadingOlderMessages) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels <= 160) {
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
        for (final message in olderMessages) {
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
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final channelState = ref.watch(chatChannelProvider(widget.session));
    final channel = channelState.value;
    final otherSlotId = widget.session.slotId == 'slot1' ? 'slot2' : 'slot1';
    final ownTypingState = ref.watch(chatTypingProvider((channelName: widget.session.channelName, slotId: widget.session.slotId)));
    final otherOnlineState = ref.watch(chatOnlineProvider((channelName: widget.session.channelName, slotId: otherSlotId)));

    final otherNick = channel?.slots[otherSlotId]?.nick ?? 'Karşı taraf';
    final ownNick = widget.session.nick;
    final isOtherOnline = otherOnlineState.value ?? false;

    ref.listen<AsyncValue<List<dynamic>>>(chatMessagesProvider(widget.session), (previous, next) {
      final incoming = next.value;
      if (incoming != null && incoming.isNotEmpty) {
        _mergeIncomingMessages(incoming);
      }
    });

    ref.listen<AsyncValue<String?>>(chatTypingProvider((channelName: widget.session.channelName, slotId: otherSlotId)), (previous, next) {
      final text = next.value ?? '';
      if (_peerTypingController.text != text) {
        _peerTypingController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });

    ref.listen<AsyncValue<String?>>(chatTypingProvider((channelName: widget.session.channelName, slotId: widget.session.slotId)), (previous, next) {
      final text = next.value ?? '';
      if (_composerController.text != text) {
        _composerController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });

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
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('Main Page')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingOlderMessages) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
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

                final message = _messageItems[index - 1];
                final isMine = message.senderNick == widget.session.nick;
                final timeText = TimeOfDay.fromDateTime(
                  DateTime.fromMillisecondsSinceEpoch(message.timestamp),
                ).format(context);

                return Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 520),
                    decoration: BoxDecoration(
                      color: isMine ? const Color(0xFFD7F5E8) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.senderNick,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(message.text),
                        const SizedBox(height: 6),
                        Text(
                          timeText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          LiveTypingBox(
            label: 'Karşı tarafın canlı yazısı',
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
            onSend: null,
            sendEnabled: false,
            helperText: 'Bu alanı sadece $otherNick gönderebilir',
            compact: true,
          ),
          LiveTypingBox(
            label: 'Kendi canlı yazın',
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
                      'Canlı durum: ${channel == null ? 'bekleniyor' : 'bağlandı'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if ((ownTypingState.value ?? '').isNotEmpty)
                  Text(
                    '$ownNick yazıyor: ${(ownTypingState.value ?? '').length} karakter',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}