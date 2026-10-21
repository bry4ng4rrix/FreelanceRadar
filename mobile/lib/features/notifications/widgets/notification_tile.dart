import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui.dart';
import '../data/notification_models.dart';

/// Icône du type de notification dans un cercle teinté.
class NotificationTypeIcon extends StatelessWidget {
  const NotificationTypeIcon({super.key, required this.notification, this.size = 40});

  final AppNotification notification;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = notification.type?.color ?? AppColors.textSecondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.tint(color, 0.14), shape: BoxShape.circle),
      child: Icon(
        notification.type?.icon ?? Icons.notifications_none_rounded,
        size: size * 0.5,
        color: color,
      ),
    );
  }
}

/// Élément de la liste des alertes : icône, titre, message (2 lignes), type et date.
/// Les notifications non lues sont mises en avant (fond plus clair, titre blanc, point).
class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final unread = !notification.isRead;
    final meta = [
      notification.type?.label ?? 'Notification',
      Fmt.relative(notification.createdAt),
    ].join(' · ');

    return Semantics(
      label: unread ? 'Non lue' : null,
      child: AppCard(
        onTap: onTap,
        color: unread ? AppColors.surfaceRaised : AppColors.surface,
        borderColor: unread ? AppColors.borderStrong : AppColors.border,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NotificationTypeIcon(notification: notification),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleSmall?.copyWith(
                            color: unread ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const Gap(10),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (notification.body.trim().isNotEmpty) ...[
                    const Gap(4),
                    Text(
                      notification.body.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium?.copyWith(
                        color: unread ? AppColors.textSecondary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                  const Gap(10),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.labelSmall?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
