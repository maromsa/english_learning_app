import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/optimized_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_character.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../providers/coin_provider.dart';
import '../providers/theme_provider.dart';
import '../services/word_repository.dart';
import '../services/local_user_service.dart';
import '../widgets/character_avatar.dart';
import 'character_selection_screen.dart';
import 'user_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBusy = false;
  final LocalUserService _localUserService = LocalUserService();
  String? _localUserName;
  int? _localUserAge;
  String? _localUserPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadLocalUser();
  }

  Future<void> _loadLocalUser() async {
    final localUser = await _localUserService.getActiveUser();
    if (mounted) {
      setState(() {
        _localUserName = localUser?.name;
        _localUserAge = localUser?.age;
        _localUserPhotoUrl = localUser?.photoUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? null : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('הגדרות',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Hero Profile Header
          _ProfileHeroCard(
            name: _localUserName,
            age: _localUserAge,
            photoUrl: _localUserPhotoUrl,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserSelectionScreen(),
                ),
              );
              if (result == true && mounted) {
                await _loadLocalUser();
                setState(() {});
              }
            },
          ),

          const SizedBox(height: 24),
          const _SectionHeader(title: "הדמות שלי"),
          const SizedBox(height: 8),

          // 2. Character Section
          Consumer<CharacterProvider>(
            builder: (context, characterProvider, _) {
              return _CharacterCard(
                character: characterProvider.character,
                onTap: characterProvider.hasCharacter
                    ? () => _editCharacter(context)
                    : () => _selectCharacter(context),
              );
            },
          ),

          const SizedBox(height: 24),
          const _SectionHeader(title: "הגדרות אפליקציה"),
          const SizedBox(height: 8),

          // 3. App Settings Group
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.dark_mode,
                  iconColor: Colors.purple,
                  title: 'מצב כהה',
                  subtitle: 'ערכת נושא לילה',
                  trailing: Switch.adaptive(
                    value: isDarkMode,
                    onChanged: (value) async {
                      await themeProvider.toggleTheme(value);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 60),
                _SettingsTile(
                  icon: Icons.cleaning_services,
                  iconColor: Colors.orange,
                  title: 'ניקוי מטמון',
                  subtitle: 'פינוי מקום באחסון',
                  onTap: _isBusy ? null : () => _clearWordCache(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const _SectionHeader(title: "חשבון ונתונים"),
          const SizedBox(height: 8),

          // 4. Account Actions Group
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.auto_fix_high,
                  iconColor: Colors.blue,
                  title: 'איפוס התקדמות',
                  subtitle: 'מחיקת כוכבים ומטבעות',
                  onTap: _isBusy ? null : () => _confirmResetProgress(context),
                ),
                const Divider(height: 1, indent: 60),
                _SettingsTile(
                  icon: Icons.swap_horiz,
                  iconColor: Colors.green,
                  title: 'החלפת משתמש',
                  subtitle: 'עבור לפרופיל אחר',
                  onTap: _isBusy
                      ? null
                      : () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UserSelectionScreen(),
                            ),
                          );
                          if (mounted) {
                            await _loadLocalUser();
                            if (result == true) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                ),
                const Divider(height: 1, indent: 60),
                _SettingsTile(
                  icon: Icons.logout,
                  iconColor: Colors.red,
                  title: 'התנתקות',
                  subtitle: 'יציאה מהחשבון',
                  isDestructive: true,
                  onTap: _isBusy
                      ? null
                      : () async {
                          setState(() => _isBusy = true);
                          try {
                            await context.read<AuthProvider>().signOut();
                          } finally {
                            if (mounted) {
                              setState(() => _isBusy = false);
                            }
                          }
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmResetProgress(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('לאפס את המסע?'),
          content: const Text(
            'הפעולה תאפס את הכוכבים שנצברו והמטבעות שהושגו בשלבים.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('איפוס'),
            ),
          ],
        );
      },
    );

    if (shouldReset == true) {
      await _resetProgress();
    }
  }

  Future<void> _resetProgress() async {
    setState(() => _isBusy = true);
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs
        .getKeys()
        .where((key) => key.startsWith('level_') && key.endsWith('_stars'))
        .toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
    if (mounted) {
      await context.read<CoinProvider>().setCoins(0);
    }

    if (!mounted) return;
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ההתקדמות אופסה בהצלחה.')));
  }

  Future<void> _clearWordCache(BuildContext context) async {
    setState(() => _isBusy = true);
    final repository = WordRepository();
    await repository.clearCache();

    if (!mounted) return;
    setState(() => _isBusy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('מטמון המילים נוקה. בפעם הבאה נטען תוכן חדש מהענן.'),
        ),
      );
    }
  }

  Future<void> _selectCharacter(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.firebaseUser == null) return;

    final character = await Navigator.push<PlayerCharacter>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSelectionScreen(
          userId: authProvider.firebaseUser!.uid,
        ),
      ),
    );

    if (character == null || !mounted) return;
    final characterProvider = context.read<CharacterProvider>();
    await characterProvider.setCharacter(character);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('הדמות נשמרה בהצלחה!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _editCharacter(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.firebaseUser == null) return;

    final character = await Navigator.push<PlayerCharacter>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSelectionScreen(
          userId: authProvider.firebaseUser!.uid,
        ),
      ),
    );

    if (character == null || !mounted) return;
    final characterProvider = context.read<CharacterProvider>();
    await characterProvider.setCharacter(character);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('הדמות עודכנה בהצלחה!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// --- Helper Widgets for Settings ---

class _ProfileHeroCard extends StatelessWidget {
  final String? name;
  final int? age;
  final String? photoUrl;
  final VoidCallback onTap;

  const _ProfileHeroCard({
    this.name,
    this.age,
    this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use auth provider for fallbacks if local data missing
    final authProvider = context.watch<AuthProvider>();
    final appUser = authProvider.currentUser;
    final firebaseUser = authProvider.firebaseUser;
    final displayPhoto = photoUrl ?? appUser?.photoUrl ?? firebaseUser?.photoURL;
    final displayName = name ??
        appUser?.displayName ??
        firebaseUser?.displayName ??
        'אורח';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade400],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              child: OptimizedAvatar(
                imageUrl: displayPhoto,
                radius: 32,
                backgroundColor: Colors.white,
                fallbackText: displayName.isNotEmpty ? displayName : '?',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    age != null ? 'גיל: $age' : 'משתמש ראשי',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final PlayerCharacter? character;
  final VoidCallback onTap;

  const _CharacterCard({
    this.character,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasChar = character != null;
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (hasChar)
                CharacterAvatar(character: character!, size: 50)
              else
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add, color: Colors.grey),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasChar ? character!.characterName : 'בחירת דמות',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      hasChar
                          ? 'הדמות המלווה שלך'
                          : 'לחצו כדי לבחור חבר למסע',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey.shade400)
              : null),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }
}
