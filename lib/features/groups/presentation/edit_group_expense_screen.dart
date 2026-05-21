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

class EditGroupExpenseScreen extends ConsumerStatefulWidget {
  final String? groupId;
  final Map<String, dynamic>? expense;

  const EditGroupExpenseScreen({super.key, this.groupId, this.expense});

  @override
  ConsumerState<EditGroupExpenseScreen> createState() => _EditGroupExpenseScreenState();
}

class _EditGroupExpenseScreenState extends ConsumerState<EditGroupExpenseScreen> {
  late TextEditingController _amountController;
  late TextEditingController _descController;
  
  String _selectedCategory = 'other';
  String? _selectedPayerId;
  String _splitType = 'equal';
  
  Map<String, double> _customSplitAmounts = {};
  final Map<String, TextEditingController> _splitControllers = {};
  bool _isSaving = false;
  bool _isLoadingSplits = false;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'food', 'name': 'Food & Dining', 'icon': LucideIcons.utensils},
    {'id': 'transport', 'name': 'Transportation', 'icon': LucideIcons.car},
    {'id': 'entertainment', 'name': 'Entertainment', 'icon': LucideIcons.film},
    {'id': 'shopping', 'name': 'Shopping', 'icon': LucideIcons.shoppingBag},
    {'id': 'bills', 'name': 'Bills & Utilities', 'icon': LucideIcons.fileSpreadsheet},
    {'id': 'other', 'name': 'Other', 'icon': LucideIcons.moreHorizontal},
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.expense?['amount']?.toString() ?? '0.00',
    );
    _descController = TextEditingController(
      text: widget.expense?['description'] ?? '',
    );
    _selectedCategory = widget.expense?['category'] ?? 'other';
    _selectedPayerId = widget.expense?['paid_by'];
    final rawSplitType = widget.expense?['split_type'] ?? 'equal';
    _splitType = (rawSplitType == 'unequal') ? 'custom' : rawSplitType;

    // Hook listener to auto-distribute splits when the amount changes
    _amountController.addListener(_onAmountChanged);

    if (_splitType == 'custom') {
      _loadCustomSplits();
    }
  }

  Future<void> _loadCustomSplits() async {
    if (widget.expense == null) return;
    setState(() => _isLoadingSplits = true);
    try {
      final splits = await ref.read(groupServiceProvider).getExpenseSplits(widget.expense!['id']);
      final Map<String, double> map = {};
      for (final s in splits) {
        final userId = s['user_id'] as String?;
        final amount = s['amount'] is num ? (s['amount'] as num).toDouble() : 0.0;
        if (userId != null) {
          map[userId] = amount;
        }
      }
      setState(() {
        _customSplitAmounts = map;
      });
    } catch (e) {
      debugPrint('Error loading custom splits: $e');
    } finally {
      setState(() => _isLoadingSplits = false);
    }
  }

  void _onAmountChanged() {
    if (_splitType != 'custom') return;
    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    
    // Fetch group members from the provider's current state
    final members = ref.read(groupMembersStreamProvider(widget.groupId!)).value ?? [];
    if (members.isEmpty) return;

    // Distribute equally as a starting baseline
    final equalShare = totalAmount / members.length;
    final updatedSplits = <String, double>{};
    for (final m in members) {
      final userId = m['user_id'] as String;
      updatedSplits[userId] = double.parse(equalShare.toStringAsFixed(2));
    }
    
    setState(() {
      _customSplitAmounts = updatedSplits;
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _descController.dispose();
    for (final controller in _splitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showPayerSelectionSheet(List<Map<String, dynamic>> members) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final currentUserId = ref.read(currentUserProvider)?.id;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Who Paid?',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final m = members[index];
                    final userId = m['user_id'] as String;
                    final isSelf = userId == currentUserId;
                    final displayName = isSelf ? 'You' : (m['nickname'] ?? m['display_name'] ?? 'Member');
                    final isSelected = _selectedPayerId == userId || (_selectedPayerId == null && isSelf);

                    return ListTile(
                       leading: CircleAvatar(
                        backgroundColor: AppColors.accentCyan.withOpacity(0.12),
                        child: Text(
                          displayName.isEmpty ? 'U' : displayName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      trailing: isSelected
                          ? const Icon(LucideIcons.check, color: AppColors.accentCyan, size: 20)
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
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateExpense() async {
    if (widget.expense?['id']?.toString().startsWith('temp_') == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense is syncing with the server. Please wait...')),
      );
      return;
    }
    final title = _descController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid details')));
      return;
    }

    if (_splitType == 'custom') {
      final sum = _customSplitAmounts.values.fold(0.0, (a, b) => a + b);
      if ((sum - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Total splits (₹${sum.toStringAsFixed(2)}) must equal total amount (₹${amount.toStringAsFixed(2)})'),
            backgroundColor: AppColors.accentRose,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final currentUserId = ref.read(currentUserProvider)?.id ?? '';
      await ref.read(groupServiceProvider).updateGroupExpense(
        groupId: widget.groupId!,
        expenseId: widget.expense!['id'],
        description: title,
        amount: amount,
        category: _selectedCategory,
        paidBy: _selectedPayerId ?? currentUserId,
        splitType: _splitType,
        customSplits: _splitType == 'custom' ? _customSplitAmounts : null,
      );
      
      ref.invalidate(groupExpensesStreamProvider(widget.groupId!));
      ref.invalidate(expensesStreamProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense updated successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteExpense() async {
    if (widget.expense?['id']?.toString().startsWith('temp_') == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense is syncing with the server. Please wait...')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.trash2, color: AppColors.accentRose, size: 22),
            SizedBox(width: 10),
            Text('Delete Expense', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: AppColors.bgPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(groupServiceProvider).deleteGroupExpense(
        widget.groupId!,
        widget.expense!['id'],
      );
      
      ref.invalidate(groupExpensesStreamProvider(widget.groupId!));
      ref.invalidate(expensesStreamProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting expense: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null || widget.expense == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Group Expense'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Error: Missing group ID or expense data', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId!));
    final currentUserId = ref.read(currentUserProvider)?.id ?? '';
    final isOwner = widget.expense!['paid_by'] == currentUserId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isOwner ? 'Edit Group Expense' : 'View Group Expense',
          style: const TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: AppColors.accentRose, size: 20),
              onPressed: _isSaving ? null : _deleteExpense,
              tooltip: 'Delete Expense',
            ),
        ],
      ),
      body: SafeArea(
        child: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.accentRose))),
          data: (members) {
            final payerId = _selectedPayerId ?? currentUserId;
            final payer = members.firstWhere((m) => m['user_id'] == payerId, orElse: () => {});
            final payerName = payerId == currentUserId ? 'You' : (payer['nickname'] ?? payer['display_name'] ?? 'Member');

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  
                  // Amount Section
                  GlassCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('₹', style: TextStyle(color: AppColors.accentCyan, fontSize: 36, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              IntrinsicWidth(
                                child: TextField(
                                  controller: _amountController,
                                  readOnly: !isOwner,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'JetBrainsMono',
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    hintText: '0.00',
                                    hintStyle: TextStyle(color: AppColors.textTertiary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Divider(color: AppColors.borderSubtle, height: 24),
                          GestureDetector(
                            onTap: isOwner ? () => _showPayerSelectionSheet(members) : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Paid by ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                                Text(
                                  payerName,
                                  style: TextStyle(
                                    color: AppColors.accentCyan,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    decoration: isOwner ? TextDecoration.underline : TextDecoration.none,
                                  ),
                                ),
                                if (isOwner) ...[
                                  const SizedBox(width: 4),
                                  const Icon(LucideIcons.chevronDown, color: AppColors.accentCyan, size: 14),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Details Card
                  GlassCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('EXPENSE DETAILS', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Description',
                            hint: 'What was this for?',
                            controller: _descController,
                            enabled: isOwner,
                            prefixIcon: const Icon(LucideIcons.alignLeft, color: AppColors.textTertiary),
                          ),
                          const SizedBox(height: 20),
                          const Text('Category', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategory == cat['id'];
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(cat['icon'] as IconData, size: 14, color: isSelected ? AppColors.bgPrimary : AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(cat['name'] as String),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: isOwner ? (selected) {
                                  if (selected) {
                                    setState(() => _selectedCategory = cat['id'] as String);
                                  }
                                } : null,
                                selectedColor: AppColors.accentCyan,
                                backgroundColor: AppColors.bgTertiary,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppColors.bgPrimary : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Split Options
                  GlassCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SPLIT OPTIONS', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Split Equally')),
                                  selected: _splitType == 'equal',
                                  onSelected: isOwner ? (selected) {
                                    if (selected) {
                                      setState(() => _splitType = 'equal');
                                    }
                                  } : null,
                                  selectedColor: AppColors.accentCyan,
                                  backgroundColor: AppColors.bgTertiary,
                                  labelStyle: TextStyle(
                                    color: _splitType == 'equal' ? AppColors.bgPrimary : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Split Custom')),
                                  selected: _splitType == 'custom',
                                  onSelected: isOwner ? (selected) {
                                    if (selected) {
                                      setState(() => _splitType = 'custom');
                                      _onAmountChanged();
                                    }
                                  } : null,
                                  selectedColor: AppColors.accentCyan,
                                  backgroundColor: AppColors.bgTertiary,
                                  labelStyle: TextStyle(
                                    color: _splitType == 'custom' ? AppColors.bgPrimary : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),

                          if (_splitType == 'custom') ...[
                            const SizedBox(height: 20),
                            const Text('Custom Allocation', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            _isLoadingSplits 
                              ? const Center(child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                                ))
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: members.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, idx) {
                                    final m = members[idx];
                                    final userId = m['user_id'] as String;
                                    final displayName = userId == currentUserId ? 'You' : (m['nickname'] ?? m['display_name'] ?? 'Member');
                                    final currentVal = _customSplitAmounts[userId] ?? 0.0;
                                    final controller = _splitControllers.putIfAbsent(userId, () {
                                      return TextEditingController(
                                        text: currentVal > 0 ? currentVal.toStringAsFixed(2) : '',
                                      );
                                    });

                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppColors.accentCyan.withOpacity(0.12),
                                          child: Text(
                                            displayName.isEmpty ? 'U' : displayName.substring(0, 1).toUpperCase(),
                                            style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 110,
                                          height: 40,
                                          child: TextField(
                                            controller: controller,
                                            readOnly: !isOwner,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700),
                                            decoration: InputDecoration(
                                              prefixText: '₹',
                                              prefixStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderSubtle)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderSubtle)),
                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentCyan)),
                                            ),
                                            onChanged: (val) {
                                              final dVal = double.tryParse(val) ?? 0.0;
                                              _customSplitAmounts[userId] = dVal;
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                            
                            // Realtime split validation indicator
                            if (!_isLoadingSplits) ...[
                              const SizedBox(height: 16),
                              Builder(
                                builder: (context) {
                                  final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
                                  final sum = _customSplitAmounts.values.fold(0.0, (a, b) => a + b);
                                  final difference = totalAmount - sum;

                                  final isMatched = difference.abs() < 0.02;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: (isMatched ? AppColors.accentEmerald : AppColors.accentRose).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: (isMatched ? AppColors.accentEmerald : AppColors.accentRose).withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isMatched ? LucideIcons.checkCircle2 : LucideIcons.alertTriangle,
                                          color: isMatched ? AppColors.accentEmerald : AppColors.accentRose,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isMatched
                                                ? 'Total matched!'
                                                : (difference > 0
                                                    ? '₹${difference.toStringAsFixed(2)} remaining to assign'
                                                    : 'Over-allocated by ₹${difference.abs().toStringAsFixed(2)}'),
                                            style: TextStyle(
                                              color: isMatched ? AppColors.accentEmerald : AppColors.accentRose,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (isOwner) ...[
                    GradientButton(
                      text: 'Update Expense',
                      icon: LucideIcons.save,
                      onPressed: _isSaving ? null : _updateExpense,
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
