import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/bottom_bar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/ui.dart';
import '../applications/applications_providers.dart';
import '../applications/data/applications_repository.dart';
import '../sources/sources_providers.dart';
import 'data/offer_models.dart';
import 'offers_providers.dart';
import 'widgets/offer_card.dart';

/// Détail d'une offre : en-tête, notes, description, informations et actions
/// (favori, statut, annonce d'origine, archivage).
class OfferDetailPage extends ConsumerWidget {
  const OfferDetailPage({super.key, required this.offerId});

  final int offerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(offerDetailProvider(offerId));
    final offer = detail.value;
    return Scaffold(
      appBar: AppBar(
        actions: offer == null
            ? null
            : [
                IconButton(
                  tooltip: offer.status == OfferStatus.favorite
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris',
                  icon: Icon(
                    offer.status == OfferStatus.favorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: offer.status == OfferStatus.favorite ? AppColors.warning : null,
                  ),
                  onPressed: () => runAction(
                    () => ref
                        .read(offerDetailProvider(offerId).notifier)
                        .setStatus(
                          offer.status == OfferStatus.favorite
                              ? OfferStatus.relevant
                              : OfferStatus.favorite,
                        ),
                    success: offer.status == OfferStatus.favorite
                        ? 'Retirée des favoris'
                        : 'Ajoutée aux favoris',
                  ),
                ),
                _MoreMenu(offer: offer),
                const Gap(4),
              ],
      ),
      body: AsyncValueView<Offer>(
        value: detail,
        onRetry: () => ref.invalidate(offerDetailProvider(offerId)),
        data: (offer) => _DetailBody(offer: offer),
      ),
      bottomNavigationBar: offer == null ? null : _ActionBar(offer: offer),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu « … »
// ---------------------------------------------------------------------------

enum _MenuAction { changeStatus, markNew, toggleIgnore, copyLink, archive }

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.offer});

  final Offer offer;

  Future<void> _onSelected(BuildContext context, WidgetRef ref, _MenuAction action) async {
    final notifier = ref.read(offerDetailProvider(offer.id).notifier);
    switch (action) {
      case _MenuAction.changeStatus:
        await _changeStatus(context, ref, offer);
      case _MenuAction.markNew:
        await runAction(
          () => notifier.setStatus(OfferStatus.newOffer),
          success: 'Marquée comme nouvelle',
        );
      case _MenuAction.toggleIgnore:
        final ignored = offer.status == OfferStatus.ignored;
        await runAction(
          () => notifier.setStatus(ignored ? OfferStatus.newOffer : OfferStatus.ignored),
          success: ignored ? 'Offre rétablie' : 'Offre ignorée',
        );
      case _MenuAction.copyLink:
        await copyText(offer.url, message: 'Lien copié');
      case _MenuAction.archive:
        final confirmed = await confirmDialog(
          context,
          title: 'Archiver cette offre ?',
          message:
              'Elle n\'apparaîtra plus dans la liste (sauf avec le filtre « Archivées »). '
              'L\'offre reste conservée sur le serveur.',
          confirmLabel: 'Archiver',
        );
        if (!confirmed) return;
        await runAction(notifier.archive, success: 'Offre archivée');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    PopupMenuItem<_MenuAction> item(_MenuAction value, IconData icon, String label) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.textSecondary),
              const Gap(12),
              Text(label),
            ],
          ),
        );
    final ignored = offer.status == OfferStatus.ignored;
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Plus d\'actions',
      icon: const Icon(Icons.more_vert_rounded),
      position: PopupMenuPosition.under,
      onSelected: (action) => _onSelected(context, ref, action),
      itemBuilder: (_) => [
        item(_MenuAction.changeStatus, Icons.flag_outlined, 'Changer le statut'),
        if (offer.status != OfferStatus.newOffer)
          item(_MenuAction.markNew, Icons.fiber_new_outlined, 'Marquer comme nouvelle'),
        item(
          _MenuAction.toggleIgnore,
          ignored ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ignored ? 'Ne plus ignorer' : 'Ignorer cette offre',
        ),
        if (offer.url.isNotEmpty) item(_MenuAction.copyLink, Icons.link_rounded, 'Copier le lien'),
        if (!offer.isArchived) item(_MenuAction.archive, Icons.archive_outlined, 'Archiver'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Barre d'actions : annonce + statut
// ---------------------------------------------------------------------------

/// Feuille de choix du statut (statuts posables par l'utilisateur).
Future<void> _changeStatus(BuildContext context, WidgetRef ref, Offer offer) async {
  final status = await showAppSheet<OfferStatus>(
    context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Statut de l\'offre'),
          for (final status in OfferStatus.userSettable)
            ListTile(
              minTileHeight: 52,
              leading: Icon(status.icon, color: status.color),
              title: Text(status.label),
              trailing: status == offer.status
                  ? const Icon(Icons.check_rounded, color: AppColors.textPrimary)
                  : null,
              onTap: () => Navigator.of(context).pop(status),
            ),
          const Gap(8),
        ],
      ),
    ),
  );
  if (status == null || status == offer.status) return;
  await runAction(
    () => ref.read(offerDetailProvider(offer.id).notifier).setStatus(status),
    success: 'Statut : ${status.label.toLowerCase()}',
  );
}

