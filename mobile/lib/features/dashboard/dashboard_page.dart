import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/blocks.dart';
import '../../core/widgets/ui.dart';
import '../offers/data/offer_models.dart';
import '../offers/offers_providers.dart';
import '../offers/widgets/offer_card.dart';
import '../profile/profile_providers.dart';
import '../sources/data/source_models.dart';
import '../sources/sources_providers.dart';
import 'dashboard_providers.dart';

/// Date du jour en toutes lettres : `Mercredi 21 octobre`.
String todayLabel([DateTime? now]) {
  final text = DateFormat('EEEE d MMMM', 'fr_FR').format(now ?? DateTime.now());
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Onglet « Accueil » : indicateurs, dernières offres, état des sources, actions rapides.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(offerCountsProvider)
      ..invalidate(latestOffersProvider)
      ..invalidate(allSourcesProvider);
    try {
      await Future.wait<Object?>([
        ref.read(offerCountsProvider.future),
        ref.read(latestOffersProvider.future),
        ref.read(allSourcesProvider.future),
      ]);
    } catch (_) {
      // Les erreurs sont affichées dans chaque section.
    }
  }

  /// Ouvre l'onglet Offres avec les filtres donnés.
  static void openOffers(BuildContext context, WidgetRef ref, OfferFilters filters) {
    ref.read(offerFiltersProvider.notifier).set(filters);
    context.go(Routes.offers);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une offre modifiée ailleurs (statut, archivage) change les compteurs.
    ref.listen(offerChangesProvider, (_, _) {
      ref
        ..invalidate(offerCountsProvider)
        ..invalidate(latestOffersProvider);
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageListView(
          onRefresh: () => _refresh(ref),
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, 40),
          children: [
            const _Greeting(),
            const Gap(24),
            const _StatsGrid(),
            SectionHeader(
              'Dernières offres',
              action: 'Tout voir',
              onAction: () => openOffers(context, ref, const OfferFilters()),
            ),
            const _LatestOffersCard(),
            SectionHeader('Sources', action: 'Gérer', onAction: () => context.push(Routes.sources)),
            const _SourcesCard(),
          ],
        ),
      ),
    );
  }
}

/// `Bonjour, Jane` + date du jour + avatar (vers le profil).
class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final email = ref.watch(currentUserProvider.select((user) => user?.email));
    final fullName = ref.watch(profileProvider.select((p) => p.value?.fullName));
    final firstName = fullName?.split(RegExp(r'\s+')).first;
    final now = DateTime.now();
    final hello = now.hour >= 18 ? 'Bonsoir' : 'Bonjour';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todayLabel(now),
                style: theme.labelLarge?.copyWith(color: AppColors.textTertiary),
              ),
              const Gap(6),
              Text(
                firstName == null ? hello : '$hello, $firstName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.displaySmall,
              ),
            ],
          ),
        ),
        const Gap(12),
        Semantics(
          button: true,
          label: 'Mon profil',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go(Routes.profile),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: AppAvatar(label: fullName ?? email, size: 44),
            ),
          ),
        ),
      ],
    );
  }
}

