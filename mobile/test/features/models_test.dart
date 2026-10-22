import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceradar/features/applications/data/application_models.dart';
import 'package:freelanceradar/features/applications/data/reply_models.dart';
import 'package:freelanceradar/features/notifications/data/notification_models.dart';
import 'package:freelanceradar/features/offers/data/offer_models.dart';
import 'package:freelanceradar/features/profile/data/profile_models.dart';
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

const profileJson = <String, dynamic>{
  'id': 1,
  'full_name': 'Jane Dev',
  'professional_title': 'Développeuse Python / Flutter',
  'summary': null,
  'primary_email': 'dev@example.com',
  'secondary_emails': <String>[],
  'phone': null,
  'location': 'Antananarivo',
  'portfolio_url': null,
  'github_url': 'https://github.com/janedev',
  'linkedin_url': null,
  'preferred_languages': ['fr', 'en'],
  'availability': 'partially_available',
  'available_from': '2026-11-01',
  'default_rate': '450.00',
  'rate_unit': 'day',
  'minimum_budget': null,
  'currency': 'EUR',
  'contract_types': ['freelance', 'unknown'],
  'accepted_locations': ['Remote'],
  'accepted_timezones': <String>[],
  'included_keywords': ['fastapi'],
  'excluded_keywords': <String>[],
  'created_at': '2026-10-21T08:00:00Z',
  'updated_at': '2026-10-21T08:00:00Z',
};

const skillJson = <String, dynamic>{
  'id': 1,
  'name': 'FastAPI',
  'category': 'Backend',
  'proficiency_level': 'advanced',
  'years_experience': '3.5',
  'aliases': ['fast-api'],
  'created_at': '2026-10-21T08:00:00Z',
  'updated_at': '2026-10-21T08:00:00Z',
};

const notificationJson = <String, dynamic>{
  'id': 1,
  'type': 'new_offers',
  'title': 'Nouvelles offres',
  'body': '2 nouvelles offres — We Work Remotely',
  'offer_id': null,
  'source_id': 3,
  'collection_run_id': 4,
  'created_at': '2026-10-21T08:30:00Z',
  'read_at': null,
};

const applicationJson = <String, dynamic>{
  'id': 7,
  'offer_id': 12,
  'offer_title': 'Acme Fictive: Développeur FastAPI senior',
  'offer_url': 'https://jobs.example.com/remote-jobs/acme-fastapi',
  'status': 'pending_approval',
  'recipient_email': null,
  'subject': 'Candidature — Développeur FastAPI',
  'message': 'Bonjour,\n\nVotre mission correspond à mon profil.\n\nJane Dev',
  'language': 'fr',
  'generated_subject': 'Candidature — Développeur FastAPI',
  'generated_message': 'Bonjour,\n\nVotre mission correspond à mon profil.\n\nJane Dev',
  'referenced_skills': ['FastAPI'],
  'ai_warnings': ['Budget non indiqué'],
  'ai_confidence': 0.8,
  'ai_provider': 'gemini',
  'ai_model': 'gemini-3.8-flash',
  'generated_at': '2026-10-21T10:00:00Z',
  'generation_count': 1,
  'send_attempts': 0,
  'sent_at': null,
  'sent_from': null,
  'sent_to': null,
  'sent_subject': null,
  'sent_message': null,
  'error_message': null,
  'created_at': '2026-10-21T10:00:00Z',
  'updated_at': '2026-10-21T10:00:00Z',
};

void main() {
  group('Application', () {
    test('lit une candidature du serveur', () {
      final application = Application.fromJson(applicationJson);
      expect(application.status, ApplicationStatus.pendingApproval);
      expect(application.offerTitle, startsWith('Acme'));
      expect(application.aiConfidence, 0.8);
      expect(application.isEdited, isFalse);
    });

    test('règles de statut identiques au serveur', () {
      expect(ApplicationStatus.pendingApproval.isSendable, isTrue);
      expect(ApplicationStatus.failed.isSendable, isTrue);
      expect(ApplicationStatus.deliveryUnknown.isSendable, isFalse);
      expect(ApplicationStatus.sent.isEditable, isFalse);
      expect(ApplicationStatus.sent.canCancel, isFalse);
      expect(ApplicationStatus.fromApi('delivery_unknown'), ApplicationStatus.deliveryUnknown);
      expect(ApplicationStatus.replied.canCancel, isFalse);
      expect(ApplicationStatus.replied.isSendable, isFalse);
    });

    test('Reply', () {
      final reply = Reply.fromJson({
        'id': 3,
        'application_id': 7,
        'offer_title': 'Offre',
        'from_address': 'client@example.org',
        'from_name': null,
        'subject': 'Re: Candidature',
        'body_text': 'Merci',
        'received_at': '2026-10-21T12:00:00Z',
        'created_at': '2026-10-21T12:01:00Z',
        'read_at': null,
        'match_method': 'headers',
      });
      expect(reply.sender, 'client@example.org');
      expect(reply.isRead, isFalse);
    });
  });
  group('Profile', () {
    test('lit le profil du serveur (montant en chaîne, date seule, type inconnu ignoré)', () {
      final profile = Profile.fromJson(profileJson);
      expect(profile.availability, Availability.partiallyAvailable);
      expect(profile.defaultRate, 450);
      expect(profile.availableFrom, DateTime(2026, 11));
      expect(profile.contractTypes, [ContractType.freelance]);
      expect(profile.missingFields(skillCount: 2), ['présentation']);
    });

    test('corps de PATCH /profile : textes vides pour effacer, date au format API', () {
      final json = Profile.fromJson(profileJson).toUpdateJson();
      expect(json['summary'], '');
      expect(json['available_from'], '2026-11-01');
      expect(json['contract_types'], ['freelance']);
      expect(json['default_rate'], 450);
      expect(json.containsKey('id'), isFalse);
    });

    test('complétude', () {
      const empty = Profile(id: 1);
      expect(empty.completion(skillCount: 0), 0);
      expect(Profile.fromJson(profileJson).completion(skillCount: 2), 88);
    });
  });

  group('Skill', () {
    test('lecture et corps envoyé (une décimale au plus)', () {
      final skill = Skill.fromJson(skillJson);
      expect(skill.level, SkillLevel.advanced);
      expect(skill.yearsExperience, 3.5);
      const input = SkillInput(
        name: ' Go ',
        level: SkillLevel.expert,
        category: ' ',
        yearsExperience: 1.26,
      );
      expect(input.toJson(), {
        'name': 'Go',
        'category': null,
        'proficiency_level': 'expert',
        'years_experience': 1.3,
        'aliases': <String>[],
      });
    });

    test('yearsLabel', () {
      expect(yearsLabel(1), '1 an');
      expect(yearsLabel(3), '3 ans');
      expect(yearsLabel(2.5), '2,5 ans');
      expect(yearsLabel(0.5), '6 mois');
    });
  });

  test('AppNotification', () {
    final notification = AppNotification.fromJson(notificationJson);
    expect(notification.type, NotificationType.newOffers);
    expect(notification.isRead, isFalse);
    expect(notification.sourceId, 3);
    expect(NotificationType.fromApi('bogus'), isNull);
  });

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
      expect(filters.toQuery()['sort'], '-published_at'); // tri par défaut
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