/// Barre d'actions : annonce d'origine et candidature (préparée par l'IA, validée par vous).
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.offer});

  final Offer offer;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  Future<void> _prepare() async {
    setState(() => _busy = true);
    try {
      final application = await ref.read(applicationsRepositoryProvider).prepare(widget.offer.id);
      ref.invalidate(applicationForOfferProvider(widget.offer.id));
      showToast(
        'Rédaction lancée : une alerte vous préviendra quand elle sera prête à valider.',
        kind: ToastKind.success,
      );
      if (mounted) await context.push(Routes.application(application.id));
    } on ApiException catch (error) {
      // Déjà préparée (autre appareil) : on ouvre la candidature existante.
      if (error.isConflict) {
        ref.invalidate(applicationForOfferProvider(widget.offer.id));
        final existing = await ref.read(applicationForOfferProvider(widget.offer.id).future);
        if (existing != null && mounted) await context.push(Routes.application(existing.id));
      } else {
        showError(error);
      }
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final application = ref.watch(applicationForOfferProvider(offer.id));
    final existing = application.value;
    return BottomBar(
      children: [
        if (offer.url.isNotEmpty)
          PrimaryButton(
            label: 'Voir l\'annonce',
            icon: Icons.open_in_new_rounded,
            outlined: true,
            onPressed: () => openExternalUrl(offer.url),
          ),
        if (existing != null)
          PrimaryButton(
            label: 'Ma candidature',
            icon: existing.status.icon,
            onPressed: () => context.push(Routes.application(existing.id)),
          )
        else
          PrimaryButton(
            label: 'Préparer ma candidature',
            icon: Icons.auto_awesome_rounded,
            loading: _busy || application.isLoading,
            onPressed: _prepare,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contenu
// ---------------------------------------------------------------------------

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceName = ref.watch(sourceNamesProvider)[offer.sourceId];
    return PageListView(
      onRefresh: () => ref.read(offerDetailProvider(offer.id).notifier).reload(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, 32),
      children: [
        _Header(offer: offer, sourceName: sourceName),
        _NotesSection(offer: offer),
        if (offer.aiSummary != null) ...[
          const SectionHeader('Résumé'),
          AppCard(child: SelectableText(offer.aiSummary!)),
        ],
        if (offer.skills.isNotEmpty) ...[
          const SectionHeader('Compétences'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final skill in offer.skills) Pill(skill)],
          ),
        ],
        const SectionHeader('Description'),
        offer.description.trim().isEmpty
            ? Text(
                'Pas de description dans l\'annonce d\'origine.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
              )
            : _Description(text: offer.description),
        const SectionHeader('Informations'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
          child: Column(
            children: [
              InfoRow(
                icon: Icons.rss_feed_rounded,
                label: 'Source',
                value: sourceName ?? 'Source n° ${offer.sourceId}',
                onTap: () => context.push(Routes.source(offer.sourceId)),
              ),
              if (offer.url.isNotEmpty)
                InfoRow(
                  icon: Icons.link_rounded,
                  label: 'Annonce',
                  value: offer.url,
                  onTap: () => openExternalUrl(offer.url),
                ),
              InfoRow(
                icon: Icons.event_outlined,
                label: 'Publiée le',
                value: offer.publishedAt == null ? 'Non indiqué' : Fmt.dateTime(offer.publishedAt),
              ),
              InfoRow(
                icon: Icons.download_outlined,
                label: 'Collectée le',
                value: Fmt.dateTime(offer.collectedAt),
              ),
              if (offer.isArchived)
                InfoRow(
                  icon: Icons.archive_outlined,
                  label: 'Archivée le',
                  value: Fmt.dateTime(offer.archivedAt),
                ),
              if (offer.externalId != null)
                InfoRow(
                  icon: Icons.tag_rounded,
                  label: 'Référence de la source',
                  value: offer.externalId,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.offer, required this.sourceName});

  final Offer offer;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final budget = offerBudget(offer);
    final meta = [
      sourceName ?? 'Offre',
      if (offer.displayDate != null) Fmt.relative(offer.displayDate),
    ].join(' · ');
    final pills = <Widget>[
      Pill(offer.status.label, color: offer.status.color, icon: offer.status.icon),
      if (offer.isArchived) const Pill('Archivée', icon: Icons.archive_outlined),
      if (offer.category != null) Pill(offer.category!, icon: Icons.category_outlined),
      if (offer.missionType != null) Pill(offer.missionType!, icon: Icons.description_outlined),
      if (budget != null) Pill(budget, icon: Icons.payments_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rss_feed_rounded, size: 15, color: AppColors.textTertiary),
                      const Gap(6),
                      Expanded(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.labelMedium?.copyWith(color: AppColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                  const Gap(10),
                  SelectableText(offer.title, style: theme.headlineSmall),
                  if (offer.company != null) ...[
                    const Gap(8),
                    Text(
                      offer.company!,
                      style: theme.titleMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  if (offer.location != null) ...[
                    const Gap(2),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 15, color: AppColors.textTertiary),
                        const Gap(4),
                        Expanded(
                          child: Text(
                            offer.location!,
                            style: theme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (offer.relevanceScore != null) ...[
              const Gap(16),
              ScoreRing(score: offer.relevanceScore, size: 68, strokeWidth: 5),
            ],
          ],
        ),
        const Gap(16),
        Wrap(spacing: 6, runSpacing: 8, children: pills),
      ],
    );
  }
}

/// Notes personnelles : affichage et modification (`PATCH /offers/{id}`).
class _NotesSection extends ConsumerWidget {
  const _NotesSection({required this.offer});

  final Offer offer;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final text = await promptText(
      context,
      title: 'Notes personnelles',
      label: 'Ex. : relancer lundi, budget à négocier…',
      initialValue: offer.notes,
      confirmLabel: 'Enregistrer',
      maxLines: 6,
      keyboardType: TextInputType.multiline,
    );
    if (text == null || text.trim() == (offer.notes ?? '')) return;
    await runAction(
      () => ref.read(offerDetailProvider(offer.id).notifier).setNotes(text),
      success: text.trim().isEmpty ? 'Notes effacées' : 'Notes enregistrées',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Notes',
          action: offer.hasNotes ? 'Modifier' : 'Ajouter',
          onAction: () => _edit(context, ref),
        ),
        AppCard(
          onTap: () => _edit(context, ref),
          child: offer.hasNotes
              ? SelectableText(offer.notes!, style: theme.bodyMedium?.copyWith(height: 1.45))
              : Text(
                  'Aucune note. Touchez pour en ajouter une.',
                  style: theme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                ),
        ),
      ],
    );
  }
}

/// Description lisible, sélectionnable, repliée si elle est longue.
class _Description extends StatefulWidget {
  const _Description({required this.text});

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  static const _collapsedLines = 14;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      height: 1.65,
      color: AppColors.textPrimary.withValues(alpha: 0.9),
    );
    final long = widget.text.length > 900 || '\n'.allMatches(widget.text).length > _collapsedLines;
    final collapsed = long && !_expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (collapsed)
          Text(
            widget.text,
            maxLines: _collapsedLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          )
        else
          SelectableText(widget.text, style: style),
        if (long)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 44)),
            icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
            label: Text(_expanded ? 'Réduire' : 'Lire la suite'),
          ),
      ],
    );
  }
}
