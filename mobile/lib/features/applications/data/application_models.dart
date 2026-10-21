import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json.dart';

/// Statut d'une candidature (`ApplicationStatus`).
enum ApplicationStatus {
  generating('generating', 'Rédaction en cours', Icons.auto_awesome_rounded, AppColors.violet),
  generationFailed(
    'generation_failed',
    'Rédaction impossible',
    Icons.error_outline_rounded,
    AppColors.danger,
  ),
  pendingApproval('pending_approval', 'À valider', Icons.rate_review_outlined, AppColors.warning),
  sending('sending', 'Envoi en cours', Icons.outgoing_mail, AppColors.info),
  sent('sent', 'Envoyée', Icons.send_rounded, AppColors.success),
  failed('failed', 'Échec d\'envoi', Icons.error_outline_rounded, AppColors.danger),
  deliveryUnknown(
    'delivery_unknown',
    'Envoi incertain',
    Icons.help_outline_rounded,
    AppColors.warning,
  ),
  cancelled('cancelled', 'Annulée', Icons.block_rounded, AppColors.textTertiary);

  const ApplicationStatus(this.api, this.label, this.icon, this.color);

  final String api;
  final String label;
  final IconData icon;
  final Color color;

  /// Brouillon modifiable (mêmes règles que le serveur).
  bool get isEditable => this == pendingApproval || this == generationFailed || this == failed;

  /// Envoi possible (une nouvelle tentative contrôlée après un échec certain).
  bool get isSendable => this == pendingApproval || this == failed;

  bool get canRegenerate => isEditable;

  bool get canCancel =>
      this != sending && this != sent && this != deliveryUnknown && this != cancelled;

  static ApplicationStatus fromApi(Object? value) =>
      values.firstWhere((s) => s.api == value, orElse: () => pendingApproval);
}

/// Candidature (`ApplicationRead`).
class Application {
  const Application({
    required this.id,
    required this.offerId,
    required this.offerTitle,
    required this.offerUrl,
    required this.status,
    this.recipientEmail,
    this.subject,
    this.message,
    this.language,
    this.generatedSubject,
    this.generatedMessage,
    this.referencedSkills = const [],
    this.aiWarnings = const [],
    this.aiConfidence,
    this.aiModel,
    this.generatedAt,
    this.generationCount = 0,
    this.sendAttempts = 0,
    this.sentAt,
    this.sentFrom,
    this.sentTo,
    this.sentSubject,
    this.sentMessage,
    this.errorMessage,
    this.updatedAt,
  });

  final int id;
  final int offerId;
  final String offerTitle;
  final String offerUrl;
  final ApplicationStatus status;
  final String? recipientEmail;
  final String? subject;
  final String? message;
  final String? language;
  final String? generatedSubject;
  final String? generatedMessage;
  final List<String> referencedSkills;
  final List<String> aiWarnings;
  final double? aiConfidence;
  final String? aiModel;
  final DateTime? generatedAt;
  final int generationCount;
  final int sendAttempts;
  final DateTime? sentAt;
  final String? sentFrom;
  final String? sentTo;
  final String? sentSubject;
  final String? sentMessage;
  final String? errorMessage;
  final DateTime? updatedAt;

  /// Le texte a été modifié par rapport à la version rédigée par l'IA.
  bool get isEdited =>
      generatedMessage != null && (message != generatedMessage || subject != generatedSubject);

  factory Application.fromJson(Map<String, dynamic> json) => Application(
    id: parseInt(json['id']) ?? 0,
    offerId: parseInt(json['offer_id']) ?? 0,
    offerTitle: json['offer_title']?.toString() ?? 'Offre',
    offerUrl: json['offer_url']?.toString() ?? '',
    status: ApplicationStatus.fromApi(json['status']),
    recipientEmail: json['recipient_email']?.toString(),
    subject: json['subject']?.toString(),
    message: json['message']?.toString(),
    language: json['language']?.toString(),
    generatedSubject: json['generated_subject']?.toString(),
    generatedMessage: json['generated_message']?.toString(),
    referencedSkills: parseStringList(json['referenced_skills']),
    aiWarnings: parseStringList(json['ai_warnings']),
    aiConfidence: parseDouble(json['ai_confidence']),
    aiModel: json['ai_model']?.toString(),
    generatedAt: parseDate(json['generated_at']),
    generationCount: parseInt(json['generation_count']) ?? 0,
    sendAttempts: parseInt(json['send_attempts']) ?? 0,
    sentAt: parseDate(json['sent_at']),
    sentFrom: json['sent_from']?.toString(),
    sentTo: json['sent_to']?.toString(),
    sentSubject: json['sent_subject']?.toString(),
    sentMessage: json['sent_message']?.toString(),
    errorMessage: json['error_message']?.toString(),
    updatedAt: parseDate(json['updated_at']),
  );
}
