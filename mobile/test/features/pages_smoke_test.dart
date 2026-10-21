import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceradar/core/auth/app_user.dart';
import 'package:freelanceradar/core/auth/auth_controller.dart';
import 'package:freelanceradar/core/config/app_config.dart';
import 'package:freelanceradar/core/network/paginated.dart';
import 'package:freelanceradar/core/theme/app_theme.dart';
import 'package:freelanceradar/core/widgets/feedback.dart';
import 'package:freelanceradar/features/dashboard/dashboard_page.dart';
import 'package:freelanceradar/features/notifications/data/notification_models.dart';
import 'package:freelanceradar/features/notifications/data/notifications_repository.dart';
import 'package:freelanceradar/features/notifications/notifications_page.dart';
import 'package:freelanceradar/features/notifications/notifications_providers.dart';
import 'package:freelanceradar/features/offers/data/offer_models.dart';
import 'package:freelanceradar/features/offers/data/offers_repository.dart';
import 'package:freelanceradar/features/offers/offer_detail_page.dart';
import 'package:freelanceradar/features/offers/offers_page.dart';
import 'package:freelanceradar/features/profile/data/profile_models.dart';
import 'package:freelanceradar/features/profile/data/profile_repository.dart';
import 'package:freelanceradar/features/profile/edit_profile_page.dart';
import 'package:freelanceradar/features/profile/profile_page.dart';
import 'package:freelanceradar/features/profile/skills_page.dart';
import 'package:freelanceradar/features/settings/settings_page.dart';
import 'package:freelanceradar/features/sources/data/source_models.dart';
import 'package:freelanceradar/features/sources/data/sources_repository.dart';
import 'package:freelanceradar/features/sources/source_detail_page.dart';
import 'package:freelanceradar/features/sources/sources_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models_test.dart';

/// Tests de fumée : les pages se construisent sans erreur de mise en page (téléphone et
/// grand écran), avec des dépôts factices. Aucun appel réseau.

final _offers = [
  Offer.fromJson({
    ...offerJson,
    'title': 'Développeur Full Stack Python / React avec un titre vraiment très long (H/F)',
    'description': 'Description complète.\n' * 40,
    'notes': 'Relancer lundi',
  }),
  Offer.fromJson({...offerJson, 'id': 13, 'status': 'new', 'budget_min': null, 'budget_max': null}),
];

final _sources = [
  Source.fromJson(sourceJson),
  Source.fromJson({
    ...sourceJson,
    'id': 4,
    'name': 'Upwork - RSS OCR & Python',
    'health_status': 'error',
    'last_error': 'Réponse HTTP 404.',
    'error_count': 2,
    'consecutive_failures': 2,
    'offers_count': 0,
  }),
  Source.fromJson({
    ...sourceJson,
    'id': 5,
    'name': 'Codeur.com',
    'target_type': 'playwright',
    'is_active': false,
    'health_status': 'unknown',
    'selectors': {'item': '.project-item'},
  }),
];

class _FakeOffers implements OffersRepository {
  @override
  Future<Paginated<Offer>> search(OfferFilters filters, {int page = 1, int pageSize = 20}) async =>
      Paginated(items: _offers, total: _offers.length, page: 1, pageSize: pageSize);

  @override
  Future<Offer> get(int id) async => _offers.firstWhere((o) => o.id == id);

  @override
  Future<Offer> setStatus(int id, OfferStatus status) async => get(id);

  @override
  Future<Offer> setNotes(int id, String notes) async => get(id);

  @override
  Future<Offer> archive(int id) async => get(id);
}

class _FakeSources implements SourcesRepository {
  @override
  Future<Paginated<Source>> sources({
    int page = 1,
    int pageSize = 50,
    bool? isActive,
    SourceType? type,
  }) async => Paginated(items: _sources, total: _sources.length, page: 1, pageSize: pageSize);

  @override
  Future<Source> source(int id) async => _sources.firstWhere((s) => s.id == id);

