import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/ui.dart';
import '../applications_providers.dart';
import '../data/application_models.dart';

/// « Valider l'envoi » : récapitulatif exact de ce qui part + case de confirmation explicite.
/// Aucune candidature n'est envoyée sans cette confirmation. Renvoie la candidature à jour.
Future<Application?> showSendSheet(BuildContext context, Application application) =>
    showAppSheet<Application>(
      context,
      expand: true,
      builder: (_) => _SendSheet(application: application),
    );

class _SendSheet extends ConsumerStatefulWidget {
  const _SendSheet({required this.application});

  final Application application;

  @override
  ConsumerState<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends ConsumerState<_SendSheet> {
  bool _confirmed = false;
  bool _sending = false;

  Application get _app => widget.application;

  Future<void> _send() async {
    setState(() => _sending = true);
    final result = await runAction(
      () => ref.read(applicationDetailProvider(_app.id).notifier).send(),
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _sending = false);
      return;
    }
    switch (result.status) {
      case ApplicationStatus.sent:
        showToast('Candidature envoyée à ${result.sentTo}', kind: ToastKind.success);
      case ApplicationStatus.deliveryUnknown:
        showToast(
          'Envoi incertain : vérifiez le dossier « Envoyés » de votre messagerie.',
          kind: ToastKind.error,
        );
      default:
        showToast(result.errorMessage ?? 'L\'envoi a échoué.', kind: ToastKind.error);
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return DetailSheet(
      title: 'Valider l\'envoi',
      actions: [
        PrimaryButton(
          label: 'Envoyer la candidature',
          icon: Icons.send_rounded,
          loading: _sending,
          onPressed: _confirmed ? _send : null,
        ),
      ],
      children: [
        Text(
          'Vérifiez ce qui sera envoyé depuis votre adresse. Rien ne part sans votre confirmation.',
          style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SheetSection('Destinataire'),
        Text(_app.recipientEmail ?? '—', style: theme.titleMedium),
        const SheetSection('Objet'),
        Text(_app.subject ?? '', style: theme.titleSmall),
        const SheetSection('Message'),
        AppCard(
          child: SelectableText(_app.message ?? '', style: theme.bodyMedium?.copyWith(height: 1.5)),
        ),
        if (_app.aiWarnings.isNotEmpty) ...[
          const Gap(12),
          NoteBox(
            title: 'Points signalés par l\'IA',
            message: _app.aiWarnings.join('\n'),
            color: AppColors.warning,
            icon: Icons.warning_amber_rounded,
          ),
        ],
        const Gap(12),
        CheckboxListTile(
          value: _confirmed,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: _sending ? null : (value) => setState(() => _confirmed = value ?? false),
          title: const Text('J\'ai relu ce message et je confirme son envoi.'),
        ),
      ],
    );
  }
}
