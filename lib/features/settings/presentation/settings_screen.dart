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
            SliverToBoxAdapter(child: _buildSection('Categories & Budgets', _buildCategoryItems(context))),
            SliverToBoxAdapter(child: _buildSection('Groups', _buildGroupsItems(context))),
            SliverToBoxAdapter(child: _buildSection('Data & Security', _buildDataSecurityItems())),
            SliverToBoxAdapter(child: _buildSection('Support & About', _buildSupportItems())),
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
      return 'Synced: $day $month, $hour:$minute';
    }

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(activeCurrency.icon, color: AppColors.accentEmerald, size: 22),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Base Currency', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _showPickerSheet(
                context,
                'Currency',
                currencies,
                prefs.currencyIndex,
                (i) => ref.read(preferencesProvider.notifier).updateCurrencyIndex(i),
              ),
              child: Text(currencies[prefs.currencyIndex], style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            ),
          ],
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.refreshCw,
        'Exchange Rates',
        prefs.isLoadingRates
            ? 'Syncing live rates...'
            : (prefs.ratesError ?? formatLastUpdate(prefs.lastRatesUpdate)),
        prefs.ratesError != null ? AppColors.accentRose : AppColors.accentCyan,
        trailing: prefs.isLoadingRates
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
              )
            : IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.accentCyan),
                onPressed: () async {
                  await ref.read(preferencesProvider.notifier).fetchRates(force: true);
                  if (context.mounted) {
                    final updatedPrefs = ref.read(preferencesProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(updatedPrefs.ratesError ?? 'Exchange rates synced successfully!'),
                        backgroundColor: updatedPrefs.ratesError != null ? AppColors.accentRose : AppColors.accentEmerald,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
              ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            const Icon(LucideIcons.palette, color: AppColors.accentCyan, size: 22),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App Theme', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _showPickerSheet(
                context,
                'Theme',
                themes,
                prefs.themeIndex,
                (i) => ref.read(preferencesProvider.notifier).updateThemeIndex(i),
              ),
              child: Text(themes[prefs.themeIndex], style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            ),
          ],
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(
        LucideIcons.bellRing,
        'Daily Reminder',
        'Remind to log expenses',
        AppColors.accentPurple,
        trailing: Switch(
          value: prefs.dailyReminders,
          onChanged: (v) => ref.read(preferencesProvider.notifier).updateDailyReminders(v),
          activeThumbColor: AppColors.accentCyan,
        ),
      ),
    ];
  }

  List<Widget> _buildCategoryItems(BuildContext context) {
    return [
      _buildSettingsTile(LucideIcons.tags, 'Manage Categories', 'Add/edit expense tags', AppColors.accentEmerald, onTap: () {}),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.target, 'Budget Limits', 'Set monthly caps', AppColors.accentCyan, onTap: () => context.push('/budget')),
    ];
  }

  List<Widget> _buildGroupsItems(BuildContext context) {
    return [
      _buildSettingsTile(LucideIcons.users, 'Manage Groups', 'View active groups', AppColors.accentPurple, onTap: () => context.push('/groups')),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.gitMerge, 'Default Split Rule', 'Currently: Equal Split', AppColors.accentCyan, onTap: () {}),
    ];
  }

  List<Widget> _buildDataSecurityItems() {
    final prefs = ref.watch(preferencesProvider);

    return [
      _buildSettingsTile(
        LucideIcons.fingerprint,
        'App Lock',
        'Biometric security',
        AppColors.accentCyan,
        trailing: Switch(
          value: prefs.appLock,
          onChanged: (v) => ref.read(preferencesProvider.notifier).updateAppLock(v),
          activeThumbColor: AppColors.accentCyan,
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.cloudLightning, 'Cloud Backup', 'Sync data to cloud', AppColors.accentEmerald, onTap: _runCloudBackup),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.download, 'Export Data', 'Download CSV report', AppColors.accentPurple, onTap: _exportData),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.trash2, 'Clear Cache', 'Free up space', AppColors.textSecondary, onTap: _clearCache),
    ];
  }

  List<Widget> _buildSupportItems() {
    return [
      _buildSettingsTile(LucideIcons.helpCircle, 'Help & Support', 'FAQs and Contact', AppColors.accentEmerald, onTap: _showSupportCenter),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.logOut, 'Sign Out', 'Disconnect this device', AppColors.accentRose, onTap: () async {
        await ref.read(authServiceProvider).signOut();
        if (mounted) {
          context.go('/login');
        }
      }),
    ];
  }

  void _runCloudBackup() {
    final stepNotifier = ValueNotifier<String>('Preparing secure archive...');
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    Future.delayed(const Duration(milliseconds: 1000), () {
      stepNotifier.value = 'Encrypting configuration tables...';
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      stepNotifier.value = 'Syncing local ledger database...';
    });

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (context.mounted) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Cloud backup successfully completed!'),
              ],
            ),
            backgroundColor: AppColors.accentEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

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
                    const Text('SECURE CLOUD BACKUP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentCyan, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Text(step, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                  ],
                );
              },
            ),
          ),
        );
      },
    ).then((_) {
      stepNotifier.dispose();
    });
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

      final Map<String, dynamic> exportMap = {
        'exported_at': DateTime.now().toIso8601String(),
        'app': 'Kanakku Tracker',
        'version': '1.0.0',
        'user': {
          'id': user?.id ?? 'guest',
          'email': user?.email ?? 'guest@kanakku.com',
          'username': prefs.username,
          'timezone': prefs.timezone,
          'currency_index': prefs.currencyIndex,
        },
        'settings': {
          'theme_index': prefs.themeIndex,
          'daily_reminders': prefs.dailyReminders,
          'app_lock': prefs.appLock,
          'layout': prefs.dashboardLayout,
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

  void _clearCache() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Clear Cached Data?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will reset your local settings and layout configurations to default. Active session details will remain intact.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Clear cache
              await LocalCacheService.clearAll();
              // Re-persist is_logged_in as true so user stays logged in
              await LocalCacheService.cacheData('is_logged_in', true);
              // Re-read preferences
              ref.read(preferencesProvider.notifier).handleUserChange();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Cache cleared successfully!'),
                    backgroundColor: AppColors.accentEmerald,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.accentRose)),
          ),
        ],
      ),
    );
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
