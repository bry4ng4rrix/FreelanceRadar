import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/ui.dart';
import '../../sources/data/source_models.dart';
import '../../sources/sources_providers.dart';
import '../data/offer_models.dart';

/// Ouvre la feuille de filtres complète. Renvoie les nouveaux filtres (null = annulé).
Future<OfferFilters?> showOfferFiltersSheet(BuildContext context, OfferFilters initial) =>
    showAppSheet<OfferFilters>(context, builder: (_) => _OfferFiltersSheet(initial: initial));

/// Période de publication proposée (jours).
const _periods = [1, 7, 30];

class _OfferFiltersSheet extends ConsumerStatefulWidget {
  const _OfferFiltersSheet({required this.initial});

  final OfferFilters initial;

  @override
  ConsumerState<_OfferFiltersSheet> createState() => _OfferFiltersSheetState();
}

class _OfferFiltersSheetState extends ConsumerState<_OfferFiltersSheet> {
  late OfferFilters _filters = widget.initial;

  /// Période sélectionnée, déduite de la date `published_after` (arrondie au jour).
  int? get _period {
    final after = _filters.publishedAfter;
    if (after == null) return null;
    final days = DateTime.now().difference(after).inHours / 24;
    for (final period in _periods) {
      if ((days - period).abs() < 1) return period;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sources = ref.watch(allSourcesProvider).value ?? const <Source>[];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filtres', style: theme.titleLarge),
            const Gap(20),
            const FieldLabel('Statut'),
            ChoiceChips<OfferStatus>(
              values: OfferStatus.values,
              selected: _filters.status,
              allowDeselect: true,
              labelOf: (status) => status.label,
              onSelected: (status) =>
                  setState(() => _filters = _filters.copyWith(status: () => status)),
            ),
            formGap,
            if (sources.isNotEmpty) ...[
              AppDropdown<int>(
                label: 'Source',
                values: [for (final source in sources) source.id],
                value: _filters.sourceId,
                labelOf: (id) => sources.firstWhere((s) => s.id == id).name,
                allowNull: true,
                nullLabel: 'Toutes les sources',
                onChanged: (id) => setState(() => _filters = _filters.copyWith(sourceId: () => id)),
              ),
              formGap,
            ],
            const FieldLabel('Publiées depuis'),
            ChoiceChips<int>(
              values: _periods,
              selected: _period,
              allowDeselect: true,
              labelOf: (days) => days == 1 ? '24 h' : '$days jours',
              onSelected: (days) => setState(
                () => _filters = _filters.copyWith(
                  publishedAfter: () =>
                      days == null ? null : DateTime.now().subtract(Duration(days: days)),
                ),
              ),
            ),
            formGap,
            SwitchRow(
              title: 'Inclure les offres archivées',
              value: _filters.includeArchived,
              onChanged: (value) =>
                  setState(() => _filters = _filters.copyWith(includeArchived: value)),
            ),
            const Gap(28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(OfferFilters(search: _filters.search, sort: _filters.sort)),
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
