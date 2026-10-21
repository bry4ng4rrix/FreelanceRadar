import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/bottom_bar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/tag_input.dart';
import '../../core/widgets/ui.dart';
import 'data/profile_models.dart';
import 'profile_providers.dart';

/// Modification du profil (`PATCH /profile`).
class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return AsyncValueView<Profile>(
      value: profile,
      onRetry: () => ref.invalidate(profileProvider),
      loading: Scaffold(
        appBar: AppBar(title: const Text('Modifier le profil')),
        body: const LoadingView(),
      ),
      // Le formulaire garde ses propres valeurs : il n'est construit qu'une fois par profil chargé.
      data: (profile) => _EditProfileForm(key: ValueKey(profile.id), initial: profile),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({super.key, required this.initial});

  final Profile initial;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final Profile p = widget.initial;

  late final _fullName = TextEditingController(text: p.fullName);
  late final _title = TextEditingController(text: p.professionalTitle);
  late final _summary = TextEditingController(text: p.summary);
  late final _email = TextEditingController(text: p.primaryEmail);
  late final _phone = TextEditingController(text: p.phone);
  late final _location = TextEditingController(text: p.location);
  late final _portfolio = TextEditingController(text: p.portfolioUrl);
  late final _github = TextEditingController(text: p.githubUrl);
  late final _linkedin = TextEditingController(text: p.linkedinUrl);
  late final _rate = TextEditingController(text: _amount(p.defaultRate));
  late final _budget = TextEditingController(text: _amount(p.minimumBudget));
  late final _currency = TextEditingController(text: p.currency);

  late List<String> _secondaryEmails = [...p.secondaryEmails];
  late List<String> _languages = [...p.preferredLanguages];
  late Availability _availability = p.availability;
  late DateTime? _availableFrom = p.availableFrom;
  late RateUnit _rateUnit = p.rateUnit;
  late Set<ContractType> _contracts = {...p.contractTypes};
  late List<String> _locations = [...p.acceptedLocations];
  late List<String> _timezones = [...p.acceptedTimezones];
  late List<String> _included = [...p.includedKeywords];
  late List<String> _excluded = [...p.excludedKeywords];

  bool _saving = false;
  bool _dirty = false;

  static String _amount(double? value) => value == null
      ? ''
      : (value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(2))
            .replaceAll('.', ',');

  static double? _parseAmount(String text) {
    final value = text.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (value.isEmpty) return null;
    final parsed = double.tryParse(value);
    return parsed == null ? null : (parsed * 100).round() / 100;
  }

  static String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final amount = _parseAmount(value);
    return amount == null || amount < 0 ? 'Montant invalide' : null;
  }

  static String? _optionalEmail(String? value) =>
      value == null || value.trim().isEmpty ? null : Validators.email(value);

  static String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^\+?[0-9 ().-]{6,30}$').hasMatch(value.trim()) ? null : 'Numéro invalide';
  }

  static String? _validateCurrency(String? value) =>
      RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '') ? null : '3 lettres (EUR, USD, MGA…)';

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _title,
      _summary,
      _email,
      _phone,
      _location,
      _portfolio,
      _github,
      _linkedin,
      _rate,
      _budget,
      _currency,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed(VoidCallback update) => setState(() {
    update();
    _dirty = true;
  });

  String? _text(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  bool get _listsValid =>
      _secondaryEmails.every((e) => _optionalEmail(e) == null) &&
      _languages.every((l) => RegExp(r'^[a-z]{2,3}$').hasMatch(l));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_listsValid) {
      showToast('Corrigez les champs signalés.', kind: ToastKind.error);
      return;
    }
    final updated = Profile(
      id: p.id,
      fullName: _text(_fullName),
      professionalTitle: _text(_title),
      summary: _text(_summary),
      primaryEmail: _text(_email),
      secondaryEmails: _secondaryEmails,
      phone: _text(_phone),
      location: _text(_location),
      portfolioUrl: _text(_portfolio),
      githubUrl: _text(_github),
      linkedinUrl: _text(_linkedin),
      preferredLanguages: _languages,
      availability: _availability,
      availableFrom: _availableFrom,
      defaultRate: _parseAmount(_rate.text),
      rateUnit: _rateUnit,
      minimumBudget: _parseAmount(_budget.text),
      currency: _currency.text.trim().toUpperCase(),
      contractTypes: ContractType.values.where(_contracts.contains).toList(),
      acceptedLocations: _locations,
      acceptedTimezones: _timezones,
      includedKeywords: _included,
      excludedKeywords: _excluded,
    );
    setState(() => _saving = true);
    final saved = await runAction(
      () => ref.read(profileProvider.notifier).save(updated.toUpdateJson()),
      success: 'Profil enregistré',
    );
    if (!mounted) return;
    if (saved != null) {
      // Fermeture pendant que `_saving` est vrai : pas de demande de confirmation.
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmDialog(
      context,
      title: 'Abandonner les modifications ?',
      message: 'Les changements non enregistrés seront perdus.',
      confirmLabel: 'Abandonner',
      destructive: true,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Modifier le profil')),
        bottomNavigationBar: BottomBar(
          children: [PrimaryButton(label: 'Enregistrer', loading: _saving, onPressed: _save)],
        ),
        body: Form(
          key: _formKey,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
          child: PageListView(
            children: [
              const SectionHeader('Identité'),
              AppTextField(
                label: 'Nom complet',
                controller: _fullName,
                optional: true,
                maxLength: 200,
              ),
              formGap,
              AppTextField(
                label: 'Titre professionnel',
                controller: _title,
                optional: true,
                hint: 'ex. Développeur Python / Flutter',
                maxLength: 200,
              ),
              formGap,
              AppTextField(
                label: 'Présentation',
                controller: _summary,
                optional: true,
                hint: 'Votre parcours et ce que vous proposez, en quelques phrases.',
                minLines: 4,
                maxLines: 10,
                maxLength: 5000,
              ),
              const SectionHeader('Coordonnées'),
              AppTextField(
                label: 'Email principal',
                controller: _email,
                optional: true,
                keyboardType: TextInputType.emailAddress,
                validator: _optionalEmail,
              ),
              formGap,
              TagInput(
                label: 'Autres emails',
                optional: true,
                values: _secondaryEmails,
                maxTags: 10,
                hint: 'Ajouter un email puis Entrée',
                onChanged: (values) => _changed(() => _secondaryEmails = values),
              ),
              if (_secondaryEmails.any((e) => _optionalEmail(e) != null)) ...[
                const Gap(6),
                Text(
                  'Un des emails ajoutés est invalide.',
                  style: theme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ],
              formGap,
              AppTextField(
                label: 'Téléphone',
                controller: _phone,
                optional: true,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
              formGap,
              AppTextField(
                label: 'Localisation',
                controller: _location,
                optional: true,
                hint: 'ex. Antananarivo, Madagascar',
                maxLength: 200,
              ),
              const SectionHeader('Liens'),
              AppTextField(
                label: 'Portfolio',
                controller: _portfolio,
                optional: true,
                keyboardType: TextInputType.url,
                hint: 'https://…',
                validator: Validators.optionalUrl,
              ),
              formGap,
              AppTextField(
                label: 'GitHub',
                controller: _github,
                optional: true,
                keyboardType: TextInputType.url,
                hint: 'https://github.com/…',
                validator: Validators.optionalUrl,
              ),
              formGap,
              AppTextField(
                label: 'LinkedIn',
                controller: _linkedin,
                optional: true,
                keyboardType: TextInputType.url,
                hint: 'https://www.linkedin.com/in/…',
                validator: Validators.optionalUrl,
              ),
              const SectionHeader('Disponibilité et tarif'),
              const FieldLabel('Disponibilité'),
              ChoiceChips<Availability>(
                values: Availability.values,
                selected: _availability,
                labelOf: (a) => a.label,
                onSelected: (a) => _changed(() => _availability = a ?? _availability),
              ),
              formGap,
              DateField(
                label: 'Disponible à partir du',
                optional: true,
                value: _availableFrom,
                onChanged: (date) => _changed(() => _availableFrom = date),
              ),
              formGap,
              const FieldLabel('Unité du tarif'),
              ChoiceChips<RateUnit>(
                values: RateUnit.values,
                selected: _rateUnit,
                labelOf: (u) => u.title,
                onSelected: (u) => _changed(() => _rateUnit = u ?? _rateUnit),
              ),
              formGap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      label: 'Tarif par ${_rateUnit.label}',
                      controller: _rate,
                      optional: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 .,]'))],
                      validator: _validateAmount,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: AppTextField(
                      label: 'Devise',
                      controller: _currency,
                      maxLength: 3,
                      validator: _validateCurrency,
                    ),
                  ),
                ],
              ),
              formGap,
              AppTextField(
                label: 'Budget minimal d\'une mission',
                controller: _budget,
                optional: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 .,]'))],
                validator: _validateAmount,
              ),
              formGap,
              TagInput(
                label: 'Langues',
                optional: true,
                values: _languages,
                maxTags: 10,
                hint: 'Code ISO puis Entrée (fr, en, mg…)',
                suggestions: const ['fr', 'en', 'mg', 'es', 'de'],
                onChanged: (values) =>
                    _changed(() => _languages = [for (final v in values) v.toLowerCase()]),
              ),
              if (_languages.any((l) => !RegExp(r'^[a-z]{2,3}$').hasMatch(l))) ...[
                const Gap(6),
                Text(
                  'Utilisez des codes de 2 ou 3 lettres (fr, en, mg).',
                  style: theme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ],
              const SectionHeader('Recherche'),
              const FieldLabel('Types de missions', optional: true),
              MultiChoiceChips<ContractType>(
                values: ContractType.values,
                selected: _contracts,
                labelOf: (t) => t.label,
                onChanged: (values) => _changed(() => _contracts = values),
              ),
              formGap,
              TagInput(
                label: 'Lieux acceptés',
                optional: true,
                values: _locations,
                maxTags: 20,
                hint: 'ex. Remote, Paris…',
                suggestions: const ['Remote', 'Madagascar', 'France', 'Europe'],
                onChanged: (values) => _changed(() => _locations = values),
              ),
              formGap,
              TagInput(
                label: 'Fuseaux horaires acceptés',
                optional: true,
                values: _timezones,
                maxTags: 20,
                hint: 'ex. UTC+3, Europe/Paris…',
                onChanged: (values) => _changed(() => _timezones = values),
              ),
              formGap,
              TagInput(
                label: 'Mots-clés recherchés',
                optional: true,
                values: _included,
                hint: 'ex. fastapi, scraping…',
                onChanged: (values) => _changed(() => _included = values),
              ),
              formGap,
              TagInput(
                label: 'Mots-clés exclus',
                optional: true,
                values: _excluded,
                hint: 'ex. wordpress, stage…',
                onChanged: (values) => _changed(() => _excluded = values),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
