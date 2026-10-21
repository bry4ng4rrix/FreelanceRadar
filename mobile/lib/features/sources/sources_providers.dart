import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/source_models.dart';
import 'data/sources_repository.dart';

/// Détail d'une source.
final sourceDetailProvider = FutureProvider.autoDispose.family<Source, int>(
  (ref, id) => ref.watch(sourcesRepositoryProvider).source(id),
);

/// Dernières collectes d'une source.
final sourceRunsProvider = FutureProvider.autoDispose.family<List<CollectionRun>, int>((
  ref,
  id,
) async {
  final page = await ref.watch(sourcesRepositoryProvider).runs(id, pageSize: 10);
  return page.items;
});

/// Toutes les sources (100 au maximum, limite de l'API) : noms affichés sur les offres,
/// filtre par source et résumé de l'accueil.
final allSourcesProvider = FutureProvider.autoDispose<List<Source>>((ref) async {
  final page = await ref.watch(sourcesRepositoryProvider).sources(pageSize: 100);
  return page.items;
});

/// Nom d'une source par identifiant (vide tant que la liste n'est pas chargée).
final sourceNamesProvider = Provider.autoDispose<Map<int, String>>((ref) {
  final sources = ref.watch(allSourcesProvider).value ?? const <Source>[];
  return {for (final source in sources) source.id: source.name};
});
