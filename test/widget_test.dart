import 'package:flutter_test/flutter_test.dart';

import 'package:policy/main.dart';

void main() {
  testWidgets('App widget can be constructed', (WidgetTester tester) async {
    expect(const MakkFinsolApp(), isA<MakkFinsolApp>());
  });
}
