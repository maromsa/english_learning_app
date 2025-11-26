import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_session_provider.dart';
import 'user_switch_sheet.dart';
import '../optimized_avatar.dart';

class CurrentUserAvatar extends StatelessWidget {
  const CurrentUserAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserSessionProvider>(
      builder: (context, sessionProvider, child) {
        final user = sessionProvider.currentUser;

        if (user == null) {
          return IconButton(
            icon: const Icon(Icons.account_circle, size: 32),
            onPressed: () => _showSwitchSheet(context),
          );
        }

        return GestureDetector(
          onTap: () => _showSwitchSheet(context),
          child: Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // אווטר
                OptimizedAvatar(
                  imageUrl: user.photoUrl,
                  radius: 16,
                  fallbackText: user.name.isNotEmpty ? user.name : '?',
                  backgroundColor: Colors.blue.shade100,
                ),
                const SizedBox(width: 8),
                // שם משתמש - מוסתר במסכים קטנים מאוד
                Flexible(
                  child: Text(
                    user.name,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[600]),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSwitchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const UserSwitchSheet(),
    );
  }
}











