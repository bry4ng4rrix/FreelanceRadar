import '../../../core/utils/json.dart';

/// Réponse d'un client à une candidature, lue dans la boîte de réception (`ReplyRead`).
class Reply {
  const Reply({
    required this.id,
    required this.applicationId,
    required this.offerTitle,
    required this.fromAddress,
    required this.subject,
    required this.body,
    this.fromName,
    this.receivedAt,
    this.createdAt,
    this.readAt,
  });

  final int id;
  final int applicationId;
  final String offerTitle;
  final String fromAddress;
  final String? fromName;
  final String subject;
  final String body;
  final DateTime? receivedAt;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
  String get sender => fromName ?? fromAddress;

  factory Reply.fromJson(Map<String, dynamic> json) => Reply(
    id: parseInt(json['id']) ?? 0,
    applicationId: parseInt(json['application_id']) ?? 0,
    offerTitle: json['offer_title']?.toString() ?? 'Offre',
    fromAddress: json['from_address']?.toString() ?? '',
    fromName: json['from_name']?.toString(),
    subject: json['subject']?.toString() ?? '',
    body: json['body_text']?.toString() ?? '',
    receivedAt: parseDate(json['received_at']),
    createdAt: parseDate(json['created_at']),
    readAt: parseDate(json['read_at']),
  );
}
