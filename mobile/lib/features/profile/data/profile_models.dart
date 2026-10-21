import '../../../core/utils/json.dart';

/// Disponibilité (`availability`).
enum Availability {
  available('available', 'Disponible'),
  partiallyAvailable('partially_available', 'Partiellement disponible'),
  unavailable('unavailable', 'Indisponible');

  const Availability(this.api, this.label);

  final String api;
  final String label;

  static Availability fromApi(Object? value) =>
      values.firstWhere((a) => a.api == value, orElse: () => available);
}

/// Unité du tarif par défaut (`rate_unit`).
enum RateUnit {
  day('day', 'jour', 'TJM'),
  hour('hour', 'heure', 'Taux horaire');

  const RateUnit(this.api, this.label, this.title);

  final String api;
  final String label;
  final String title;

  static RateUnit fromApi(Object? value) =>
      values.firstWhere((u) => u.api == value, orElse: () => day);
}

/// Types de missions recherchées (`contract_types`).
enum ContractType {
  freelance('freelance', 'Freelance (régie)'),
  fixedPrice('fixed_price', 'Forfait'),
  partTime('part_time', 'Temps partiel'),
  fullTime('full_time', 'Temps plein');

  const ContractType(this.api, this.label);

  final String api;
  final String label;

  static ContractType? fromApi(Object? value) {
    for (final type in values) {
      if (type.api == value) return type;
    }
    return null;
  }
}

/// Niveau de maîtrise d'une compétence (`proficiency_level`).
enum SkillLevel {
  beginner('beginner', 'Débutant', 1),
  intermediate('intermediate', 'Intermédiaire', 2),
  advanced('advanced', 'Avancé', 3),
  expert('expert', 'Expert', 4);

  const SkillLevel(this.api, this.label, this.rank);

  final String api;
  final String label;
  final int rank;

  static SkillLevel fromApi(Object? value) =>
      values.firstWhere((l) => l.api == value, orElse: () => intermediate);
}

/// Profil professionnel (`ProfileRead`).
class Profile {
  const Profile({
    required this.id,
    this.fullName,
    this.professionalTitle,
    this.summary,
    this.primaryEmail,
    this.secondaryEmails = const [],
    this.phone,
    this.location,
    this.portfolioUrl,
    this.githubUrl,
    this.linkedinUrl,
    this.preferredLanguages = const [],
    this.availability = Availability.available,
    this.availableFrom,
    this.defaultRate,
    this.rateUnit = RateUnit.day,
    this.minimumBudget,
    this.currency = 'EUR',
    this.contractTypes = const [],
    this.acceptedLocations = const [],
    this.acceptedTimezones = const [],
    this.includedKeywords = const [],
    this.excludedKeywords = const [],
    this.updatedAt,
  });

  final int id;
  final String? fullName;
  final String? professionalTitle;
  final String? summary;
  final String? primaryEmail;
  final List<String> secondaryEmails;
  final String? phone;
  final String? location;
  final String? portfolioUrl;
  final String? githubUrl;
  final String? linkedinUrl;
  final List<String> preferredLanguages;
  final Availability availability;
  final DateTime? availableFrom;
  final double? defaultRate;
  final RateUnit rateUnit;
  final double? minimumBudget;
  final String currency;
  final List<ContractType> contractTypes;
  final List<String> acceptedLocations;
  final List<String> acceptedTimezones;
  final List<String> includedKeywords;
  final List<String> excludedKeywords;
  final DateTime? updatedAt;

  /// Éléments utiles à une candidature encore absents (affichés comme « à compléter »).
  List<String> missingFields({required int skillCount}) => [
    if (_blank(fullName)) 'nom',
    if (_blank(professionalTitle)) 'titre',
    if (_blank(summary)) 'présentation',
    if (_blank(location)) 'localisation',
    if (preferredLanguages.isEmpty) 'langues',
    if (defaultRate == null) 'tarif',
    if (_blank(portfolioUrl) && _blank(githubUrl) && _blank(linkedinUrl)) 'liens',
    if (skillCount == 0) 'compétences',
  ];

  /// Complétude (0-100) calculée sur les 8 éléments de [missingFields].
  int completion({required int skillCount}) =>
      ((8 - missingFields(skillCount: skillCount).length) * 100 / 8).round();

