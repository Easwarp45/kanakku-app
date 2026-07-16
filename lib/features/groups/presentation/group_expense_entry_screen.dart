import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../data/group_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../expenses/data/expense_service.dart';
import '../../../core/utils/multi_currency_helper.dart';
import '../../../core/providers/preferences_provider.dart';

class GroupExpenseEntryScreen extends ConsumerStatefulWidget {
  final String? groupId;
  const GroupExpenseEntryScreen({super.key, this.groupId});

  @override
  ConsumerState<GroupExpenseEntryScreen> createState() => _GroupExpenseEntryScreenState();
}

class _GroupExpenseEntryScreenState extends ConsumerState<GroupExpenseEntryScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSaving = false;
  String _selectedCurrency = 'INR';
  
  String _selectedCategory = 'other';
  final List<String> _categories = [
    'food',
    'transport',
    'entertainment',
    'health',
    'shopping',
    'bills',
    'travel',
    'education',
    'other',
  ];

  String? _selectedPayerId;
  String _splitType = 'equal';
  final Map<String, double> _customSplitAmounts = {};
  final Map<String, TextEditingController> _splitControllers = {};

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesProvider);
    _selectedCurrency = supportedCurrencies[prefs.currencyIndex].code;
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (_splitType == 'equal') return;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;
    final membersAsync = ref.read(groupMembersStreamProvider(widget.groupId!));
    final members = membersAsync.value ?? [];
    if (members.isNotEmpty) {
      final equalShare = amount / members.length;
      setState(() {
        for (final m in members) {
          final userId = m['user_id'] as String?;
          if (userId != null) {
            _customSplitAmounts[userId] = equalShare;
            final controller = _splitControllers[userId];
            if (controller != null) {
              controller.text = equalShare.toStringAsFixed(2);
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (var c in _splitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initializeCustomSplits(List<Map<String, dynamic>> members) {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0 || members.isEmpty) return;

    final equalShare = amount / members.length;
    for (final m in members) {
      final userId = m['user_id'] as String?;
      if (userId != null) {
        _customSplitAmounts[userId] = equalShare;
        final controller = _splitControllers[userId];
        if (controller != null) {
          controller.text = equalShare.toStringAsFixed(2);
        }
      }
    }
  }

  void _showPayerSelection(List<Map<String, dynamic>> members, String currentUserId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Select Payer', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final userId = member['user_id'] as String;
                    final displayName = member['nickname'] ?? member['display_name'] ?? 'Unknown Member';
                    final isMe = userId == currentUserId;
                    final showName = isMe ? '$displayName (You)' : displayName;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(displayName.isEmpty ? 'U' : displayName.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(showName, style: const TextStyle(color: AppColors.textPrimary)),
                      trailing: _selectedPayerId == userId
                          ? const Icon(LucideIcons.check, color: AppColors.accentCyan)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedPayerId = userId;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSplitOptionsSelection(List<Map<String, dynamic>> members) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Split Options', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accentCyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.split, color: AppColors.accentCyan),
                ),
                title: const Text('Split Equally', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Everyone pays an equal share', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                trailing: _splitType == 'equal' ? const Icon(LucideIcons.check, color: AppColors.accentCyan) : null,
                onTap: () {
                  setState(() {
                    _splitType = 'equal';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.percent, color: AppColors.accentPurple),
                ),
                title: const Text('Split Unequally (Custom)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Specify exact amounts for each member', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                trailing: _splitType == 'custom' ? const Icon(LucideIcons.check, color: AppColors.accentPurple) : null,
                onTap: () {
                  setState(() {
                    _splitType = 'custom';
                    _initializeCustomSplits(members);
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveExpense() async {
    if (widget.groupId == null) return;
    final title = _titleController.text.trim();
    final originalAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (title.isEmpty || originalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid details')));
      return;
    }

    final prefs = ref.read(preferencesProvider);
    final rate = prefs.rates[_selectedCurrency] ?? 1.0;
    final baseAmount = originalAmount / rate;

    final symbol = supportedCurrencies.firstWhere((c) => c.code == _selectedCurrency, orElse: () => supportedCurrencies[0]).symbol;

    if (_splitType == 'custom') {
      final sum = _customSplitAmounts.values.fold(0.0, (a, b) => a + b);
      if ((sum - originalAmount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Total splits ($symbol${sum.toStringAsFixed(2)}) must equal total amount ($symbol${originalAmount.toStringAsFixed(2)})'),
            backgroundColor: AppColors.accentRose,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      Map<String, double>? baseCustomSplits;
      if (_splitType == 'custom') {
        baseCustomSplits = {};
        for (final entry in _customSplitAmounts.entries) {
          baseCustomSplits[entry.key] = entry.value / rate;
        }
      }

      String finalDesc = title;
      if (_selectedCurrency != 'INR') {
        final mcData = MultiCurrencyData(
          amount: originalAmount,
          currency: _selectedCurrency,
          rate: rate,
          baseAmount: baseAmount,
          baseCurrency: 'INR',
        );
        finalDesc = '${mcData.toToken()} $finalDesc';
      }

      await ref.read(groupServiceProvider).addGroupExpense(
        groupId: widget.groupId!,
        description: finalDesc,
        amount: _selectedCurrency == 'INR' ? originalAmount : baseAmount,
        category: _selectedCategory,
        paidBy: _selectedPayerId,
        splitType: _splitType,
        customSplits: baseCustomSplits,
      );
      ref.invalidate(groupExpensesStreamProvider(widget.groupId!));
      ref.invalidate(expensesStreamProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) return const Scaffold(body: Center(child: Text('Error: No Group ID')));
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId!));
    final currencySymbol = supportedCurrencies.firstWhere((c) => c.code == _selectedCurrency, orElse: () => supportedCurrencies[0]).symbol;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.x, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('ADD EXPENSE', style: TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w700, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                label: 'Description',
                hint: 'What was this for?',
                controller: _titleController,
                prefixIcon: const Icon(LucideIcons.fileText, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 24),
              const Text('Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _buildAmountInput(),
              const SizedBox(height: 32),
              
              const Text('Category', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat.toUpperCase()),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedCategory = cat),
                        selectedColor: AppColors.accentCyan,
                        backgroundColor: AppColors.bgSecondary,
                        labelStyle: TextStyle(color: isSelected ? AppColors.bgPrimary : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              const Text('Paid By', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) {
                  final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
                  _selectedPayerId ??= currentUserId;

                  final selectedMember = members.firstWhere(
                    (m) => m['user_id'] == _selectedPayerId,
                    orElse: () => <String, dynamic>{},
                  );
                  final name = selectedMember['nickname'] ?? selectedMember['display_name'] ?? 'Member';
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentCyan.withValues(alpha: 0.12),
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'Y',
                        style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      _selectedPayerId == currentUserId ? 'You' : name,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
                    onTap: () => _showPayerSelection(members, currentUserId),
                  );
                },
                loading: () => const ListTile(
                  title: Text('Loading members...', style: TextStyle(color: AppColors.textSecondary)),
                ),
                error: (err, stack) => ListTile(
                  title: Text('Error: $err', style: const TextStyle(color: AppColors.accentRose)),
                ),
              ),
              Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 16),
              const Text('Split Options', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) {
                  final isEqually = _splitType == 'equal';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isEqually ? AppColors.accentCyan : AppColors.accentPurple).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isEqually ? LucideIcons.split : LucideIcons.percent,
                        color: isEqually ? AppColors.accentCyan : AppColors.accentPurple,
                      ),
                    ),
                    title: Text(
                      isEqually ? 'Split Equally' : 'Split Unequally (Custom)',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isEqually ? 'Everyone pays an equal share' : 'Specify exact amounts for each member',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
                    onTap: () => _showSplitOptionsSelection(members),
                  );
                },
                loading: () => const ListTile(title: Text('Loading options...')),
                error: (err, stack) => ListTile(title: Text('Error: $err')),
              ),

              if (_splitType == 'custom') ...[
                const SizedBox(height: 24),
                const Text('Split Breakdown', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                membersAsync.when(
                  data: (members) {
                    return GlassCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ...members.map((m) {
                            final userId = m['user_id'] as String;
                            final name = m['nickname'] ?? m['display_name'] ?? 'Unknown Member';
                            final controller = _splitControllers.putIfAbsent(userId, () {
                              final initialVal = _customSplitAmounts[userId] ?? 0.0;
                              return TextEditingController(text: initialVal > 0 ? initialVal.toStringAsFixed(2) : '');
                            });
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text(name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase()),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 120,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.bgSecondary,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                      textAlign: TextAlign.end,
                                      decoration: InputDecoration(
                                        prefixText: ' $currencySymbol ',
                                        prefixStyle: const TextStyle(color: AppColors.textTertiary),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      ),
                                      onChanged: (val) {
                                        final doubleVal = double.tryParse(val) ?? 0.0;
                                        setState(() {
                                          _customSplitAmounts[userId] = doubleVal;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
                              final sum = _customSplitAmounts.values.fold(0.0, (a, b) => a + b);
                              final difference = totalAmount - sum;
                              final isMatched = difference.abs() < 0.01;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isMatched ? 'Total matched!' : 'Remaining to split:',
                                    style: TextStyle(
                                      color: isMatched ? AppColors.accentEmerald : AppColors.accentRose,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '$currencySymbol${difference.abs().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: isMatched ? AppColors.accentEmerald : AppColors.accentRose,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              );
                            }
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error: $e'),
                ),
              ],
              
              const SizedBox(height: 48),
              GradientButton(
                text: 'Save Expense',
                icon: LucideIcons.check,
                isLoading: _isSaving,
                onPressed: _saveExpense,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    final prefs = ref.watch(preferencesProvider);
    final preferredCurrencyCode = supportedCurrencies[prefs.currencyIndex].code;
    
    final amountText = _amountController.text;
    final originalAmount = double.tryParse(amountText) ?? 0.0;
    String conversionLabel = '';
    
    if (originalAmount > 0 && _selectedCurrency != preferredCurrencyCode) {
      final rate = prefs.rates[_selectedCurrency] ?? 1.0;
      final baseAmount = originalAmount / rate;
      final prefRate = prefs.rates[preferredCurrencyCode] ?? 1.0;
      final convertedAmount = baseAmount * prefRate;
      conversionLabel = '≈ ${CurrencyFormatter.format(convertedAmount, preferredCurrencyCode)}';
    }

    final info = supportedCurrencies.firstWhere((c) => c.code == _selectedCurrency, orElse: () => supportedCurrencies[0]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PopupMenuButton<String>(
              initialValue: _selectedCurrency,
              tooltip: 'Select Currency',
              color: AppColors.bgElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (code) {
                setState(() {
                  _selectedCurrency = code;
                });
                _onAmountChanged();
              },
              itemBuilder: (context) {
                return supportedCurrencies.map((c) {
                  return PopupMenuItem<String>(
                    value: c.code,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 18, color: AppColors.accentCyan),
                        const SizedBox(width: 10),
                        Text('${c.code} (${c.symbol})', style: const TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      info.symbol,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.chevronDown, color: AppColors.textSecondary, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: false,
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ),
            ),
          ],
        ),
        if (conversionLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              conversionLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
