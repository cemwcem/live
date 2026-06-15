import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:live_chat_app/app.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const LiveChatApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
