import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json.dart';

/// Type de notification (`NotificationType`).
enum NotificationType {
  newOffers('new_offers', 'Nouvelles offres', Icons.work_outline_rounded, AppColors.info),
  sourceError('source_error', 'Source en erreur', Icons.error_outline_rounded, AppColors.danger),
  sourceBlocked('source_blocked', 'Source bloquée', Icons.block_rounded, AppColors.warning);

  const NotificationType(this.api, this.label, this.icon, this.color);

  final String api;
  final String label;
  final IconData icon;
  final Color color;

  static NotificationType? fromApi(Object? value) {
    for (final type in values) {
      if (type.api == value) return type;
    }
    return null;
  }
}

/// Notification persistée (`NotificationRead`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.typeValue,
    required this.title,
    required this.body,
    this.offerId,
    this.sourceId,
    this.collectionRunId,
    this.createdAt,
    this.readAt,
  });

  final int id;
  final String typeValue;
  final String title;
  final String body;
  final int? offerId;
  final int? sourceId;
  final int? collectionRunId;
  final DateTime? createdAt;
  final DateTime? readAt;

  NotificationType? get type => NotificationType.fromApi(typeValue);
  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: parseInt(json['id']) ?? 0,
    typeValue: json['type']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Notification',
    body: json['body']?.toString() ?? '',
    offerId: parseInt(json['offer_id']),
    sourceId: parseInt(json['source_id']),
    collectionRunId: parseInt(json['collection_run_id']),
    createdAt: parseDate(json['created_at']),
    readAt: parseDate(json['read_at']),
  );
}