  static bool _blank(String? value) => value == null || value.trim().isEmpty;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: parseInt(json['id']) ?? 0,
    fullName: _text(json['full_name']),
    professionalTitle: _text(json['professional_title']),
    summary: _text(json['summary']),
    primaryEmail: _text(json['primary_email']),
    secondaryEmails: parseStringList(json['secondary_emails']),
    phone: _text(json['phone']),
    location: _text(json['location']),
    portfolioUrl: _text(json['portfolio_url']),
    githubUrl: _text(json['github_url']),
    linkedinUrl: _text(json['linkedin_url']),
    preferredLanguages: parseStringList(json['preferred_languages']),
    availability: Availability.fromApi(json['availability']),
    // Date seule : pas de conversion de fuseau horaire.
    availableFrom: json['available_from'] is String
        ? DateTime.tryParse(json['available_from'] as String)
        : null,
    // Les montants (Decimal) arrivent sous forme de chaîne.
    defaultRate: parseDouble(json['default_rate']),
    rateUnit: RateUnit.fromApi(json['rate_unit']),
    minimumBudget: parseDouble(json['minimum_budget']),
    currency: json['currency']?.toString() ?? 'EUR',
    contractTypes: parseStringList(
      json['contract_types'],
    ).map(ContractType.fromApi).whereType<ContractType>().toList(),
    acceptedLocations: parseStringList(json['accepted_locations']),
    acceptedTimezones: parseStringList(json['accepted_timezones']),
    includedKeywords: parseStringList(json['included_keywords']),
    excludedKeywords: parseStringList(json['excluded_keywords']),
    updatedAt: parseDate(json['updated_at']),
  );

  /// Corps complet de `PATCH /profile` (les textes vides effacent la valeur côté serveur).
  Map<String, dynamic> toUpdateJson() => {
    'full_name': fullName ?? '',
    'professional_title': professionalTitle ?? '',
    'summary': summary ?? '',
    'primary_email': primaryEmail ?? '',
    'secondary_emails': secondaryEmails,
    'phone': phone ?? '',
    'location': location ?? '',
    'portfolio_url': portfolioUrl ?? '',
    'github_url': githubUrl ?? '',
    'linkedin_url': linkedinUrl ?? '',
    'preferred_languages': preferredLanguages,
    'availability': availability.api,
    'available_from': availableFrom == null ? null : formatApiDate(availableFrom!),
    'default_rate': defaultRate,
    'rate_unit': rateUnit.api,
    'minimum_budget': minimumBudget,
    'currency': currency,
    'contract_types': [for (final type in contractTypes) type.api],
    'accepted_locations': acceptedLocations,
    'accepted_timezones': acceptedTimezones,
    'included_keywords': includedKeywords,
    'excluded_keywords': excludedKeywords,
  };

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// Compétence du profil (`SkillRead`).
class Skill {
  const Skill({
    required this.id,
    required this.name,
    required this.level,
    this.category,
    this.yearsExperience,
    this.aliases = const [],
  });

  final int id;
  final String name;
  final String? category;
  final SkillLevel level;
  final double? yearsExperience;
  final List<String> aliases;

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: parseInt(json['id']) ?? 0,
    name: json['name']?.toString() ?? '',
    category: json['category']?.toString(),
    level: SkillLevel.fromApi(json['proficiency_level']),
    yearsExperience: parseDouble(json['years_experience']),
    aliases: parseStringList(json['aliases']),
  );
}

/// Champs d'une compétence (`SkillCreate` ; aussi utilisé pour `PATCH`).
class SkillInput {
  const SkillInput({
    required this.name,
    required this.level,
    this.category,
    this.yearsExperience,
    this.aliases = const [],
  });

  final String name;
  final String? category;
  final SkillLevel level;
  final double? yearsExperience;
  final List<String> aliases;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'category': category == null || category!.trim().isEmpty ? null : category!.trim(),
    'proficiency_level': level.api,
    // Une décimale au plus (règle du serveur).
    'years_experience': yearsExperience == null ? null : (yearsExperience! * 10).round() / 10,
    'aliases': aliases,
  };
}

/// `3 ans`, `1 an`, `6 mois`, `2,5 ans`.
String yearsLabel(double years) {
  if (years < 1) {
    final months = (years * 12).round();
    return months <= 1 ? '1 mois' : '$months mois';
  }
  final rounded = years == years.roundToDouble()
      ? years.round().toString()
      : years.toStringAsFixed(1).replaceAll('.', ',');
  return years == 1 ? '1 an' : '$rounded ans';
}

/// Compétences proposées à l'ajout (liste de `prompt.md` §2) : le niveau reste à choisir.
const suggestedSkills = [
  'Python',
  'Django',
  'Django REST Framework',
  'FastAPI',
  'Django-Ninja',
  'PHP',
  'Laravel',
  'React',
  'Next.js',
  'TypeScript',
  'Flutter',
  'Dart',
  'PostgreSQL',
  'MySQL',
  'Docker',
  'Linux',
  'Git',
  'CI/CD',
  'API REST',
  'Web scraping',
  'Playwright',
  'OCR',
  'Tesseract',
];

/// Catégories proposées (saisie libre possible).
const suggestedCategories = ['Backend', 'Frontend', 'Mobile', 'Data', 'DevOps', 'Outils'];
