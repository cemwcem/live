import 'package:flutter/material.dart';

/// Sohbet ekranına özel renkler; açık ve karanlık tema için tek kaynak.
/// Kullanım: `final colors = ChatColors.of(context);`
@immutable
class ChatColors extends ThemeExtension<ChatColors> {
  const ChatColors({
    required this.myBubble,
    required this.myBubbleBorder,
    required this.otherBubble,
    required this.otherBubbleBorder,
    required this.myReply,
    required this.myReplyBorder,
    required this.otherReply,
    required this.otherReplyBorder,
    required this.myText,
    required this.otherText,
    required this.metaText,
    required this.dayChip,
    required this.dayChipBorder,
    required this.peerBox,
    required this.peerInputFill,
    required this.peerInputBorder,
    required this.peerInputText,
    required this.ownBox,
    required this.ownInputFill,
    required this.ownInputBorder,
    required this.ownInputText,
    required this.ownCursorNick,
    required this.remoteCursor,
    required this.link,
    required this.subtle,
    required this.divider,
  });

  final Color myBubble;
  final Color myBubbleBorder;
  final Color otherBubble;
  final Color otherBubbleBorder;
  final Color myReply;
  final Color myReplyBorder;
  final Color otherReply;
  final Color otherReplyBorder;
  final Color myText;
  final Color otherText;
  final Color metaText;
  final Color dayChip;
  final Color dayChipBorder;
  final Color peerBox;
  final Color peerInputFill;
  final Color peerInputBorder;
  final Color peerInputText;
  final Color ownBox;
  final Color ownInputFill;
  final Color ownInputBorder;
  final Color ownInputText;
  final Color ownCursorNick;
  final Color remoteCursor;
  final Color link;

  /// Ek dosya kutuları vb. için hafif vurgu zemini.
  final Color subtle;
  final Color divider;

  static const light = ChatColors(
    myBubble: Color(0xFFDDF7EA),
    myBubbleBorder: Color(0xFFC5E8D7),
    otherBubble: Color(0xFFF1F4F8),
    otherBubbleBorder: Color(0xFFD9E0E8),
    myReply: Color(0xFFCBEEDC),
    myReplyBorder: Color(0xFFB4DCC8),
    otherReply: Color(0xFFE6ECF2),
    otherReplyBorder: Color(0xFFD3DBE3),
    myText: Color(0xDD000000),
    otherText: Color(0xFF324D67),
    metaText: Color(0x8A000000),
    dayChip: Color(0xFFF5F5F5),
    dayChipBorder: Color(0x1F000000),
    peerBox: Color(0xFFE9EFF6),
    peerInputFill: Color(0xFFF6F9FC),
    peerInputBorder: Color(0xFFBCCBDB),
    peerInputText: Color(0xFF3E5A77),
    ownBox: Color(0xFFEAF8EF),
    ownInputFill: Color(0xFFF8FCF9),
    ownInputBorder: Color(0xFFBFDCCB),
    ownInputText: Color(0xDD000000),
    ownCursorNick: Color(0xFF084336),
    remoteCursor: Color(0xFF0A4F96),
    link: Color(0xFF0A58CA),
    subtle: Color(0x0F000000),
    divider: Color(0x1F000000),
  );

  static const dark = ChatColors(
    myBubble: Color(0xFF1E4D3B),
    myBubbleBorder: Color(0xFF2C6A52),
    otherBubble: Color(0xFF26313D),
    otherBubbleBorder: Color(0xFF34414F),
    myReply: Color(0xFF2A5E49),
    myReplyBorder: Color(0xFF3A7A60),
    otherReply: Color(0xFF303C4A),
    otherReplyBorder: Color(0xFF425062),
    myText: Color(0xFFE6F2EC),
    otherText: Color(0xFFD5E1EE),
    metaText: Color(0xFF9AA8B6),
    dayChip: Color(0xFF2A323B),
    dayChipBorder: Color(0xFF3A444F),
    peerBox: Color(0xFF1C2631),
    peerInputFill: Color(0xFF222D39),
    peerInputBorder: Color(0xFF3A4A5C),
    peerInputText: Color(0xFFC9D7E6),
    ownBox: Color(0xFF17281F),
    ownInputFill: Color(0xFF1D3027),
    ownInputBorder: Color(0xFF355A47),
    ownInputText: Color(0xFFE6F2EC),
    ownCursorNick: Color(0xFF7FD6B4),
    remoteCursor: Color(0xFF7DB5F0),
    link: Color(0xFF8AB4F8),
    subtle: Color(0x14FFFFFF),
    divider: Color(0x29FFFFFF),
  );

  static ChatColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ChatColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  ChatColors copyWith() => this;

  @override
  ChatColors lerp(ThemeExtension<ChatColors>? other, double t) {
    if (other is! ChatColors) {
      return this;
    }
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ChatColors(
      myBubble: l(myBubble, other.myBubble),
      myBubbleBorder: l(myBubbleBorder, other.myBubbleBorder),
      otherBubble: l(otherBubble, other.otherBubble),
      otherBubbleBorder: l(otherBubbleBorder, other.otherBubbleBorder),
      myReply: l(myReply, other.myReply),
      myReplyBorder: l(myReplyBorder, other.myReplyBorder),
      otherReply: l(otherReply, other.otherReply),
      otherReplyBorder: l(otherReplyBorder, other.otherReplyBorder),
      myText: l(myText, other.myText),
      otherText: l(otherText, other.otherText),
      metaText: l(metaText, other.metaText),
      dayChip: l(dayChip, other.dayChip),
      dayChipBorder: l(dayChipBorder, other.dayChipBorder),
      peerBox: l(peerBox, other.peerBox),
      peerInputFill: l(peerInputFill, other.peerInputFill),
      peerInputBorder: l(peerInputBorder, other.peerInputBorder),
      peerInputText: l(peerInputText, other.peerInputText),
      ownBox: l(ownBox, other.ownBox),
      ownInputFill: l(ownInputFill, other.ownInputFill),
      ownInputBorder: l(ownInputBorder, other.ownInputBorder),
      ownInputText: l(ownInputText, other.ownInputText),
      ownCursorNick: l(ownCursorNick, other.ownCursorNick),
      remoteCursor: l(remoteCursor, other.remoteCursor),
      link: l(link, other.link),
      subtle: l(subtle, other.subtle),
      divider: l(divider, other.divider),
    );
  }
}
