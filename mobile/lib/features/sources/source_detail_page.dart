import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/blocks.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import '../offers/offers_providers.dart';
import 'data/source_models.dart';
import 'data/sources_repository.dart';
import 'sources_providers.dart';
import 'widgets/run_widgets.dart';
import 'widgets/source_form_sheet.dart';
import 'widgets/source_test_sheet.dart';

/// Détail d'une source : réglages, test, lancement d'une collecte, historique.
class SourceDetailPage extends ConsumerStatefulWidget {
  const SourceDetailPage({super.key, required this.sourceId});

  final int sourceId;

  @override
  ConsumerState<SourceDetailPage> createState() => _SourceDetailPageState();
}

enum _Menu { edit, delete }

class _SourceDetailPageState extends ConsumerState<SourceDetailPage> {
  bool _launching = false;
  bool _saving = false;

  SourcesRepository get _repo => ref.read(sourcesRepositoryProvider);

  void _reload() {
    ref.invalidate(sourceDetailProvider(widget.sourceId));
    ref.invalidate(sourceRunsProvider(widget.sourceId));
    ref.invalidate(allSourcesProvider);
  }

  Future<void> _edit(Source source) async {
    final saved = await showSourceForm(context, source: source);
    if (saved != null) _reload();
  }

  Future<void> _delete(Source source) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer « ${source.name} » ?',
      message:
          'Possible uniquement pour une source sans offre ni historique. '
          'Sinon, désactivez-la : ses offres restent consultables.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _repo.delete(source.id);
      ref.invalidate(allSourcesProvider);
      showToast('Source supprimée', kind: ToastKind.success);
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (!error.isConflict) return showError(error);
      showToast(
        error.userMessage,
        kind: ToastKind.error,
        action: source.isActive
            ? SnackBarAction(
                label: 'Désactiver',
                onPressed: () => _patch({'is_active': false}, success: 'Source désactivée'),
              )
            : null,
      );
    } catch (error) {
      showError(error);
    }
  }

  /// Modification rapide (`PATCH /sources/{id}`).
  Future<bool> _patch(Map<String, dynamic> body, {String? success}) async {
    if (!mounted) return false;
    setState(() => _saving = true);
    final saved = await runAction(() => _repo.update(widget.sourceId, body), success: success);
    if (!mounted) return saved != null;
    setState(() => _saving = false);
    if (saved != null) _reload();
    return saved != null;
  }

  void _test(Source source) =>
      showAppSheet<void>(context, expand: true, builder: (_) => SourceTestSheet(source: source));

  Future<void> _launch(Source source) async {
    setState(() => _launching = true);
    final taskId = await runAction(() => _repo.run(source.id));
    if (!mounted) return;
    setState(() => _launching = false);
    if (taskId == null) return;
    showToast(
      'Collecte mise en file. Tirez pour actualiser l\'historique.',
      kind: ToastKind.success,
    );
    // Le worker traite la tâche en quelques secondes : on relit l'historique un peu après.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) _reload();
    });
  }

  void _showOffers(Source source) {
    final filters = ref.read(offerFiltersProvider);
    ref.read(offerFiltersProvider.notifier).set(filters.copyWith(sourceId: () => source.id));
    context.go(Routes.offers);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(sourceDetailProvider(widget.sourceId));
    final source = value.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(source?.name ?? 'Source'),
        actions: [
          if (source != null)
            PopupMenuButton<_Menu>(
              tooltip: 'Plus d\'actions',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (item) => switch (item) {
                _Menu.edit => _edit(source),
                _Menu.delete => _delete(source),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _Menu.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _Menu.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: Text('Supprimer', style: TextStyle(color: AppColors.danger)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          const Gap(4),
        ],
      ),
      body: AsyncValueView<Source>(
        value: value,
        onRetry: _reload,
        data: (source) => PageListView(
          onRefresh: () async {
            _reload();
            await ref.read(sourceDetailProvider(widget.sourceId).future).catchError((_) => source);
          },
          children: [
            _Header(source: source),
            const Gap(16),
            _Actions(
              source: source,
              launching: _launching,
              onTest: () => _test(source),
              onLaunch: () => _launch(source),
            ),
            const SectionHeader('Réglages'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchRow(
                title: 'Source active',
                subtitle: 'Incluse dans les collectes planifiées.',
                value: source.isActive,
                onChanged: _saving
                    ? null
                    : (v) => _patch({
                        'is_active': v,
                      }, success: v ? 'Source activée' : 'Source désactivée'),
              ),
            ),
            const SectionHeader('Informations'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.link_rounded,
                    label: 'Adresse',
                    value: source.url,
                    onTap: () => openExternalUrl(source.url),
                  ),
                  InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Fréquence',
                    value: _frequencyLabel(source.frequencyMinutes),
                  ),
                  InfoRow(
                    icon: Icons.work_outline_rounded,
                    label: 'Offres collectées',
                    value: Fmt.number(source.offersCount),
                    onTap: source.offersCount > 0 ? () => _showOffers(source) : null,
                  ),
                  InfoRow(
                    icon: Icons.history_rounded,
                    label: 'Dernière tentative',
                    value: source.lastAttemptAt == null
                        ? 'Jamais'
                        : Fmt.dateTime(source.lastAttemptAt),
                  ),
                  InfoRow(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Dernier succès',
                    value: source.lastSuccessAt == null
                        ? 'Jamais'
                        : Fmt.dateTime(source.lastSuccessAt),
                  ),
                  InfoRow(
                    icon: Icons.error_outline_rounded,
                    label: 'Erreurs',
                    value: source.consecutiveFailures > 0
                        ? '${source.errorCount} au total · ${source.consecutiveFailures} d\'affilée'
                        : '${source.errorCount} au total',
                  ),
                  InfoRow(
                    icon: Icons.event_outlined,
                    label: 'Créée / modifiée',
                    value: '${Fmt.date(source.createdAt)} · ${Fmt.relative(source.updatedAt)}',
                  ),
                ],
              ),
            ),
            if (source.hasError && source.health != SourceHealth.ok) ...[
              const Gap(12),
              NoteBox(
                title: 'Dernière erreur',
                message: source.lastError!,
                color: AppColors.danger,
                icon: Icons.error_outline_rounded,
              ),
            ],
            if (source.keywords.isNotEmpty) ...[
              const SectionHeader('Mots-clés'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final keyword in source.keywords) Pill(keyword)],
              ),
            ],
            if (source.selectors.isNotEmpty) ...[
              const SectionHeader('Sélecteurs'),
              JsonBlock(value: source.selectors),
            ],
            _RecentRuns(sourceId: widget.sourceId),
          ],
        ),
      ),
    );
  }
}

