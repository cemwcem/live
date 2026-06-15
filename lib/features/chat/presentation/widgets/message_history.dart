import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/message_model.dart';

class MessageHistory extends StatelessWidget {
  const MessageHistory({
    super.key,
    required this.messages,
    required this.currentNick,
  });

  final List<MessageModel> messages;
  final String currentNick;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('Henüz mesaj yok'));
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        final isMine = message.senderNick == currentNick;
        final timeText = DateFormat.Hm().format(
          DateTime.fromMillisecondsSinceEpoch(message.timestamp),
        );

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
    );
  }
}