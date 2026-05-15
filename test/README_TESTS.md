This folder will contain unit and widget tests.

Run tests with:

```bash
flutter test
```

Suggested initial tests:
- `test/auth_repository_test.dart` - cover login/logout flows (mock Dio)
- `test/providers/auth_provider_test.dart` - test AuthNotifier state transitions
- `test/widgets/login_screen_test.dart` - widget test for login form validation

You can scaffold tests using `mocktail` or `mockito` for Dio stubbing.
