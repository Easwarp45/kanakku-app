import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('DB test with dummy UUID', () async {
    SharedPreferences.setMockInitialValues({});

    // Load env
    await dotenv.load(fileName: ".env");

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['VITE_SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['VITE_SUPABASE_ANON_KEY'] ?? '',
    );

    final client = Supabase.instance.client;
    final dummyGroupId = '00000000-0000-0000-0000-000000000000';

    // 1. Try inserting with 'custom'
    try {
      print('Attempting to insert with split_type: custom and dummy group ID...');
      await client.from('group_expenses').insert({
        'group_id': dummyGroupId,
        'amount': 10.0,
        'description': 'Test Custom Constraint',
        'category': 'other',
        'split_type': 'custom',
      }).select();
      print('SUCCESS with custom (unexpected, should have failed FK)');
    } catch (e) {
      print('RESULT for custom: $e');
    }

    // 2. Try inserting with 'unequal'
    try {
      print('Attempting to insert with split_type: unequal and dummy group ID...');
      await client.from('group_expenses').insert({
        'group_id': dummyGroupId,
        'amount': 10.0,
        'description': 'Test Unequal Constraint',
        'category': 'other',
        'split_type': 'unequal',
      }).select();
      print('SUCCESS with unequal (unexpected, should have failed FK)');
    } catch (e) {
      print('RESULT for unequal: $e');
    }
  });
}
