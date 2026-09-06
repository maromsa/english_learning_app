import 'package:flutter/material.dart';

import '../../models/child_profile.dart';
import '../../utils/aurora_tokens.dart';
import '../ui/kid_button.dart';

/// The values a parent/child picks when adding a new player.
class ChildProfileDraft {
  const ChildProfileDraft({
    required this.displayName,
    required this.avatarColor,
  });

  final String displayName;
  final int avatarColor;
}

/// Lightweight "new player" dialog — a name field and an avatar-colour picker.
///
/// Shared by [ChildProfileSelectionScreen] and the quick [UserSwitchSheet] so a
/// sibling can be added without leaving the map. Returns a [ChildProfileDraft]
/// via `Navigator.pop`, or `null` if cancelled.
class ChildProfileCreateDialog extends StatefulWidget {
  const ChildProfileCreateDialog({super.key});

  @override
  State<ChildProfileCreateDialog> createState() =>
      _ChildProfileCreateDialogState();
}

class _ChildProfileCreateDialogState extends State<ChildProfileCreateDialog> {
  final _nameController = TextEditingController();
  int _selectedColor = ChildProfile.defaultAvatarColors.first;

  bool get _canCreate => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      ChildProfileDraft(displayName: name, avatarColor: _selectedColor),
    );
  }

  InputDecoration _nameFieldDecoration(BuildContext context) {
    final base = Theme.of(context).inputDecorationTheme;
    return InputDecoration(
      labelText: 'שם הילד/ה',
      hintText: 'איך קוראים לך?',
      prefixIcon: Icon(
        Icons.face_rounded,
        color: AuroraTokens.plum.withValues(alpha: 0.85),
      ),
      filled: true,
      fillColor: AuroraTokens.paper2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AuroraTokens.rMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AuroraTokens.rMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AuroraTokens.rMd),
        borderSide: const BorderSide(color: AuroraTokens.plum, width: 2),
      ),
      contentPadding: base.contentPadding,
      labelStyle: base.labelStyle,
      hintStyle: base.hintStyle,
    );
  }

  Widget _colorSwatch(int color) {
    final selected = _selectedColor == color;
    return Semantics(
      button: true,
      selected: selected,
      label: 'צבע אווטאר',
      child: GestureDetector(
        onTap: () => setState(() => _selectedColor = color),
        child: AnimatedContainer(
          duration: AuroraTokens.dBounce,
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AuroraTokens.plum : Colors.transparent,
              width: 3,
            ),
            boxShadow: selected ? AuroraTokens.glow(AuroraTokens.plum) : null,
          ),
          child: CircleAvatar(
            radius: selected ? 20 : 18,
            backgroundColor: Color(color),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: AuroraTokens.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'שחקן חדש',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                style: textTheme.bodyLarge,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_canCreate) {
                    _submit();
                  }
                },
                decoration: _nameFieldDecoration(context),
              ),
              const SizedBox(height: 20),
              Text(
                'בחרו צבע',
                textAlign: TextAlign.center,
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children:
                    ChildProfile.defaultAvatarColors.map(_colorSwatch).toList(),
              ),
              const SizedBox(height: 24),
              KidButton.primary(
                label: 'צור',
                leadingIcon: Icons.add_rounded,
                fullWidth: true,
                onPressed: _canCreate ? _submit : null,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AuroraTokens.inkSoft,
                  textStyle: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('ביטול'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
