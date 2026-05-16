import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../data/group_service.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSaving = false;

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name is required')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(groupServiceProvider).createGroup(name, _descController.text.trim());
      if (mounted) context.pop();
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.x, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('CREATE GROUP', style: TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w700, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.camera, color: AppColors.textTertiary, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                label: 'Group Name',
                hint: 'e.g. Goa Trip 2024',
                controller: _nameController,
                prefixIcon: const Icon(LucideIcons.users, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Description (Optional)',
                hint: 'What is this group for?',
                controller: _descController,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              const Text('Group Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Default Currency', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('INR (₹)', style: TextStyle(color: AppColors.textSecondary)),
                trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
                onTap: () {},
              ),
              Divider(color: AppColors.borderSubtle),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require Admin Approval', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Only admins can add members', style: TextStyle(color: AppColors.textSecondary)),
                trailing: Switch(value: false, onChanged: (v){}, activeThumbColor: AppColors.accentCyan),
              ),
              const SizedBox(height: 48),
              GradientButton(
                text: 'Create Group',
                icon: LucideIcons.check,
                isLoading: _isSaving,
                onPressed: _createGroup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
