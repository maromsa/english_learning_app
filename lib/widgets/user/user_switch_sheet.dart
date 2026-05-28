import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/child_profile.dart';
import '../../providers/child_profile_provider.dart';
import '../../screens/child_profile_selection_screen.dart';
import '../optimized_avatar.dart';

class UserSwitchSheet extends StatelessWidget {
  const UserSwitchSheet({super.key});

  Future<void> _selectProfile(
    BuildContext context,
    ChildProfile profile,
  ) async {
    final provider = context.read<ChildProfileProvider>();
    await provider.selectProfile(context, profile);

    if (!context.mounted) {
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          SparkStrings.welcomeBackUser(profile.displayName),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ChildProfileProvider>();
    final activeId = profileProvider.activeProfileId;

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
          Text(
            'מי משחק עכשיו?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (profileProvider.loading)
            const Center(child: CircularProgressIndicator())
          else if (profileProvider.profiles.isEmpty)
            const Text('אין פרופילים. צרו פרופיל חדש.')
          else
            ...profileProvider.profiles.map((profile) {
              final isActive = activeId == profile.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _selectProfile(context, profile),
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
                          imageUrl: profile.avatarUrl,
                          radius: 24,
                          fallbackText: profile.displayName.isNotEmpty
                              ? profile.displayName
                              : '?',
                          backgroundColor: Color(profile.avatarColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            profile.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color:
                                  isActive ? Colors.blue[800] : Colors.black87,
                            ),
                          ),
                        ),
                        if (isActive)
                          const Icon(Icons.check_circle, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const Divider(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChildProfileSelectionScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.switch_account),
              label: const Text('החלפת פרופיל / פרופיל חדש'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
