import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/blocks.dart';
import '../../core/widgets/bottom_bar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import 'applications_providers.dart';
import 'data/application_models.dart';
import 'widgets/application_widgets.dart';
import 'widgets/send_sheet.dart';

/// Candidature : relecture et modification du brouillon rédigé par l'IA, puis validation de l'envoi.
class ApplicationDetailPage extends ConsumerWidget {
  const ApplicationDetailPage({super.key, required this.applicationId});

  final int applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(applicationDetailProvider(applicationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Candidature')),
      body: AsyncValueView<Application>(
        value: value,
        onRetry: () => ref.invalidate(applicationDetailProvider(applicationId)),
        // Une clé par version : le formulaire repart des valeurs du serveur après une action.
        data: (application) => _ApplicationBody(
          key: ValueKey('${application.id}-${application.status}-${application.generationCount}'),
          application: application,
        ),
      ),
    );
  }
}

class _ApplicationBody extends ConsumerStatefulWidget {
  const _ApplicationBody({super.key, required this.application});

  final Application application;

  @override
  ConsumerState<_ApplicationBody> createState() => _ApplicationBodyState();
}

class _ApplicationBodyState extends ConsumerState<_ApplicationBody> {
  final _formKey = GlobalKey<FormState>();
  late final _recipient = TextEditingController(text: widget.application.recipientEmail);
  late final _subject = TextEditingController(text: widget.application.subject);
  late final _message = TextEditingController(text: widget.application.message);
  bool _dirty = false;
  bool _busy = false;

  Application get _app => widget.application;

  ApplicationDetailNotifier get _notifier => ref.read(applicationDetailProvider(_app.id).notifier);

