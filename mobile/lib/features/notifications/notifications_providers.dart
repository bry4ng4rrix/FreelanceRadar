import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import 'data/notifications_repository.dart';

/// Nombre de notifications non lues (badge de l'onglet « Alertes »).
///
/// Pas encore de push (FCM) : le compteur est relu au démarrage, au retour de l'application
/// au premier plan, toutes les [pollInterval] tant qu'elle est ouverte, et après chaque action.
class UnreadCountNotifier extends Notifier<int> {
  static const pollInterval = Duration(seconds: 60);

  @override
  int build() {
    if (!ref.watch(authControllerProvider.select((auth) => auth.isSignedIn))) return 0;
    final timer = Timer.periodic(pollInterval, (_) => refresh());
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      timer.cancel();
      lifecycle.dispose();
    });
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    try {
      final count = await ref.read(notificationsRepositoryProvider).unreadCount();
      if (ref.mounted) state = count;
    } catch (_) {
      // Hors ligne ou serveur indisponible : on garde la dernière valeur connue.
    }
  }

  /// Mise à jour locale immédiate (notification lue, tout marquer comme lu).
  void set(int count) => state = count < 0 ? 0 : count;
}

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);
