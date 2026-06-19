import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.sendInline = false,
    this.showInlineBadge = false,
    this.containerColor,
    this.inputFillColor,
    this.inputBorderColor,
    this.inputTextColor,
    this.showCursorNick = false,
    this.cursorNick,
    this.onCursorChanged,
    this.remoteCursorNick,
    this.remoteCursorOffset,
    this.remoteCursorColor,
    this.maxLength,
    this.onMaxLengthReached,
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
  final bool sendInline;
  final bool showInlineBadge;
  final Color? containerColor;
  final Color? inputFillColor;
  final Color? inputBorderColor;
  final Color? inputTextColor;
  final bool showCursorNick;
  final String? cursorNick;
  final ValueChanged<int>? onCursorChanged;
  final String? remoteCursorNick;
  final int? remoteCursorOffset;
  final Color? remoteCursorColor;
  final int? maxLength;
  final VoidCallback? onMaxLengthReached;

  @override
  Widget build(BuildContext context) {
    final inlineBadgeMaxWidth = (MediaQuery.sizeOf(context).width * 0.16)
        .clamp(72.0, 160.0)
        .toDouble();
    final resolvedBorderColor = inputBorderColor ?? Colors.black26;
    final fieldDecoration = InputDecoration(
      hintText: 'Mesaj',
      isDense: compact,
      filled: true,
      fillColor: inputFillColor ?? Theme.of(context).colorScheme.surface,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 10 : 14,
      ),
      helperText: compact ? null : helperText,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: resolvedBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: resolvedBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: badgeColor.withValues(alpha: 0.7),
          width: 1.4,
        ),
      ),
    );

    final textField = _CursorNickTextField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      minLines: compact ? 1 : 3,
      maxLines: compact ? 2 : 5,
      onChanged: onChanged,
      textTransformer: textTransformer,
      onSubmitted: sendEnabled ? (_) => onSend?.call() : null,
      decoration: fieldDecoration,
      style: TextStyle(color: inputTextColor ?? Colors.black87),
      showCursorNick: showCursorNick,
      cursorNick: cursorNick,
      onCursorChanged: onCursorChanged,
      remoteCursorNick: remoteCursorNick,
      remoteCursorOffset: remoteCursorOffset,
      remoteCursorColor: remoteCursorColor,
      maxLength: maxLength,
      onMaxLengthReached: onMaxLengthReached,
    );

    final trailingBadge = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: inlineBadgeMaxWidth),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
        ),
        child: Text(
          badgeLabel,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: badgeColor, fontWeight: FontWeight.w700),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, compact ? 6 : 12),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color:
            containerColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
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
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailingBadge,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
          ],
          if (sendInline || showInlineBadge) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: textField),
                if (showInlineBadge) ...[
                  const SizedBox(width: 8),
                  trailingBadge,
                ],
                if (showSendButton && sendInline) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: sendEnabled ? onSend : null,
                    child: const Text('Gönder'),
                  ),
                ],
              ],
            ),
          ] else ...[
            textField,
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
        ],
      ),
    );
  }
}

