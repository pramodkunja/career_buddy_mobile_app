import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/jam_history_profile.dart';
import '../controllers/jam_profile_controller.dart';

/// `jam:profile` (`templates/jam/profile.html`) — stats sidebar + editable
/// personal info + "Danger Zone" (Reset All Progress).
class JamProfileScreen extends ConsumerWidget {
  const JamProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jamProfileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile Settings')),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final profile) => _ProfileBody(profile: profile),
            AsyncError(:final error) => AppErrorView(
              message: error is Failure ? error.message : 'Could not load your profile.',
              onRetry: () => ref.read(jamProfileControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading profile...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});

  final JamProfile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _bio;
  bool _submitting = false;
  String? _submitError;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.profile.firstName);
    _lastName = TextEditingController(text: widget.profile.lastName);
    _email = TextEditingController(text: widget.profile.email);
    _bio = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final result = await ref.read(jamProfileControllerProvider.notifier).updateProfile(
      JamProfileUpdate(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        bio: _bio.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
      case Failed(failure: final failure):
        setState(() => _submitError = failure.message);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      // Verbatim web wording (`dashboard.html`'s Danger Zone section).
      builder: (context) => AlertDialog(
        title: const Text('Reset All Progress'),
        content: const Text(
          'Resetting your progress will permanently delete all your sessions, scores, and '
          'practice history. This action cannot be undone.\n\n'
          'Are you sure you want to reset all your progress?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset All Progress', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resetting = true);
    final result = await ref.read(jamProfileControllerProvider.notifier).resetProgress();
    if (!mounted) return;
    setState(() => _resetting = false);
    switch (result) {
      case Success():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All progress has been reset successfully.')),
        );
      case Failed(failure: final failure):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFFFE4E1),
                  child: Text(
                    profile.fullName.isEmpty ? '?' : profile.fullName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFF43F5E)),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                Text(profile.email, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _statCard('Total Sessions', '${profile.totalSessions}')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _statCard('Minutes Spoken', '${profile.totalMinutes}m')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: AppSpacing.sm),
                TextField(controller: _firstName, decoration: const InputDecoration(labelText: 'First Name', isDense: true)),
                const SizedBox(height: AppSpacing.sm),
                TextField(controller: _lastName, decoration: const InputDecoration(labelText: 'Last Name', isDense: true)),
                const SizedBox(height: AppSpacing.sm),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email Address', isDense: true)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _bio,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Bio / Motivation', hintText: "Tell us why you're learning English...", isDense: true),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(_submitError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppButton(label: 'Save Changes', icon: Icons.save_outlined, isLoading: _submitting, onPressed: _save),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              border: Border.all(color: const Color(0xFFFECDD3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Danger Zone', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE11D48), fontSize: 16)),
                const SizedBox(height: 6),
                const Text(
                  'Resetting your progress will permanently delete all your sessions, scores, and '
                  'practice history. This action cannot be undone.',
                  style: TextStyle(color: Color(0xFFBE123C), fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _resetting ? null : _confirmReset,
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE11D48)),
                  icon: _resetting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_forever_outlined),
                  label: const Text('Reset All Progress'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return AppCard(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFFF43F5E))),
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ],
      ),
    );
  }
}
