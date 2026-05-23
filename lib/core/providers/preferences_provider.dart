import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_cache_service.dart';
import '../utils/multi_currency_helper.dart';
import './auth_provider.dart';

class PreferencesState {
  final int themeIndex;
  final int currencyIndex;
  final bool dailyReminders;
  final String reminderTime;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool appLock;
  final String passcodePin;
  final bool biometricEnabled;
  final bool showCurrencyRates;
  final String timezone;
  final String dateFormat;
  final String fiscalYearStart;
  final String dashboardLayout;
  final String defaultExpenseCategory;
  final String profileVisibility;
  final String dataSharing;
  final bool googleConnected;
  final bool appleConnected;
  final bool twoFactorAuth;
  final String username;
  final String deliveryAddress;
  final String deliveryInstructions;
  final String avatarUrl;

  // Multi-Currency Rates State
  final Map<String, double> rates;
  final DateTime? lastRatesUpdate;
  final bool isLoadingRates;
  final String? ratesError;

  PreferencesState({
    this.themeIndex = 0,
    this.currencyIndex = 0,
    this.dailyReminders = true,
    this.reminderTime = '21:00',
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.appLock = false, // Set default appLock to false to prevent lockout
    this.passcodePin = '',
    this.biometricEnabled = true,
    this.showCurrencyRates = true,
    this.timezone = 'Asia/Kolkata (IST)',
    this.dateFormat = 'DD/MM/YYYY',
    this.fiscalYearStart = 'April 1st',
    this.dashboardLayout = 'Standard View',
    this.defaultExpenseCategory = 'Food & Dining',
    this.profileVisibility = 'Private',
    this.dataSharing = 'Analytics Only',
    this.googleConnected = true,
    this.appleConnected = false,
    this.twoFactorAuth = true,
    this.username = '',
    this.deliveryAddress = '',
    this.deliveryInstructions = '',
    this.avatarUrl = '',
    // Default fallback rates relative to INR (1 INR = rate units)
    this.rates = const {
      'INR': 1.0,
      'USD': 1 / 83.30,
      'EUR': 1 / 90.00,
      'GBP': 1 / 105.00,
      'JPY': 1 / 0.53,
      'AED': 1 / 22.68,
    },
    this.lastRatesUpdate,
    this.isLoadingRates = false,
    this.ratesError,
  });

  String get defaultCurrency => supportedCurrencies[currencyIndex].code;

  PreferencesState copyWith({
    int? themeIndex,
    int? currencyIndex,
    bool? dailyReminders,
    String? reminderTime,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? appLock,
    String? passcodePin,
    bool? biometricEnabled,
    bool? showCurrencyRates,
    String? timezone,
    String? dateFormat,
    String? fiscalYearStart,
    String? dashboardLayout,
    String? defaultExpenseCategory,
    String? profileVisibility,
    String? dataSharing,
    bool? googleConnected,
    bool? appleConnected,
    bool? twoFactorAuth,
    String? username,
    String? deliveryAddress,
    String? deliveryInstructions,
    String? avatarUrl,
    Map<String, double>? rates,
    DateTime? lastRatesUpdate,
    bool? isLoadingRates,
    String? ratesError,
  }) {
    return PreferencesState(
      themeIndex: themeIndex ?? this.themeIndex,
      currencyIndex: currencyIndex ?? this.currencyIndex,
      dailyReminders: dailyReminders ?? this.dailyReminders,
      reminderTime: reminderTime ?? this.reminderTime,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      appLock: appLock ?? this.appLock,
      passcodePin: passcodePin ?? this.passcodePin,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      showCurrencyRates: showCurrencyRates ?? this.showCurrencyRates,
      timezone: timezone ?? this.timezone,
      dateFormat: dateFormat ?? this.dateFormat,
      fiscalYearStart: fiscalYearStart ?? this.fiscalYearStart,
      dashboardLayout: dashboardLayout ?? this.dashboardLayout,
      defaultExpenseCategory: defaultExpenseCategory ?? this.defaultExpenseCategory,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      dataSharing: dataSharing ?? this.dataSharing,
      googleConnected: googleConnected ?? this.googleConnected,
      appleConnected: appleConnected ?? this.appleConnected,
      twoFactorAuth: twoFactorAuth ?? this.twoFactorAuth,
      username: username ?? this.username,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rates: rates ?? this.rates,
      lastRatesUpdate: lastRatesUpdate ?? this.lastRatesUpdate,
      isLoadingRates: isLoadingRates ?? this.isLoadingRates,
      ratesError: ratesError ?? this.ratesError,
    );
  }

