import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/ui.dart';
import '../applications_providers.dart';
import '../data/applications_repository.dart';
import '../data/reply_models.dart';

/// Carte d'une réponse reçue : expéditeur, objet, offre, date, point « non lue ».
class ReplyCard extends StatelessWidget {
  const ReplyCard({super.key, required this.reply, this.onTap, this.showOffer = true});

  final Reply reply;
  final VoidCallback? onTap;
  final bool showOffer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      color: reply.isRead ? AppColors.surface : AppColors.surfaceRaised,
      borderColor: reply.isRead ? AppColors.border : AppColors.borderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reply.sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall?.copyWith(
                    fontWeight: reply.isRead ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
              if (!reply.isRead) ...[
                const Gap(8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
          const Gap(4),
          Text(
            reply.subject.isEmpty ? '(sans objet)' : reply.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const Gap(6),
          Text(
            [
              if (showOffer) reply.offerTitle,
              Fmt.relative(reply.receivedAt ?? reply.createdAt),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Ouvre une réponse et la marque comme lue.
Future<void> showReply(BuildContext context, WidgetRef ref, Reply reply) async {
  if (!reply.isRead) {
    try {
      await ref.read(applicationsRepositoryProvider).markReplyRead(reply.id);
      ref
        ..invalidate(latestRepliesProvider)
        ..invalidate(applicationRepliesProvider(reply.applicationId));
    } catch (error) {
      showError(error);
    }
  }
  if (!context.mounted) return;
  await showAppSheet<void>(
    context,
    expand: true,
    builder: (context) {
      final theme = Theme.of(context).textTheme;
      return DetailSheet(
        title: 'Réponse reçue',
        children: [
          Text(reply.subject.isEmpty ? '(sans objet)' : reply.subject, style: theme.titleLarge),
          const Gap(12),
          InfoRow(icon: Icons.person_outline_rounded, label: 'De', value: reply.sender),
          InfoRow(icon: Icons.alternate_email_rounded, label: 'Adresse', value: reply.fromAddress),
          InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Reçue',
            value: Fmt.dateTime(reply.receivedAt ?? reply.createdAt),
          ),
          InfoRow(icon: Icons.work_outline_rounded, label: 'Offre', value: reply.offerTitle),
          const SheetSection('Message'),
          SelectableText(
            reply.body.isEmpty ? '(message vide)' : reply.body,
            style: theme.bodyMedium?.copyWith(height: 1.5),
          ),
          const Gap(16),
          const NoteBox(
            message:
                'Pour répondre, utilisez votre messagerie : le fil de discussion y est conservé.',
            icon: Icons.info_outline_rounded,
          ),
        ],
      );
    },
  );
}
