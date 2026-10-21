import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json.dart';

/// Statut d'une offre (`OfferStatus` côté API).
enum OfferStatus {
  newOffer('new', 'Nouvelle', Icons.fiber_new_outlined, AppColors.info),
  relevant('relevant', 'Pertinente', Icons.thumb_up_alt_outlined, AppColors.success),
  favorite('favorite', 'Favorite', Icons.star_rounded, AppColors.warning),
  ignored('ignored', 'Ignorée', Icons.visibility_off_outlined, AppColors.textTertiary),
  applicationPrepared(
    'application_prepared',
    'Candidature préparée',
    Icons.edit_note_rounded,
    AppColors.violet,
  ),
  applicationSent('application_sent', 'Candidature envoyée', Icons.send_rounded, AppColors.violet);

  const OfferStatus(this.api, this.label, this.icon, this.color);

  final String api;
  final String label;
  final IconData icon;
  final Color color;

  /// Statuts que l'utilisateur peut poser lui-même (les autres viendront des candidatures).
  static const userSettable = [newOffer, relevant, favorite, ignored];

  static OfferStatus fromApi(Object? value) =>
      values.firstWhere((status) => status.api == value, orElse: () => newOffer);
}

/// Tris proposés par l'API (`sort`).
enum OfferSort {
  collectedDesc('-collected_at', 'Collecte la plus récente'),
  collectedAsc('collected_at', 'Collecte la plus ancienne'),
  publishedDesc('-published_at', 'Publication la plus récente'),
  publishedAsc('published_at', 'Publication la plus ancienne');

  const OfferSort(this.api, this.label);

  final String api;
  final String label;
}

/// Offre normalisée (`OfferRead`).
class Offer {
  const Offer({
    required this.id,
    required this.sourceId,
    required this.url,
    required this.title,
    required this.description,
    required this.status,
    required this.collectedAt,
    this.externalId,
    this.company,
    this.location,
    this.missionType,
    this.category,
    this.budgetMin,
    this.budgetMax,
    this.currency,
    this.skills = const [],
    this.publishedAt,
    this.relevanceScore,
    this.aiSummary,
    this.notes,
    this.archivedAt,
  });

  final int id;
  final int sourceId;
  final String? externalId;
  final String url;
  final String title;
  final String? company;
  final String description;
  final String? location;
  final String? missionType;
  final String? category;
  final double? budgetMin;
  final double? budgetMax;
  final String? currency;
  final List<String> skills;
  final DateTime? publishedAt;
  final DateTime? collectedAt;
  final int? relevanceScore;
  final String? aiSummary;
  final OfferStatus status;
  final String? notes;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
  bool get hasBudget => budgetMin != null || budgetMax != null;
  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;

  /// Date affichée dans les listes (publication, sinon collecte).
  DateTime? get displayDate => publishedAt ?? collectedAt;

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
    id: parseInt(json['id']) ?? 0,
    sourceId: parseInt(json['source_id']) ?? 0,
    externalId: _text(json['external_id']),
    url: json['url']?.toString() ?? '',
    title: _text(json['title']) ?? 'Sans titre',
    company: _text(json['company']),
    description: json['description']?.toString() ?? '',
    location: _text(json['location']),
    missionType: _text(json['mission_type']),
    category: _text(json['category']),
    // Les montants (Decimal) arrivent sous forme de chaîne.
    budgetMin: parseDouble(json['budget_min']),
    budgetMax: parseDouble(json['budget_max']),
    currency: _text(json['currency']),
    skills: parseStringList(json['skills']),
    publishedAt: parseDate(json['published_at']),
    collectedAt: parseDate(json['collected_at']),
    relevanceScore: parseInt(json['relevance_score']),
    aiSummary: _text(json['ai_summary']),
    status: OfferStatus.fromApi(json['status']),
    notes: _text(json['notes']),
    archivedAt: parseDate(json['archived_at']),
  );

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// Filtres de la liste des offres (paramètres de `GET /offers`).
class OfferFilters {
  const OfferFilters({
    this.search,
    this.sourceId,
    this.status,
    this.publishedAfter,
    this.includeArchived = false,
    this.sort = OfferSort.collectedDesc,
  });

  final String? search;
  final int? sourceId;
  final OfferStatus? status;
  final DateTime? publishedAfter;
  final bool includeArchived;
  final OfferSort sort;

  /// La recherche n'est envoyée qu'à partir de 2 caractères (règle du serveur).
  bool get hasSearch => (search?.trim().length ?? 0) >= 2;

  /// Nombre de filtres actifs (hors recherche et tri).
  int get activeCount => [
    sourceId != null,
    status != null,
    publishedAfter != null,
    includeArchived,
  ].where((active) => active).length;

  Map<String, dynamic> toQuery() => {
    if (hasSearch) 'q': search!.trim(),
    'source_id': sourceId,
    'status': status?.api,
    'published_after': publishedAfter,
    if (includeArchived) 'include_archived': true,
    'sort': sort.api,
  };

  OfferFilters copyWith({
    String? Function()? search,
    int? Function()? sourceId,
    OfferStatus? Function()? status,
    DateTime? Function()? publishedAfter,
    bool? includeArchived,
    OfferSort? sort,
  }) => OfferFilters(
    search: search == null ? this.search : search(),
    sourceId: sourceId == null ? this.sourceId : sourceId(),
    status: status == null ? this.status : status(),
    publishedAfter: publishedAfter == null ? this.publishedAfter : publishedAfter(),
    includeArchived: includeArchived ?? this.includeArchived,
    sort: sort ?? this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is OfferFilters &&
      other.search == search &&
      other.sourceId == sourceId &&
      other.status == status &&
      other.publishedAfter == publishedAfter &&
      other.includeArchived == includeArchived &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(search, sourceId, status, publishedAfter, includeArchived, sort);
}
