import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import 'offer_models.dart';

/// Accès à l'API des offres (`/offers`).
class OffersRepository {
  const OffersRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Offer>> search(OfferFilters filters, {int page = 1, int pageSize = 20}) => _api
      .getPage('/offers', Offer.fromJson, page: page, pageSize: pageSize, query: filters.toQuery());

  Future<Offer> get(int id) => _api.getObject('/offers/$id', Offer.fromJson);

  Future<Offer> setStatus(int id, OfferStatus status) async =>
      Offer.fromJson(asJsonMap(await _api.patch('/offers/$id', body: {'status': status.api})));

  /// Enregistre les notes (texte vide = notes effacées).
  Future<Offer> setNotes(int id, String notes) async {
    final value = notes.trim();
    return Offer.fromJson(
      asJsonMap(await _api.patch('/offers/$id', body: {'notes': value.isEmpty ? null : value})),
    );
  }

  /// Archive l'offre (idempotent côté serveur).
  Future<Offer> archive(int id) async =>
      Offer.fromJson(asJsonMap(await _api.post('/offers/$id/archive')));
}

final offersRepositoryProvider = Provider<OffersRepository>(
  (ref) => OffersRepository(ref.watch(apiClientProvider)),
);
