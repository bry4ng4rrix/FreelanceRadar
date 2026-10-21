import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/paginated.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/blocks.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/paged_list_view.dart';
import '../../core/widgets/ui.dart';
import '../offers/offers_providers.dart';
import 'data/notification_models.dart';
import 'data/notifications_repository.dart';
import 'notifications_providers.dart';
import 'widgets/notification_tile.dart';

/// Filtre de la liste : non lues, ou un type précis (`null` = toutes).
enum _Filter {
  unread('Non lues', null),
  newOffers('Nouvelles offres', NotificationType.newOffers),
  sourceError('Erreurs', NotificationType.sourceError),
  sourceBlocked('Blocages', NotificationType.sourceBlocked),
  applications('Candidatures', NotificationType.applicationReady);

  const _Filter(this.label, this.type);
  final String label;
  final NotificationType? type;
}

/// Onglet « Alertes » : centre de notifications (`/notifications`).
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _list = PagedListController();
  _Filter? _filter;
  int? _total;

  NotificationsRepository get _repo => ref.read(notificationsRepositoryProvider);

  Future<Paginated<AppNotification>> _fetch(int page) =>
      _repo.list(page: page, unreadOnly: _filter == _Filter.unread, type: _filter?.type);

  /// Ouvre l'écran lié à la notification et la marque comme lue.
  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      try {
        final read = await _repo.markRead(notification.id);
        _list.updateWhere<AppNotification>((n) => n.id == read.id, (_) => read);
        final count = ref.read(unreadCountProvider);
        ref.read(unreadCountProvider.notifier).set(count - 1);
      } catch (error) {
        showError(error);
      }
    }
    if (!mounted) return;
    final offerId = notification.offerId;
    final sourceId = notification.sourceId;
    final applicationId = notification.applicationId;
    if (applicationId != null) {
      await context.push(Routes.application(applicationId));
    } else if (offerId != null) {
      await context.push(Routes.offer(offerId));
    } else if (sourceId != null && notification.type == NotificationType.newOffers) {
      // Plusieurs nouvelles offres : liste des offres de la source.
      final filters = ref.read(offerFiltersProvider);
      ref.read(offerFiltersProvider.notifier).set(filters.copyWith(sourceId: () => sourceId));
      context.go(Routes.offers);
    } else if (sourceId != null) {
      await context.push(Routes.source(sourceId));
    }
  }

  Future<void> _markAllRead() async {
    final updated = await runAction(_repo.markAllRead);
    if (updated == null) return;
    ref.read(unreadCountProvider.notifier).set(0);
    showToast(
      updated == 0 ? 'Tout était déjà lu' : '$updated notification(s) marquée(s) comme lue(s)',
      kind: ToastKind.success,
    );
    await _list.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: [
          IconButton(
            tooltip: 'Tout marquer comme lu',
            onPressed: unread == 0 ? null : _markAllRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
          const Gap(8),
        ],
      ),
      body: PagedListView<AppNotification>(
        key: ValueKey(_filter),
        controller: _list,
        fetch: _fetch,
        onTotal: (total) {
          if (mounted) setState(() => _total = total);
          // Chaque rechargement de la liste (dont « tirer pour actualiser ») relit le badge.
          ref.read(unreadCountProvider.notifier).refresh();
        },
        header: [
          const Gap(4),
          ChipBar<_Filter>(
            values: _Filter.values,
            selected: _filter,
            labelOf: (filter) => filter.label,
            allLabel: 'Toutes',
            onSelected: (filter) => setState(() => _filter = filter),
          ),
          ListCount(count: _total, singular: 'notification', plural: 'notifications'),
        ],
        itemBuilder: (context, notification) =>
            NotificationTile(notification: notification, onTap: () => _open(notification)),
        emptyBuilder: (_) => EmptyState(
          icon: Icons.notifications_none_rounded,
          title: _filter == _Filter.unread ? 'Tout est lu' : 'Aucune notification',
          message:
              'Vous serez prévenu ici des nouvelles offres collectées et des sources '
              'en erreur ou bloquées.',
        ),
      ),
    );
  }
}
