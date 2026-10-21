import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/ui.dart';
import '../../sources/sources_providers.dart';
import '../data/offer_models.dart';

/// `Entreprise · Lieu` (ou ce qui est connu).
String offerSubtitle(Offer offer) {
  final parts = <String>[?offer.company, ?offer.location];
  if (parts.isEmpty) return offer.category ?? 'Entreprise non indiquée';
  return parts.join(' · ');
}

/// Budget lisible (`500 – 800 EUR`), ou null s'il est inconnu.
String? offerBudget(Offer offer) => offer.hasBudget
    ? Fmt.salary(min: offer.budgetMin, max: offer.budgetMax, currency: offer.currency)
    : null;

/// Carte d'une offre dans la liste : titre, entreprise, lieu, statut, budget, date et source.
class OfferCard extends ConsumerWidget {
  const OfferCard({super.key, required this.offer, this.onTap, this.onToggleFavorite, this.onMore});

  final Offer offer;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final sourceName = ref.watch(sourceNamesProvider)[offer.sourceId];
    final status = offer.status;
    final budget = offerBudget(offer);
    final favorite = status == OfferStatus.favorite;
    final pills = <Widget>[
      if (status != OfferStatus.newOffer)
        Pill(status.label, color: status.color, icon: status.icon, dense: true),
      if (offer.isArchived) const Pill('Archivée', icon: Icons.archive_outlined, dense: true),
      if (offer.category != null) Pill(offer.category!, dense: true),
      if (budget != null) Pill(budget, icon: Icons.payments_outlined, dense: true),
      if (offer.hasNotes) const Pill('Note', icon: Icons.sticky_note_2_outlined, dense: true),
    ];
    final meta = [Fmt.relative(offer.displayDate), ?sourceName].join(' · ');

    return AppCard(
      onTap: onTap,
      onLongPress: onMore,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            if (status == OfferStatus.newOffer)
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: _NewDot(),
                                ),
                              ),
                            TextSpan(text: offer.title),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleMedium,
                      ),
                      const Gap(4),
                      Text(
                        offerSubtitle(offer),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Score affiché seulement quand le serveur l'a calculé.
                if (offer.relevanceScore != null) ...[
                  const Gap(12),
                  ScoreRing(score: offer.relevanceScore, size: 46),
                ],
              ],
            ),
          ),
          if (pills.isNotEmpty) ...[
            const Gap(12),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Wrap(spacing: 6, runSpacing: 6, children: pills),
            ),
          ],
          const Gap(4),
          Row(
            children: [
              const Icon(Icons.rss_feed_rounded, size: 15, color: AppColors.textTertiary),
              const Gap(6),
              Expanded(
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
              ),
              if (onToggleFavorite != null)
                _SmallIconButton(
                  tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  icon: favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorite ? AppColors.warning : AppColors.textTertiary,
                  onPressed: onToggleFavorite!,
                ),
              if (onMore != null)
                _SmallIconButton(
                  tooltip: 'Plus d\'actions',
                  icon: Icons.more_horiz_rounded,
                  color: AppColors.textTertiary,
                  onPressed: onMore!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewDot extends StatelessWidget {
  const _NewDot();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Nouvelle',
    child: Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
    ),
  );
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 20, color: color),
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

/// Ligne compacte d'une offre (accueil) : titre, entreprise, date.
class OfferCompactTile extends StatelessWidget {
  const OfferCompactTile({super.key, required this.offer, this.onTap});

  final Offer offer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(offer.status.icon, size: 20, color: offer.status.color),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleSmall,
                  ),
                  const Gap(2),
                  Text(
                    [
                      offerSubtitle(offer),
                      if (offer.displayDate != null) Fmt.relative(offer.displayDate),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const Gap(8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Actions rapides proposées sur une offre (appui long ou menu « … »).
enum OfferQuickAction { open, toggleFavorite, markRelevant, toggleIgnore, openListing, archive }

/// Feuille d'actions rapides d'une offre. Renvoie l'action choisie.
Future<OfferQuickAction?> showOfferActionsSheet(BuildContext context, Offer offer) {
  final status = offer.status;
  return showAppSheet<OfferQuickAction>(
    context,
    builder: (context) {
      Widget tile(
        OfferQuickAction action,
        IconData icon,
        String label, {
        bool destructive = false,
      }) => ListTile(
        leading: Icon(icon, color: destructive ? AppColors.danger : AppColors.textSecondary),
        title: Text(label, style: destructive ? const TextStyle(color: AppColors.danger) : null),
        minTileHeight: 52,
        onTap: () => Navigator.of(context).pop(action),
      );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Gap(2),
                  Text(
                    offerSubtitle(offer),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(),
            const Gap(4),
            tile(OfferQuickAction.open, Icons.open_in_full_rounded, 'Ouvrir l\'offre'),
            tile(
              OfferQuickAction.toggleFavorite,
              status == OfferStatus.favorite ? Icons.star_border_rounded : Icons.star_rounded,
              status == OfferStatus.favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            ),
            if (status != OfferStatus.relevant)
              tile(
                OfferQuickAction.markRelevant,
                Icons.thumb_up_alt_outlined,
                'Marquer pertinente',
              ),
            if (offer.url.isNotEmpty)
              tile(OfferQuickAction.openListing, Icons.open_in_new_rounded, 'Voir l\'annonce'),
            if (!offer.isArchived)
              tile(OfferQuickAction.archive, Icons.archive_outlined, 'Archiver'),
            tile(
              OfferQuickAction.toggleIgnore,
              status == OfferStatus.ignored
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              status == OfferStatus.ignored ? 'Ne plus ignorer' : 'Ignorer cette offre',
              destructive: status != OfferStatus.ignored,
            ),
            const Gap(8),
          ],
        ),
      );
    },
  );
}
