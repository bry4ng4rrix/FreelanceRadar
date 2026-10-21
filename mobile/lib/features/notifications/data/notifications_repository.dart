import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/json.dart';
import 'notification_models.dart';

/// Accès au centre de notifications (`/notifications`).
class NotificationsRepository {
  const NotificationsRepository(this._api);

  final ApiClient _api;

  Future<Paginated<AppNotification>> list({
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
    NotificationType? type,
  }) => _api.getPage(
    '/notifications',
    AppNotification.fromJson,
    page: page,
    pageSize: pageSize,
    query: {if (unreadOnly) 'unread_only': true, 'type': type?.api},
  );

  Future<int> unreadCount() async =>
      parseInt(asJsonMap(await _api.get('/notifications/unread-count'))['count']) ?? 0;

  /// Idempotent côté serveur.
  Future<AppNotification> markRead(int id) async =>
      AppNotification.fromJson(asJsonMap(await _api.patch('/notifications/$id/read')));

  /// Renvoie le nombre de notifications marquées comme lues.
  Future<int> markAllRead() async =>
      parseInt(asJsonMap(await _api.post('/notifications/mark-all-read'))['updated']) ?? 0;
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);
