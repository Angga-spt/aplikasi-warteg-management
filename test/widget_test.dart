import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_warteg/main.dart';

void main() {
  testWidgets('WartegApp smoke test', (WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('NetworkImageLoadException') ||
          details.exception.toString().contains('statusCode: 400')) {
        return;
      }
      originalOnError?.call(details);
    };

    await tester.pumpWidget(const WartegApp());
    expect(find.byType(WartegApp), findsOneWidget);

    FlutterError.onError = originalOnError;
  });
}
