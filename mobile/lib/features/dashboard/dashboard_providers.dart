import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offers/data/offer_models.dart';
import '../offers/data/offers_repository.dart';

/// Compteurs d'offres de l'accueil.
///
/// Le serveur n'a pas (encore) d'endpoint de statistiques : chaque compteur est le `total`
/// d'une recherche `GET /offers?page_size=1` filtrée par statut.
class OfferCounts {
  const OfferCounts({
    required this.total,
    required this.fresh,
    required this.relevant,
    required this.favorites,
  });

  final int total;
  final int fresh;
  final int relevant;
  final int favorites;
}

final offerCountsProvider = FutureProvider.autoDispose<OfferCounts>((ref) async {
  final repo = ref.watch(offersRepositoryProvider);
  Future<int> count(OfferStatus? status) async =>
      (await repo.search(OfferFilters(status: status), pageSize: 1)).total;
  final counts = await Future.wait([
    count(null),
    count(OfferStatus.newOffer),
    count(OfferStatus.relevant),
    count(OfferStatus.favorite),
  ]);
  return OfferCounts(total: counts[0], fresh: counts[1], relevant: counts[2], favorites: counts[3]);
});

/// Les 5 dernières offres collectées.
final latestOffersProvider = FutureProvider.autoDispose<List<Offer>>((ref) async {
  final page = await ref.watch(offersRepositoryProvider).search(const OfferFilters(), pageSize: 5);
  return page.items;
});
