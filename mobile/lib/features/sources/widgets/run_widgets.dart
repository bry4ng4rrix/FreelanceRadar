import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/ui.dart';
import '../data/source_models.dart';

/// Carte et détail d'une exécution de collecte (`/sources/{id}/runs`).

String runDurationLabel(CollectionRun run) {
  final duration = run.duration;
  if (duration == null) return run.isRunning ? 'en cours' : '—';
  return Fmt.duration(duration.inMilliseconds / 1000);
}

/// Pastille de statut d'une collecte.
class RunStatusPill extends StatelessWidget {
  const RunStatusPill({super.key, required this.run, this.dense = true});

  final CollectionRun run;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final status = run.status;
    return Pill(
      status?.label ?? run.statusValue,
      color: status?.color,
      dense: dense,
      icon: run.isRunning ? Icons.autorenew_rounded : null,
    );
  }
}

/// Carte résumée d'une collecte.
class RunCard extends StatelessWidget {
  const RunCard({super.key, required this.run, this.onTap});

  final CollectionRun run;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final meta = [run.triggerLabel, if (run.duration != null) runDurationLabel(run)].join(' · ');

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.dateTime(run.startedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall,
                ),
              ),
              const Gap(10),
              RunStatusPill(run: run),
            ],
          ),
          const Gap(4),
          Text(meta, style: theme.bodySmall?.copyWith(color: AppColors.textTertiary)),
          const Gap(10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              MetricText(value: run.itemsSeen, label: run.itemsSeen > 1 ? 'lues' : 'lue'),
              MetricText(value: run.itemsNew, label: run.itemsNew > 1 ? 'nouvelles' : 'nouvelle'),
              if (run.itemsDuplicate > 0)
                MetricText(
                  value: run.itemsDuplicate,
                  label: run.itemsDuplicate > 1 ? 'doublons' : 'doublon',
                ),
              if (run.itemsInvalid > 0)
                MetricText(
                  value: run.itemsInvalid,
                  label: run.itemsInvalid > 1 ? 'invalides' : 'invalide',
                  color: AppColors.warning,
                ),
            ],
          ),
          if (run.errorMessage != null && run.errorMessage!.trim().isNotEmpty) ...[
            const Gap(8),
            Text(
              run.errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ouvre le détail d'une collecte (données déjà chargées : pas d'appel réseau).
Future<void> showRunDetail(BuildContext context, CollectionRun run) => showAppSheet<void>(
  context,
  expand: true,
  builder: (_) => DetailSheet(
    title: 'Collecte',
    children: [_RunDetailBody(run: run)],
  ),
);

class _RunDetailBody extends StatelessWidget {
  const _RunDetailBody({required this.run});

  final CollectionRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Collecte n° ${run.id}', style: theme.headlineSmall)),
            const Gap(10),
            RunStatusPill(run: run, dense: false),
          ],
        ),
        const Gap(6),
        Text(
          '${run.triggerLabel} · ${Fmt.relative(run.startedAt)}',
          style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
        ),
        const Gap(18),
        ResponsiveGrid(
          minItemWidth: 96,
          maxColumns: 4,
          spacing: 8,
          children: [
            _CountTile(label: 'Lues', value: run.itemsSeen),
            _CountTile(label: 'Nouvelles', value: run.itemsNew, color: AppColors.success),
            _CountTile(label: 'Doublons', value: run.itemsDuplicate),
            _CountTile(
              label: 'Invalides',
              value: run.itemsInvalid,
              color: run.itemsInvalid > 0 ? AppColors.warning : null,
            ),
          ],
        ),
        if (run.errorMessage != null && run.errorMessage!.trim().isNotEmpty) ...[
          const Gap(16),
          NoteBox(
            title: 'Erreur',
            message: run.errorMessage!,
            color: AppColors.danger,
            icon: Icons.error_outline_rounded,
          ),
        ],
        const SheetSection('Chronologie'),
        InfoRow(
          icon: Icons.play_circle_outline_rounded,
          label: 'Démarrée',
          value: Fmt.dateTime(run.startedAt),
        ),
        InfoRow(icon: Icons.flag_outlined, label: 'Terminée', value: Fmt.dateTime(run.finishedAt)),
        InfoRow(icon: Icons.timer_outlined, label: 'Durée', value: runDurationLabel(run)),
        if (run.taskId != null)
          InfoRow(icon: Icons.tag_rounded, label: 'Tâche Celery', value: run.taskId),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Fmt.number(value),
            style: theme.titleLarge?.copyWith(color: color ?? AppColors.textPrimary),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
