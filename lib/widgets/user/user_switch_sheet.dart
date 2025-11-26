import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/user_session_provider.dart';
import '../../services/local_user_service.dart';
import '../../models/local_user.dart';
import '../../providers/coin_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/achievement_service.dart';
import '../../screens/user_selection_screen.dart';
import '../optimized_avatar.dart';

class UserSwitchSheet extends StatefulWidget {
  const UserSwitchSheet({super.key});

  @override
  State<UserSwitchSheet> createState() => _UserSwitchSheetState();
}

class _UserSwitchSheetState extends State<UserSwitchSheet> {
  final LocalUserService _localUserService = LocalUserService();
  List<LocalUser> _localUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await _localUserService.getAllUsers();
    if (mounted) {
      setState(() {
        _localUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUserSwitch(AppSessionUser newUser) async {
    final sessionProvider = Provider.of<UserSessionProvider>(context, listen: false);

    // 1. עדכון ה-Session
    if (newUser.isGoogle) {
      // כאן נדרש שהמשתמש כבר יהיה מחובר ב-Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == newUser.id) {
        await sessionProvider.switchToGoogleUser(currentUser);
      }
    } else {
      // מציאת המשתמש המקומי המלא
      final localUser = _localUsers.firstWhere((u) => u.id == newUser.id);
      await sessionProvider.switchToLocalUser(localUser);
    }

    // 2. עדכון מטבעות ושאר הנתונים באפליקציה
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final achievementService = Provider.of<AchievementService>(context, listen: false);

    coinProvider.setUserId(newUser.id, isLocalUser: !newUser.isGoogle);
    shopProvider.setUserId(newUser.id);
    achievementService.setUserId(newUser.id);
    await coinProvider.loadCoins();

    if (!mounted) return;
    Navigator.pop(context); // סגירת הדיאלוג

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('היי ${newUser.name}, כיף שחזרת!', textAlign: TextAlign.center),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<UserSessionProvider>(context);
    final currentUser = session.currentUser;
    final googleUser = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const Text(
            "מי משחק עכשיו?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // רשימת משתמשים מקומיים
            ..._localUsers.map((localUser) {
              final isActive = currentUser != null &&
                  !currentUser.isGoogle &&
                  currentUser.id == localUser.id;
              return _buildUserTile(
                name: localUser.name,
                photoUrl: localUser.photoUrl,
                isActive: isActive,
                onTap: () => _handleUserSwitch(AppSessionUser(
                  id: localUser.id,
                  name: localUser.name,
                  isGoogle: false,
                  photoUrl: localUser.photoUrl,
                )),
              );
            }).toList(),

            // משתמש גוגל (אם מחובר)
            if (googleUser != null)
              _buildUserTile(
                name: googleUser.displayName ?? 'Google User',
                photoUrl: googleUser.photoURL,
                isGoogle: true,
                isActive: currentUser != null && currentUser.isGoogle,
                onTap: () => _handleUserSwitch(AppSessionUser(
                  id: googleUser.uid,
                  name: googleUser.displayName ?? 'Google',
                  isGoogle: true,
                  photoUrl: googleUser.photoURL,
                )),
              ),
          ],

          const Divider(height: 32),

          // כפתורי פעולה
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // ניווט למסך יצירת משתמש/בחירה מלאה
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text("ניהול משתמשים / משתמש חדש"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUserTile({
    required String name,
    String? photoUrl,
    bool isGoogle = false,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue[50] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              OptimizedAvatar(
                imageUrl: photoUrl,
                radius: 24,
                fallbackText: name.isNotEmpty ? name : '?',
                backgroundColor: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isActive ? Colors.blue[800] : Colors.black87,
                      ),
                    ),
                    if (isGoogle)
                      const Text(
                        "חשבון Google",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    if (!isGoogle)
                      const Text(
                        "משתמש מקומי",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.check_circle, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }
}











