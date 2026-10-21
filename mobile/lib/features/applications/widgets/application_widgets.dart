import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui.dart';
import '../data/application_models.dart';

/// Pastille de statut d'une candidature.
class ApplicationStatusPill extends StatelessWidget {
  const ApplicationStatusPill({super.key, required this.status, this.dense = true});

  final ApplicationStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) =>
      Pill(status.label, color: status.color, icon: status.icon, dense: dense);
}

/// Carte d'une candidature (rapport) : offre, statut, destinataire et date.
class ApplicationCard extends StatelessWidget {
  const ApplicationCard({super.key, required this.application, this.onTap});

  final Application application;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sent = application.status == ApplicationStatus.sent;
    final meta = [
      if (sent && application.sentTo != null) '→ ${application.sentTo}',
      if (!sent && application.recipientEmail != null) '→ ${application.recipientEmail}',
      Fmt.relative(sent ? application.sentAt : application.updatedAt),
    ].join(' · ');
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  application.offerTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall,
                ),
              ),
              const Gap(10),
              ApplicationStatusPill(status: application.status),
            ],
          ),
          if (application.subject != null) ...[
            const Gap(6),
            Text(
              application.subject!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const Gap(8),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Bloc « texte envoyé » en lecture seule (contenu exact transmis au serveur SMTP).
class SentMessageCard extends StatelessWidget {
  const SentMessageCard({super.key, required this.application});

  final Application application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(icon: Icons.person_outline_rounded, label: 'De', value: application.sentFrom),
          InfoRow(icon: Icons.alternate_email_rounded, label: 'À', value: application.sentTo),
          InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Envoyée le',
            value: Fmt.dateTime(application.sentAt),
          ),
          const Divider(),
          const Gap(AppSpacing.sm),
          Text(application.sentSubject ?? '', style: theme.titleSmall),
          const Gap(AppSpacing.sm),
          SelectableText(
            application.sentMessage ?? '',
            style: theme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
