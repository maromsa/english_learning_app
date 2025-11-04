import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/coin_provider.dart';
import '../providers/theme_provider.dart';
import '../services/word_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('הגדרות'),
      ),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('מצב כהה'),
            subtitle: const Text('עברו בין מצב יום ולילה'),
            value: isDarkMode,
            onChanged: (value) async {
              await themeProvider.toggleTheme(value);
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
          content: const Text('הפעולה תאפס את הכוכבים שנצברו והמטבעות שהושגו בשלבים.'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ההתקדמות אופסה בהצלחה.'),
      ),
    );
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