  double convertFromBaseline(double amount) {
    final code = supportedCurrencies[currencyIndex].code;
    final rate = rates[code] ?? 1.0;
    return amount * rate;
  }

  double convertToBaseline(double amount, String sourceCurrency) {
    final rate = rates[sourceCurrency] ?? 1.0;
    return amount / rate;
  }
}

class PreferencesNotifier extends Notifier<PreferencesState> {
  final Dio _dio = Dio();

  @override
  PreferencesState build() {
    ref.listen<User?>(currentUserProvider, (previous, next) {
      handleUserChange();
    });

    ref.listen<AsyncValue<Map<String, dynamic>?>>(userProfileProvider, (previous, next) {
      final profile = next.value;
      if (profile != null && profile.containsKey('currency')) {
        final dbCurrency = profile['currency'] as String?;
        if (dbCurrency != null) {
          final idx = supportedCurrencies.indexWhere((c) => c.code == dbCurrency);
          if (idx != -1 && idx != state.currencyIndex) {
            updateCurrencyIndex(idx, syncRemote: false);
          }
        }
      }
    });

    // Load state and schedule rate fetch if expired
    final loaded = _getLoadedState();
    Future.microtask(() {
      _checkAndFetchRates();
    });
    return loaded;
  }

  String get _userPrefix {
    final user = ref.read(currentUserProvider);
    return user != null ? 'pref_${user.id}_' : 'pref_guest_';
  }

  PreferencesState _getLoadedState() {
    final prefix = _userPrefix;
    
    // Load cached exchange rates
    Map<String, double> cachedRates = const {
      'INR': 1.0,
      'USD': 1 / 83.30,
      'EUR': 1 / 90.00,
      'GBP': 1 / 105.00,
      'JPY': 1 / 0.53,
      'AED': 1 / 22.68,
    };
    final rawRates = LocalCacheService.getCachedMap('rates_cache');
    if (rawRates != null) {
      cachedRates = rawRates.map((key, value) => MapEntry(key, (value as num).toDouble()));
    }
    
    DateTime? lastUpdate;
    final lastUpdateStr = LocalCacheService.getCachedData('rates_last_updated') as String?;
    if (lastUpdateStr != null) {
      lastUpdate = DateTime.tryParse(lastUpdateStr);
    }

    return PreferencesState(
      themeIndex: LocalCacheService.getCachedData('${prefix}themeIndex') ?? 0,
      currencyIndex: LocalCacheService.getCachedData('${prefix}currencyIndex') ?? 0,
      dailyReminders: LocalCacheService.getCachedData('${prefix}dailyReminders') ?? true,
      reminderTime: LocalCacheService.getCachedData('${prefix}reminderTime') ?? '21:00',
      emailNotifications: LocalCacheService.getCachedData('${prefix}emailNotifications') ?? true,
      pushNotifications: LocalCacheService.getCachedData('${prefix}pushNotifications') ?? true,
      appLock: LocalCacheService.getCachedData('${prefix}appLock') ?? false,
      passcodePin: LocalCacheService.getCachedData('${prefix}passcodePin') ?? '',
      biometricEnabled: LocalCacheService.getCachedData('${prefix}biometricEnabled') ?? true,
      showCurrencyRates: LocalCacheService.getCachedData('${prefix}showCurrencyRates') ?? true,
      timezone: LocalCacheService.getCachedData('${prefix}timezone') ?? 'Asia/Kolkata (IST)',
      dateFormat: LocalCacheService.getCachedData('${prefix}dateFormat') ?? 'DD/MM/YYYY',
      fiscalYearStart: LocalCacheService.getCachedData('${prefix}fiscalYearStart') ?? 'April 1st',
      dashboardLayout: LocalCacheService.getCachedData('${prefix}dashboardLayout') ?? 'Standard View',
      defaultExpenseCategory: LocalCacheService.getCachedData('${prefix}defaultExpenseCategory') ?? 'Food & Dining',
      profileVisibility: LocalCacheService.getCachedData('${prefix}profileVisibility') ?? 'Private',
      dataSharing: LocalCacheService.getCachedData('${prefix}dataSharing') ?? 'Analytics Only',
      googleConnected: LocalCacheService.getCachedData('${prefix}googleConnected') ?? true,
      appleConnected: LocalCacheService.getCachedData('${prefix}appleConnected') ?? false,
      twoFactorAuth: LocalCacheService.getCachedData('${prefix}twoFactorAuth') ?? true,
      username: LocalCacheService.getCachedData('${prefix}username') ?? '',
      deliveryAddress: LocalCacheService.getCachedData('${prefix}deliveryAddress') ?? '',
      deliveryInstructions: LocalCacheService.getCachedData('${prefix}deliveryInstructions') ?? '',
      avatarUrl: LocalCacheService.getCachedData('${prefix}avatarUrl') ?? '',
      rates: cachedRates,
      lastRatesUpdate: lastUpdate,
    );
  }

