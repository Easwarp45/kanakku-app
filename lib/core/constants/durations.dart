/// App-wide animation and delay durations
abstract class AppDurations {
  // Animation Durations
  static const Duration animationVeryFast = Duration(milliseconds: 100);
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationVerySlow = Duration(milliseconds: 800);

  // Transition Durations
  static const Duration transitionVeryFast = Duration(milliseconds: 150);
  static const Duration transitionFast = Duration(milliseconds: 250);
  static const Duration transitionMedium = Duration(milliseconds: 350);
  static const Duration transitionSlow = Duration(milliseconds: 600);

  // Toast/Snackbar Durations
  static const Duration toastShort = Duration(seconds: 2);
  static const Duration toastMedium = Duration(seconds: 3);
  static const Duration toastLong = Duration(seconds: 4);

  // Loading States
  static const Duration loadingMin = Duration(milliseconds: 500);
  static const Duration loadingDebounce = Duration(milliseconds: 300);

  // Network Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration networkConnectTimeout = Duration(seconds: 10);
  static const Duration networkReceiveTimeout = Duration(seconds: 30);

  // Delays
  static const Duration delayVeryShort = Duration(milliseconds: 100);
  static const Duration delayShort = Duration(milliseconds: 200);
  static const Duration delayMedium = Duration(milliseconds: 500);
  static const Duration delayLong = Duration(seconds: 1);
}
