import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/paged_list_view.dart';
import '../../core/widgets/ui.dart';
import '../sources/data/source_models.dart';
import '../sources/sources_providers.dart';
import 'data/offer_models.dart';
import 'data/offers_repository.dart';
import 'offers_providers.dart';
import 'widgets/offer_card.dart';
import 'widgets/offer_filters_sheet.dart';

/// Onglet « Offres » : recherche, filtres rapides, tri et liste infinie (`GET /offers`).
class OffersPage extends ConsumerStatefulWidget {
  const OffersPage({super.key});

  @override
  ConsumerState<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends ConsumerState<OffersPage> {
  final _list = PagedListController();
  late final TextEditingController _search;
  Timer? _debounce;
  int? _total;

  OfferFiltersNotifier get _filters => ref.read(offerFiltersProvider.notifier);

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(offerFiltersProvider).search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // bouton « effacer »
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _filters.setSearch(value));
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    _filters.setSearch(null);
  }

  void _reset() {
    _clearSearch();
    _filters.resetFilters();
  }

  Future<void> _openFilters() async {
    final result = await showOfferFiltersSheet(context, ref.read(offerFiltersProvider));
    if (result != null) _filters.set(result);
  }

  /// Vrai si l'offre a encore sa place dans la liste avec les filtres courants.
  static bool _stillVisible(Offer offer, OfferFilters filters) {
    if (offer.isArchived && !filters.includeArchived) return false;
    return filters.status == null || offer.status == filters.status;
  }

  void _onOfferChanged(Offer? offer) {
    if (offer == null) return;
    if (_stillVisible(offer, ref.read(offerFiltersProvider))) {
      _list.updateWhere<Offer>((item) => item.id == offer.id, (_) => offer);
    } else {
      _list.removeWhere<Offer>((item) => item.id == offer.id);
    }
  }

  Future<void> _apply(
    Future<Offer> Function(OffersRepository repo) action, {
    String? success,
  }) async {
    final updated = await runAction(
      () => action(ref.read(offersRepositoryProvider)),
      success: success,
    );
    if (updated != null) ref.read(offerChangesProvider.notifier).emit(updated);
  }

  Future<void> _setStatus(Offer offer, OfferStatus status, {String? success}) =>
      _apply((repo) => repo.setStatus(offer.id, status), success: success);

  Future<void> _toggleFavorite(Offer offer) => offer.status == OfferStatus.favorite
      ? _setStatus(offer, OfferStatus.relevant, success: 'Retirée des favoris')
      : _setStatus(offer, OfferStatus.favorite, success: 'Ajoutée aux favoris');

  Future<void> _ignore(Offer offer) async {
    final previous = offer.status;
    final updated = await runAction(
      () => ref.read(offersRepositoryProvider).setStatus(offer.id, OfferStatus.ignored),
    );
    if (updated == null) return;
    ref.read(offerChangesProvider.notifier).emit(updated);
    showToast(
      'Offre ignorée',
      action: SnackBarAction(label: 'Annuler', onPressed: () => _setStatus(updated, previous)),
    );
  }

  Future<void> _showActions(Offer offer) async {
    final action = await showOfferActionsSheet(context, offer);
    if (action == null || !mounted) return;
    switch (action) {
      case OfferQuickAction.open:
        unawaited(context.push(Routes.offer(offer.id)));
      case OfferQuickAction.toggleFavorite:
        await _toggleFavorite(offer);
      case OfferQuickAction.markRelevant:
        await _setStatus(offer, OfferStatus.relevant, success: 'Marquée pertinente');
      case OfferQuickAction.toggleIgnore:
        if (offer.status == OfferStatus.ignored) {
          await _setStatus(offer, OfferStatus.newOffer, success: 'Offre rétablie');
        } else {
          await _ignore(offer);
        }
      case OfferQuickAction.openListing:
        await openExternalUrl(offer.url);
      case OfferQuickAction.archive:
        await _apply((repo) => repo.archive(offer.id), success: 'Offre archivée');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(offerFiltersProvider);

    ref.listen(offerFiltersProvider, (previous, next) {
      if ((next.search ?? '') != _search.text.trim()) _search.text = next.search ?? '';
      if (previous != next) setState(() => _total = null);
    });
    ref.listen(offerChangesProvider, (_, offer) => _onOfferChanged(offer));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offres'),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: filters.activeCount > 0,
              label: Text('${filters.activeCount}'),
              backgroundColor: AppColors.accent,
              textColor: AppColors.onAccent,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: Column(
        children: [
          PageBody(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, 0),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _debounce?.cancel();
                _filters.setSearch(value);
              },
              decoration: InputDecoration(
                hintText: 'Rechercher dans les titres et descriptions…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _clearSearch,
                      ),
              ),
            ),
          ),
          const Gap(12),
          _QuickFilters(filters: filters, onOpenFilters: _openFilters),
          const Gap(4),
          Expanded(
            child: PagedListView<Offer>(
              key: ValueKey(filters),
              controller: _list,
              fetch: (page) => ref.read(offersRepositoryProvider).search(filters, page: page),
              onTotal: (total) {
                if (mounted) setState(() => _total = total);
              },
              header: [
                _ResultsHeader(
                  total: _total,
                  filters: filters,
                  onSort: (sort) => _filters.set(filters.copyWith(sort: sort)),
                  onReset: _reset,
                ),
              ],
              itemBuilder: (context, offer) => OfferCard(
                offer: offer,
                onTap: () => context.push(Routes.offer(offer.id)),
                onToggleFavorite: () => _toggleFavorite(offer),
                onMore: () => _showActions(offer),
              ),
              emptyBuilder: (context) => filters.activeCount > 0 || filters.hasSearch
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucune offre ne correspond',
                      message: 'Essayez d\'élargir vos critères de recherche.',
                      actionLabel: 'Réinitialiser les filtres',
                      onAction: _reset,
                    )
                  : EmptyState(
                      icon: Icons.work_outline_rounded,
                      title: 'Aucune offre pour l\'instant',
                      message:
                          'Les offres collectées par vos sources apparaîtront ici. '
                          'Lancez une collecte depuis l\'onglet Sources.',
                      actionLabel: 'Voir les sources',
                      onAction: () => context.go(Routes.sources),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rangée horizontale de filtres rapides.
class _QuickFilters extends ConsumerWidget {
  const _QuickFilters({required this.filters, required this.onOpenFilters});

  final OfferFilters filters;
  final VoidCallback onOpenFilters;

  Future<void> _pickStatus(BuildContext context, WidgetRef ref) async {
    final choice = await showAppSheet<_Choice<OfferStatus>>(
      context,
      builder: (context) => _ChoiceSheet<OfferStatus>(
        title: 'Statut',
        allLabel: 'Tous les statuts',
        values: OfferStatus.values,
        selected: filters.status,
        labelOf: (status) => status.label,
      ),
    );
    if (choice != null) {
      ref.read(offerFiltersProvider.notifier).set(filters.copyWith(status: () => choice.value));
    }
  }

  Future<void> _pickSource(BuildContext context, WidgetRef ref, List<Source> sources) async {
    final choice = await showAppSheet<_Choice<int>>(
      context,
      builder: (context) => _ChoiceSheet<int>(
        title: 'Source',
        allLabel: 'Toutes les sources',
        values: [for (final source in sources) source.id],
        selected: filters.sourceId,
        labelOf: (id) => sources.firstWhere((s) => s.id == id).name,
      ),
    );
    if (choice != null) {
      ref.read(offerFiltersProvider.notifier).set(filters.copyWith(sourceId: () => choice.value));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(offerFiltersProvider.notifier);
    final sources = ref.watch(allSourcesProvider).value ?? const <Source>[];
    final sourceName = ref.watch(sourceNamesProvider)[filters.sourceId];
    final count = filters.activeCount;
    final chips = <Widget>[
      _Chip(
        label: count > 0 ? 'Filtres · $count' : 'Filtres',
        icon: Icons.tune_rounded,
        selected: count > 0,
        onTap: onOpenFilters,
      ),
      _Chip(
        label: filters.status?.label ?? 'Statut',
        trailingIcon: Icons.expand_more_rounded,
        selected: filters.status != null,
        onTap: () => _pickStatus(context, ref),
      ),
      _Chip(
        label: filters.sourceId == null ? 'Source' : (sourceName ?? 'Source'),
        icon: Icons.rss_feed_rounded,
        trailingIcon: Icons.expand_more_rounded,
        selected: filters.sourceId != null,
        onTap: sources.isEmpty ? () {} : () => _pickSource(context, ref, sources),
      ),
      _Chip(
        label: 'Favorites',
        icon: Icons.star_border_rounded,
        selected: filters.status == OfferStatus.favorite,
        onTap: () => notifier.set(
          filters.copyWith(
            status: () => filters.status == OfferStatus.favorite ? null : OfferStatus.favorite,
          ),
        ),
      ),
      _Chip(
        label: 'Archivées',
        icon: Icons.archive_outlined,
        selected: filters.includeArchived,
        onTap: () => notifier.set(filters.copyWith(includeArchived: !filters.includeArchived)),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            AppSpacing.page +
            math.max(0.0, (constraints.maxWidth - AppSpacing.maxContentWidth) / 2);
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: side),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const Gap(8),
            itemBuilder: (_, index) => chips[index],
          ),
        );
      },
    );
  }
}

