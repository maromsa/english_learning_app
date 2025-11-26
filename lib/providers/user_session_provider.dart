import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/local_user.dart';
import '../services/local_user_service.dart';

/// מחלקה עוטפת לייצוג אחיד של משתמש ב-UI
class AppSessionUser {
  final String id;
  final String name;
  final String? photoUrl;
  final bool isGoogle;

  AppSessionUser({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.isGoogle,
  });
}

class UserSessionProvider with ChangeNotifier {
  AppSessionUser? _currentUser;
  final LocalUserService _localUserService = LocalUserService();

  AppSessionUser? get currentUser => _currentUser;

  /// טעינה ראשונית בעליית האפליקציה
  Future<void> loadActiveUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastUserId = prefs.getString('last_active_user_id');
      final bool isGoogle = prefs.getBool('last_active_is_google') ?? false;

      if (lastUserId != null) {
        if (isGoogle) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && user.uid == lastUserId) {
            _currentUser = AppSessionUser(
              id: user.uid,
              name: user.displayName ?? 'Google User',
              photoUrl: user.photoURL,
              isGoogle: true,
            );
          }
        } else {
          final users = await _localUserService.getAllUsers();
          try {
            final localUser = users.firstWhere((u) => u.id == lastUserId);
            _currentUser = AppSessionUser(
              id: localUser.id,
              name: localUser.name,
              photoUrl: localUser.photoUrl,
              isGoogle: false,
            );
          } catch (e) {
            debugPrint('User not found: $e');
            // User not found, continue without setting current user
          }
        }
        notifyListeners();
      } else {
        // אם אין משתמש שמור, ננסה לטעון את המשתמש הפעיל המקומי
        final activeLocalUser = await _localUserService.getActiveUser();
        if (activeLocalUser != null) {
          _currentUser = AppSessionUser(
            id: activeLocalUser.id,
            name: activeLocalUser.name,
            photoUrl: activeLocalUser.photoUrl,
            isGoogle: false,
          );
          await _saveSessionState();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading active user: $e');
    }
  }

  /// מעבר למשתמש מקומי
  Future<void> switchToLocalUser(LocalUser user) async {
    _currentUser = AppSessionUser(
      id: user.id,
      name: user.name,
      photoUrl: user.photoUrl,
      isGoogle: false,
    );
    await _localUserService.setActiveUser(user.id);
    await _localUserService.updateLastPlayed(user.id);
    await _saveSessionState();
    notifyListeners();
  }

  /// מעבר למשתמש גוגל
  Future<void> switchToGoogleUser(User user) async {
    _currentUser = AppSessionUser(
      id: user.uid,
      name: user.displayName ?? 'אורח',
      photoUrl: user.photoURL,
      isGoogle: true,
    );
    await _saveSessionState();
    notifyListeners();
  }

  Future<void> _saveSessionState() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active_user_id', _currentUser!.id);
    await prefs.setBool('last_active_is_google', _currentUser!.isGoogle);
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_active_user_id');
    await prefs.remove('last_active_is_google');
    notifyListeners();
  }
}

