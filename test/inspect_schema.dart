import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Check if created_by or user_id columns exist in group_expenses', () async {
    SharedPreferences.setMockInitialValues({});
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: dotenv.env['VITE_SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['VITE_SUPABASE_ANON_KEY'] ?? '',
    );
    final client = Supabase.instance.client;
    
    try {
      print('Testing created_by...');
      final res = await client.from('group_expenses').select('created_by').limit(1);
      print('created_by test succeeded: $res');
    } catch (e) {
      print('created_by test failed: $e');
    }

    try {
      print('Testing user_id...');
      final res = await client.from('group_expenses').select('user_id').limit(1);
      print('user_id test succeeded: $res');
    } catch (e) {
      print('user_id test failed: $e');
    }

    try {
      print('Testing paid_by...');
      final res = await client.from('group_expenses').select('paid_by').limit(1);
      print('paid_by test succeeded: $res');
    } catch (e) {
      print('paid_by test failed: $e');
    }
  });
}