  @override
  Future<Paginated<CollectionRun>> runs(int sourceId, {int page = 1, int pageSize = 20}) async =>
      Paginated(
        items: [
          CollectionRun.fromJson({
            'id': 1,
            'source_id': sourceId,
            'trigger': 'manual',
            'status': 'failed',
            'started_at': '2026-10-21T07:40:27Z',
            'finished_at': '2026-10-21T07:40:28Z',
            'items_seen': 0,
            'items_new': 0,
            'items_duplicate': 0,
            'items_invalid': 0,
            'error_message': 'Réponse HTTP 404.',
          }),
        ],
        total: 1,
        page: 1,
        pageSize: pageSize,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeProfile implements ProfileRepository {
  Profile profile = Profile.fromJson(profileJson);
  final skills = [
    Skill.fromJson(skillJson),
    Skill.fromJson({...skillJson, 'id': 2, 'name': 'Flutter', 'category': null}),
  ];
  Map<String, dynamic>? lastUpdate;

  @override
  Future<Profile> getProfile() async => profile;

  @override
  Future<Profile> updateProfile(Map<String, dynamic> changes) async {
    lastUpdate = changes;
    return profile = Profile.fromJson({...profileJson, ...changes});
  }

  @override
  Future<List<Skill>> listSkills() async => skills;

  @override
  Future<Skill> createSkill(SkillInput input) async => skills.first;

  @override
  Future<Skill> updateSkill(int id, SkillInput input) async => skills.first;

  @override
  Future<void> deleteSkill(int id) async {}
}

class _FakeNotifications implements NotificationsRepository {
  @override
  Future<Paginated<AppNotification>> list({
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
    NotificationType? type,
  }) async {
    final items = [
      AppNotification.fromJson(notificationJson),
      AppNotification.fromJson({
        ...notificationJson,
        'id': 2,
        'type': 'source_error',
        'title': 'Source en erreur',
        'body': 'Upwork - RSS OCR & Python : Réponse HTTP 404.',
        'read_at': '2026-10-21T09:00:00Z',
      }),
    ];
    return Paginated(items: items, total: items.length, page: 1, pageSize: pageSize);
  }

  @override
  Future<int> unreadCount() async => 1;

  @override
  Future<AppNotification> markRead(int id) async => AppNotification.fromJson(notificationJson);

  @override
  Future<int> markAllRead() async => 1;
}

/// Compteur fixe : pas de minuteur de rafraîchissement pendant les tests.
class _FixedUnread extends UnreadCountNotifier {
  @override
  int build() => 1;
}

late _FakeProfile _profileRepo;
late SharedPreferences _prefs;

Future<void> _pump(WidgetTester tester, Widget page, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        currentUserProvider.overrideWithValue(
          const AppUser(id: 1, email: 'dev@example.com', isActive: true),
        ),
        offersRepositoryProvider.overrideWithValue(_FakeOffers()),
        sourcesRepositoryProvider.overrideWithValue(_FakeSources()),
        profileRepositoryProvider.overrideWithValue(_profileRepo),
        notificationsRepositoryProvider.overrideWithValue(_FakeNotifications()),
        unreadCountProvider.overrideWith(_FixedUnread.new),
        serverHealthProvider.overrideWith(
          (ref) async => const ServerHealth(ready: true, database: true, redis: false),
        ),
      ],
      child: MaterialApp(theme: AppTheme.dark, scaffoldMessengerKey: rootMessengerKey, home: page),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  setUp(() => _profileRepo = _FakeProfile());

  for (final (label, size) in [('téléphone', Size(390, 844)), ('grand écran', Size(1280, 800))]) {
    testWidgets('DashboardPage ($label)', (tester) async {
      await _pump(tester, const DashboardPage(), size: size);
      // Les titres de section sont affichés en majuscules.
      expect(find.text('DERNIÈRES OFFRES'), findsOneWidget);
      expect(find.text('Sources en erreur'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OffersPage ($label)', (tester) async {
      await _pump(tester, const OffersPage(), size: size);
      expect(find.text('2 offres'), findsOneWidget);
      expect(find.text('Favorite'), findsOneWidget);
      await tester.tap(find.text('Filtres').first);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Publiées depuis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OfferDetailPage ($label)', (tester) async {
      await _pump(tester, const OfferDetailPage(offerId: 12), size: size);
      expect(find.text('Relancer lundi'), findsOneWidget);
      expect(find.text('Changer le statut'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SourcesPage ($label)', (tester) async {
      await _pump(tester, const SourcesPage(), size: size);
      expect(find.text('3 sources'), findsOneWidget);
      expect(find.text('Réponse HTTP 404.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SourceDetailPage : source sans connecteur ($label)', (tester) async {
      await _pump(tester, const SourceDetailPage(sourceId: 5), size: size);
      expect(find.textContaining('pas encore de connecteur'), findsOneWidget);
      // En bas d'une liste construite à la demande : on fait défiler jusqu'à l'historique.
      await tester.scrollUntilVisible(
        find.text('DERNIÈRES COLLECTES'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Réponse HTTP 404.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SettingsPage ($label)', (tester) async {
      await _pump(tester, const SettingsPage(), size: size);
      expect(find.text('dev@example.com'), findsOneWidget);
      expect(find.text('Serveur dégradé'), findsNothing);
      expect(find.text('PostgreSQL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NotificationsPage ($label)', (tester) async {
      await _pump(tester, const NotificationsPage(), size: size);
      expect(find.text('2 notifications'), findsOneWidget);
      expect(find.text('2 nouvelles offres — We Work Remotely'), findsOneWidget);
      expect(find.byTooltip('Tout marquer comme lu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfilePage ($label)', (tester) async {
      await _pump(tester, const ProfilePage(), size: size);
      expect(find.text('Jane Dev'), findsOneWidget);
      expect(find.text('2 compétences'), findsOneWidget);
      expect(find.text('450 EUR / jour'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SkillsPage et feuille d\'ajout ($label)', (tester) async {
      await _pump(tester, const SkillsPage(), size: size);
      expect(find.text('FastAPI'), findsOneWidget);
      expect(find.text('BACKEND'), findsOneWidget);
      expect(find.text('AUTRES'), findsOneWidget);
      await tester.tap(find.text('Ajouter'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Ajouter une compétence'), findsOneWidget);
      // Les compétences déjà présentes ne sont pas suggérées.
      expect(find.widgetWithText(ActionChip, 'Python'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Flutter'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('EditProfilePage : enregistre le profil complet', (tester) async {
    await _pump(tester, const EditProfilePage());
    await tester.enterText(find.widgetWithText(TextFormField, 'Jane Dev'), 'Jane Rakoto');
    await tester.tap(find.text('Enregistrer'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final sent = _profileRepo.lastUpdate!;
    expect(sent['full_name'], 'Jane Rakoto');
    expect(sent['preferred_languages'], ['fr', 'en']);
    expect(sent['default_rate'], 450);
    expect(sent['contract_types'], ['freelance']);
    expect(tester.takeException(), isNull);
  });
}
