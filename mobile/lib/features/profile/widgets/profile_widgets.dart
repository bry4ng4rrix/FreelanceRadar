import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/profile_models.dart';

/// Petits composants partagés par les écrans du profil.

/// Niveau de maîtrise en 4 barres croissantes (débutant → expert).
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.level, this.showLabel = true, this.dimmed = false});

  final SkillLevel level;
  final bool showLabel;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final active = dimmed ? AppColors.textTertiary : AppColors.textPrimary;
    return Semantics(
      label: 'Niveau ${level.label}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 1; i <= SkillLevel.values.length; i++) ...[
            if (i > 1) const Gap(2),
            Container(
              width: 4,
              height: 4.0 + i * 3,
              decoration: BoxDecoration(
                color: i <= level.rank ? active : AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
          if (showLabel) ...[
            const Gap(8),
            Text(
              level.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: dimmed ? AppColors.textTertiary : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Choix du niveau de maîtrise, avec la jauge sous chaque libellé.
class LevelSelector extends StatelessWidget {
  const LevelSelector({super.key, required this.value, required this.onChanged});

  final SkillLevel value;
  final ValueChanged<SkillLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final level in SkillLevel.values) ...[
          if (level.index > 0) const Gap(8),
          Expanded(
            child: Material(
              color: level == value ? AppColors.surfaceHighest : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.input,
                side: BorderSide(color: level == value ? AppColors.textPrimary : AppColors.border),
              ),
              child: InkWell(
                borderRadius: AppRadius.input,
                onTap: () => onChanged(level),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Column(
                    children: [
                      LevelMeter(level: level, showLabel: false, dimmed: level != value),
                      const Gap(8),
                      Text(
                        level.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.labelSmall?.copyWith(
                          color: level == value ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: level == value ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Texte d'aide discret en tête de page.
class IntroText extends StatelessWidget {
  const IntroText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    ),
  );
}
