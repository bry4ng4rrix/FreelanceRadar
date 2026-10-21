import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/ui.dart';
import 'data/profile_models.dart';
import 'profile_providers.dart';

/// Onglet « Profil » : résumé du profil, accès à la modification, aux compétences et aux réglages.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(profileProvider)
      ..invalidate(skillsProvider);
    try {
      await ref.read(profileProvider.future);
    } catch (_) {
      // L'erreur est affichée dans la page (état d'erreur avec « Réessayer »).
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final skills = ref.watch(skillsProvider).value;
    final email = ref.watch(currentUserProvider.select((user) => user?.email));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
          const Gap(8),
        ],
      ),
      body: PageListView(
        onRefresh: () => _refresh(ref),
        children: [
          AsyncValueView<Profile>(
            value: profile,
            onRetry: () => ref.invalidate(profileProvider),
            loading: const LoadingView(padding: EdgeInsets.symmetric(vertical: 56)),
            data: (profile) =>
                _ProfileOverview(profile: profile, accountEmail: email, skillCount: skills?.length),
          ),
          const SectionHeader('Mon profil'),
          MenuGroup(
            children: [
              MenuTile(
                icon: Icons.person_outline_rounded,
                title: 'Modifier le profil',
                subtitle: 'Identité, coordonnées, disponibilité, tarif, recherche',
                onTap: () => context.push(Routes.profileEdit),
              ),
              MenuTile(
                icon: Icons.psychology_outlined,
                title: 'Compétences',
                subtitle: switch (skills?.length) {
                  null => 'Ce que vous savez faire',
                  0 => 'Aucune pour l\'instant',
                  1 => '1 compétence',
                  final n => '$n compétences',
                },
                onTap: () => context.push(Routes.skills),
              ),
            ],
          ),
          const SectionHeader('Application'),
          MenuGroup(
            children: [
              MenuTile(
                icon: Icons.settings_outlined,
                title: 'Réglages',
                subtitle: 'Serveur, session, à propos',
                onTap: () => context.push(Routes.settings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// En-tête (nom, titre, lieu), complétude et informations clés du profil.
class _ProfileOverview extends StatelessWidget {
  const _ProfileOverview({required this.profile, this.accountEmail, this.skillCount});

  final Profile profile;
  final String? accountEmail;
  final int? skillCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final title = profile.professionalTitle;
    final rate = profile.defaultRate == null
        ? null
        : '${Fmt.number(profile.defaultRate)} ${profile.currency} / ${profile.rateUnit.label}';
    final pills = <Widget>[
      Pill(profile.availability.label, icon: Icons.event_available_outlined),
      if (rate != null) Pill(rate, icon: Icons.payments_outlined),
      for (final language in profile.preferredLanguages)
        Pill(language.toUpperCase(), icon: Icons.translate_rounded),
    ];
    final links = <(IconData, String, String)>[
      if (profile.portfolioUrl != null)
        (Icons.language_rounded, 'Portfolio', profile.portfolioUrl!),
      if (profile.githubUrl != null) (Icons.code_rounded, 'GitHub', profile.githubUrl!),
      if (profile.linkedinUrl != null) (Icons.badge_outlined, 'LinkedIn', profile.linkedinUrl!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(AppSpacing.sm),
        InkWell(
          borderRadius: AppRadius.card,
          onTap: () => context.push(Routes.profileEdit),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                AppAvatar(label: profile.fullName ?? accountEmail, size: 76),
                const Gap(AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName ?? 'Votre profil',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.headlineSmall,
                      ),
                      const Gap(2),
                      Text(
                        title ?? 'Ajoutez votre titre professionnel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyMedium?.copyWith(
                          color: title != null ? AppColors.textSecondary : AppColors.textTertiary,
                        ),
                      ),
                      const Gap(6),
                      if (profile.location != null)
                        _MetaLine(icon: Icons.place_outlined, text: profile.location!),
                      if (profile.primaryEmail ?? accountEmail case final email?)
                        _MetaLine(icon: Icons.alternate_email_rounded, text: email),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(AppSpacing.md),
        Wrap(spacing: 8, runSpacing: 8, children: pills),
        if (skillCount != null && profile.completion(skillCount: skillCount!) < 100) ...[
          const Gap(AppSpacing.lg),
          _CompletionCard(profile: profile, skillCount: skillCount!),
        ],
        if (profile.summary != null) ...[
          const SectionHeader('Présentation'),
          AppCard(
            child: Text(
              profile.summary!,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
        if (links.isNotEmpty) ...[
          const SectionHeader('Liens'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
            child: Column(
              children: [
                for (final (icon, label, url) in links)
                  InfoRow(
                    icon: icon,
                    label: label,
                    value: url.replaceFirst(RegExp(r'^https?://'), ''),
                    onTap: () => openExternalUrl(url),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const Gap(6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    ),
  );
}

/// Complétude du profil et éléments encore vides.
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.profile, required this.skillCount});

  final Profile profile;
  final int skillCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final percent = profile.completion(skillCount: skillCount);
    final missing = profile.missingFields(skillCount: skillCount);
    return AppCard(
      onTap: () => context.push(Routes.profileEdit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Profil complété', style: theme.titleSmall)),
              Text(
                '$percent %',
                style: theme.titleSmall?.copyWith(color: AppColors.score(percent)),
              ),
            ],
          ),
          const Gap(10),
          ThinProgress(value: percent / 100, color: AppColors.score(percent)),
          if (missing.isNotEmpty) ...[
            const Gap(10),
            Text(
              'À compléter : ${missing.join(', ')}',
              style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
