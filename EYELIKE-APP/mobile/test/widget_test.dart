import 'package:flutter_test/flutter_test.dart';

import 'package:eyelike_app/main.dart';

void main() {
  testWidgets('EyeLike app mounts', (WidgetTester tester) async {
    await bootstrap();
    await tester.pumpWidget(const EyelikeApp());
    await tester.pump();
    expect(find.byType(EyelikeApp), findsOneWidget);
  });
}
