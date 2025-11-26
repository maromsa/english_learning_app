import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_user.dart';

/// Service for managing local user profiles
class LocalUserService {
  static const String _usersKey = 'local_users';
  static const String _activeUserIdKey = 'active_local_user_id';

  /// Get all local users
  Future<List<LocalUser>> getAllUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      if (usersJson == null || usersJson.isEmpty) {
        return [];
      }

      final List<dynamic> usersList = jsonDecode(usersJson);
      return usersList
          .map((userMap) => LocalUser.fromMap(userMap as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading local users: $e');
      return [];
    }
  }

  /// Get active user
  Future<LocalUser?> getActiveUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeUserId = prefs.getString(_activeUserIdKey);
      if (activeUserId == null) {
        return null;
      }

      final users = await getAllUsers();
      return users.firstWhere(
        (user) => user.id == activeUserId,
        orElse: () => throw StateError('Active user not found'),
      );
    } catch (e) {
      debugPrint('Error getting active user: $e');
      return null;
    }
  }

  /// Create a new local user
  Future<LocalUser> createUser({
    required String name,
    required int age,
    String? photoUrl,
    String? googleUid,
    String? googleEmail,
    String? googleDisplayName,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    final user = LocalUser(
      id: id,
      name: name,
      age: age,
      photoUrl: photoUrl,
      createdAt: now,
      lastPlayedAt: now,
      isActive: false,
      googleUid: googleUid,
      googleEmail: googleEmail,
      googleDisplayName: googleDisplayName,
    );

    await _saveUser(user);
    return user;
  }

  /// Link user to Google account
  Future<void> linkUserToGoogle(
    String userId, {
    required String googleUid,
    required String googleEmail,
    required String googleDisplayName,
  }) async {
    try {
      final users = await getAllUsers();
      final user = users.firstWhere((u) => u.id == userId);
      final updatedUser = user.copyWith(
        googleUid: googleUid,
        googleEmail: googleEmail,
        googleDisplayName: googleDisplayName,
      );
      await updateUser(updatedUser);
    } catch (e) {
      debugPrint('Error linking user to Google: $e');
      rethrow;
    }
  }

  /// Get user by ID
  Future<LocalUser?> getUserById(String userId) async {
    try {
      final users = await getAllUsers();
      try {
        return users.firstWhere((u) => u.id == userId);
      } catch (e) {
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  /// Get user by Google UID
  Future<LocalUser?> getUserByGoogleUid(String googleUid) async {
    try {
      final users = await getAllUsers();
      return users.firstWhere(
        (u) => u.googleUid == googleUid,
        orElse: () => throw StateError('User not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Save user to storage
  Future<void> _saveUser(LocalUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await getAllUsers();

      // Remove existing user with same ID if exists
      users.removeWhere((u) => u.id == user.id);
      users.add(user);

      final usersJson = jsonEncode(users.map((u) => u.toMap()).toList());
      await prefs.setString(_usersKey, usersJson);
    } catch (e) {
      debugPrint('Error saving user: $e');
      rethrow;
    }
  }

  /// Update user
  Future<void> updateUser(LocalUser user) async {
    await _saveUser(user);
  }

  /// Set active user
  Future<void> setActiveUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await getAllUsers();

      // Update all users to set isActive
      for (var user in users) {
        user = user.copyWith(isActive: user.id == userId);
        await _saveUser(user);
      }

      await prefs.setString(_activeUserIdKey, userId);
    } catch (e) {
      debugPrint('Error setting active user: $e');
      rethrow;
    }
  }

  /// Delete user
  Future<bool> deleteUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await getAllUsers();

      users.removeWhere((u) => u.id == userId);

      final usersJson = jsonEncode(users.map((u) => u.toMap()).toList());
      await prefs.setString(_usersKey, usersJson);

      // If deleted user was active, clear active user
      final activeUserId = prefs.getString(_activeUserIdKey);
      if (activeUserId == userId) {
        await prefs.remove(_activeUserIdKey);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  /// Update last played time
  Future<void> updateLastPlayed(String userId) async {
    try {
      final users = await getAllUsers();
      final user = users.firstWhere((u) => u.id == userId);
      final updatedUser = user.copyWith(lastPlayedAt: DateTime.now());
      await updateUser(updatedUser);
    } catch (e) {
      debugPrint('Error updating last played: $e');
    }
  }
}