String _frequencyLabel(int minutes) {
  if (minutes % 1440 == 0) {
    return minutes == 1440 ? 'Tous les jours' : 'Tous les ${minutes ~/ 1440} jours';
  }
  if (minutes % 60 == 0) {
    return minutes == 60 ? 'Toutes les heures' : 'Toutes les ${minutes ~/ 60} h';
  }
  return 'Toutes les $minutes min';
}

class _Header extends StatelessWidget {
  const _Header({required this.source});

  final Source source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final health = source.health;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(4),
        Text(source.name, style: theme.headlineSmall),
        if (source.category != null) ...[
          const Gap(4),
          Text(source.category!, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ],
        const Gap(10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            source.isActive
                ? const Pill('Active', color: AppColors.success, icon: Icons.check_rounded)
                : const Pill('Désactivée', color: AppColors.danger),
            Pill(source.typeLabel, icon: source.type?.icon),
            Pill(health.label, color: health.color, icon: health.icon),
          ],
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.source,
    required this.launching,
    required this.onTest,
    required this.onLaunch,
  });

  final Source source;
  final bool launching;
  final VoidCallback onTest;
  final VoidCallback onLaunch;

  /// Explication quand la collecte ne peut pas aboutir.
  (String, Color?)? get _hint {
    if (!source.hasConnector) {
      return (
        'Le serveur n\'a pas encore de connecteur « ${source.typeLabel} » : le test et la '
            'collecte échoueront. Seules les sources RSS sont collectées pour l\'instant.',
        null,
      );
    }
    if (source.health == SourceHealth.blocked) {
      return (
        'Le site refuse l\'accès (HTTP 401, 403 ou 429). La source n\'est plus collectée '
            'automatiquement : aucune protection n\'est contournée.',
        AppColors.warning,
      );
    }
    if (!source.isActive) {
      return ('Source désactivée : elle n\'est pas incluse dans les collectes planifiées.', null);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hint = _hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Tester',
                icon: Icons.science_outlined,
                outlined: true,
                onPressed: onTest,
              ),
            ),
            const Gap(10),
            Expanded(
              child: PrimaryButton(
                label: 'Collecter',
                icon: Icons.play_arrow_rounded,
                loading: launching,
                onPressed: onLaunch,
              ),
            ),
          ],
        ),
        if (hint != null) ...[
          const Gap(12),
          NoteBox(
            message: hint.$1,
            color: hint.$2,
            icon: hint.$2 == null ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
          ),
        ],
      ],
    );
  }
}

class _RecentRuns extends ConsumerWidget {
  const _RecentRuns({required this.sourceId});

  final int sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(sourceRunsProvider(sourceId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Dernières collectes'),
        AsyncValueView<List<CollectionRun>>(
          value: runs,
          onRetry: () => ref.invalidate(sourceRunsProvider(sourceId)),
          loading: const LoadingView(padding: EdgeInsets.symmetric(vertical: 32)),
          data: (items) => items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aucune collecte pour cette source.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final run in items) ...[
                      RunCard(run: run, onTap: () => showRunDetail(context, run)),
                      const Gap(10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
