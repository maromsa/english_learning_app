import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../providers/coin_provider.dart';
import '../providers/theme_provider.dart';
import '../services/word_repository.dart';
import '../services/background_music_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBusy = false;
  bool _musicEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadMusicSetting();
  }

  Future<void> _loadMusicSetting() async {
    final musicService = BackgroundMusicService();
    setState(() {
      _musicEnabled = musicService.isEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('הגדרות')),
      body: ListView(
        children: [
          _buildProfileHeader(context),
          const Divider(),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('מצב כהה'),
            subtitle: const Text('עברו בין מצב יום ולילה'),
            value: isDarkMode,
            onChanged: (value) async {
              await themeProvider.toggleTheme(value);
            },
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.music_note),
            title: const Text('מוזיקת רקע'),
            subtitle: const Text('הפעל או כבה את מוזיקת הרקע'),
            value: _musicEnabled,
            onChanged: (value) async {
              setState(() {
                _musicEnabled = value;
              });
              await BackgroundMusicService().setEnabled(value);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.auto_fix_high),
            title: const Text('איפוס התקדמות במפה'),
            subtitle: const Text('מאפס כוכבים ומטבעות שהושגו בשלבים'),
            enabled: !_isBusy,
            onTap: _isBusy ? null : () => _confirmResetProgress(context),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('ניקוי מטמון מילים'),
            subtitle: const Text('מוחק מילים שנשמרו במכשיר לצורך טעינה מהירה'),
            enabled: !_isBusy,
            onTap: _isBusy ? null : () => _clearWordCache(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('התנתקות מהחשבון'),
            subtitle: const Text('חזרה למסך הכניסה של Google'),
            enabled: !_isBusy,
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
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final appUser = authProvider.currentUser;
    final firebaseUser = authProvider.firebaseUser;

    final displayName = appUser?.displayName ?? firebaseUser?.displayName;
    final email = appUser?.email ?? firebaseUser?.email ?? '';
    final photoUrl = appUser?.photoUrl ?? firebaseUser?.photoURL;

    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withOpacity(0.15),
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null
            ? Text(
                email.isNotEmpty ? email[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(displayName ?? 'משתמש ללא שם'),
      subtitle: Text(email.isEmpty ? 'לא נמצאה כתובת Gmail' : email),
      trailing: authProvider.isBusy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
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
    await context.read<CoinProvider>().setCoins(0);

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('מטמון המילים נוקה. בפעם הבאה נטען תוכן חדש מהענן.'),
      ),
    );
  }
}
