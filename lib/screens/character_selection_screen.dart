import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/player_character.dart';
import '../services/user_data_service.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({
    super.key,
    required this.userId,
    this.onCharacterSelected,
  });

  final String userId;
  final Function(PlayerCharacter)? onCharacterSelected;

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  String? _selectedCharacterId;
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCharacter() async {
    if (_selectedCharacterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא בחר דמות'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final characterName = _nameController.text.trim();
    if (characterName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא הכנס שם לדמות'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final characterOption = CharacterOption.getById(_selectedCharacterId!);
      if (characterOption == null) {
        throw Exception('Character not found');
      }

      final character = PlayerCharacter(
        characterId: characterOption.id,
        characterName: characterName,
        color: characterOption.color,
      );

      final userDataService = UserDataService();
      await userDataService.updatePlayerData(
        widget.userId,
        {'character': character.toMap()},
      );

      if (mounted) {
        widget.onCharacterSelected?.call(character);
        Navigator.of(context).pop(character);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת הדמות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedOption = _selectedCharacterId != null
        ? CharacterOption.getById(_selectedCharacterId!)
        : null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.secondary.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'בחר את הדמות שלך!',
                  style: GoogleFonts.assistant(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'בחר דמות ונתן לה שם מיוחד',
                  style: GoogleFonts.assistant(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Character Selection Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: CharacterOption.availableCharacters.length,
                  itemBuilder: (context, index) {
                    final option = CharacterOption.availableCharacters[index];
                    final isSelected = _selectedCharacterId == option.id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCharacterId = option.id;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(option.color).withValues(alpha: 0.2)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Color(option.color)
                                : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? Color(option.color).withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.1),
                              blurRadius: isSelected ? 12 : 4,
                              spreadRadius: isSelected ? 2 : 0,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Character Emoji
                            Text(
                              option.emoji,
                              style: const TextStyle(fontSize: 64),
                            ),
                            const SizedBox(height: 12),
                            // Character Name
                            Text(
                              option.name,
                              style: GoogleFonts.assistant(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Color(option.color)
                                    : Colors.black87,
                              ),
                            ),
                            if (option.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                option.description!,
                                style: GoogleFonts.assistant(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (isSelected) ...[
                              const SizedBox(height: 8),
                              Icon(
                                Icons.check_circle,
                                color: Color(option.color),
                                size: 24,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Name Input
                if (selectedOption != null) ...[
                  Text(
                    'איך תרצה לקרוא לדמות שלך?',
                    style: GoogleFonts.assistant(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.assistant(fontSize: 20),
                    decoration: InputDecoration(
                      hintText: 'הכנס שם לדמות',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Color(selectedOption.color),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Color(selectedOption.color).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Color(selectedOption.color),
                          width: 3,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.edit,
                        color: Color(selectedOption.color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Save Button
                if (selectedOption != null)
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveCharacter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(selectedOption.color),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'שמור והמשך',
                                style: GoogleFonts.assistant(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isSaving ? null : () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'דלג לעת עתה',
                          style: GoogleFonts.assistant(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

