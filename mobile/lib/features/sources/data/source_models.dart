import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json.dart';

/// Type de connecteur d'une source (`target_type`).
enum SourceType {
  rss('rss', 'RSS / Atom', Icons.rss_feed_rounded),
  html('html', 'Page HTML', Icons.code_rounded),
  playwright('playwright', 'Playwright', Icons.web_rounded),
  restApi('api', 'API', Icons.api_rounded),
  manual('manual', 'Manuelle', Icons.edit_outlined);

  const SourceType(this.api, this.label, this.icon);

  final String api;
  final String label;
  final IconData icon;

  /// Connecteurs implémentés par le serveur (registre `app/collectors/registry.py`).
  /// Les autres types sont enregistrables mais leur collecte échoue (`unsupported`).
  bool get hasConnector => this == rss;

  static SourceType? fromApi(Object? value) {
    for (final type in values) {
      if (type.api == value) return type;
    }
    return null;
  }
}

/// État de santé d'une source (`health_status`).
enum SourceHealth {
  unknown('unknown', 'Jamais collectée', AppColors.textTertiary, Icons.help_outline_rounded),
  ok('ok', 'Opérationnelle', AppColors.success, Icons.check_circle_outline_rounded),
  error('error', 'En erreur', AppColors.danger, Icons.error_outline_rounded),
  blocked('blocked', 'Bloquée par le site', AppColors.warning, Icons.block_rounded),
  unsupported('unsupported', 'Connecteur absent', AppColors.textTertiary, Icons.extension_off);

  const SourceHealth(this.api, this.label, this.color, this.icon);

  final String api;
  final String label;
  final Color color;
  final IconData icon;

  static SourceHealth fromApi(Object? value) =>
      values.firstWhere((health) => health.api == value, orElse: () => unknown);
}