/// Choix renvoyé par [_ChoiceSheet] (`value` null = « tous »).
class _Choice<T> {
  const _Choice(this.value);
  final T? value;
}

/// Feuille de choix unique avec une option « tous ».
class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.allLabel,
    required this.values,
    required this.selected,
    required this.labelOf,
  });

  final String title;
  final String allLabel;
  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;

  @override
  Widget build(BuildContext context) {
    Widget tile(T? value, String label) => ListTile(
      minTileHeight: 48,
      title: Text(label),
      trailing: value == selected
          ? const Icon(Icons.check_rounded, color: AppColors.textPrimary)
          : null,
      onTap: () => Navigator.of(context).pop(_Choice<T>(value)),
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: title),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  tile(null, allLabel),
                  for (final value in values) tile(value, labelOf(value)),
                ],
              ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}

/// Pastille de filtre : fond blanc quand active.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onAccent : AppColors.textPrimary;
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.accent : AppColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.onAccent : AppColors.textSecondary,
                ),
                const Gap(6),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
              if (trailingIcon != null) ...[const Gap(4), Icon(trailingIcon, size: 16, color: fg)],
            ],
          ),
        ),
      ),
    );
  }
}

/// « 85 offres · Trier ».
class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.total,
    required this.filters,
    required this.onSort,
    required this.onReset,
  });

  final int? total;
  final OfferFilters filters;
  final ValueChanged<OfferSort> onSort;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final count = total;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null ? ' ' : (count <= 1 ? '$count offre' : '${Fmt.number(count)} offres'),
              style: theme.labelLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (filters.activeCount > 0 || filters.hasSearch)
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Réinitialiser'),
            ),
          // Flexible : sur un petit écran, le libellé du tri se raccourcit (« … »).
          Flexible(
            child: PopupMenuButton<OfferSort>(
              tooltip: 'Trier',
              position: PopupMenuPosition.under,
              onSelected: onSort,
              itemBuilder: (context) => [
                for (final sort in OfferSort.values)
                  CheckedPopupMenuItem<OfferSort>(
                    value: sort,
                    checked: sort == filters.sort,
                    child: Text(sort.label),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort_rounded, size: 18, color: AppColors.textSecondary),
                    const Gap(6),
                    Flexible(
                      child: Text(
                        filters.sort.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.labelLarge?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
