import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kanakku_flutter/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  setUpAll(() async {
    // Mock SharedPreferences method channel to avoid dependency warnings and native errors
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return null;
      },
    );

    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummyKey',
    );
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: KanakkuApp()));

    // Wait for initial routing
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
