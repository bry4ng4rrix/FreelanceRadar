import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/ui.dart';
import '../data/source_models.dart';
import '../data/sources_repository.dart';

/// Ouvre le formulaire de création ([source] null) ou de modification d'une source.
/// Renvoie la source enregistrée.
Future<Source?> showSourceForm(BuildContext context, {Source? source}) =>
    showAppSheet<Source>(context, expand: true, builder: (_) => SourceFormSheet(source: source));

/// Formulaire d'une source (`SourceCreate` / `SourceUpdate`).
class SourceFormSheet extends ConsumerStatefulWidget {
  const SourceFormSheet({super.key, this.source});

  final Source? source;

  @override
  ConsumerState<SourceFormSheet> createState() => _SourceFormSheetState();
}

class _SourceFormSheetState extends ConsumerState<SourceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _url;
  late final TextEditingController _frequency;
  late final TextEditingController _keywords;
  late final TextEditingController _selectors;
  late SourceType _type;
  late bool _active;
  bool _saving = false;

  bool get _editing => widget.source != null;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _name = TextEditingController(text: s?.name ?? '');
    _category = TextEditingController(text: s?.category ?? '');
    _url = TextEditingController(text: s?.url ?? '');
    _frequency = TextEditingController(text: '${s?.frequencyMinutes ?? 60}');
    _keywords = TextEditingController(text: s?.keywords.join(', ') ?? '');
    _selectors = TextEditingController(
      text: (s == null || s.selectors.isEmpty) ? '{}' : JsonBlock.format(s.selectors),
    );
    _type = s?.type ?? SourceType.rss;
    // Une nouvelle source est inactive par défaut : on la teste avant de l'activer.
    _active = s?.isActive ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _url.dispose();
    _frequency.dispose();
    _keywords.dispose();
    _selectors.dispose();
    super.dispose();
  }

  static String? _validateUrl(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null || !uri.hasAuthority || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return 'Adresse http(s) complète attendue';
    }
    return null;
  }

  static String? _validateFrequency(String? value) {
    final minutes = int.tryParse(value?.trim() ?? '');
    if (minutes == null || minutes < 5 || minutes > 10080) {
      return 'Entre 5 minutes et 7 jours (10 080 min)';
    }
    return null;
  }

  static String? _validateSelectors(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text) is Map ? null : 'Un objet JSON est attendu : { ... }';
    } catch (_) {
      return 'JSON invalide';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final selectorsText = _selectors.text.trim();
    final input = SourceInput(
      name: _name.text,
      category: _category.text,
      url: _url.text,
      type: _type,
      frequencyMinutes: int.parse(_frequency.text.trim()),
      isActive: _active,
      keywords: splitList(_keywords.text),
      selectors: selectorsText.isEmpty
          ? const {}
          : (jsonDecode(selectorsText) as Map).cast<String, dynamic>(),
    );
    setState(() => _saving = true);
    final repo = ref.read(sourcesRepositoryProvider);
    final saved = await runAction(
      () => _editing ? repo.update(widget.source!.id, input.toJson()) : repo.create(input),
      success: _editing ? 'Source enregistrée' : 'Source créée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: _editing ? 'Modifier la source' : 'Nouvelle source',
    formKey: _formKey,
    saving: _saving,
    onSubmit: _submit,
    submitLabel: _editing ? 'Enregistrer' : 'Créer la source',
    children: [
      AppTextField(
        label: 'Nom',
        controller: _name,
        hint: 'We Work Remotely — Full Stack',
        maxLength: 200,
        validator: Validators.required,
      ),
      formGap,
      AppTextField(
        label: 'Adresse',
        controller: _url,
        hint: 'https://exemple.com/flux.rss',
        keyboardType: TextInputType.url,
        validator: _validateUrl,
      ),
      formGap,
      const FieldLabel('Type de connecteur'),
      ChoiceChips<SourceType>(
        values: SourceType.values,
        selected: _type,
        labelOf: (type) => type.label,
        onSelected: (type) => setState(() => _type = type ?? _type),
      ),
      if (!_type.hasConnector) ...[
        const Gap(10),
        const NoteBox(
          message:
              'Le serveur ne sait pas encore collecter ce type de source : seule la '
              'collecte RSS est disponible pour l\'instant.',
          icon: Icons.info_outline_rounded,
        ),
      ],
      formGap,
      AppTextField(
        label: 'Fréquence (minutes)',
        controller: _frequency,
        keyboardType: TextInputType.number,
        validator: _validateFrequency,
        helper: 'Respectez les limites demandées par le site (ex. Remotive : 4 fois par jour).',
      ),
      formGap,
      AppTextField(
        label: 'Catégorie',
        controller: _category,
        optional: true,
        hint: 'Remote International',
        maxLength: 200,
      ),
      formGap,
      AppTextField(
        label: 'Mots-clés',
        controller: _keywords,
        optional: true,
        hint: 'python, flutter, fastapi',
        helper: 'Séparés par des virgules.',
      ),
      formGap,
      AppTextField(
        label: 'Sélecteurs (JSON)',
        controller: _selectors,
        optional: true,
        maxLines: 6,
        minLines: 3,
        validator: _validateSelectors,
        helper: 'Utilisés par les futurs connecteurs HTML/Playwright. Inutiles pour RSS.',
      ),
      formGap,
      SwitchRow(
        title: 'Source active',
        subtitle: 'Incluse dans les collectes planifiées.',
        value: _active,
        onChanged: (value) => setState(() => _active = value),
      ),
    ],
  );
}
