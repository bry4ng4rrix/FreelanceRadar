import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/notifications_providers.dart';
import '../theme/app_colors.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Accueil', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  _Destination('Offres', Icons.work_outline_rounded, Icons.work_rounded),
  _Destination('Alertes', Icons.notifications_none_rounded, Icons.notifications_rounded),
  _Destination('Rapport', Icons.insights_outlined, Icons.insights_rounded),
  _Destination('Profil', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Index de l'onglet « Alertes » (badge des notifications non lues).
const _alertsIndex = 2;

/// Coquille de navigation : barre du bas (mobile) ou rail latéral (écran large, Linux).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const wideBreakpoint = 840.0;

  void _go(WidgetRef ref, int index) {
    // Ouvrir les alertes relit le compteur sans attendre le prochain cycle.
    if (index == _alertsIndex) ref.read(unreadCountProvider.notifier).refresh();
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    Widget icon(int index, {required bool selected}) {
      final destination = _destinations[index];
      final widget = Icon(selected ? destination.selectedIcon : destination.icon);
      if (index != _alertsIndex || unread == 0) return widget;
      return Badge.count(count: unread, child: widget);
    }

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => _go(ref, index),
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.9,
                leading: const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 24),
                  child: _Logo(),
                ),
                destinations: [
                  for (var i = 0; i < _destinations.length; i++)
                    NavigationRailDestination(
                      icon: icon(i, selected: false),
                      selectedIcon: icon(i, selected: true),
                      label: Text(_destinations[i].label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => _go(ref, index),
          destinations: [
            for (var i = 0; i < _destinations.length; i++)
              NavigationDestination(
                icon: icon(i, selected: false),
                selectedIcon: icon(i, selected: true),
                label: _destinations[i].label,
              ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: AppColors.textPrimary,
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: const Text(
      'F',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onAccent),
    ),
  );
}
