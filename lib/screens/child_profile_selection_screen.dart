import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/child_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/child_profile_provider.dart';
import '../widgets/optimized_avatar.dart';
import '../widgets/spark_overlay_suppressor.dart';
import 'map_screen.dart';

/// "Who is playing?" screen shown after parent authentication.
class ChildProfileSelectionScreen extends StatefulWidget {
  const ChildProfileSelectionScreen({
    super.key,
    this.allowSkipToMap = false,
  });

  /// When true, tapping back or finishing with one profile goes to [MapScreen].
  final bool allowSkipToMap;

  @override
  State<ChildProfileSelectionScreen> createState() =>
      _ChildProfileSelectionScreenState();
}

class _ChildProfileSelectionScreenState
    extends State<ChildProfileSelectionScreen> {
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  Future<void> _ensureLoaded() async {
    final provider = context.read<ChildProfileProvider>();
    if (provider.initialized) {
      return;
    }

    final auth = context.read<AuthProvider>();
    await provider.initialize(parentUid: auth.firebaseUser?.uid);
  }

  Future<void> _selectProfile(ChildProfile profile) async {
    final provider = context.read<ChildProfileProvider>();
    await provider.selectProfile(context, profile);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
  }

  Future<void> _createProfile() async {
    final result = await showDialog<_CreateProfileResult>(
      context: context,
      builder: (context) => const _CreateProfileDialog(),
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() => _creating = true);
    try {
      final provider = context.read<ChildProfileProvider>();
      final profile = await provider.createProfile(
        displayName: result.displayName,
        avatarColor: result.avatarColor,
      );
      await _selectProfile(profile);
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _deleteProfile(ChildProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת פרופיל'),
        content: Text('למחוק את הפרופיל של ${profile.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('מחק'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final provider = context.read<ChildProfileProvider>();
    await provider.deleteProfile(profile.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profileProvider = context.watch<ChildProfileProvider>();

    return SparkOverlaySuppressor(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('מי משחק?'),
          centerTitle: true,
        ),
        body: profileProvider.loading || _creating
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.blue.shade50],
                          stops: const [0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      if (auth.isAuthenticated)
                        _ParentBanner(
                          name: auth.currentUser?.displayName ??
                              auth.firebaseUser?.displayName ??
                              'הורה',
                          email: auth.currentUser?.email ??
                              auth.firebaseUser?.email ??
                              '',
                          photoUrl: auth.currentUser?.photoUrl ??
                              auth.firebaseUser?.photoURL,
                        ),
                      Expanded(
                        child: profileProvider.profiles.isEmpty
                            ? _EmptyState(onCreate: _createProfile)
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  100,
                                ),
                                itemCount: profileProvider.profiles.length,
                                itemBuilder: (context, index) {
                                  final profile =
                                      profileProvider.profiles[index];
                                  final isActive = profileProvider
                                          .activeProfileId ==
                                      profile.id;
                                  return _ProfileCard(
                                    profile: profile,
                                    isActive: isActive,
                                    onTap: () => _selectProfile(profile),
                                    onDelete: () => _deleteProfile(profile),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _creating ? null : _createProfile,
          icon: const Icon(Icons.add),
          label: const Text('פרופיל חדש'),
          backgroundColor: const Color(0xFF50C878),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class _ParentBanner extends StatelessWidget {
  const _ParentBanner({
    required this.name,
    required this.email,
    this.photoUrl,
  });

  final String name;
  final String email;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          OptimizedAvatar(
            imageUrl: photoUrl,
            radius: 22,
            fallbackText: name.isNotEmpty ? name : '?',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.family_restroom, color: Colors.white),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final ChildProfile profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: Colors.green, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Color(profile.avatarColor),
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        profile.displayName.isNotEmpty
                            ? profile.displayName[0]
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${profile.totalStars} כוכבים · רצף ${profile.dailyStreak}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.child_care, size: 80, color: Colors.blue.shade200),
          const SizedBox(height: 16),
          const Text(
            'עדיין אין פרופילים',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('צרו פרופיל ראשון לילד/ה'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('פרופיל חדש'),
          ),
        ],
      ),
    );
  }
}

class _CreateProfileResult {
  const _CreateProfileResult({
    required this.displayName,
    required this.avatarColor,
  });

  final String displayName;
  final int avatarColor;
}

class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog();

  @override
  State<_CreateProfileDialog> createState() => _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  final _nameController = TextEditingController();
  int _selectedColor = ChildProfile.defaultAvatarColors.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('פרופיל חדש'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'שם הילד/ה',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: ChildProfile.defaultAvatarColors.map((color) {
              final selected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: CircleAvatar(
                  radius: selected ? 22 : 18,
                  backgroundColor: Color(color),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _CreateProfileResult(
                displayName: name,
                avatarColor: _selectedColor,
              ),
            );
          },
          child: const Text('צור'),
        ),
      ],
    );
  }
}
