import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/application_models.dart';
import 'data/applications_repository.dart';
import 'data/reply_models.dart';

/// Dernière candidature modifiée (rapport, détail d'offre) à répercuter sur les autres écrans.
class ApplicationChangesNotifier extends Notifier<Application?> {
  @override
  Application? build() => null;

  void emit(Application application) => state = application;
}

final applicationChangesProvider = NotifierProvider<ApplicationChangesNotifier, Application?>(
  ApplicationChangesNotifier.new,
);

/// Détail d'une candidature, avec ses actions. Relu toutes les 5 s pendant la rédaction.
class ApplicationDetailNotifier extends AsyncNotifier<Application> {
  ApplicationDetailNotifier(this.applicationId);

  static const pollInterval = Duration(seconds: 5);

  final int applicationId;
  Timer? _poll;

  ApplicationsRepository get _repo => ref.read(applicationsRepositoryProvider);

  @override
  Future<Application> build() async {
    ref.onDispose(() => _poll?.cancel());
    final application = await ref.watch(applicationsRepositoryProvider).get(applicationId);
    _schedulePoll(application);
    return application;
  }

  void _schedulePoll(Application application) {
    _poll?.cancel();
    if (application.status != ApplicationStatus.generating) return;
    _poll = Timer(pollInterval, () async {
      if (!ref.mounted) return;
      try {
        _set(await _repo.get(applicationId));
      } catch (_) {
        _schedulePoll(application); // hors ligne : on réessaie au prochain cycle
      }
    });
  }

  void _set(Application application) {
    if (!ref.mounted) return;
    state = AsyncData(application);
    ref.read(applicationChangesProvider.notifier).emit(application);
    _schedulePoll(application);
  }

  Future<void> reload() async => _set(await _repo.get(applicationId));

  Future<Application> save({
    required String recipientEmail,
    required String subject,
    required String message,
  }) => _apply(
    () => _repo.update(
      applicationId,
      recipientEmail: recipientEmail,
      subject: subject,
      message: message,
    ),
  );

  Future<Application> regenerate() => _apply(() => _repo.regenerate(applicationId));

  Future<Application> send() => _apply(() => _repo.send(applicationId));

  Future<Application> cancel() => _apply(() => _repo.cancel(applicationId));

  Future<Application> _apply(Future<Application> Function() action) async {
    final updated = await action();
    _set(updated);
    return updated;
  }
}

final applicationDetailProvider = AsyncNotifierProvider.autoDispose
    .family<ApplicationDetailNotifier, Application, int>(ApplicationDetailNotifier.new);

/// Candidature existante pour une offre (null s'il n'y en a pas).
final applicationForOfferProvider = FutureProvider.autoDispose.family<Application?, int>((
  ref,
  offerId,
) async {
  final page = await ref.watch(applicationsRepositoryProvider).list(offerId: offerId, pageSize: 1);
  return page.items.isEmpty ? null : page.items.first;
});

/// Compteurs du rapport : total par statut (`GET /applications?status=…&page_size=1`).
class ApplicationCounts {
  const ApplicationCounts({required this.sent, required this.pending, required this.failed});

  final int sent;
  final int pending;
  final int failed;
}

final applicationCountsProvider = FutureProvider.autoDispose<ApplicationCounts>((ref) async {
  final repo = ref.watch(applicationsRepositoryProvider);
  Future<int> count(ApplicationStatus status) async =>
      (await repo.list(status: status, pageSize: 1)).total;
  final counts = await Future.wait([
    count(ApplicationStatus.sent),
    count(ApplicationStatus.pendingApproval),
    count(ApplicationStatus.failed),
    count(ApplicationStatus.deliveryUnknown),
    count(ApplicationStatus.generationFailed),
  ]);
  return ApplicationCounts(
    sent: counts[0],
    pending: counts[1],
    failed: counts[2] + counts[3] + counts[4],
  );
});

/// Candidatures à valider (aperçu du rapport).
final pendingApplicationsProvider = FutureProvider.autoDispose<List<Application>>((ref) async {
  final page = await ref
      .watch(applicationsRepositoryProvider)
      .list(status: ApplicationStatus.pendingApproval, pageSize: 10);
  return page.items;
});

/// Dernières réponses reçues (rapport).
final latestRepliesProvider = FutureProvider.autoDispose<List<Reply>>((ref) async {
  final page = await ref.watch(applicationsRepositoryProvider).replies(pageSize: 10);
  return page.items;
});

/// Réponses reçues pour une candidature.
final applicationRepliesProvider = FutureProvider.autoDispose.family<List<Reply>, int>((
  ref,
  applicationId,
) async {
  final page = await ref
      .watch(applicationsRepositoryProvider)
      .replies(applicationId: applicationId, pageSize: 50);
  return page.items;
});
