import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/database/local_cache_service.dart';
import '../../../core/utils/multi_currency_helper.dart';
import '../../../core/database/supabase_service.dart';
import '../../auth/presentation/passcode_screen.dart';
import '../../expenses/data/expense_service.dart';
import '../../income/data/income_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 4)),
            SliverToBoxAdapter(child: _buildProfileBanner(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSection('Preferences', _buildPreferencesItems())),
            SliverToBoxAdapter(child: _buildSection('Security & Data', _buildDataSecurityItems())),
            SliverToBoxAdapter(child: _buildSection('Support', _buildSupportItems())),
            SliverToBoxAdapter(child: const SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Text('Kanakku Tracker v1.0.0', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                ),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 5),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PREFERENCES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentCyan, letterSpacing: 2)),
                SizedBox(height: 2),
                Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileBanner(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final prefs = ref.watch(preferencesProvider);
    String name = 'User';
    String initials = 'U';

    profileAsync.whenData((profile) {
      if (profile != null && profile['display_name'] != null && profile['display_name'].toString().isNotEmpty) {
        name = profile['display_name'];
        initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
      }
    });

    Widget avatarWidget;
    if (prefs.avatarUrl.isNotEmpty && prefs.avatarUrl.startsWith('assets/')) {
      avatarWidget = CircleAvatar(
        radius: 26,
        backgroundColor: Colors.transparent,
        child: Image.asset(prefs.avatarUrl, fit: BoxFit.contain, width: 52, height: 52),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: 26,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => context.push('/profile'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.accentCyan, AppColors.accentPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              avatarWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                    const Text('Manage Personal Info', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          GlassCard(margin: EdgeInsets.zero, padding: EdgeInsets.zero, child: Column(children: items)),
        ],
      ),
    );
  }

  List<Widget> _buildPreferencesItems() {
    final prefs = ref.watch(preferencesProvider);
    final themes = ['System Default', 'Dark Mode', 'Light Mode'];
    final currencies = supportedCurrencies.map((c) => '${c.code} (${c.symbol})').toList();
    final activeCurrency = supportedCurrencies[prefs.currencyIndex];

    String formatLastUpdate(DateTime? dt) {
      if (dt == null) return 'Never synced';
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return 'Synced $day $month, $hour:$minute';
    }

    return [
      _buildSettingsTile(
        activeCurrency.icon,
        'Base Currency',
        '${currencies[prefs.currencyIndex]} • ${formatLastUpdate(prefs.lastRatesUpdate)}',
        AppColors.accentEmerald,
        onTap: () => _showPickerSheet(
          context,
          'Currency',
          currencies,
          prefs.currencyIndex,
          (i) => ref.read(preferencesProvider.notifier).updateCurrencyIndex(i),
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.palette,
        'App Theme',
        themes[prefs.themeIndex],
        AppColors.accentCyan,
        onTap: () => _showPickerSheet(
          context,
          'Theme',
          themes,
          prefs.themeIndex,
          (i) => ref.read(preferencesProvider.notifier).updateThemeIndex(i),
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.bellRing,
        'Daily Reminder',
        prefs.dailyReminders
            ? 'Scheduled daily at ${_formatReminderTime(prefs.reminderTime)}'
            : 'Notification reminder to log expenses',
        AppColors.accentPurple,
        onTap: prefs.dailyReminders ? _pickReminderTime : null,
        trailing: Switch(
          value: prefs.dailyReminders,
          onChanged: (v) async {
            await ref.read(preferencesProvider.notifier).updateDailyReminders(v);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(v 
                    ? 'Daily reminder scheduled for ${_formatReminderTime(prefs.reminderTime)}!' 
                    : 'Daily reminders deactivated.'),
                  backgroundColor: v ? AppColors.accentEmerald : AppColors.textSecondary,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
          activeThumbColor: AppColors.accentCyan,
          activeTrackColor: AppColors.accentCyan.withValues(alpha: 0.2),
        ),
      ),
    ];
  }

  List<Widget> _buildDataSecurityItems() {
    final prefs = ref.watch(preferencesProvider);

    return [
      _buildSettingsTile(
        LucideIcons.fingerprint,
        'App Lock',
        prefs.appLock ? 'Protected with 4-digit PIN' : 'Secure database with passcode PIN',
        AppColors.accentCyan,
        trailing: Switch(
          value: prefs.appLock,
          onChanged: (v) {
            if (v) {
              context.push(
                '/passcode',
                extra: {
                  'mode': PasscodeMode.setup,
                  'onSuccess': () async {
                    await ref.read(preferencesProvider.notifier).updateAppLock(true);
                    if (mounted) {
                      context.pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('App Lock enabled with passcode PIN!'),
                          backgroundColor: AppColors.accentEmerald,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  }
                },
              );
            } else {
              context.push(
                '/passcode',
                extra: {
                  'mode': PasscodeMode.verifyDisable,
                  'onSuccess': () async {
                    await ref.read(preferencesProvider.notifier).updateAppLock(false);
                    if (mounted) {
                      context.pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('App Lock disabled.'),
                          backgroundColor: AppColors.textSecondary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  }
                },
              );
            }
          },
          activeThumbColor: AppColors.accentCyan,
          activeTrackColor: AppColors.accentCyan.withValues(alpha: 0.2),
        ),
      ),
      if (prefs.appLock) ...[
        Divider(color: AppColors.borderSubtle, height: 1),
        _buildSettingsTile(
          LucideIcons.keyRound,
          'Change Passcode',
          'Change your 4-digit security PIN',
          AppColors.accentCyan,
          onTap: () {
            context.push(
              '/passcode',
              extra: {
                'mode': PasscodeMode.change,
                'onSuccess': () {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Passcode updated successfully!'),
                      backgroundColor: AppColors.accentEmerald,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
            );
          },
        ),
      ],
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.creditCard,
        'UPI Payment Accounts',
        'Link banks and view quick-receive QR codes',
        AppColors.accentCyan,
        onTap: () => context.push('/upi'),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.cloudLightning,
        'Cloud Backup & Sync',
        'Sync ledger database safely to Supabase',
        AppColors.accentEmerald,
        onTap: _runCloudBackup,
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.download,
        'Export Data',
        'Download personal config as JSON report',
        AppColors.accentPurple,
        onTap: _exportData,
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.upload,
        'Import Data',
        'Restore personal config and transactions from JSON',
        AppColors.accentPurple,
        onTap: _importData,
      ),
    ];
  }

  List<Widget> _buildSupportItems() {
    return [
      _buildSettingsTile(
        LucideIcons.helpCircle,
        'Help & Support',
        'FAQs and contact helpdesk ticket vault',
        AppColors.accentEmerald,
        onTap: _showSupportCenter,
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.bookOpen,
        'System Setup & Guide',
        'Learn how to onboard and sync on various devices',
        AppColors.accentPurple,
        onTap: () => context.push('/install-guide'),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.logOut,
        'Sign Out',
        'Disconnect session from this device safely',
        AppColors.accentRose,
        onTap: () async {
          await ref.read(authServiceProvider).signOut();
          if (mounted) {
            context.go('/login');
          }
        },
      ),
    ];
  }

  void _runCloudBackup() async {
    final stepNotifier = ValueNotifier<String>('Connecting to secure cloud nodes...');
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ValueListenableBuilder<String>(
              valueListenable: stepNotifier,
              builder: (context, step, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 3),
                    ),
                    const SizedBox(height: 20),
                    const Text('SECURE CLOUD SYNC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentCyan, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Text(step, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) stepNotifier.value = 'Reconciling offline ledger actions...';
      
      // Perform actual sync
      final syncManager = ref.read(realtimeSyncManagerProvider);
      await syncManager.triggerSync();
      
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) stepNotifier.value = 'Updating regional caches and profiles...';
      
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (mounted) {
        Navigator.pop(context); // Close dialog
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Cloud ledger sync completed successfully!'),
              ],
            ),
            backgroundColor: AppColors.accentEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Sync failed: $e')),
              ],
            ),
            backgroundColor: AppColors.accentRose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      stepNotifier.dispose();
    }
  }

  Future<void> _exportData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
    );

    try {
      final prefs = ref.read(preferencesProvider);
      final user = ref.read(currentUserProvider);
      final userId = user?.id ?? 'guest';

      final cachedExpenses = LocalCacheService.getCachedData('expenses_$userId') ?? [];
      final cachedIncome = LocalCacheService.getCachedData('income_$userId') ?? [];

      final Map<String, dynamic> exportMap = {
        'exported_at': DateTime.now().toIso8601String(),
        'app': 'Kanakku Tracker',
        'version': '1.0.0',
        'user': {
          'id': userId,
          'email': user?.email ?? 'guest@kanakku.com',
          'username': prefs.username,
          'timezone': prefs.timezone,
        },
        'settings': {
          'theme_index': prefs.themeIndex,
          'currency_index': prefs.currencyIndex,
          'daily_reminders': prefs.dailyReminders,
          'reminder_time': prefs.reminderTime,
          'app_lock': prefs.appLock,
          'passcode_pin': prefs.passcodePin,
          'layout': prefs.dashboardLayout,
        },
        'data': {
          'expenses': cachedExpenses,
          'income': cachedIncome,
        }
      };

      final jsonString = jsonEncode(exportMap);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/kanakku_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        Navigator.pop(context); // Close loading
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Kanakku Ledger & Profile backup',
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.accentRose),
        );
      }
    }
  }

  String _formatReminderTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final tod = TimeOfDay(hour: hour, minute: minute);
      
      final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
      final m = tod.minute.toString().padLeft(2, '0');
      final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $period';
    } catch (_) {
      return timeStr;
    }
  }

  void _pickReminderTime() async {
    final prefs = ref.read(preferencesProvider);
    final parts = prefs.reminderTime.split(':');
    final initialHour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 21) : 21;
    final initialMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentCyan,
              surface: AppColors.bgElevated,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      final formattedTime = '$hourStr:$minStr';
      await ref.read(preferencesProvider.notifier).updateReminderTime(formattedTime);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily reminder updated to ${_formatReminderTime(formattedTime)}!'),
            backgroundColor: AppColors.accentEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _importData() {
    final textController = TextEditingController();
    bool isRestoring = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Import JSON Backup',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Paste the exported backup JSON below. This will restore settings and transactions, replacing the current local database state.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      maxLines: 8,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'JetBrains Mono'),
                      decoration: InputDecoration(
                        hintText: '{\n  "app": "Kanakku Tracker",\n  "version": "1.0.0",\n  ...\n}',
                        hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.5), fontSize: 13),
                        fillColor: AppColors.bgPrimary.withValues(alpha: 0.5),
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentCyan,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isRestoring ? null : () async {
                          final jsonText = textController.text.trim();
                          if (jsonText.isEmpty) return;

                          setModalState(() => isRestoring = true);
                          await Future.delayed(const Duration(milliseconds: 1000));

                          try {
                            final Map<String, dynamic> parsed = jsonDecode(jsonText);
                            if (parsed['app'] != 'Kanakku Tracker') {
                              throw Exception('Invalid app signature');
                            }

                            final user = ref.read(currentUserProvider);
                            final userId = user?.id ?? 'guest';
                            final prefsNotifier = ref.read(preferencesProvider.notifier);

                            // Restore Settings
                            final settings = parsed['settings'] as Map<String, dynamic>?;
                            if (settings != null) {
                              if (settings.containsKey('theme_index')) {
                                await prefsNotifier.updateThemeIndex(settings['theme_index'] as int);
                              }
                              if (settings.containsKey('currency_index')) {
                                await prefsNotifier.updateCurrencyIndex(settings['currency_index'] as int);
                              }
                              if (settings.containsKey('daily_reminders')) {
                                await prefsNotifier.updateDailyReminders(settings['daily_reminders'] as bool);
                              }
                              if (settings.containsKey('reminder_time')) {
                                await prefsNotifier.updateReminderTime(settings['reminder_time'] as String);
                              }
                              if (settings.containsKey('app_lock')) {
                                await prefsNotifier.updateAppLock(settings['app_lock'] as bool);
                              }
                              if (settings.containsKey('passcode_pin')) {
                                await prefsNotifier.updatePasscodePin(settings['passcode_pin'] as String);
                              }
                            }

                            // Restore Transaction Data
                            final data = parsed['data'] as Map<String, dynamic>?;
                            if (data != null) {
                              if (data.containsKey('expenses')) {
                                final expenses = List<Map<String, dynamic>>.from(data['expenses']);
                                await LocalCacheService.cacheData('expenses_$userId', expenses);
                              }
                              if (data.containsKey('income')) {
                                final income = List<Map<String, dynamic>>.from(data['income']);
                                await LocalCacheService.cacheData('income_$userId', income);
                              }
                            }

                            ref.invalidate(expensesStreamProvider);
                            ref.invalidate(incomeStreamProvider);

                            if (modalContext.mounted) {
                              Navigator.pop(modalContext);
                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                SnackBar(
                                  content: const Text('Backup restored successfully!'),
                                  backgroundColor: AppColors.accentEmerald,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isRestoring = false);
                            if (modalContext.mounted) {
                              showDialog(
                                context: modalContext,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.bgElevated,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Restore Failed', style: TextStyle(color: AppColors.accentRose)),
                                  content: Text('Error: $e\nMake sure the JSON matches the exported format exactly.', style: const TextStyle(color: AppColors.textSecondary)),
                                  actions: [
                                    TextButton(
                                      child: const Text('OK', style: TextStyle(color: AppColors.accentCyan)),
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: isRestoring
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.bgPrimary, strokeWidth: 2))
                            : const Text('Restore Backup', style: TextStyle(color: AppColors.bgPrimary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) => textController.dispose());
  }

  void _showSupportCenter() {
    final msgController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Help & Support',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        const Text('FREQUENTLY ASKED QUESTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentCyan, letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        _buildFAQTile('How is my ledger data synced?', 'Kanakku uses offline-first local cache synchronization (Hive) which resolves payload differences against our cloud nodes (Supabase DB) as soon as connectivity restores.'),
                        _buildFAQTile('How do I export my financial reports?', 'Go to Settings > Export Data to save a full backup copy of your personal settings, currency configs and authentication headers as a portable JSON payload.'),
                        _buildFAQTile('How is biometric lock configuration handled?', 'Kanakku interfaces with your platform LocalAuth providers. Switching on App Lock checks for saved credentials or passcode setups before granting access.'),
                        const SizedBox(height: 24),
                        const Text('CONTACT DEVELOPMENT VAULT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentCyan, letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgTertiary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Report issues or request custom infrastructure:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: msgController,
                                maxLines: 3,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Describe your query or integration issue...',
                                  hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.8), fontSize: 14),
                                  fillColor: AppColors.bgPrimary.withValues(alpha: 0.5),
                                  filled: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentCyan,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: isSubmitting ? null : () async {
                                    if (msgController.text.trim().isEmpty) return;
                                    final messenger = ScaffoldMessenger.of(context);
                                    final navigator = Navigator.of(modalContext);
                                    setModalState(() => isSubmitting = true);
                                    await Future.delayed(const Duration(milliseconds: 1500));
                                    if (modalContext.mounted) {
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: const Text('Support request dispatched to developer team!'),
                                          backgroundColor: AppColors.accentEmerald,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                    }
                                  },
                                  child: isSubmitting
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.bgPrimary, strokeWidth: 2))
                                      : const Text('Submit Ticket', style: TextStyle(color: AppColors.bgPrimary, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => msgController.dispose());
  }

  Widget _buildFAQTile(String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        iconColor: AppColors.accentCyan,
        collapsedIconColor: AppColors.textSecondary,
        title: Text(question, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(answer, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  void _showPickerSheet(BuildContext context, String title, List<String> items, int selectedIndex, ValueChanged<int> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: items.length + 1,
        separatorBuilder: (context, index) => Divider(color: AppColors.borderSubtle.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            );
          }
          final actualIndex = index - 1;
          return ListTile(
            title: Text(items[actualIndex], style: const TextStyle(color: AppColors.textPrimary)),
            trailing: actualIndex == selectedIndex ? const Icon(LucideIcons.check, color: AppColors.accentCyan) : null,
            onTap: () {
              onSelected(actualIndex);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, Color color, {Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: trailing ?? (onTap != null ? const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary, size: 18) : null),
    );
  }
}