  @override
  void dispose() {
    _recipient.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  static String? _validateRecipient(String? value) =>
      value == null || value.trim().isEmpty ? null : Validators.email(value);

  Future<Application?> _save({bool quiet = false}) async {
    if (!_formKey.currentState!.validate()) return null;
    setState(() => _busy = true);
    final saved = await runAction(
      () => _notifier.save(
        recipientEmail: _recipient.text,
        subject: _subject.text,
        message: _message.text,
      ),
      success: quiet ? null : 'Brouillon enregistré',
    );
    if (mounted) setState(() => _busy = false);
    return saved;
  }

  Future<void> _validateAndSend() async {
    if (_recipient.text.trim().isEmpty) {
      showToast(
        'Renseignez le destinataire (adresse de candidature indiquée dans l\'annonce).',
        kind: ToastKind.error,
      );
      return;
    }
    // Le texte modifié est enregistré avant le récapitulatif : c'est lui qui sera envoyé.
    final current = _dirty || _app.recipientEmail != _recipient.text.trim()
        ? await _save(quiet: true)
        : _app;
    if (current == null || !mounted) return;
    await showSendSheet(context, current);
  }

  Future<void> _regenerate() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Rédiger à nouveau ?',
      message: 'L\'IA va réécrire l\'objet et le message. Vos modifications seront remplacées.',
      confirmLabel: 'Rédiger',
    );
    if (!confirmed) return;
    await runAction(_notifier.regenerate, success: 'Nouvelle rédaction lancée');
  }

  Future<void> _cancel() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Annuler cette candidature ?',
      message: 'Elle ne pourra plus être envoyée.',
      confirmLabel: 'Annuler la candidature',
      destructive: true,
    );
    if (!confirmed) return;
    await runAction(_notifier.cancel, success: 'Candidature annulée');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final status = _app.status;
    final editable = status.isEditable;

    final body = Form(
      key: _formKey,
      onChanged: () {
        if (!_dirty) setState(() => _dirty = true);
      },
      child: PageListView(
        onRefresh: _notifier.reload,
        children: [
          // Wrap : sur un petit écran, l'adéquation passe sous le statut au lieu de déborder.
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ApplicationStatusPill(status: status, dense: false),
              if (_app.aiConfidence != null)
                Text(
                  'Adéquation estimée ${Fmt.score(_app.aiConfidence! * 100)}',
                  style: theme.labelMedium?.copyWith(color: AppColors.textTertiary),
                ),
            ],
          ),
          const Gap(12),
          InkWell(
            onTap: () => context.push(Routes.offer(_app.offerId)),
            child: Row(
              children: [
                Expanded(child: Text(_app.offerTitle, style: theme.headlineSmall)),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
              ],
            ),
          ),
          if (status == ApplicationStatus.generating) ...[
            const Gap(24),
            const NoteBox(
              title: 'Rédaction en cours',
              message:
                  'L\'IA rédige votre candidature à partir de votre profil et de vos compétences. '
                  'Vous recevrez une alerte dès qu\'elle sera prête à valider.',
              icon: Icons.auto_awesome_rounded,
            ),
            const LoadingView(padding: EdgeInsets.symmetric(vertical: 32)),
          ],
          if (_app.errorMessage != null && status != ApplicationStatus.sent) ...[
            const Gap(16),
            NoteBox(
              title: status.label,
              message: _app.errorMessage!,
              color: status == ApplicationStatus.deliveryUnknown
                  ? AppColors.warning
                  : AppColors.danger,
              icon: Icons.error_outline_rounded,
            ),
          ],
          if (_app.aiWarnings.isNotEmpty && editable) ...[
            const Gap(16),
            NoteBox(
              title: 'À vérifier avant l\'envoi',
              message: _app.aiWarnings.join('\n'),
              color: AppColors.warning,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          if (_app.referencedSkills.isNotEmpty) ...[
            const SectionHeader('Compétences mises en avant'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final skill in _app.referencedSkills) Pill(skill)],
            ),
          ],
          if (status == ApplicationStatus.sent) ...[
            const SectionHeader('Message envoyé'),
            SentMessageCard(application: _app),
          ] else if (editable) ...[
            const SectionHeader('Brouillon'),
            AppTextField(
              label: 'Destinataire',
              controller: _recipient,
              hint: 'adresse de candidature indiquée dans l\'annonce',
              keyboardType: TextInputType.emailAddress,
              validator: _validateRecipient,
              helper: 'Jamais devinée : recopiez l\'adresse donnée par le client.',
            ),
            formGap,
            AppTextField(
              label: 'Objet',
              controller: _subject,
              maxLength: 200,
              validator: Validators.required,
            ),
            formGap,
            AppTextField(
              label: 'Message',
              controller: _message,
              minLines: 10,
              maxLines: 30,
              maxLength: 8000,
              validator: Validators.required,
            ),
            if (_app.offerUrl.isNotEmpty) ...[
              const Gap(8),
              TextButton.icon(
                onPressed: () => openExternalUrl(_app.offerUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Voir l\'annonce (adresse de candidature)'),
              ),
            ],
          ],
          if (_app.aiModel != null) ...[
            const Gap(12),
            Text(
              'Rédigée par ${_app.aiModel} · ${Fmt.relative(_app.generatedAt)}'
              '${_app.isEdited ? ' · modifiée par vous' : ''}',
              style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
          if (status.canCancel && status != ApplicationStatus.generating) ...[
            const Gap(AppSpacing.xl),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _cancel,
                child: const Text(
                  'Annuler la candidature',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      body: body,
      bottomNavigationBar: !editable
          ? null
          : BottomBar(
              children: [
                if (status.canRegenerate)
                  PrimaryButton(
                    label: 'Rédiger à nouveau',
                    icon: Icons.auto_awesome_rounded,
                    outlined: true,
                    onPressed: _busy ? null : _regenerate,
                  ),
                if (status.isSendable)
                  PrimaryButton(
                    label: 'Valider l\'envoi',
                    icon: Icons.send_rounded,
                    loading: _busy,
                    onPressed: _validateAndSend,
                  )
                else
                  PrimaryButton(
                    label: 'Enregistrer',
                    loading: _busy,
                    onPressed: _dirty ? _save : null,
                  ),
              ],
            ),
    );
  }
}
