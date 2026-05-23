import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/glass_card.dart';

enum PasscodeMode {
  setup,
  verifyDisable,
  unlock,
}

class PasscodeScreen extends ConsumerStatefulWidget {
  final PasscodeMode mode;
  final VoidCallback? onSuccess;

  const PasscodeScreen({
    super.key,
    required this.mode,
    this.onSuccess,
  });

  @override
  ConsumerState<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends ConsumerState<PasscodeScreen> with SingleTickerProviderStateMixin {
  final List<int> _digits = [];
  String _firstEntry = '';
  String _statusText = '';
  String _errorText = '';
  
  // Animation controllers
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _initStatusText();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 12), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 12, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -12, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 8, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  void _initStatusText() {
    switch (widget.mode) {
      case PasscodeMode.setup:
        _statusText = 'Create a 4-Digit Passcode';
        break;
      case PasscodeMode.verifyDisable:
        _statusText = 'Enter PIN to Disable Lock';
        break;
      case PasscodeMode.unlock:
        _statusText = 'Enter PIN to Unlock';
        break;
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _handleNumberPress(int number) {
    if (_digits.length >= 4) return;
    
    setState(() {
      _digits.add(number);
      _errorText = '';
    });

    if (_digits.length == 4) {
      // Process full PIN entry after brief delay for visual effect
      Future.delayed(const Duration(milliseconds: 150), _processPasscode);
    }
  }

  void _handleBackspace() {
    if (_digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _errorText = '';
    });
  }

  void _triggerShake() {
    _shakeCtrl.forward(from: 0);
    setState(() {
      _digits.clear();
    });
  }

  void _processPasscode() async {
    final enteredPin = _digits.join();
    final prefs = ref.read(preferencesProvider);
    final isSetup = widget.mode == PasscodeMode.setup;

    if (isSetup) {
      if (_firstEntry.isEmpty) {
        // Storing the first entry to confirm
        setState(() {
          _firstEntry = enteredPin;
          _digits.clear();
          _statusText = 'Confirm Your Passcode';
        });
      } else {
        if (enteredPin == _firstEntry) {
          // Success: PIN set up!
          await ref.read(preferencesProvider.notifier).updatePasscodePin(enteredPin);
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            if (mounted) context.pop();
          }
        } else {
          // mismatch
          setState(() {
            _errorText = 'Passcodes do not match. Start over.';
            _firstEntry = '';
            _initStatusText();
          });
          _triggerShake();
        }
      }
    } else {
      final actualPin = prefs.passcodePin;
      if (enteredPin == actualPin) {
        if (widget.mode == PasscodeMode.verifyDisable) {
          // Success: Disable lock
          await ref.read(preferencesProvider.notifier).updatePasscodePin('');
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            if (mounted) context.pop();
          }
        } else {
          // Success: Unlock App
          ref.read(sessionLockProvider.notifier).setLock(false);
          if (mounted) {
            context.go('/dashboard');
          }
        }
      } else {
        setState(() {
          _errorText = 'Incorrect Passcode';
        });
        _triggerShake();
      }
    }
  }

  void _handleSignOutBypass() async {
    // Show confirmation dialog before erasing data
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reset Passcode & App?', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Forgetting your passcode requires signing out. This will clear local cache and synchronization queues.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRose),
              onPressed: () async {
                Navigator.pop(dialogContext);
                // sign out
                await ref.read(authServiceProvider).signOut();
                ref.read(sessionLockProvider.notifier).setLock(true);
                if (mounted) {
                  context.go('/login');
                }
              },
              child: const Text('Confirm Sign Out', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            );
          },
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.shieldAlert, size: 60, color: AppColors.accentCyan),
                  const SizedBox(height: 24),
                  Text(
                    _statusText,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  if (_errorText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_errorText, style: const TextStyle(color: AppColors.accentRose, fontSize: 13)),
                  ],
                  const SizedBox(height: 36),
                  
                  // DOTS INDICATOR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _digits.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? AppColors.accentCyan : Colors.transparent,
                          border: Border.all(
                            color: isFilled ? AppColors.accentCyan : AppColors.border,
                            width: 1.5,
                          ),
                          boxShadow: isFilled
                              ? [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 1)]
                              : null,
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // NUMBER PAD
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        if (index == 9) {
                          // CANCEL BUTTON (only during setup or verifyDisable)
                          final isUnlock = widget.mode == PasscodeMode.unlock;
                          return isUnlock
                              ? const SizedBox()
                              : _buildNumpadButton(
                                  icon: LucideIcons.x,
                                  onTap: () => context.pop(),
                                  color: AppColors.textSecondary,
                                );
                        }
                        if (index == 10) {
                          // ZERO
                          return _buildNumpadButton(
                            text: '0',
                            onTap: () => _handleNumberPress(0),
                          );
                        }
                        if (index == 11) {
                          // BACKSPACE
                          return _buildNumpadButton(
                            icon: LucideIcons.delete,
                            onTap: _handleBackspace,
                            color: AppColors.textSecondary,
                          );
                        }
                        // NUMBERS 1-9
                        final number = index + 1;
                        return _buildNumpadButton(
                          text: number.toString(),
                          onTap: () => _handleNumberPress(number),
                        );
                      },
                    ),
                  ),
                  
                  if (widget.mode == PasscodeMode.unlock) ...[
                    const SizedBox(height: 48),
                    TextButton(
                      onPressed: _handleSignOutBypass,
                      child: const Text(
                        'Forgot Passcode? Sign Out',
                        style: TextStyle(color: AppColors.accentRose, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadButton({
    String? text,
    IconData? icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
          ),
          alignment: Alignment.center,
          child: text != null
              ? Text(
                  text,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                )
              : Icon(
                  icon,
                  color: color ?? AppColors.textPrimary,
                  size: 24,
                ),
        ),
      ),
    );
  }
}

// Global Provider to manage active passcode session verification (locked status)
class SessionLockNotifier extends Notifier<bool> {
  @override
  bool build() {
    return true; // Default to locked
  }

  void setLock(bool locked) {
    state = locked;
  }
}

final sessionLockProvider = NotifierProvider<SessionLockNotifier, bool>(() {
  return SessionLockNotifier();
});
