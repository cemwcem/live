import 'package:flutter/material.dart';

class LiveTypingBox extends StatelessWidget {
  const LiveTypingBox({
    super.key,
    required this.label,
    required this.badgeLabel,
    required this.badgeColor,
    required this.controller,
    required this.enabled,
    required this.readOnly,
    required this.onChanged,
    required this.sendEnabled,
    required this.helperText,
    required this.compact,
    this.onSend,
    this.textTransformer,
    this.showSendButton = true,
    this.showHeader = true,
  });

  final String label;
  final String badgeLabel;
  final Color badgeColor;
  final TextEditingController controller;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSend;
  final bool sendEnabled;
  final String helperText;
  final bool compact;
  final String Function(String text)? textTransformer;
  final bool showSendButton;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, compact ? 6 : 12),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
          ],
          TextField(
            controller: controller,
            enabled: enabled,
            readOnly: readOnly,
            minLines: compact ? 1 : 3,
            maxLines: compact ? 2 : 5,
            onChanged: (value) {
              final transformed = textTransformer?.call(value) ?? value;
              if (transformed != value) {
                controller.value = TextEditingValue(
                  text: transformed,
                  selection: TextSelection.collapsed(offset: transformed.length),
                );
              }
              onChanged(transformed);
            },
            decoration: InputDecoration(
              hintText: 'Canli yazi burada akar',
              isDense: compact,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 10 : 14,
              ),
              helperText: compact ? null : helperText,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: sendEnabled ? (_) => onSend?.call() : null,
          ),
          if (showSendButton) ...[
            SizedBox(height: compact ? 6 : 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: sendEnabled ? onSend : null,
                child: const Text('Gönder'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
