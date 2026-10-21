import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceradar/features/offers/data/offer_models.dart';
import 'package:freelanceradar/features/sources/data/source_models.dart';

/// Réponses calquées sur les schémas du backend (`OfferRead`, `SourceRead`, ...).
const offerJson = <String, dynamic>{
  'id': 12,
  'source_id': 3,
  'external_id': 'https://jobs.example.com/remote-jobs/acme-fastapi',
  'url': 'https://jobs.example.com/remote-jobs/acme-fastapi',
  'title': 'Acme Fictive: Développeur FastAPI senior',
  'company': null,
  'description': 'Mission FastAPI & PostgreSQL.\nPython 3.12',
  'location': 'Anywhere in the World',
  'mission_type': null,
  'category': 'Back-End Programming',
  'budget_min': '500.00',
  'budget_max': '800.00',
  'currency': 'EUR',
  'skills': <String>[],
  'published_at': '2026-10-19T08:30:00Z',
  'collected_at': '2026-10-21T07:40:29Z',
  'relevance_score': null,
  'ai_summary': null,
  'status': 'favorite',
  'notes': '  ',
  'archived_at': null,
};

const sourceJson = <String, dynamic>{
  'id': 3,
  'name': 'We Work Remotely - Full Stack & Mobile (RSS)',
  'category': 'Remote International',
  'url': 'https://weworkremotely.com/categories/remote-full-stack-programming-jobs.rss',
  'target_type': 'rss',
  'frequency_minutes': 30,
  'is_active': true,
  'keywords': ['fullstack', 'python'],
  'selectors': <String, dynamic>{},
  'health_status': 'ok',
  'last_attempt_at': '2026-10-21T07:40:27Z',
  'last_success_at': '2026-10-21T07:40:29Z',
  'last_error': null,
  'offers_count': 75,
  'error_count': 0,
  'consecutive_failures': 0,
  'created_at': '2026-10-21T07:39:00Z',
  'updated_at': '2026-10-21T07:40:29Z',
};

void main() {
  group('Offer', () {
    test('lit une offre du serveur (montants en chaîne, champs vides)', () {
      final offer = Offer.fromJson(offerJson);
      expect(offer.id, 12);
      expect(offer.sourceId, 3);
      expect(offer.status, OfferStatus.favorite);
      expect(offer.budgetMin, 500);
      expect(offer.budgetMax, 800);
      expect(offer.hasBudget, isTrue);
      expect(offer.company, isNull);
      expect(offer.hasNotes, isFalse, reason: 'des espaces ne sont pas une note');
      expect(offer.isArchived, isFalse);
      expect(offer.displayDate, DateTime.utc(2026, 10, 19, 8, 30).toLocal());
    });

    test('statut inconnu : repli sur « Nouvelle »', () {
      expect(OfferStatus.fromApi('bogus'), OfferStatus.newOffer);
      expect(OfferStatus.userSettable, isNot(contains(OfferStatus.applicationSent)));
    });
  });

  group('OfferFilters', () {
    test('paramètres envoyés à GET /offers', () {
      final filters = OfferFilters(
        search: ' fastapi ',
        sourceId: 3,
        status: OfferStatus.relevant,
        publishedAfter: DateTime.utc(2026, 10, 14),
        includeArchived: true,
        sort: OfferSort.publishedDesc,
      );
      expect(filters.toQuery(), {
        'q': 'fastapi',
        'source_id': 3,
        'status': 'relevant',
        'published_after': DateTime.utc(2026, 10, 14),
        'include_archived': true,
        'sort': '-published_at',
      });
      expect(filters.activeCount, 4);
    });

    test('recherche d\'un seul caractère non envoyée (minimum serveur : 2)', () {
      const filters = OfferFilters(search: 'a');
      expect(filters.hasSearch, isFalse);
      expect(filters.toQuery().containsKey('q'), isFalse);
      expect(filters.toQuery()['sort'], '-collected_at');
    });

    test('égalité (clé de rechargement de la liste)', () {
      expect(const OfferFilters(sourceId: 1), const OfferFilters(sourceId: 1));
      expect(const OfferFilters(sourceId: 1).copyWith(sourceId: () => null), const OfferFilters());
    });
  });

  group('Source', () {
    test('lit une source du serveur', () {
      final source = Source.fromJson(sourceJson);
      expect(source.type, SourceType.rss);
      expect(source.hasConnector, isTrue);
      expect(source.health, SourceHealth.ok);
      expect(source.offersCount, 75);
      expect(source.keywords, ['fullstack', 'python']);
      expect(source.copyWith(isActive: false).isActive, isFalse);
    });

    test('type sans connecteur et santé inconnue', () {
      final source = Source.fromJson({
        ...sourceJson,
        'target_type': 'playwright',
        'health_status': 'blocked',
      });
      expect(source.hasConnector, isFalse);
      expect(source.health, SourceHealth.blocked);
      expect(SourceType.fromApi('api'), SourceType.restApi);
      expect(SourceHealth.fromApi(null), SourceHealth.unknown);
    });

    test('SourceInput : corps de POST /sources', () {
      const input = SourceInput(
        name: '  Remotive ',
        category: ' ',
        url: 'https://remotive.com/remote-jobs/feed ',
        type: SourceType.rss,
        frequencyMinutes: 360,
        isActive: false,
        keywords: ['python'],
      );
      expect(input.toJson(), {
        'name': 'Remotive',
        'category': null,
        'url': 'https://remotive.com/remote-jobs/feed',
        'target_type': 'rss',
        'frequency_minutes': 360,
        'is_active': false,
        'keywords': ['python'],
        'selectors': <String, dynamic>{},
      });
    });
  });

  test('CollectionRun : durée et libellés', () {
    final run = CollectionRun.fromJson({
      'id': 4,
      'source_id': 3,
      'trigger': 'schedule',
      'status': 'success',
      'task_id': 'abc',
      'started_at': '2026-10-21T07:40:27Z',
      'finished_at': '2026-10-21T07:40:29Z',
      'items_seen': 76,
      'items_new': 75,
      'items_duplicate': 1,
      'items_invalid': 0,
      'error_message': null,
    });
    expect(run.status, RunStatus.success);
    expect(run.triggerLabel, 'Planifiée');
    expect(run.duration, const Duration(seconds: 2));
    expect(run.isRunning, isFalse);
  });

  test('SourceTestResult', () {
    final result = SourceTestResult.fromJson({
      'ok': false,
      'items_found': 0,
      'valid_items': 0,
      'sample_titles': <String>[],
      'error': 'Accès refusé par la plateforme (HTTP 403).',
    });
    expect(result.ok, isFalse);
    expect(result.error, contains('403'));
  });
}