/// Grille d'indicateurs : 2 colonnes sur téléphone, 3 sur grand écran.
class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(offerCountsProvider);
    final sources = ref.watch(allSourcesProvider);
    if (!counts.hasValue && counts.hasError) {
      return InlineError(error: counts.error!, onRetry: () => ref.invalidate(offerCountsProvider));
    }
    final c = counts.value;
    final s = sources.value;
    String n(int? value) => value == null ? '—' : Fmt.number(value);
    final active = s?.where((source) => source.isActive).length;
    final failing = s
        ?.where(
          (source) => source.health == SourceHealth.error || source.health == SourceHealth.blocked,
        )
        .length;
    void open(OfferFilters filters) => DashboardPage.openOffers(context, ref, filters);

    final tiles = [
      StatTile(
        label: 'Offres',
        value: n(c?.total),
        icon: Icons.work_outline_rounded,
        caption: 'Hors archivées',
        onTap: () => open(const OfferFilters()),
      ),
      StatTile(
        label: 'Nouvelles',
        value: n(c?.fresh),
        icon: Icons.fiber_new_outlined,
        color: (c?.fresh ?? 0) > 0 ? AppColors.info : null,
        caption: 'À trier',
        onTap: () => open(const OfferFilters(status: OfferStatus.newOffer)),
      ),
      StatTile(
        label: 'Pertinentes',
        value: n(c?.relevant),
        icon: Icons.thumb_up_alt_outlined,
        color: (c?.relevant ?? 0) > 0 ? AppColors.success : null,
        onTap: () => open(const OfferFilters(status: OfferStatus.relevant)),
      ),
      StatTile(
        label: 'Favorites',
        value: n(c?.favorites),
        icon: Icons.star_border_rounded,
        onTap: () => open(const OfferFilters(status: OfferStatus.favorite)),
      ),
      StatTile(
        label: 'Sources actives',
        value: n(active),
        icon: Icons.rss_feed_rounded,
        caption: s == null ? null : 'Sur ${s.length}',
        onTap: () => context.push(Routes.sources),
      ),
      StatTile(
        label: 'Sources en erreur',
        value: n(failing),
        icon: Icons.error_outline_rounded,
        color: (failing ?? 0) > 0 ? AppColors.danger : null,
        caption: 'Erreur ou blocage',
        onTap: () => context.push(Routes.sources),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += columns) {
          if (i > 0) rows.add(const Gap(12));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + columns; j++) ...[
                    if (j > i) const Gap(12),
                    Expanded(child: j < tiles.length ? tiles[j] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

/// Les 5 dernières offres collectées.
class _LatestOffersCard extends ConsumerWidget {
  const _LatestOffersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestOffersProvider);
    return AsyncValueView<List<Offer>>(
      value: latest,
      onRetry: () => ref.invalidate(latestOffersProvider),
      loading: const LoadingView(padding: EdgeInsets.symmetric(vertical: 32)),
      data: (offers) => offers.isEmpty
          ? const AppCard(
              child: EmptyState(
                icon: Icons.work_outline_rounded,
                title: 'Aucune offre pour l\'instant',
                message: 'Activez une source RSS puis lancez une collecte.',
              ),
            )
          : AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < offers.length; i++) ...[
                    if (i > 0) const Divider(indent: 72),
                    OfferCompactTile(
                      offer: offers[i],
                      onTap: () => context.push(Routes.offer(offers[i].id)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// État des sources actives (et de celles en erreur).
class _SourcesCard extends ConsumerWidget {
  const _SourcesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final sources = ref.watch(allSourcesProvider);
    return AsyncValueView<List<Source>>(
      value: sources,
      onRetry: () => ref.invalidate(allSourcesProvider),
      loading: const LoadingView(padding: EdgeInsets.symmetric(vertical: 32)),
      data: (items) {
        final shown = items.where((s) => s.isActive || s.health == SourceHealth.error).toList();
        if (shown.isEmpty) {
          return AppCard(
            child: EmptyState(
              icon: Icons.rss_feed_rounded,
              title: 'Aucune source active',
              message: 'Activez une source pour lancer les collectes planifiées.',
              actionLabel: 'Voir les sources',
              onAction: () => context.push(Routes.sources),
            ),
          );
        }
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const Divider(indent: 48),
                InkWell(
                  onTap: () => context.push(Routes.source(shown[i].id)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        StatusDot(color: shown[i].health.color),
                        const Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shown[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.titleSmall,
                              ),
                              Text(
                                [
                                  shown[i].health.label,
                                  if (shown[i].lastAttemptAt != null)
                                    Fmt.relative(shown[i].lastAttemptAt),
                                ].join(' · '),
                                style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Fmt.number(shown[i].offersCount),
                          style: theme.titleSmall?.copyWith(color: AppColors.textSecondary),
                        ),
                        const Gap(4),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
