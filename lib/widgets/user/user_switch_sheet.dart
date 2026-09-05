import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/child_profile.dart';
import '../../providers/child_profile_provider.dart';
import '../../screens/child_profile_selection_screen.dart';
import '../optimized_avatar.dart';
import 'child_profile_create_dialog.dart';

/// Quick "who is playing now?" switcher shown from the map app bar.
///
/// Lets a sibling swap in — or a brand-new player be added inline — without
/// going through the gated Parent Dashboard. The heavy lifting (reloading
/// [CoinProvider], SRS/[WordMasteryService] user scope, streaks, missions) is
/// done by [ChildProfileProvider.selectProfile] → `ActiveProfileScope.apply`.
class UserSwitchSheet extends StatefulWidget {
  const UserSwitchSheet({super.key});

  @override
  State<UserSwitchSheet> createState() => _UserSwitchSheetState();
}

class _UserSwitchSheetState extends State<UserSwitchSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Defensive: normally AuthGate has already loaded profiles on startup, but
    // if that timed out make sure the list is populated when the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ChildProfileProvider>();
      if (!provider.initialized && !provider.loading) {
        provider.initialize();
      }
    });
  }

  Future<void> _selectProfile(ChildProfile profile) async {
    if (_busy) return;
    final provider = context.read<ChildProfileProvider>();
    if (provider.activeProfileId == profile.id) {
      Navigator.pop(context);
      return;
    }

    setState(() => _busy = true);
    await provider.selectProfile(context, profile);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!context.mounted) return;
    Navigator.pop(context);
    _showWelcome(profile.displayName);
  }

  Future<void> _addNewPlayer() async {
    if (_busy) return;
    final draft = await showDialog<ChildProfileDraft>(
      context: context,
      builder: (_) => const ChildProfileCreateDialog(),
    );
    if (draft == null || !mounted) return;

    final provider = context.read<ChildProfileProvider>();
    setState(() => _busy = true);
    try {
      final profile = await provider.createProfile(
        displayName: draft.displayName,
        avatarColor: draft.avatarColor,
      );
      if (!mounted) return;
      await provider.selectProfile(context, profile);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!context.mounted) return;
      Navigator.pop(context);
      _showWelcome(profile.displayName);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showWelcome(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          SparkStrings.welcomeBackUser(name),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openFullManager() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChildProfileSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ChildProfileProvider>();
    final activeId = profileProvider.activeProfileId;
    final profiles = profileProvider.profiles;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'מי משחק עכשיו?',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (profileProvider.loading || _busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (profiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'עדיין אין שחקנים. הוסיפו את הראשון!',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final profile in profiles)
                        _ProfileRow(
                          profile: profile,
                          isActive: activeId == profile.id,
                          onTap: () => _selectProfile(profile),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _addNewPlayer,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('הוסף שחקן חדש'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _busy ? null : _openFullManager,
              icon: const Icon(Icons.manage_accounts_rounded, size: 20),
              label: const Text('ניהול פרופילים'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  final ChildProfile profile;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue[50] : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              OptimizedAvatar(
                imageUrl: profile.avatarUrl,
                radius: 26,
                fallbackText:
                    profile.displayName.isNotEmpty ? profile.displayName : '?',
                backgroundColor: Color(profile.avatarColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: isActive ? Colors.blue[800] : Colors.black87,
                      ),
                    ),
                    Text(
                      '${profile.totalStars} כוכבים · רצף ${profile.dailyStreak}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.check_circle, color: Colors.blue)
              else
                Icon(Icons.chevron_left, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
