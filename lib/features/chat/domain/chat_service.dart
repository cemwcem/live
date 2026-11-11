import 'dart:typed_data';

import '../../../core/models/channel_model.dart';
import '../../../core/models/cursor_presence_model.dart';
import '../../../core/models/message_model.dart';
import '../../../core/models/message_cleanup_request_model.dart';
import '../../../core/models/message_cleanup_result_model.dart';
import '../../../core/models/slot_model.dart';
import '../data/chat_repository.dart';

class ChatService {
  ChatService(this._repository);

  final ChatRepository _repository;

  Stream<List<MessageModel>> watchMessages(String channelName) {
    return _repository.watchMessages(channelName: channelName);
  }

  Stream<ChannelModel?> watchChannel(String channelName) {
    return _repository.watchChannel(channelName: channelName);
  }

  Future<void> sendMessage({
    required String channelName,
    required String slotId,
    required String nick,
    required String text,
    String? replyToMessageId,
    String? replyToSenderNick,
    String? replyToText,
    String? attachmentUrl,
    String? attachmentStoragePath,
    String? attachmentFileName,
    String? attachmentMimeType,
    bool isViewOnce = false,
  }) {
    return _repository.sendMessage(
      channelName: channelName,
      slotId: slotId,
      nick: nick,
      text: text,
      replyToMessageId: replyToMessageId,
      replyToSenderNick: replyToSenderNick,
      replyToText: replyToText,
      attachmentUrl: attachmentUrl,
      attachmentStoragePath: attachmentStoragePath,
      attachmentFileName: attachmentFileName,
      attachmentMimeType: attachmentMimeType,
      isViewOnce: isViewOnce,
    );
  }

  Future<UploadedAttachment> uploadAttachment({
    required String channelName,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    return _repository.uploadAttachment(
      channelName: channelName,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  Future<void> markAttachmentViewed({
    required String channelName,
    required String messageId,
  }) {
    return _repository.markAttachmentViewed(
      channelName: channelName,
      messageId: messageId,
    );
  }

  Future<int> deleteMessagesByRetention({
    required String channelName,
    Duration? keepDuration,
    int? referenceTimestamp,
  }) {
    return _repository.deleteMessagesByRetention(
      channelName: channelName,
      keepDuration: keepDuration,
      referenceTimestamp: referenceTimestamp,
    );
  }

  Future<int> deleteRecentMessagesWithin({
    required String channelName,
    required Duration within,
    int? referenceTimestamp,
  }) {
    return _repository.deleteRecentMessagesWithin(
      channelName: channelName,
      within: within,
      referenceTimestamp: referenceTimestamp,
    );
  }

  Stream<MessageCleanupRequestModel?> watchMessageCleanupRequest(
    String channelName,
  ) {
    return _repository.watchMessageCleanupRequest(channelName: channelName);
  }

  Future<void> createMessageCleanupRequest({
    required String channelName,
    required String requesterSessionId,
    required String requesterSlotId,
    required String requesterNick,
    Duration? keepDuration,
    bool deleteWithinWindow = false,
  }) {
    return _repository.createMessageCleanupRequest(
      channelName: channelName,
      requesterSessionId: requesterSessionId,
      requesterSlotId: requesterSlotId,
      requesterNick: requesterNick,
      keepDuration: keepDuration,
      deleteWithinWindow: deleteWithinWindow,
    );
  }

  Stream<MessageCleanupResultModel?> watchMessageCleanupResult(
    String channelName,
  ) {
    return _repository.watchMessageCleanupResult(channelName: channelName);
  }

  Future<int?> respondMessageCleanupRequest({
    required String channelName,
    required String requestId,
    required String responderSlotId,
    required String responderNick,
    required bool approve,
  }) {
    return _repository.respondMessageCleanupRequest(
      channelName: channelName,
      requestId: requestId,
      responderSlotId: responderSlotId,
      responderNick: responderNick,
      approve: approve,
    );
  }

  Future<void> acknowledgeMessages({
    required String channelName,
    required String slotId,
    required List<String> messageIds,
    bool markRead = true,
  }) {
    return _repository.acknowledgeMessages(
      channelName: channelName,
      slotId: slotId,
      messageIds: messageIds,
      markRead: markRead,
    );
  }

  Future<void> updateTyping({
    required String channelName,
    required String slotId,
    required String text,
    bool touchPresence = true,
  }) {
    return _repository.updateTyping(
      channelName: channelName,
      slotId: slotId,
      text: text,
      touchPresence: touchPresence,
    );
  }

  Future<void> updateCursor({
    required String channelName,
    required String slotId,
    required String nick,
    required int offset,
    bool touchPresence = true,
  }) {
    return _repository.updateCursor(
      channelName: channelName,
      slotId: slotId,
      nick: nick,
      offset: offset,
      touchPresence: touchPresence,
    );
  }

  Future<void> setOnline({
    required String channelName,
    required String slotId,
    required bool online,
  }) {
    return _repository.setOnline(
      channelName: channelName,
      slotId: slotId,
      online: online,
    );
  }

  Future<void> heartbeat({
    required String channelName,
    required String slotId,
  }) {
    return _repository.heartbeat(channelName: channelName, slotId: slotId);
  }

  Future<void> reconnect() {
    return _repository.reconnect();
  }

  Future<void> setNotificationEmail({
    required String channelName,
    required String slotId,
    required String? email,
  }) {
    return _repository.setNotificationEmail(
      channelName: channelName,
      slotId: slotId,
      email: email,
    );
  }

  Future<void> setOnlineNotification({
    required String channelName,
    required String slotId,
    required OnlineNotificationSettings settings,
  }) {
    return _repository.setOnlineNotification(
      channelName: channelName,
      slotId: slotId,
      settings: settings,
    );
  }

  Stream<String?> watchTyping({
    required String channelName,
    required String slotId,
  }) {
    return _repository.watchTyping(channelName: channelName, slotId: slotId);
  }

  Stream<CursorPresenceModel?> watchCursor({
    required String channelName,
    required String slotId,
  }) {
    return _repository.watchCursor(channelName: channelName, slotId: slotId);
  }

  Stream<SlotModel?> watchSlot({
    required String channelName,
    required String slotId,
  }) {
    return _repository.watchSlot(channelName: channelName, slotId: slotId);
  }

  Stream<bool?> watchSlotOnline({
    required String channelName,
    required String slotId,
  }) {
    return _repository.watchSlotOnline(
      channelName: channelName,
      slotId: slotId,
    );
  }
}
