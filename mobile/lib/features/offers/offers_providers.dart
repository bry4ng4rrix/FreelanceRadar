import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/offer_models.dart';
import 'data/offers_repository.dart';

/// Filtres de la liste des offres, gardés en mémoire entre les changements d'onglet.
class OfferFiltersNotifier extends Notifier<OfferFilters> {
  @override
  OfferFilters build() => const OfferFilters();

  void set(OfferFilters filters) => state = filters;

  void setSearch(String? value) => state = state.copyWith(search: () => value);

  /// Réinitialise les filtres (la recherche texte et le tri sont conservés).
  void resetFilters() => state = OfferFilters(search: state.search, sort: state.sort);
}

final offerFiltersProvider = NotifierProvider<OfferFiltersNotifier, OfferFilters>(
  OfferFiltersNotifier.new,
);

/// Dernière offre modifiée ailleurs (détail) à répercuter sur les listes.
class OfferChangesNotifier extends Notifier<Offer?> {
  @override
  Offer? build() => null;

  void emit(Offer offer) => state = offer;
}

/// Flux des modifications d'offres (à écouter avec `ref.listen`).
final offerChangesProvider = NotifierProvider<OfferChangesNotifier, Offer?>(
  OfferChangesNotifier.new,
);

/// Détail d'une offre, modifiable sur place (statut, notes, archivage).
class OfferDetailNotifier extends AsyncNotifier<Offer> {
  OfferDetailNotifier(this.offerId);

  final int offerId;

  OffersRepository get _repo => ref.read(offersRepositoryProvider);

  @override
  Future<Offer> build() => ref.watch(offersRepositoryProvider).get(offerId);

  Future<void> reload() async {
    state = await AsyncValue.guard(() => _repo.get(offerId));
  }

  Future<Offer> setStatus(OfferStatus status) => _apply(() => _repo.setStatus(offerId, status));

  Future<Offer> setNotes(String notes) => _apply(() => _repo.setNotes(offerId, notes));

  Future<Offer> archive() => _apply(() => _repo.archive(offerId));

  Future<Offer> _apply(Future<Offer> Function() action) async {
    final updated = await action();
    if (ref.mounted) state = AsyncData(updated);
    ref.read(offerChangesProvider.notifier).emit(updated);
    return updated;
  }
}

final offerDetailProvider = AsyncNotifierProvider.autoDispose
    .family<OfferDetailNotifier, Offer, int>(OfferDetailNotifier.new);