  void handleUserChange() {
    state = _getLoadedState();
    _checkAndFetchRates();
  }

  String get currencySymbol => supportedCurrencies[state.currencyIndex].symbol;
  String get currencyCode => supportedCurrencies[state.currencyIndex].code;
  IconData get currencyIcon => supportedCurrencies[state.currencyIndex].icon;

  double convertFromBaseline(double amount) {
    final code = currencyCode;
    final rate = state.rates[code] ?? 1.0;
    return amount * rate;
  }

  double convertToBaseline(double amount, String sourceCurrency) {
    final rate = state.rates[sourceCurrency] ?? 1.0;
    return amount / rate;
  }

  /// Automatically check cache age and fetch rates if older than 6 hours
  void _checkAndFetchRates() {
    final last = state.lastRatesUpdate;
    if (last == null || DateTime.now().difference(last).inHours >= 6) {
      fetchRates();
    }
  }

  /// Fetch live exchange rates from public ExchangeRate API
  Future<void> fetchRates({bool force = false}) async {
    if (state.isLoadingRates) return;
    
    state = state.copyWith(isLoadingRates: true, ratesError: null);
    try {
      final response = await _dio.get('https://open.er-api.com/v6/latest/INR');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['result'] == 'success' && data['rates'] != null) {
          final fetchedRates = data['rates'] as Map<String, dynamic>;
          
          final Map<String, double> newRates = {};
          // Parse only rates of our supported currencies
          for (final cur in supportedCurrencies) {
            if (fetchedRates.containsKey(cur.code)) {
              newRates[cur.code] = (fetchedRates[cur.code] as num).toDouble();
            } else {
              // Keep old or default rate if missing
              newRates[cur.code] = state.rates[cur.code] ?? 1.0;
            }
          }

          final now = DateTime.now();
          state = state.copyWith(
            rates: newRates,
            lastRatesUpdate: now,
            isLoadingRates: false,
            ratesError: null,
          );

          // Persist in local cache
          await LocalCacheService.cacheData('rates_cache', newRates);
          await LocalCacheService.cacheData('rates_last_updated', now.toIso8601String());
          return;
        }
      }
      throw Exception('API returned invalid payload');
    } catch (e) {
      state = state.copyWith(
        isLoadingRates: false,
        ratesError: 'Failed to sync exchange rates: $e',
      );
    }
  }

  Future<void> updateThemeIndex(int index) async {
    state = state.copyWith(themeIndex: index);
    await LocalCacheService.cacheData('${_userPrefix}themeIndex', index);
  }

  Future<void> updateCurrencyIndex(int index, {bool syncRemote = true}) async {
    state = state.copyWith(currencyIndex: index);
    await LocalCacheService.cacheData('${_userPrefix}currencyIndex', index);

    if (syncRemote) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          final code = supportedCurrencies[index].code;
          await ref.read(authServiceProvider).updateProfile(user.id, {
            'currency': code,
          });
        } catch (_) {}
      }
    }
  }

  Future<void> updateDailyReminders(bool value) async {
    state = state.copyWith(dailyReminders: value);
    await LocalCacheService.cacheData('${_userPrefix}dailyReminders', value);
  }

  Future<void> updateReminderTime(String time) async {
    state = state.copyWith(reminderTime: time);
    await LocalCacheService.cacheData('${_userPrefix}reminderTime', time);
  }

  Future<void> updateEmailNotifications(bool value) async {
    state = state.copyWith(emailNotifications: value);
    await LocalCacheService.cacheData('${_userPrefix}emailNotifications', value);
  }

  Future<void> updatePushNotifications(bool value) async {
    state = state.copyWith(pushNotifications: value);
    await LocalCacheService.cacheData('${_userPrefix}pushNotifications', value);
  }

  Future<void> updateAppLock(bool value) async {
    state = state.copyWith(appLock: value);
    await LocalCacheService.cacheData('${_userPrefix}appLock', value);
  }

  Future<void> updatePasscodePin(String pin) async {
    state = state.copyWith(passcodePin: pin);
    await LocalCacheService.cacheData('${_userPrefix}passcodePin', pin);
  }

  Future<void> updateBiometric(bool value) async {
    state = state.copyWith(biometricEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}biometricEnabled', value);
  }

  Future<void> updateShowCurrencyRates(bool value) async {
    state = state.copyWith(showCurrencyRates: value);
    await LocalCacheService.cacheData('${_userPrefix}showCurrencyRates', value);
  }

  Future<void> updateDefaultCurrency(String code) async {
    final idx = supportedCurrencies.indexWhere((c) => c.code == code);
    if (idx != -1) {
      await updateCurrencyIndex(idx);
    }
  }

  Future<void> updateTimezone(String value) async {
    state = state.copyWith(timezone: value);
    await LocalCacheService.cacheData('${_userPrefix}timezone', value);
  }

  Future<void> updateDateFormat(String value) async {
    state = state.copyWith(dateFormat: value);
    await LocalCacheService.cacheData('${_userPrefix}dateFormat', value);
  }

  Future<void> updateFiscalYearStart(String value) async {
    state = state.copyWith(fiscalYearStart: value);
    await LocalCacheService.cacheData('${_userPrefix}fiscalYearStart', value);
  }

  Future<void> updateDashboardLayout(String value) async {
    state = state.copyWith(dashboardLayout: value);
    await LocalCacheService.cacheData('${_userPrefix}dashboardLayout', value);
  }

  Future<void> updateDefaultExpenseCategory(String value) async {
    state = state.copyWith(defaultExpenseCategory: value);
    await LocalCacheService.cacheData('${_userPrefix}defaultExpenseCategory', value);
  }

  Future<void> updateProfileVisibility(String value) async {
    state = state.copyWith(profileVisibility: value);
    await LocalCacheService.cacheData('${_userPrefix}profileVisibility', value);
  }

  Future<void> updateDataSharing(String value) async {
    state = state.copyWith(dataSharing: value);
    await LocalCacheService.cacheData('${_userPrefix}dataSharing', value);
  }

  Future<void> updateGoogleConnected(bool value) async {
    state = state.copyWith(googleConnected: value);
    await LocalCacheService.cacheData('${_userPrefix}googleConnected', value);
  }

  Future<void> updateAppleConnected(bool value) async {
    state = state.copyWith(appleConnected: value);
    await LocalCacheService.cacheData('${_userPrefix}appleConnected', value);
  }

  Future<void> updateTwoFactorAuth(bool value) async {
    state = state.copyWith(twoFactorAuth: value);
    await LocalCacheService.cacheData('${_userPrefix}twoFactorAuth', value);
  }

  Future<void> updateUsername(String value) async {
    state = state.copyWith(username: value);
    await LocalCacheService.cacheData('${_userPrefix}username', value);
  }

  Future<void> updateDeliveryAddress(String value) async {
    state = state.copyWith(deliveryAddress: value);
    await LocalCacheService.cacheData('${_userPrefix}deliveryAddress', value);
  }

  Future<void> updateDeliveryInstructions(String value) async {
    state = state.copyWith(deliveryInstructions: value);
    await LocalCacheService.cacheData('${_userPrefix}deliveryInstructions', value);
  }

  Future<void> updateAvatarUrl(String value) async {
    state = state.copyWith(avatarUrl: value);
    await LocalCacheService.cacheData('${_userPrefix}avatarUrl', value);
  }
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, PreferencesState>(() {
  return PreferencesNotifier();
});