/// Source d'offres (`SourceRead`).
class Source {
  const Source({
    required this.id,
    required this.name,
    required this.url,
    required this.typeValue,
    required this.frequencyMinutes,
    required this.isActive,
    required this.health,
    this.category,
    this.keywords = const [],
    this.selectors = const {},
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.lastError,
    this.offersCount = 0,
    this.errorCount = 0,
    this.consecutiveFailures = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? category;
  final String url;
  final String typeValue;
  final int frequencyMinutes;
  final bool isActive;
  final List<String> keywords;
  final Map<String, dynamic> selectors;
  final SourceHealth health;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final int offersCount;
  final int errorCount;
  final int consecutiveFailures;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SourceType? get type => SourceType.fromApi(typeValue);
  String get typeLabel => type?.label ?? typeValue;
  bool get hasConnector => type?.hasConnector ?? false;
  bool get hasError => lastError != null && lastError!.trim().isNotEmpty;

  factory Source.fromJson(Map<String, dynamic> json) => Source(
    id: parseInt(json['id']) ?? 0,
    name: json['name']?.toString() ?? 'Source',
    category: _text(json['category']),
    url: json['url']?.toString() ?? '',
    typeValue: json['target_type']?.toString() ?? '',
    frequencyMinutes: parseInt(json['frequency_minutes']) ?? 60,
    isActive: json['is_active'] as bool? ?? false,
    keywords: parseStringList(json['keywords']),
    selectors: parseMap(json['selectors']),
    health: SourceHealth.fromApi(json['health_status']),
    lastAttemptAt: parseDate(json['last_attempt_at']),
    lastSuccessAt: parseDate(json['last_success_at']),
    lastError: _text(json['last_error']),
    offersCount: parseInt(json['offers_count']) ?? 0,
    errorCount: parseInt(json['error_count']) ?? 0,
    consecutiveFailures: parseInt(json['consecutive_failures']) ?? 0,
    createdAt: parseDate(json['created_at']),
    updatedAt: parseDate(json['updated_at']),
  );

  Source copyWith({bool? isActive}) => Source(
    id: id,
    name: name,
    category: category,
    url: url,
    typeValue: typeValue,
    frequencyMinutes: frequencyMinutes,
    isActive: isActive ?? this.isActive,
    keywords: keywords,
    selectors: selectors,
    health: health,
    lastAttemptAt: lastAttemptAt,
    lastSuccessAt: lastSuccessAt,
    lastError: lastError,
    offersCount: offersCount,
    errorCount: errorCount,
    consecutiveFailures: consecutiveFailures,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// Champs modifiables d'une source (`SourceCreate` / `SourceUpdate`).
class SourceInput {
  const SourceInput({
    required this.name,
    required this.url,
    required this.type,
    required this.frequencyMinutes,
    required this.isActive,
    this.category,
    this.keywords = const [],
    this.selectors = const {},
  });

  final String name;
  final String? category;
  final String url;
  final SourceType type;
  final int frequencyMinutes;
  final bool isActive;
  final List<String> keywords;
  final Map<String, dynamic> selectors;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'category': category == null || category!.trim().isEmpty ? null : category!.trim(),
    'url': url.trim(),
    'target_type': type.api,
    'frequency_minutes': frequencyMinutes,
    'is_active': isActive,
    'keywords': keywords,
    'selectors': selectors,
  };
}

/// Statut d'une exécution de collecte.
enum RunStatus {
  running('running', 'En cours', AppColors.info),
  success('success', 'Réussie', AppColors.success),
  failed('failed', 'Échec', AppColors.danger),
  blocked('blocked', 'Bloquée', AppColors.warning),
  unsupported('unsupported', 'Non supportée', AppColors.textTertiary);

  const RunStatus(this.api, this.label, this.color);

  final String api;
  final String label;
  final Color color;

  static RunStatus? fromApi(Object? value) {
    for (final status in values) {
      if (status.api == value) return status;
    }
    return null;
  }
}

/// Exécution d'une collecte (`CollectionRunRead`).
class CollectionRun {
  const CollectionRun({
    required this.id,
    required this.sourceId,
    required this.triggerValue,
    required this.statusValue,
    this.taskId,
    this.startedAt,
    this.finishedAt,
    this.itemsSeen = 0,
    this.itemsNew = 0,
    this.itemsDuplicate = 0,
    this.itemsInvalid = 0,
    this.errorMessage,
  });

  final int id;
  final int sourceId;
  final String triggerValue;
  final String statusValue;
  final String? taskId;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int itemsSeen;
  final int itemsNew;
  final int itemsDuplicate;
  final int itemsInvalid;
  final String? errorMessage;

  RunStatus? get status => RunStatus.fromApi(statusValue);
  bool get isRunning => status == RunStatus.running;
  String get triggerLabel => switch (triggerValue) {
    'manual' => 'Manuelle',
    'schedule' => 'Planifiée',
    _ => triggerValue,
  };

  Duration? get duration =>
      startedAt == null || finishedAt == null ? null : finishedAt!.difference(startedAt!);

  factory CollectionRun.fromJson(Map<String, dynamic> json) => CollectionRun(
    id: parseInt(json['id']) ?? 0,
    sourceId: parseInt(json['source_id']) ?? 0,
    triggerValue: json['trigger']?.toString() ?? '',
    statusValue: json['status']?.toString() ?? '',
    taskId: json['task_id']?.toString(),
    startedAt: parseDate(json['started_at']),
    finishedAt: parseDate(json['finished_at']),
    itemsSeen: parseInt(json['items_seen']) ?? 0,
    itemsNew: parseInt(json['items_new']) ?? 0,
    itemsDuplicate: parseInt(json['items_duplicate']) ?? 0,
    itemsInvalid: parseInt(json['items_invalid']) ?? 0,
    errorMessage: json['error_message']?.toString(),
  );
}

/// Résultat d'une collecte d'essai, sans écriture en base (`SourceTestResult`).
class SourceTestResult {
  const SourceTestResult({
    required this.ok,
    required this.itemsFound,
    required this.validItems,
    required this.sampleTitles,
    this.error,
  });

  final bool ok;
  final int itemsFound;
  final int validItems;
  final List<String> sampleTitles;
  final String? error;

  factory SourceTestResult.fromJson(Map<String, dynamic> json) => SourceTestResult(
    ok: json['ok'] as bool? ?? false,
    itemsFound: parseInt(json['items_found']) ?? 0,
    validItems: parseInt(json['valid_items']) ?? 0,
    sampleTitles: parseStringList(json['sample_titles']),
    error: json['error']?.toString(),
  );
}
