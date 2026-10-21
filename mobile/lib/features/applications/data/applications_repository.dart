import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import 'application_models.dart';

/// Accès à l'API des candidatures (`/applications`).
class ApplicationsRepository {
  const ApplicationsRepository(this._api);

  final ApiClient _api;

  /// Lance la rédaction par l'IA (tâche de fond) ; une notification annonce le brouillon prêt.
  Future<Application> prepare(int offerId) async => Application.fromJson(
    asJsonMap(await _api.post('/applications/prepare', body: {'offer_id': offerId})),
  );

  Future<Paginated<Application>> list({
    int page = 1,
    int pageSize = 20,
    ApplicationStatus? status,
    int? offerId,
  }) => _api.getPage(
    '/applications',
    Application.fromJson,
    page: page,
    pageSize: pageSize,
    query: {'status': status?.api, 'offer_id': offerId},
  );

  Future<Application> get(int id) => _api.getObject('/applications/$id', Application.fromJson);

  /// Modifie le brouillon (destinataire vide = effacé).
  Future<Application> update(
    int id, {
    required String recipientEmail,
    required String subject,
    required String message,
  }) async => Application.fromJson(
    asJsonMap(
      await _api.patch(
        '/applications/$id',
        body: {
          'recipient_email': recipientEmail.trim(),
          'subject': subject.trim(),
          'message': message.trim(),
        },
      ),
    ),
  );

  Future<Application> regenerate(int id) async =>
      Application.fromJson(asJsonMap(await _api.post('/applications/$id/regenerate')));

  /// Envoi confirmé explicitement. Le statut renvoyé est le résultat réel de l'envoi.
  Future<Application> send(int id) async => Application.fromJson(
    asJsonMap(await _api.post('/applications/$id/send', body: {'confirm': true})),
  );

  Future<Application> cancel(int id) async =>
      Application.fromJson(asJsonMap(await _api.post('/applications/$id/cancel')));
}

final applicationsRepositoryProvider = Provider<ApplicationsRepository>(
  (ref) => ApplicationsRepository(ref.watch(apiClientProvider)),
);
