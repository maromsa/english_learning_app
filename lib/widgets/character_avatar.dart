import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/player_character.dart';

/// Widget to display player character avatar
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.character,
    this.size = 48,
    this.showName = false,
    this.onTap,
  });

  final PlayerCharacter character;
  final double size;
  final bool showName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final characterOption = CharacterOption.getById(character.characterId);
    final color = character.color != null
        ? Color(character.color!)
        : (characterOption?.color != null
            ? Color(characterOption!.color)
            : Colors.blue);

    final emoji = characterOption?.emoji ?? '👤';

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.6),
        ),
      ),
    );

    if (onTap != null) {
      avatar = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: avatar,
      );
    }

    if (showName) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(height: 4),
          Text(
            character.characterName,
            style: GoogleFonts.assistant(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return avatar;
  }
}

