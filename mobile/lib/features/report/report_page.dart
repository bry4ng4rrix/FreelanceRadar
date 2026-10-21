import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/blocks.dart';
import '../../core/widgets/paged_list_view.dart';
import '../../core/widgets/ui.dart';
import '../applications/applications_providers.dart';
import '../applications/data/application_models.dart';
import '../applications/data/applications_repository.dart';
import '../applications/widgets/application_widgets.dart';

/// Onglet « Rapport » : candidatures à valider, candidatures envoyées et réponses reçues.
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _list = PagedListController();

  void _invalidateSummary() {
    ref
      ..invalidate(applicationCountsProvider)
      ..invalidate(pendingApplicationsProvider);
  }

  Future<void> _open(Application application) async {
    await context.push(Routes.application(application.id));
    if (!mounted) return;
    _invalidateSummary();
    await _list.refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Une candidature modifiée ailleurs (détail, notification) met le rapport à jour.
    ref.listen(applicationChangesProvider, (_, _) {
      _invalidateSummary();
      _list.refresh();
    });
    final repo = ref.watch(applicationsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rapport')),
      body: PagedListView<Application>(
        controller: _list,
        fetch: (page) => repo.list(page: page, status: ApplicationStatus.sent),
        // « Tirer pour actualiser » recharge la liste : on relit aussi le résumé.
        onTotal: (_) => _invalidateSummary(),
        header: [
          const Gap(4),
          const _Counters(),
          _PendingSection(onOpen: _open),
          const SectionHeader('Réponses reçues'),
          const NoteBox(
            message:
                'La lecture de votre boîte de réception (IMAP) n\'est pas encore en place : les '
                'réponses des clients apparaîtront ici dès qu\'elle sera configurée. En attendant, '
                'consultez-les dans votre messagerie.',
            icon: Icons.mark_email_unread_outlined,
          ),
          const SectionHeader('Candidatures envoyées'),
        ],
        itemBuilder: (context, application) =>
            ApplicationCard(application: application, onTap: () => _open(application)),
        emptyBuilder: (_) => const EmptyState(
          icon: Icons.send_outlined,
          title: 'Aucune candidature envoyée',
          message:
              'Depuis une offre, touchez « Préparer ma candidature » : l\'IA la rédige, '
              'vous la validez, puis elle part depuis votre adresse.',
        ),
      ),
    );
  }
}

/// Envoyées, à valider, en échec.
class _Counters extends ConsumerWidget {
  const _Counters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(applicationCountsProvider);
    if (!counts.hasValue && counts.hasError) {
      return InlineError(
        error: counts.error!,
        onRetry: () => ref.invalidate(applicationCountsProvider),
      );
    }
    final c = counts.value;
    String n(int? value) => value == null ? '—' : Fmt.number(value);
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Envoyées',
            value: n(c?.sent),
            icon: Icons.send_rounded,
            color: (c?.sent ?? 0) > 0 ? AppColors.success : null,
          ),
        ),
        const Gap(12),
        Expanded(
          child: StatTile(
            label: 'À valider',
            value: n(c?.pending),
            icon: Icons.rate_review_outlined,
            color: (c?.pending ?? 0) > 0 ? AppColors.warning : null,
          ),
        ),
        const Gap(12),
        Expanded(
          child: StatTile(
            label: 'Échecs',
            value: n(c?.failed),
            icon: Icons.error_outline_rounded,
            color: (c?.failed ?? 0) > 0 ? AppColors.danger : null,
          ),
        ),
      ],
    );
  }
}

/// Candidatures prêtes, en attente de votre validation.
class _PendingSection extends ConsumerWidget {
  const _PendingSection({required this.onOpen});

  final ValueChanged<Application> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingApplicationsProvider).value ?? const <Application>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('À valider'),
        for (final application in pending) ...[
          ApplicationCard(application: application, onTap: () => onOpen(application)),
          const Gap(10),
        ],
      ],
    );
  }
}
