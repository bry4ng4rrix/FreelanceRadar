import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/ui.dart';
import '../data/source_models.dart';
import '../data/sources_repository.dart';

/// Collecte d'essai d'une source (`POST /sources/{id}/test`) : rien n'est enregistré.
final _testProvider = FutureProvider.autoDispose.family<SourceTestResult, int>(
  (ref, id) => ref.watch(sourcesRepositoryProvider).test(id),
);

class SourceTestSheet extends ConsumerWidget {
  const SourceTestSheet({super.key, required this.source});

  final Source source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(_testProvider(source.id));
    return DetailSheet(
      title: 'Test de la source',
      actions: [
        PrimaryButton(
          label: 'Relancer le test',
          icon: Icons.refresh_rounded,
          outlined: true,
          loading: result.isLoading,
          onPressed: () => ref.invalidate(_testProvider(source.id)),
        ),
      ],
      children: [
        Text(
          'Le serveur télécharge la source et analyse son contenu, sans rien enregistrer.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
        ),
        const Gap(16),
        AsyncValueView<SourceTestResult>(
          value: result,
          onRetry: () => ref.invalidate(_testProvider(source.id)),
          loading: const LoadingView(padding: EdgeInsets.symmetric(vertical: 48)),
          data: (test) => _TestResultView(result: test),
        ),
      ],
    );
  }
}

class _TestResultView extends StatelessWidget {
  const _TestResultView({required this.result});

  final SourceTestResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    if (!result.ok) {
      return NoteBox(
        title: 'Échec du test',
        message: result.error ?? 'Erreur inconnue.',
        color: AppColors.danger,
        icon: Icons.error_outline_rounded,
      );
    }
    final invalid = result.itemsFound - result.validItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoteBox(
          title: 'Source accessible',
          message: result.itemsFound == 0
              ? 'Le flux est lisible mais ne contient aucune offre pour le moment.'
              : '${result.itemsFound} élément(s) trouvé(s), dont ${result.validItems} '
                    'exploitable(s)${invalid > 0 ? ' et $invalid sans titre ou sans lien' : ''}.',
          color: AppColors.success,
          icon: Icons.check_circle_outline_rounded,
        ),
        if (result.sampleTitles.isNotEmpty) ...[
          const SheetSection('Aperçu'),
          for (final title in result.sampleTitles)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.work_outline_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const Gap(10),
                  Expanded(child: Text(title, style: theme.bodyMedium)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
