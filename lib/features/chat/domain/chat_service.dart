import '../../../core/models/channel_model.dart';
import '../../../core/models/message_model.dart';
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
  }) {
    return _repository.sendMessage(
      channelName: channelName,
      slotId: slotId,
      nick: nick,
      text: text,
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
  }) {
    return _repository.updateTyping(
      channelName: channelName,
      slotId: slotId,
      text: text,
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

  Stream<String?> watchTyping({
    required String channelName,
    required String slotId,
  }) {
    return _repository.watchTyping(channelName: channelName, slotId: slotId);
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
    return _repository.watchSlotOnline(channelName: channelName, slotId: slotId);
  }
}