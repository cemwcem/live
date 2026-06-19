import 'package:flutter/material.dart';

import '../../../core/utils/emoji_shortcodes.dart';

class EmojiHelpScreen extends StatelessWidget {
  const EmojiHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = EmojiShortcodes.uniqueEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emojiler'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Mesaj yazarken asagidaki klasik kodlari kullanabilirsin. Kod yazildiginda otomatik olarak emojiye donusur.',
                ),
              ),
            );
          }

          final entry = entries[index - 1];
          return ListTile(
            tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Text(entry.emoji, style: const TextStyle(fontSize: 28)),
            title: Text(entry.code),
            subtitle: Text(entry.label),
          );
        },
      ),
    );
  }
}