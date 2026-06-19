import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_release.dart';
import '../../../core/models/message_model.dart';
import '../../../core/utils/emoji_shortcodes.dart';
import '../../../core/utils/session_storage.dart';
import '../../auth/domain/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import 'emoji_help_screen.dart';
import 'message_cleanup_screen.dart';
import 'chat_provider.dart';
import 'widgets/live_typing_box.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.session});

  final ChannelSession session;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  static const int _maxMessageChars = 2000;
  static const int _typingIndicatorGraceMs = 2200;

  final _composerController = TextEditingController();
  final _peerTypingController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messageItems = [];
  final Set<String> _messageIds = {};
  final Map<String, GlobalKey> _messageBubbleKeys = {};
  Timer? _heartbeatTimer;
  Timer? _typingOwnDebounce;
  Timer? _typingPeerDebounce;
  Timer? _cursorOwnDebounce;
  Timer? _cursorPeerDebounce;
  bool _initialMessagesLoaded = false;
  bool _loadingOlderMessages = false;
  bool _isScreenActive = true;
  int? _oldestTimestamp;
  String? _activeCleanupRequestDialogId;
  String? _lastHandledCleanupResultId;
  bool _charLimitWarningVisible = false;
  int? _remoteOwnTypingLastActiveMs;
  int? _remoteOtherTypingLastActiveMs;
  MessageModel? _replyTarget;
  String? _hoveredMessageId;
  String? _menuOpenMessageId;
  bool _jumpToReplyInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref
          .read(chatServiceProvider)
          .heartbeat(
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
    _typingOwnDebounce?.cancel();
    _typingPeerDebounce?.cancel();
    _cursorOwnDebounce?.cancel();
    _cursorPeerDebounce?.cancel();
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
    final messages = await ref
        .read(chatRepositoryProvider)
        .fetchMessagesPage(channelName: widget.session.channelName, limit: 30);
    if (!context.mounted) {
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
    _messageBubbleKeys.clear();
    for (final message in messages) {
      _messageItems.add(message);
      if (message.id != null) {
        _messageIds.add(message.id!);
        _messageBubbleKeys.putIfAbsent(message.id!, GlobalKey.new);
      }
    }
    _oldestTimestamp = messages.isEmpty ? null : messages.first.timestamp;
  }

  void _mergeIncomingMessages(List<MessageModel> incomingMessages) {
    var changed = false;
    for (final message in incomingMessages) {
      final messageId = message.id;
      if (messageId != null && _messageIds.contains(messageId)) {
        final existingIndex = _messageItems.indexWhere(
          (item) => item.id == messageId,
        );
        if (existingIndex != -1) {
          final existingMessage = _messageItems[existingIndex];
          if (existingMessage.senderNick != message.senderNick ||
              existingMessage.senderSlotId != message.senderSlotId ||
              existingMessage.text != message.text ||
              existingMessage.timestamp != message.timestamp ||
              existingMessage.replyToMessageId != message.replyToMessageId ||
              existingMessage.replyToSenderNick != message.replyToSenderNick ||
              existingMessage.replyToText != message.replyToText ||
              existingMessage.deliveredSlots.toString() !=
                  message.deliveredSlots.toString() ||
              existingMessage.readSlots.toString() !=
                  message.readSlots.toString()) {
            _messageItems[existingIndex] = message;
            changed = true;
          }
        }
        continue;
      }
      _messageItems.add(message);
      if (messageId != null) {
        _messageIds.add(messageId);
        _messageBubbleKeys.putIfAbsent(messageId, GlobalKey.new);
      }
      changed = true;
    }

    if (incomingMessages.isNotEmpty) {
      _oldestTimestamp ??= incomingMessages.first.timestamp;
    }

    if (changed) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_jumpToReplyInProgress) {
          return;
        }
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

    final olderMessages = await ref
        .read(chatRepositoryProvider)
        .fetchMessagesPage(
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
            _messageBubbleKeys.putIfAbsent(messageId, GlobalKey.new);
          }
        }
        _oldestTimestamp = _messageItems.isEmpty
            ? null
            : _messageItems.first.timestamp;
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

  void _showMessageLimitWarning() {
    if (!mounted || _charLimitWarningVisible) {
      return;
    }
    _charLimitWarningVisible = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Karakter sınırına ulaşıldı.')),
    );
  }

  String _replyPreviewText(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 80) {
      return normalized;
    }
    return '${normalized.substring(0, 80)}...';
  }

  void _setReplyTarget(MessageModel message) {
    setState(() {
      _replyTarget = message;
    });
  }

  void _clearReplyTarget() {
    if (_replyTarget == null) {
      return;
    }
    setState(() {
      _replyTarget = null;
    });
  }

  Future<void> _openMessageActions(MessageModel message) async {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Mesaja yanıt ver'),
                subtitle: Text(
                  _replyPreviewText(EmojiShortcodes.emojify(message.text)),
                ),
                onTap: () => Navigator.of(context).pop('reply'),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Kopyala'),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (selected == 'reply') {
      _setReplyTarget(message);
    } else if (selected == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (!mounted) {
        return;
      }
      messenger?.showSnackBar(const SnackBar(content: Text('Mesaj kopyalandı.')));
    }
  }

  Future<void> _handleMessageMenuAction({
    required String action,
    required MessageModel message,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (action == 'reply') {
      _setReplyTarget(message);
      return;
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (!mounted) {
        return;
      }
      messenger?.showSnackBar(const SnackBar(content: Text('Mesaj kopyalandı.')));
    }
  }

  Future<bool> _ensureMessageLoaded(String messageId) async {
    if (_messageIds.contains(messageId)) {
      return true;
    }

    var oldestTimestamp = _oldestTimestamp;
    while (oldestTimestamp != null) {
      final olderMessages = await ref
          .read(chatRepositoryProvider)
          .fetchMessagesPage(
            channelName: widget.session.channelName,
            endAtTimestamp: oldestTimestamp - 1,
            limit: 80,
          );
      if (olderMessages.isEmpty) {
        return false;
      }

      if (!mounted) {
        return false;
      }

      setState(() {
        for (final message in olderMessages.reversed) {
          final id = message.id;
          if (id != null && _messageIds.contains(id)) {
            continue;
          }
          _messageItems.insert(0, message);
          if (id != null) {
            _messageIds.add(id);
            _messageBubbleKeys.putIfAbsent(id, GlobalKey.new);
          }
        }
        _oldestTimestamp =
            _messageItems.isEmpty ? null : _messageItems.first.timestamp;
      });

      if (_messageIds.contains(messageId)) {
        return true;
      }

      final nextOldestTimestamp = _oldestTimestamp;
      if (nextOldestTimestamp == oldestTimestamp) {
        break;
      }
      oldestTimestamp = nextOldestTimestamp;
    }

    return _messageIds.contains(messageId);
  }

  Future<bool> _bringMessageIntoViewport(String messageId) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if (_messageBubbleKeys[messageId]?.currentContext != null) {
        return true;
      }
      if (!_scrollController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        continue;
      }

      final index = _messageItems.indexWhere((item) => item.id == messageId);
      if (index == -1) {
        return false;
      }
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        continue;
      }

      final ratio = _messageItems.length <= 1
          ? 0.0
          : 1 - (index / (_messageItems.length - 1));
      final viewport = _scrollController.position.viewportDimension;
      final jitter = attempt.isEven ? 0.0 : viewport * 0.18;
      final estimatedOffset =
          (maxScroll * ratio + jitter).clamp(0.0, maxScroll).toDouble();
      _scrollController.jumpTo(estimatedOffset);
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }

    return _messageBubbleKeys[messageId]?.currentContext != null;
  }

  Future<void> _jumpToMessageById(String? messageId) async {
    if (messageId == null || messageId.isEmpty || _jumpToReplyInProgress) {
      return;
    }

    _jumpToReplyInProgress = true;
    try {
      final loaded = await _ensureMessageLoaded(messageId);
      if (!mounted || !loaded) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) {
        return;
      }

      final hasTargetInViewport = await _bringMessageIntoViewport(messageId);
      if (!mounted || !hasTargetInViewport) {
        return;
      }

      final targetContext = _messageBubbleKeys[messageId]?.currentContext;
      if (targetContext == null || !targetContext.mounted) {
        return;
      }

      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    } finally {
      _jumpToReplyInProgress = false;
    }
  }

  bool _canPlaceMetaInline({
    required String text,
    required TextStyle textStyle,
    required double maxWidth,
    required double trailingMetaWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final lines = painter.computeLineMetrics();
    if (lines.isEmpty) {
      return true;
    }

    final lastLineWidth = lines.last.width;
    return maxWidth - lastLineWidth >= trailingMetaWidth;
  }

  Widget _buildMessageMetaSlot({
    required bool isMine,
    required bool showHoverMenuButton,
    required String otherSlotId,
    required MessageModel message,
  }) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isMine)
            Opacity(
              opacity: showHoverMenuButton ? 0 : 1,
              child: Icon(
                _statusIconForMessage(message: message, otherSlotId: otherSlotId),
                size: 16,
                color: _statusColorForMessage(
                  message: message,
                  otherSlotId: otherSlotId,
                ),
              ),
            ),
          Opacity(
            opacity: showHoverMenuButton ? 1 : 0,
            child: IgnorePointer(
              ignoring: !showHoverMenuButton,
              child: PopupMenuButton<String>(
                tooltip: 'Mesaj menüsü',
                padding: EdgeInsets.zero,
                splashRadius: 14,
                constraints: const BoxConstraints(minWidth: 130),
                onOpened: () {
                  setState(() {
                    _menuOpenMessageId = message.id;
                  });
                },
                onCanceled: () {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    if (_menuOpenMessageId == message.id) {
                      _menuOpenMessageId = null;
                    }
                  });
                },
                onSelected: (value) {
                  setState(() {
                    if (_menuOpenMessageId == message.id) {
                      _menuOpenMessageId = null;
                    }
                  });
                  _handleMessageMenuAction(action: value, message: message);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'reply', child: Text('Yanıtla')),
                  PopupMenuItem(value: 'copy', child: Text('Kopyala')),
                ],
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAboutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hakkında'),
          content: Text(
            'live chat\nRelease: ${AppRelease.name} (${AppRelease.version})\nDeploy tarihi: ${AppRelease.deployedAt}\n\nNot: Deploy oncesi release bilgisi guncellenir.',
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

  bool _isSlotEffectivelyOnline({
    required bool? online,
    required int? lastSeen,
    required int nowMillis,
  }) {
    if (online == true) {
      return true;
    }
    if (lastSeen == null || lastSeen <= 0) {
      return false;
    }
    return nowMillis - lastSeen <= 45000;
  }

  void _scheduleTypingUpdate({
    required String targetSlotId,
    required String text,
  }) {
    final debounce = targetSlotId == widget.session.slotId
        ? _typingOwnDebounce
        : _typingPeerDebounce;
    debounce?.cancel();

    final timer = Timer(const Duration(milliseconds: 180), () {
      ref
          .read(chatServiceProvider)
          .updateTyping(
            channelName: widget.session.channelName,
            slotId: targetSlotId,
            text: text,
          );
    });

    if (targetSlotId == widget.session.slotId) {
      _typingOwnDebounce = timer;
    } else {
      _typingPeerDebounce = timer;
    }
  }

  void _scheduleCursorUpdate({
    required String targetSlotId,
    required String nick,
    required int offset,
  }) {
    final debounce = targetSlotId == widget.session.slotId
        ? _cursorOwnDebounce
        : _cursorPeerDebounce;
    debounce?.cancel();

    final timer = Timer(const Duration(milliseconds: 120), () {
      ref
          .read(chatServiceProvider)
          .updateCursor(
            channelName: widget.session.channelName,
            slotId: targetSlotId,
            nick: nick,
            offset: offset,
          );
    });

    if (targetSlotId == widget.session.slotId) {
      _cursorOwnDebounce = timer;
    } else {
      _cursorPeerDebounce = timer;
    }
  }

  String _cleanupOptionTitle(Duration? keepDuration) {
    if (keepDuration == null) {
      return 'Hepsi silinsin';
    }
    if (keepDuration.inHours == 1) {
      return 'Son 1 saat kalsın';
    }
    if (keepDuration.inHours == 6) {
      return 'Son 6 saat kalsın';
    }
    if (keepDuration.inHours == 24) {
      return 'Son 24 saat kalsın';
    }
    if (keepDuration.inDays == 7) {
      return 'Son 7 gün kalsın';
    }
    return 'Mesaj temizleme talebi';
  }

  String _durationLabel(Duration? duration) {
    if (duration == null) {
      return '';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '$hours saat $minutes dakika';
    }
    if (hours > 0) {
      return '$hours saat';
    }
    return '$minutes dakika';
  }

  void _showIncomingCleanupDialogIfNeeded({
    required String requestId,
    required String requesterNick,
    required Duration? keepDuration,
    required bool deleteWithinWindow,
    required int requestedAt,
  }) {
    if (_activeCleanupRequestDialogId == requestId || !mounted) {
      return;
    }

    _activeCleanupRequestDialogId = requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final requestDate = requestedAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(requestedAt)
          : DateTime.now();
      final requestTimeLabel =
          '${_formatDayHeader(requestDate)} ${_formatTime24(requestDate)}';

      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Mesaj silme onayı'),
            content: Text(
              '$requesterNick mesajları temizlemek istiyor.\n\nSeçim: ${deleteWithinWindow ? 'Son ${_durationLabel(keepDuration)} içindekiler silinsin' : _cleanupOptionTitle(keepDuration)}\nTalep zamanı: $requestTimeLabel\n\nOnaylıyor musun?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Reddet'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Onayla'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      final deletedCount = await ref
          .read(chatServiceProvider)
          .respondMessageCleanupRequest(
            channelName: widget.session.channelName,
            requestId: requestId,
            responderSlotId: widget.session.slotId,
            responderNick: widget.session.nick,
            approve: approved == true,
          );

      if (!mounted) {
        return;
      }

      if (approved == true) {
        final text = deletedCount != null && deletedCount > 0
            ? '$deletedCount mesaj silindi.'
            : 'Mesajlar temizlendi.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj silme talebini reddettiniz.')),
        );
      }

      _initialMessagesLoaded = false;
      await _loadInitialMessages();
      _activeCleanupRequestDialogId = null;
    });
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
    List<MessageModel> messages, {
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

    await ref
        .read(chatServiceProvider)
        .acknowledgeMessages(
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
    final otherTypingState = ref.watch(
      chatTypingProvider((
        channelName: widget.session.channelName,
        slotId: otherSlotId,
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
    final ownCursorState = ref.watch(
      chatCursorProvider((
        channelName: widget.session.channelName,
        slotId: widget.session.slotId,
      )),
    );
    final otherCursorState = ref.watch(
      chatCursorProvider((
        channelName: widget.session.channelName,
        slotId: otherSlotId,
      )),
    );

    final otherNick = channel?.slots[otherSlotId]?.nick ?? 'Karşı taraf';
    final otherSlot = otherSlotState.value;
    final otherLastSeen = otherSlot?.lastSeen;
    final ownNick =
      channel?.slots[widget.session.slotId]?.nick ?? widget.session.nick;
    final isOtherOnline = _isSlotEffectivelyOnline(
      online: otherSlot?.online ?? otherOnlineState.value,
      lastSeen: otherLastSeen,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    final statusText = isOtherOnline
      ? (otherLastSeen != null && otherLastSeen > 0
          ? 'Şu an aktif (${_formatTime24(DateTime.fromMillisecondsSinceEpoch(otherLastSeen))})'
          : 'Şu an aktif')
      : _formatLastSeenText(otherLastSeen);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final ownSlotCursor = ownCursorState.value;
    final otherSlotCursor = otherCursorState.value;

    final showRemoteCursorOnOwnSlot =
        ownSlotCursor != null &&
        ownSlotCursor.nick != ownNick &&
        ownSlotCursor.offset >= 0 &&
        nowMillis - ownSlotCursor.updatedAt <= 12000;
    final showRemoteCursorOnOtherSlot =
        otherSlotCursor != null &&
        otherSlotCursor.nick != ownNick &&
        otherSlotCursor.offset >= 0 &&
        nowMillis - otherSlotCursor.updatedAt <= 12000;
    if (showRemoteCursorOnOwnSlot) {
      _remoteOwnTypingLastActiveMs = nowMillis;
    }
    if (showRemoteCursorOnOtherSlot) {
      _remoteOtherTypingLastActiveMs = nowMillis;
    }

    final ownAreaText = ownTypingState.value ?? '';
    final otherAreaText = otherTypingState.value ?? '';
    final showRemoteTypingOwnArea =
        ownAreaText.isNotEmpty &&
        _remoteOwnTypingLastActiveMs != null &&
        nowMillis - _remoteOwnTypingLastActiveMs! <= _typingIndicatorGraceMs;
    final showRemoteTypingOtherArea =
        otherAreaText.isNotEmpty &&
        _remoteOtherTypingLastActiveMs != null &&
        nowMillis - _remoteOtherTypingLastActiveMs! <= _typingIndicatorGraceMs;
    final remoteTypingOwnAreaText = showRemoteTypingOwnArea
        ? '$otherNick yazıyor: ${ownAreaText.length} karakter.'
        : null;
    final remoteTypingOtherAreaText = showRemoteTypingOtherArea
        ? '$otherNick yazıyor: ${otherAreaText.length} karakter.'
        : null;

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

    ref.listen(chatMessageCleanupRequestProvider(widget.session), (
      previous,
      next,
    ) {
      final request = next.value;
      if (request == null) {
        _activeCleanupRequestDialogId = null;
        return;
      }

      if (request.requesterSlotId == widget.session.slotId) {
        return;
      }

      _showIncomingCleanupDialogIfNeeded(
        requestId: request.requestId,
        requesterNick: request.requesterNick,
        keepDuration: request.keepDuration,
        deleteWithinWindow: request.deleteWithinWindow,
        requestedAt: request.requestedAt,
      );
    });

    ref.listen(chatMessageCleanupResultProvider(widget.session), (
      previous,
      next,
    ) async {
      final result = next.value;
      if (result == null) {
        return;
      }
      if (result.requesterSessionId != widget.session.sessionId) {
        return;
      }
      if (_lastHandledCleanupResultId == result.requestId) {
        return;
      }

      _lastHandledCleanupResultId = result.requestId;
      if (!mounted) {
        return;
      }

      final text = result.isApproved
          ? 'Silme onaylandı (${result.responderNick}) ve tamamlandı. ${result.deletedCount ?? 0} mesaj silindi.'
          : 'Silme talebi ${result.responderNick} tarafından reddedildi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

      if (result.isApproved) {
        _initialMessagesLoaded = false;
        await _loadInitialMessages();
      }
    });

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
        title: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                '#${widget.session.channelName}   $otherNick: ${isOtherOnline ? '🟢 Online' : '🔴 Offline'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await ref
                    .read(chatServiceProvider)
                    .setOnline(
                      channelName: widget.session.channelName,
                      slotId: widget.session.slotId,
                      online: false,
                    );
                await SessionStorage.clearActiveSession();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    (_) => false,
                  );
                }
              } else if (value == 'emojis' && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EmojiHelpScreen(),
                  ),
                );
              } else if (value == 'cleanup' && context.mounted) {
                final cleanupResult =
                    await Navigator.of(context).push<Map<String, Object?>>(
                  MaterialPageRoute<Map<String, Object?>>(
                    builder: (_) => MessageCleanupScreen(
                      session: widget.session,
                    ),
                  ),
                );

                if (!context.mounted || cleanupResult == null) {
                  return;
                }

                final type = cleanupResult['type'] as String?;
                if (type == 'request') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Silme talebi gönderildi. Karşı tarafın onayı bekleniyor.',
                      ),
                    ),
                  );
                  return;
                }
              } else if (value == 'about' && context.mounted) {
                await _showAboutDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'emojis', child: Text('Emojiler')),
              const PopupMenuItem(
                value: 'cleanup',
                child: Text('Mesajları temizle'),
              ),
              const PopupMenuItem(value: 'about', child: Text('Hakkında')),
              const PopupMenuItem(value: 'logout', child: Text('Main Page')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingOlderMessages)
            const LinearProgressIndicator(minHeight: 2),
          LiveTypingBox(
            label: '',
            badgeLabel: otherNick,
            badgeColor: const Color(0xFF4B6A88),
            controller: _peerTypingController,
            enabled: true,
            readOnly: false,
            onChanged: (value) {
              if (value.length >= _maxMessageChars) {
                _showMessageLimitWarning();
              } else {
                _charLimitWarningVisible = false;
              }
              _scheduleTypingUpdate(targetSlotId: otherSlotId, text: value);
            },
            textTransformer: EmojiShortcodes.emojify,
            onSend: null,
            sendEnabled: false,
            showSendButton: false,
            showHeader: false,
            showInlineBadge: true,
            maxLength: _maxMessageChars,
            onMaxLengthReached: _showMessageLimitWarning,
            showCursorNick: true,
            cursorNick: ownNick,
            containerColor: const Color(0xFFE9EFF6),
            inputFillColor: const Color(0xFFF6F9FC),
            inputBorderColor: const Color(0xFFBCCBDB),
            inputTextColor: const Color(0xFF3E5A77),
            onCursorChanged: (offset) {
              _scheduleCursorUpdate(
                targetSlotId: otherSlotId,
                nick: ownNick,
                offset: offset,
              );
            },
            remoteCursorNick: showRemoteCursorOnOtherSlot
                ? otherSlotCursor.nick
                : null,
            remoteCursorOffset: showRemoteCursorOnOtherSlot
                ? otherSlotCursor.offset
                : null,
            remoteCursorColor: const Color(0xFF0A4F96),
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
                    previousDate == null ||
                    !_isSameDay(messageDate, previousDate);
                final timeText = _formatTime24(messageDate);
                final replyTextRaw = message.replyToText;
                final replyNickRaw = message.replyToSenderNick;
                final hasReply =
                  (replyTextRaw?.isNotEmpty ?? false) &&
                  (replyNickRaw?.isNotEmpty ?? false);
                final replyText = hasReply
                  ? _replyPreviewText(EmojiShortcodes.emojify(replyTextRaw!))
                  : null;
                final showHoverMenuButton = message.id != null &&
                    (_hoveredMessageId == message.id ||
                        _menuOpenMessageId == message.id);

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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMine
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: MouseRegion(
                              onEnter: (_) {
                                if (message.id == null) {
                                  return;
                                }
                                setState(() {
                                  _hoveredMessageId = message.id;
                                });
                              },
                              onExit: (_) {
                                if (_hoveredMessageId != message.id ||
                                    _menuOpenMessageId == message.id) {
                                  return;
                                }
                                setState(() {
                                  _hoveredMessageId = null;
                                });
                              },
                              child: GestureDetector(
                                onLongPress: () => _openMessageActions(message),
                                child: Container(
                                  key: message.id != null
                                      ? _messageBubbleKeys.putIfAbsent(
                                          message.id!,
                                          GlobalKey.new,
                                        )
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  constraints: const BoxConstraints(maxWidth: 520),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? const Color(0xFFDDF7EA)
                                        : const Color(0xFFF1F4F8),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: Radius.circular(
                                        isMine ? 18 : 6,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMine ? 6 : 18,
                                      ),
                                    ),
                                    border: Border.all(
                                      color: isMine
                                          ? const Color(0xFFC5E8D7)
                                          : const Color(0xFFD9E0E8),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMine
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (hasReply)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _jumpToMessageById(
                                            message.replyToMessageId,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isMine
                                                  ? const Color(0xFFCBEEDC)
                                                  : const Color(0xFFE6ECF2),
                                              borderRadius: BorderRadius.circular(
                                                10,
                                              ),
                                              border: Border.all(
                                                color: isMine
                                                    ? const Color(0xFFB4DCC8)
                                                    : const Color(0xFFD3DBE3),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  replyNickRaw!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  replyText!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Builder(
                                        builder: (context) {
                                          final messageText = EmojiShortcodes.emojify(
                                            message.text,
                                          );
                                          final messageTextStyle = TextStyle(
                                            color: isMine
                                                ? Colors.black87
                                                : const Color(0xFF324D67),
                                          );
                                          final timeStyle = Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(color: Colors.black54) ??
                                              const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              );

                                          final metaWidget = Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(timeText, style: timeStyle),
                                              const SizedBox(width: 6),
                                              _buildMessageMetaSlot(
                                                isMine: isMine,
                                                showHoverMenuButton:
                                                    showHoverMenuButton,
                                                otherSlotId: otherSlotId,
                                                message: message,
                                              ),
                                            ],
                                          );

                                          // Metnin sonuna görünmez placeholder ekleyerek
                                          // meta için yer ayrılır; meta Stack ile
                                          // her zaman sağ-alt köşeye sabitlenir.
                                          return Stack(
                                            children: [
                                              Text.rich(
                                                TextSpan(
                                                  style: messageTextStyle,
                                                  children: [
                                                    TextSpan(text: messageText),
                                                    const WidgetSpan(
                                                      alignment:
                                                          PlaceholderAlignment
                                                              .middle,
                                                      child: SizedBox(
                                                        width: 72,
                                                        height: 20,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: metaWidget,
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 90),
                            child: Text(
                              message.senderNick,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                  ),
                            ),
                          ),
                        ],
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
            badgeColor: widget.session.slotId == 'slot1'
                ? Colors.green
                : Colors.red,
            controller: _composerController,
            enabled: true,
            readOnly: false,
            onChanged: (value) {
              if (value.length >= _maxMessageChars) {
                _showMessageLimitWarning();
              } else {
                _charLimitWarningVisible = false;
              }
              _scheduleTypingUpdate(
                targetSlotId: widget.session.slotId,
                text: value,
              );
            },
            textTransformer: EmojiShortcodes.emojify,
            onSend: () async {
              final text = _composerController.text.trim();
              if (text.isEmpty) {
                return;
              }
              final replyTarget = _replyTarget;
              await ref
                  .read(chatServiceProvider)
                  .sendMessage(
                    channelName: widget.session.channelName,
                    slotId: widget.session.slotId,
                    nick: widget.session.nick,
                    text: text,
                    replyToMessageId: replyTarget?.id,
                    replyToSenderNick: replyTarget?.senderNick,
                    replyToText: replyTarget == null
                        ? null
                        : _replyPreviewText(
                            EmojiShortcodes.emojify(replyTarget.text),
                          ),
                  );
              _composerController.clear();
              _charLimitWarningVisible = false;
              _clearReplyTarget();
            },
            sendEnabled: true,
            showHeader: false,
            sendInline: true,
            maxLength: _maxMessageChars,
            onMaxLengthReached: _showMessageLimitWarning,
            showCursorNick: true,
            cursorNick: ownNick,
            containerColor: const Color(0xFFEAF8EF),
            inputFillColor: const Color(0xFFF8FCF9),
            inputBorderColor: const Color(0xFFBFDCCB),
            inputTextColor: Colors.black87,
            onCursorChanged: (offset) {
              _scheduleCursorUpdate(
                targetSlotId: widget.session.slotId,
                nick: ownNick,
                offset: offset,
              );
            },
            remoteCursorNick: showRemoteCursorOnOwnSlot
                ? ownSlotCursor.nick
                : null,
            remoteCursorOffset: showRemoteCursorOnOwnSlot
                ? ownSlotCursor.offset
                : null,
            remoteCursorColor: const Color(0xFF0A4F96),
            helperText: 'Mesajı yalnızca kendi alanından gönderebilirsin',
            compact: true,
            replyPreviewNick: _replyTarget?.senderNick,
            replyPreviewText: _replyTarget == null
                ? null
                : _replyPreviewText(
                    EmojiShortcodes.emojify(_replyTarget!.text),
                  ),
            onClearReply: _clearReplyTarget,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (remoteTypingOwnAreaText != null)
                  Text(
                    remoteTypingOwnAreaText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (remoteTypingOwnAreaText != null &&
                    remoteTypingOtherAreaText != null)
                  const SizedBox(height: 2),
                if (remoteTypingOtherAreaText != null)
                  Text(
                    remoteTypingOtherAreaText,
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
