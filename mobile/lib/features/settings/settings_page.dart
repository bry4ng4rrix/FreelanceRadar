import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/app_user.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/ui.dart';
import '../auth/widgets/server_sheet.dart';

/// État du serveur (`GET /api/v1/ready`) avec la latence mesurée.
class ServerHealth {
  const ServerHealth({
    required this.ready,
    required this.database,
    required this.redis,
    this.latency,
  });

  final bool ready;
  final bool database;
  final bool redis;
  final Duration? latency;
}

final serverHealthProvider = FutureProvider.autoDispose<ServerHealth>((ref) async {
  final watch = Stopwatch()..start();
  final data = await ref.watch(apiClientProvider).ready();
  watch.stop();
  return ServerHealth(
    ready: data['status'] == 'ok',
    database: data['database'] == true,
    redis: data['redis'] == true,
    latency: watch.elapsed,
  );
});

/// Réglages : compte, serveur, à propos, déconnexion.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Se déconnecter ?',
      message:
          'Toutes vos sessions seront fermées, y compris sur vos autres appareils '
          '(le serveur révoque tous les jetons du compte).',
      confirmLabel: 'Se déconnecter',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final serverUrl = ref.watch(serverUrlProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: PageListView(
        onRefresh: () async {
          ref.invalidate(serverHealthProvider);
          await ref
              .read(serverHealthProvider.future)
              .catchError((_) => const ServerHealth(ready: false, database: false, redis: false));
        },
        children: [
          if (user != null) _AccountCard(user: user),
          SectionHeader(
            'Serveur',
            action: 'Tester',
            onAction: () => ref.invalidate(serverHealthProvider),
          ),
          _ServerCard(serverUrl: serverUrl),
          const Gap(10),
          MenuGroup(
            children: [
              MenuTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Changer de serveur',
                subtitle: 'Une reconnexion sera nécessaire',
                onTap: () => showAppSheet<void>(context, builder: (_) => const ServerSheet()),
              ),
            ],
          ),
          const SectionHeader('Collecte'),
          MenuGroup(
            children: [
              MenuTile(
                icon: Icons.rss_feed_rounded,
                title: 'Sources',
                subtitle: 'Sites collectés, tests, historique des collectes',
                onTap: () => context.push(Routes.sources),
              ),
            ],
          ),
          const SectionHeader('À propos'),
          MenuGroup(
            children: [
              const MenuTile(
                icon: Icons.info_outline_rounded,
                title: kAppName,
                subtitle: 'Version $kAppVersion',
              ),
              MenuTile(
                icon: Icons.menu_book_outlined,
                title: 'Documentation de l\'API',
                subtitle: '${_hostLabel(serverUrl)}/docs',
                trailing: const Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onTap: () => openExternalUrl('$serverUrl/docs'),
              ),
            ],
          ),
          const Gap(AppSpacing.xxl),
          MenuGroup(
            children: [
              MenuTile(
                icon: Icons.logout_rounded,
                title: 'Se déconnecter',
                subtitle: 'Ferme toutes vos sessions',
                destructive: true,
                trailing: const SizedBox.shrink(),
                onTap: () => _logout(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _hostLabel(String url) => url.replaceFirst(RegExp(r'^https?://'), '');

/// Carte du compte : avatar, email, date de création.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(label: user.email, size: 52),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleMedium,
                    ),
                    const Gap(6),
                    user.isActive
                        ? const Pill(
                            'Compte actif',
                            icon: Icons.check_rounded,
                            color: AppColors.success,
                            dense: true,
                          )
                        : const Pill('Compte désactivé', color: AppColors.danger, dense: true),
                  ],
                ),
              ),
            ],
          ),
          if (user.createdAt != null) ...[
            const Gap(12),
            const Divider(),
            const Gap(4),
            InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Compte créé le',
              value: Fmt.date(user.createdAt),
            ),
          ],
        ],
      ),
    );
  }
}

/// Carte du serveur : adresse, état de l'API, de PostgreSQL et de Redis.
class _ServerCard extends ConsumerWidget {
  const _ServerCard({required this.serverUrl});

  final String serverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final health = ref.watch(serverHealthProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_outlined, size: 20, color: AppColors.textSecondary),
              const Gap(12),
              Expanded(
                child: SelectableText(_hostLabel(serverUrl), maxLines: 1, style: theme.titleSmall),
              ),
              if (serverUrl.startsWith('https://'))
                const Pill('HTTPS', icon: Icons.lock_outline_rounded, dense: true)
              else
                const Pill('HTTP', color: AppColors.warning, dense: true),
            ],
          ),
          const Gap(14),
          const Divider(),
          const Gap(12),
          _HealthStatus(health: health),
          if (!serverUrl.startsWith('https://')) ...[
            const Gap(12),
            Text(
              'Connexion non chiffrée : à réserver au réseau local. '
              'En production, servez l\'API en HTTPS.',
              style: theme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthStatus extends StatelessWidget {
  const _HealthStatus({required this.health});

  final AsyncValue<ServerHealth> health;

  @override
  Widget build(BuildContext context) {
    if (health.isLoading) {
      return const _StatusLine(label: 'Vérification du serveur...', loading: true);
    }
    final value = health.value;
    if (health.hasError || value == null) {
      final error = health.error;
      return _StatusLine(
        color: AppColors.danger,
        label: 'Serveur injoignable',
        detail: error == null ? null : ApiException.describe(error),
      );
    }
    final latency = value.latency == null ? '' : ' · ${value.latency!.inMilliseconds} ms';
    Widget check(String label, bool ok) => Pill(
      label,
      icon: ok ? Icons.check_rounded : Icons.close_rounded,
      color: ok ? AppColors.success : AppColors.danger,
      dense: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusLine(
          color: value.ready ? AppColors.success : AppColors.warning,
          label: value.ready ? 'Serveur opérationnel$latency' : 'Serveur dégradé$latency',
        ),
        const Gap(10),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [check('PostgreSQL', value.database), check('Redis', value.redis)],
          ),
        ),
      ],
    );
  }
}

/// Ligne d'état : pastille colorée (ou chargement), libellé, détail.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    this.color = AppColors.textTertiary,
    this.detail,
    this.loading = false,
  });

  final String label;
  final Color color;
  final String? detail;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: loading
                ? const SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.bodyMedium),
              if (detail != null)
                Text(detail!, style: theme.bodySmall?.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }
}
