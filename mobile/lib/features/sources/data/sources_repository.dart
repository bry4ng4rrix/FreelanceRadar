import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import 'source_models.dart';

/// Accès à l'API des sources (`/sources`) et de leur historique de collecte.
class SourcesRepository {
  const SourcesRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Source>> sources({
    int page = 1,
    int pageSize = 50,
    bool? isActive,
    SourceType? type,
  }) => _api.getPage(
    '/sources',
    Source.fromJson,
    page: page,
    pageSize: pageSize,
    query: {'is_active': isActive, 'target_type': type?.api},
  );

  Future<Source> source(int id) => _api.getObject('/sources/$id', Source.fromJson);

  Future<Source> create(SourceInput input) async =>
      Source.fromJson(asJsonMap(await _api.post('/sources', body: input.toJson())));

  /// Modification partielle (`PATCH`) : seuls les champs fournis changent.
  Future<Source> update(int id, Map<String, dynamic> changes) async =>
      Source.fromJson(asJsonMap(await _api.patch('/sources/$id', body: changes)));

  /// Refusée (409) si la source a des offres ou un historique : il faut la désactiver.
  Future<void> delete(int id) => _api.delete('/sources/$id');

  /// Collecte d'essai : le serveur télécharge et analyse la source sans rien enregistrer.
  Future<SourceTestResult> test(int id) async =>
      SourceTestResult.fromJson(asJsonMap(await _api.post('/sources/$id/test')));

  /// Met une collecte en file (worker Celery). Renvoie l'identifiant de la tâche.
  Future<String> run(int id) async =>
      asJsonMap(await _api.post('/sources/$id/run'))['task_id']?.toString() ?? '';

  Future<Paginated<CollectionRun>> runs(int sourceId, {int page = 1, int pageSize = 20}) => _api
      .getPage('/sources/$sourceId/runs', CollectionRun.fromJson, page: page, pageSize: pageSize);
}

final sourcesRepositoryProvider = Provider<SourcesRepository>(
  (ref) => SourcesRepository(ref.watch(apiClientProvider)),
);
