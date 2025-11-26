import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/optimized_avatar.dart';

import '../models/local_user.dart';
import '../providers/auth_provider.dart';
import '../providers/coin_provider.dart';
import '../providers/shop_provider.dart';
import '../services/achievement_service.dart';
import '../services/local_user_service.dart';
import 'create_user_screen.dart';
import 'map_screen.dart';
import 'sign_in_screen.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final LocalUserService _userService = LocalUserService();
  List<LocalUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectUser(LocalUser user) async {
    try {
      await _userService.setActiveUser(user.id);
      await _userService.updateLastPlayed(user.id);

      // If user is linked to Google, sign in automatically
      if (user.isLinkedToGoogle && user.googleUid != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isAuthenticated) {
          try {
            await authProvider.signInWithGoogle();
            // Verify it's the same Google account
            if (authProvider.firebaseUser?.uid != user.googleUid) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'החשבון Google לא תואם. אנא התחברו עם החשבון הנכון.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('Error auto-signing in with Google: $e');
            // Continue without Google sign-in
          }
        }
      }

      // Update providers with local user ID
      if (!mounted) return;
      final coinProvider = Provider.of<CoinProvider>(context, listen: false);
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final achievementService =
          Provider.of<AchievementService>(context, listen: false);

      coinProvider.setUserId(user.id, isLocalUser: true);
      shopProvider.setUserId(user.id);
      achievementService.setUserId(user.id);

      // Load coins for the selected user
      await coinProvider.loadCoins();

      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const MapScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('שגיאה בבחירת משתמש: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createNewUser() async {
    final user = await Navigator.push<LocalUser>(
      context,
      MaterialPageRoute(builder: (_) => const CreateUserScreen()),
    );

    if (user == null || !mounted) return;
    await _loadUsers();
    await _selectUser(user);
  }

  Future<void> _linkUserToGoogle(LocalUser user) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithGoogle();

      if (authProvider.isAuthenticated && authProvider.firebaseUser != null) {
        final firebaseUser = authProvider.firebaseUser!;
        await _userService.linkUserToGoogle(
          user.id,
          googleUid: firebaseUser.uid,
          googleEmail: firebaseUser.email ?? '',
          googleDisplayName: firebaseUser.displayName ?? '',
        );

        if (mounted) {
          await _loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('המשתמש קושר בהצלחה לחשבון Google!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בקישור ל-Google: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(LocalUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת משתמש'),
        content: Text('האם אתם בטוחים שברצונכם למחוק את ${user.name}?'),
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

    if (confirmed == true) {
      final deleted = await _userService.deleteUser(user.id);
      if (!mounted) return;
      if (deleted) {
        await _loadUsers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('המשתמש נמחק בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('מי משחק היום?'),
        centerTitle: true,
        actions: [
          if (authProvider.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'התנתקות',
              onPressed: () async {
                await authProvider.signOut();
                if (!mounted) return;
                final navigator = Navigator.of(context);
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Background Gradient
                Positioned.fill(
                  child: Container(
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
                    if (authProvider.isAuthenticated)
                      _GoogleHeroCard(authProvider: authProvider),

                    Expanded(
                      child: _users.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                return _UserCard(
                                  user: user,
                                  isActive: user.isActive,
                                  onTap: () => _selectUser(user),
                                  onDelete: () => _deleteUser(user),
                                  onLink: () => _linkUserToGoogle(user),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewUser,
        label: const Text('שחקן חדש'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF50C878),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_very_satisfied,
              size: 80, color: Colors.blue.shade200),
          const SizedBox(height: 16),
          Text(
            "אף אחד עוד לא כאן!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "לחצו על הכפתור למטה כדי ליצור משתמש חדש",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// --- Helper Widgets for User Selection ---

class _GoogleHeroCard extends StatelessWidget {
  final AuthProvider authProvider;
  const _GoogleHeroCard({required this.authProvider});

  @override
  Widget build(BuildContext context) {
    final appUser = authProvider.currentUser;
    final firebaseUser = authProvider.firebaseUser;
    final name = appUser?.displayName ??
        firebaseUser?.displayName ??
        'משתמש Google';
    final email = appUser?.email ?? firebaseUser?.email ?? '';
    final photoUrl = appUser?.photoUrl ?? firebaseUser?.photoURL;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: OptimizedAvatar(
                    imageUrl: photoUrl,
                    radius: 24,
                    placeholder: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: const Icon(Icons.cloud, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final LocalUser user;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onLink;

  const _UserCard({
    required this.user,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onLink,
  });

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
              Stack(
                children: [
                  OptimizedAvatar(
                    imageUrl: user.photoUrl,
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    fallbackText: user.name.isNotEmpty ? user.name : '?',
                  ),
                  if (isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        )),
                    Row(
                      children: [
                        Text('גיל: ${user.age}',
                            style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                        if (user.isLinkedToGoogle)
                          const Icon(Icons.cloud_done,
                              color: Colors.blue, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
              if (!user.isLinkedToGoogle)
                IconButton(
                  icon: const Icon(Icons.link, color: Colors.blue),
                  tooltip: "קשר ל-Google",
                  onPressed: onLink,
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
