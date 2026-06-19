import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/channel_model.dart';
import '../../../core/models/cursor_presence_model.dart';
import '../../../core/models/message_model.dart';
import '../../../core/models/message_cleanup_request_model.dart';
import '../../../core/models/message_cleanup_result_model.dart';
import '../../../core/models/slot_model.dart';
import '../../auth/domain/auth_service.dart';
import '../data/chat_repository.dart';
import '../domain/chat_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return FirebaseChatRepository();
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(chatRepositoryProvider));
});

final chatChannelProvider =
    StreamProvider.family<ChannelModel?, ChannelSession>((ref, session) {
      return ref.watch(chatServiceProvider).watchChannel(session.channelName);
    });

final chatMessagesProvider =
    StreamProvider.family<List<MessageModel>, ChannelSession>((ref, session) {
      return ref.watch(chatServiceProvider).watchMessages(session.channelName);
    });

final chatMessageCleanupRequestProvider =
    StreamProvider.family<MessageCleanupRequestModel?, ChannelSession>((
      ref,
      session,
    ) {
      return ref
          .watch(chatServiceProvider)
          .watchMessageCleanupRequest(session.channelName);
    });

final chatMessageCleanupResultProvider =
    StreamProvider.family<MessageCleanupResultModel?, ChannelSession>((
      ref,
      session,
    ) {
      return ref
          .watch(chatServiceProvider)
          .watchMessageCleanupResult(session.channelName);
    });

final chatTypingProvider =
    StreamProvider.family<String?, ({String channelName, String slotId})>((
      ref,
      params,
    ) {
      return ref
          .watch(chatServiceProvider)
          .watchTyping(channelName: params.channelName, slotId: params.slotId);
    });

final chatCursorProvider =
    StreamProvider.family<
      CursorPresenceModel?,
      ({String channelName, String slotId})
    >((ref, params) {
      return ref
          .watch(chatServiceProvider)
          .watchCursor(channelName: params.channelName, slotId: params.slotId);
    });

final chatOnlineProvider =
    StreamProvider.family<bool?, ({String channelName, String slotId})>((
      ref,
      params,
    ) {
      return ref
          .watch(chatServiceProvider)
          .watchSlotOnline(
            channelName: params.channelName,
            slotId: params.slotId,
          );
    });

final chatSlotProvider =
    StreamProvider.family<SlotModel?, ({String channelName, String slotId})>((
      ref,
      params,
    ) {
      return ref
          .watch(chatServiceProvider)
          .watchSlot(channelName: params.channelName, slotId: params.slotId);
    });
