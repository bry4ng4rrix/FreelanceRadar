import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/blocks.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/paged_list_view.dart';
import '../../core/widgets/ui.dart';
import 'data/source_models.dart';
import 'data/sources_repository.dart';
import 'sources_providers.dart';
import 'widgets/source_form_sheet.dart';

/// Filtres de la liste des sources.
class _SourceFilters {
  const _SourceFilters({this.type, this.active});

  final SourceType? type;
  final bool? active;

  _SourceFilters copyWith({SourceType? Function()? type, bool? Function()? active}) =>
      _SourceFilters(
        type: type == null ? this.type : type(),
        active: active == null ? this.active : active(),
      );

  @override
  bool operator ==(Object other) =>
      other is _SourceFilters && other.type == type && other.active == active;

  @override
  int get hashCode => Object.hash(type, active);
}

/// Onglet « Sources » : filtre par type, activation rapide, création.
class SourcesPage extends ConsumerStatefulWidget {
  const SourcesPage({super.key});

  @override
  ConsumerState<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends ConsumerState<SourcesPage> {
  final _controller = PagedListController();
  _SourceFilters _filters = const _SourceFilters();
  int? _total;

  void _changed() => ref.invalidate(allSourcesProvider);

  Future<void> _create() async {
    final source = await showSourceForm(context);
    if (source == null || !mounted) return;
    _changed();
    await _controller.refresh();
    if (mounted) await context.push(Routes.source(source.id));
  }

  Future<void> _open(Source source) async {
    await context.push(Routes.source(source.id));
    if (!mounted) return;
    // La source a pu être modifiée ou supprimée depuis le détail.
    try {
      final fresh = await ref.read(sourcesRepositoryProvider).source(source.id);
      _controller.updateWhere<Source>((s) => s.id == source.id, (_) => fresh);
    } on ApiException catch (error) {
      if (error.isNotFound) _controller.removeWhere<Source>((s) => s.id == source.id);
    } catch (_) {}
  }

  Future<void> _toggle(Source source, bool active) async {
    _controller.updateWhere<Source>((s) => s.id == source.id, (s) => s.copyWith(isActive: active));
    try {
      final saved = await ref.read(sourcesRepositoryProvider).update(source.id, {
        'is_active': active,
      });
      _controller.updateWhere<Source>((s) => s.id == source.id, (_) => saved);
      ref.invalidate(sourceDetailProvider(source.id));
      _changed();
      showToast(active ? 'Source activée' : 'Source désactivée', kind: ToastKind.success);
    } catch (error) {
      _controller.updateWhere<Source>((s) => s.id == source.id, (_) => source);
      showError(error);
    }
  }

  Future<void> _openFilters() async {
    final result = await showAppSheet<_SourceFilters>(
      context,
      builder: (_) => _FiltersSheet(initial: _filters),
    );
    if (result != null && result != _filters) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(sourcesRepositoryProvider);
    final filters = _filters;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources'),
        actions: [
          FilterAction(active: filters.active != null, onPressed: _openFilters),
          const Gap(8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sources-add',
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Source'),
      ),
      body: PagedListView<Source>(
        key: ValueKey(filters),
        controller: _controller,
        fetch: (page) => repo.sources(page: page, type: filters.type, isActive: filters.active),
        onTotal: (total) => setState(() => _total = total),
        header: [
          const Gap(4),
          ChipBar<SourceType>(
            values: SourceType.values,
            selected: filters.type,
            labelOf: (type) => type.label,
            iconOf: (type) => type.icon,
            allLabel: 'Toutes',
            onSelected: (type) => setState(() => _filters = filters.copyWith(type: () => type)),
          ),
          if (filters.active != null) ...[
            const Gap(10),
            Wrap(
              spacing: 8,
              children: [
                InputChip(
                  label: Text(filters.active! ? 'Actives' : 'Désactivées'),
                  onDeleted: () => setState(() => _filters = filters.copyWith(active: () => null)),
                ),
              ],
            ),
          ],
          ListCount(count: _total, singular: 'source', plural: 'sources'),
        ],
        emptyBuilder: (_) => EmptyState(
          icon: Icons.rss_feed_rounded,
          title: 'Aucune source',
          message: filters == const _SourceFilters()
              ? 'Ajoutez une source, ou importez data/sources.json sur le serveur '
                    '(python -m app.cli import-sources).'
              : 'Aucune source ne correspond à ces filtres.',
        ),
        itemBuilder: (context, source) => SourceCard(
          source: source,
          onTap: () => _open(source),
          onToggle: (value) => _toggle(source, value),
        ),
      ),
    );
  }
}

/// Carte d'une source : nom, type, état, dernière collecte, interrupteur d'activation.
class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.source, required this.onTap, this.onToggle});

  final Source source;
  final VoidCallback onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final health = source.health;
    final lastRun = source.lastAttemptAt == null
        ? 'Jamais collectée'
        : 'Dernière tentative ${Fmt.relative(source.lastAttemptAt)}';
    final showError = source.hasError && health != SourceHealth.ok;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall?.copyWith(
                    color: source.isActive ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                ),
                const Gap(8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(source.typeLabel, icon: source.type?.icon, dense: true),
                    Pill(health.label, color: health.color, icon: health.icon, dense: true),
                    Pill('${Fmt.number(source.offersCount)} offres', dense: true, filled: false),
                  ],
                ),
                const Gap(8),
                Row(
                  children: [
                    Icon(
                      showError ? Icons.error_outline_rounded : Icons.history_rounded,
                      size: 14,
                      color: showError ? AppColors.danger : AppColors.textTertiary,
                    ),
                    const Gap(6),
                    Expanded(
                      child: Text(
                        showError ? source.lastError! : lastRun,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(
                          color: showError ? AppColors.danger : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onToggle != null)
            Tooltip(
              message: source.isActive ? 'Désactiver' : 'Activer',
              child: Switch(value: source.isActive, onChanged: onToggle),
            ),
        ],
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial});

  final _SourceFilters initial;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late _SourceFilters _filters = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filtres', style: theme.titleLarge),
            const Gap(20),
            const FieldLabel('État'),
            ChoiceChips<bool>(
              values: const [true, false],
              selected: _filters.active,
              allowDeselect: true,
              labelOf: (v) => v ? 'Actives' : 'Désactivées',
              onSelected: (v) => setState(() => _filters = _filters.copyWith(active: () => v)),
            ),
            const Gap(28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_SourceFilters(type: _filters.type)),
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_filters),
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
