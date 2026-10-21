import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blocks.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/tag_input.dart';
import '../../core/widgets/ui.dart';
import 'data/profile_models.dart';
import 'profile_providers.dart';
import 'widgets/profile_widgets.dart';

/// Mes compétences (`/profile/skills`), groupées par catégorie.
class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(skillsProvider);
    try {
      await ref.read(skillsProvider.future);
    } catch (_) {
      // Erreur affichée par la page.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(skillsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Compétences')),
      floatingActionButton: skills.hasValue
          ? FloatingActionButton.extended(
              heroTag: 'skills-add',
              onPressed: () => openSkillSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter'),
            )
          : null,
      body: AsyncValueView<List<Skill>>(
        value: skills,
        onRetry: () => ref.invalidate(skillsProvider),
        data: (items) {
          if (items.isEmpty) {
            return PageListView(
              onRefresh: () => _refresh(ref),
              children: [
                EmptyState(
                  icon: Icons.psychology_outlined,
                  title: 'Aucune compétence',
                  message:
                      'Ajoutez ce que vous savez faire, avec votre niveau réel : '
                      'elles serviront à trier les offres et à rédiger vos candidatures.',
                  actionLabel: 'Ajouter une compétence',
                  onAction: () => openSkillSheet(context),
                ),
              ],
            );
          }
          final groups = <String, List<Skill>>{};
          for (final skill in items) {
            groups.putIfAbsent(skill.category ?? 'Autres', () => []).add(skill);
          }
          // Catégories par ordre alphabétique, « Autres » en dernier.
          final keys = groups.keys.toList()
            ..sort((a, b) {
              if (a == 'Autres') return 1;
              if (b == 'Autres') return -1;
              return a.toLowerCase().compareTo(b.toLowerCase());
            });

          return PageListView(
            onRefresh: () => _refresh(ref),
            children: [
              IntroText(
                '${items.length} compétence${items.length > 1 ? 's' : ''}. Indiquez votre niveau '
                'réel : il n\'est jamais deviné ni modifié automatiquement.',
              ),
              for (final key in keys) ...[
                SectionHeader(
                  key,
                  trailing: Text(
                    '${groups[key]!.length}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
                  ),
                ),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < groups[key]!.length; i++) ...[
                        if (i > 0) const Divider(indent: AppSpacing.lg),
                        _SkillRow(skill: groups[key]![i]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final details = [
      if (skill.yearsExperience != null && skill.yearsExperience! > 0)
        yearsLabel(skill.yearsExperience!),
      if (skill.aliases.isNotEmpty) skill.aliases.join(', '),
    ].join(' · ');
    return InkWell(
      onTap: () => openSkillSheet(context, skill: skill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(skill.name, style: theme.titleSmall),
                  if (details.isNotEmpty) ...[
                    const Gap(2),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(12),
            LevelMeter(level: skill.level),
            const Gap(4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Ouvre la feuille d'ajout (sans [skill]) ou de modification d'une compétence.
Future<void> openSkillSheet(BuildContext context, {Skill? skill}) =>
    showAppSheet<void>(context, expand: true, builder: (_) => _SkillSheet(skill: skill));

class _SkillSheet extends ConsumerStatefulWidget {
  const _SkillSheet({this.skill});

  final Skill? skill;

  @override
  ConsumerState<_SkillSheet> createState() => _SkillSheetState();
}

class _SkillSheetState extends ConsumerState<_SkillSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.skill?.name ?? '');
  late final _category = TextEditingController(text: widget.skill?.category ?? '');
  late final _years = TextEditingController(
    text: widget.skill?.yearsExperience == null ? '' : _formatYears(widget.skill!.yearsExperience!),
  );
  late SkillLevel _level = widget.skill?.level ?? SkillLevel.intermediate;
  late List<String> _aliases = [...?widget.skill?.aliases];
  bool _saving = false;

  bool get _editing => widget.skill != null;

  static String _formatYears(double years) => years == years.roundToDouble()
      ? years.round().toString()
      : years.toString().replaceAll('.', ',');

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _years.dispose();
    super.dispose();
  }

  double? get _yearsValue => double.tryParse(_years.text.trim().replaceAll(',', '.'));

  String? _validateYears(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final years = _yearsValue;
    return years == null || years < 0 || years > 60 ? 'Un nombre entre 0 et 60' : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final input = SkillInput(
      name: _name.text,
      category: _category.text,
      level: _level,
      yearsExperience: _years.text.trim().isEmpty ? null : _yearsValue,
      aliases: _aliases,
    );
    setState(() => _saving = true);
    final notifier = ref.read(skillsProvider.notifier);
    final done = await runAction(() async {
      _editing ? await notifier.edit(widget.skill!.id, input) : await notifier.add(input);
      return true;
    }, success: _editing ? 'Compétence mise à jour' : '« ${input.name.trim()} » ajoutée');
    if (!mounted) return;
    setState(() => _saving = false);
    if (done == true) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final skill = widget.skill!;
    final confirmed = await confirmDialog(
      context,
      title: 'Retirer « ${skill.name} » ?',
      message: 'La compétence sera retirée de votre profil.',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final done = await runAction(() async {
      await ref.read(skillsProvider.notifier).remove(skill.id);
      return true;
    }, success: 'Compétence retirée');
    if (!mounted) return;
    setState(() => _saving = false);
    if (done == true) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final existing = (ref.watch(skillsProvider).value ?? const <Skill>[])
        .map((s) => s.name.toLowerCase())
        .toSet();
    final suggestions = _editing
        ? const <String>[]
        : suggestedSkills.where((s) => !existing.contains(s.toLowerCase())).toList();

    return FormSheet(
      title: _editing ? 'Modifier la compétence' : 'Ajouter une compétence',
      formKey: _formKey,
      saving: _saving,
      onSubmit: _submit,
      submitLabel: _editing ? 'Enregistrer' : 'Ajouter',
      onDelete: _editing ? _delete : null,
      children: [
        AppTextField(
          label: 'Compétence',
          controller: _name,
          hint: 'ex. FastAPI',
          maxLength: 100,
          validator: Validators.required,
          onChanged: (_) => setState(() {}),
        ),
        if (suggestions.isNotEmpty) ...[
          const Gap(4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in suggestions.take(12))
                ActionChip(label: Text(name), onPressed: () => setState(() => _name.text = name)),
            ],
          ),
        ],
        formGap,
        const FieldLabel('Niveau'),
        LevelSelector(value: _level, onChanged: (level) => setState(() => _level = level)),
        formGap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Années de pratique',
                controller: _years,
                optional: true,
                hint: 'ex. 3',
                validator: _validateYears,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
            ),
            const Gap(12),
            Expanded(
              child: AppTextField(
                label: 'Catégorie',
                controller: _category,
                optional: true,
                hint: 'ex. Backend',
                maxLength: 100,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in suggestedCategories)
              ChoiceChip(
                label: Text(category),
                selected: _category.text == category,
                onSelected: (_) => setState(() => _category.text = category),
              ),
          ],
        ),
        formGap,
        TagInput(
          label: 'Autres noms',
          optional: true,
          values: _aliases,
          maxTags: 20,
          hint: 'ex. fast-api, puis Entrée',
          onChanged: (values) => setState(() => _aliases = values),
        ),
      ],
    );
  }
}