class _CursorNickTextField extends StatefulWidget {
  const _CursorNickTextField({
    required this.controller,
    required this.enabled,
    required this.readOnly,
    required this.minLines,
    required this.maxLines,
    required this.onChanged,
    required this.onSubmitted,
    required this.decoration,
    required this.style,
    required this.showCursorNick,
    required this.cursorNick,
    required this.onCursorChanged,
    required this.remoteCursorNick,
    required this.remoteCursorOffset,
    required this.remoteCursorColor,
    required this.maxLength,
    required this.onMaxLengthReached,
    this.textTransformer,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool readOnly;
  final int minLines;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration decoration;
  final TextStyle style;
  final bool showCursorNick;
  final String? cursorNick;
  final ValueChanged<int>? onCursorChanged;
  final String? remoteCursorNick;
  final int? remoteCursorOffset;
  final Color? remoteCursorColor;
  final int? maxLength;
  final VoidCallback? onMaxLengthReached;
  final String Function(String text)? textTransformer;

  @override
  State<_CursorNickTextField> createState() => _CursorNickTextFieldState();
}

class _CursorNickTextFieldState extends State<_CursorNickTextField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _blinkTimer;
  bool _blinkVisible = true;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
    widget.controller.addListener(_handleTextSelectionChange);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    widget.controller.removeListener(_handleTextSelectionChange);
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus && widget.showCursorNick) {
      _startBlink();
    } else {
      _blinkTimer?.cancel();
      if (_blinkVisible != true) {
        setState(() {
          _blinkVisible = true;
        });
      }
    }
    _emitCursorOffset();
    setState(() {});
  }

  void _handleTextSelectionChange() {
    _emitCursorOffset();
    if (widget.showCursorNick && _focusNode.hasFocus && mounted) {
      setState(() {});
    }
  }

  void _emitCursorOffset() {
    if (widget.onCursorChanged == null) {
      return;
    }
    if (!_focusNode.hasFocus || !widget.controller.selection.isCollapsed) {
      widget.onCursorChanged!(-1);
      return;
    }
    final maxOffset = widget.controller.text.length;
    final offset = widget.controller.selection.extentOffset.clamp(0, maxOffset);
    widget.onCursorChanged!(offset);
  }

  void _startBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 520), (_) {
      if (!mounted || !_focusNode.hasFocus) {
        return;
      }
      setState(() {
        _blinkVisible = !_blinkVisible;
      });
    });
  }

  Offset _estimateCaretOffset({
    required String text,
    required int rawOffset,
    required double maxTextWidth,
    required double horizontalPadding,
    required double verticalPadding,
    required TextStyle style,
    required int maxLines,
  }) {
    var offset = rawOffset;
    if (offset < 0) {
      offset = text.length;
    }
    if (offset > text.length) {
      offset = text.length;
    }

    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxTextWidth);

    final caretOffset = painter.getOffsetForCaret(
      TextPosition(offset: offset),
      Rect.zero,
    );
    final dx = horizontalPadding + caretOffset.dx;
    final dy = verticalPadding + caretOffset.dy;
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final ownSelection = widget.controller.selection;
    final ownOffset = ownSelection.extentOffset < 0
        ? widget.controller.text.length
        : ownSelection.extentOffset;
    final showTag =
        widget.showCursorNick &&
        _focusNode.hasFocus &&
        (widget.cursorNick?.trim().isNotEmpty ?? false) &&
        ownSelection.isCollapsed;

    final remoteOffsetRaw = widget.remoteCursorOffset ?? -1;
    final remoteOffsetClamped = remoteOffsetRaw.clamp(
      0,
      widget.controller.text.length,
    );
    final showRemoteTag =
        (widget.remoteCursorNick?.trim().isNotEmpty ?? false) &&
        remoteOffsetRaw >= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentPadding = widget.decoration.contentPadding;
        final horizontalPadding = contentPadding is EdgeInsets
            ? contentPadding.left
            : 12.0;
        final verticalPadding = contentPadding is EdgeInsets
            ? contentPadding.top
            : 10.0;
        final maxTextWidth = (constraints.maxWidth - (horizontalPadding * 2))
            .clamp(20.0, 2000.0);
        final caretOffset = _estimateCaretOffset(
          text: widget.controller.text,
          rawOffset: ownOffset,
          maxTextWidth: maxTextWidth,
          horizontalPadding: horizontalPadding,
          verticalPadding: verticalPadding,
          style: widget.style,
          maxLines: widget.maxLines,
        );
        final remoteCaretOffset = _estimateCaretOffset(
          text: widget.controller.text,
          rawOffset: remoteOffsetClamped,
          maxTextWidth: maxTextWidth,
          horizontalPadding: horizontalPadding,
          verticalPadding: verticalPadding,
          style: widget.style,
          maxLines: widget.maxLines,
        );
        final ownTagTop = (caretOffset.dy - 10.0).clamp(2.0, 2000.0);
        final remoteTagTop = (remoteCaretOffset.dy - 10.0).clamp(2.0, 2000.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              style: widget.style,
              onChanged: (value) {
                final transformed =
                    widget.textTransformer?.call(value) ?? value;
                if (transformed != value) {
                  widget.controller.value = TextEditingValue(
                    text: transformed,
                    selection: TextSelection.collapsed(
                      offset: transformed.length,
                    ),
                  );
                }
                final maxLength = widget.maxLength;
                if (maxLength != null && transformed.length >= maxLength) {
                  widget.onMaxLengthReached?.call();
                }
                widget.onChanged(transformed);
              },
              decoration: widget.decoration.copyWith(counterText: ''),
              buildCounter: (
                context, {
                required int currentLength,
                required bool isFocused,
                required int? maxLength,
              }) {
                return null;
              },
              onSubmitted: widget.onSubmitted,
            ),
            if (showTag)
              Positioned(
                left: (caretOffset.dx + 11).clamp(
                  8.0,
                  constraints.maxWidth - 8,
                ),
                top: ownTagTop,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _blinkVisible ? 0.96 : 0.68,
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      widget.cursorNick!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF084336),
                      ),
                    ),
                  ),
                ),
              ),
            if (showRemoteTag)
              Positioned(
                left: (remoteCaretOffset.dx + 11).clamp(
                  8.0,
                  constraints.maxWidth - 8,
                ),
                top: remoteTagTop,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _blinkVisible ? 0.97 : 0.7,
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      widget.remoteCursorNick!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color:
                            widget.remoteCursorColor ?? const Color(0xFF083E78),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
