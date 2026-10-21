import 'package:dio/dio.dart';

/// Erreur renvoyée par l'API FreelanceRadar (format `{"error": {code, message, details}}`)
/// ou erreur réseau. [userMessage] est le texte à afficher (en français).
///
/// Codes du serveur : `http_<statut>` (ex. `http_401`, `http_409`), `validation_error`,
/// `internal_error`. Les messages du serveur sont déjà en français.
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode, this.details});

  final int? statusCode;
  final String code;
  final String message;
  final Object? details;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isNetwork => code == 'NETWORK_ERROR' || code == 'TIMEOUT';

  /// Message lisible pour l'utilisateur.
  String get userMessage {
    final known = _messages[code];
    if (known != null) return known;
    if (code == 'validation_error') {
      final fields = fieldErrors;
      if (fields.isNotEmpty) {
        return fields.entries
            .map((e) => e.key.isEmpty ? e.value : '${e.key} : ${e.value}')
            .join('\n');
      }
      return 'Données invalides.';
    }
    if (statusCode != null && statusCode! >= 500) return 'Erreur du serveur. Réessayez plus tard.';
    return message.isNotEmpty ? message : 'Une erreur est survenue.';
  }

  /// Erreurs de validation par champ (`details: [{loc: ["body", "name"], msg, type}]`).
  Map<String, String> get fieldErrors {
    final result = <String, String>{};
    final raw = details;
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final loc = item['loc'];
        final field = loc is List && loc.isNotEmpty && loc.last is String
            ? loc.last as String
            : '';
        final label = _fieldLabels[field] ?? field;
        final text = item['msg']?.toString() ?? 'Valeur invalide';
        result[label] = text.replaceFirst('Value error, ', '');
      }
    }
    return result;
  }

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;
    if (data is Map && data['error'] is Map) {
      final body = data['error'] as Map;
      return ApiException(
        statusCode: response?.statusCode,
        code: body['code']?.toString() ?? 'ERROR',
        message: body['message']?.toString() ?? '',
        details: body['details'],
      );
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          code: 'TIMEOUT',
          message: 'Le serveur met trop de temps à répondre.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          code: 'NETWORK_ERROR',
          message: 'Impossible de joindre le serveur.',
        );
      case DioExceptionType.cancel:
        return const ApiException(code: 'CANCELLED', message: 'Requête annulée.');
      case DioExceptionType.badCertificate:
        return const ApiException(
          code: 'BAD_CERTIFICATE',
          message: 'Certificat du serveur invalide.',
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return ApiException(
          statusCode: response?.statusCode,
          code: response == null ? 'NETWORK_ERROR' : 'http_${response.statusCode}',
          message: response == null
              ? 'Impossible de joindre le serveur.'
              : 'Erreur HTTP ${response.statusCode}.',
        );
    }
  }

  /// Convertit n'importe quelle erreur en message lisible.
  static String describe(Object error) {
    if (error is ApiException) return error.userMessage;
    if (error is DioException) return ApiException.fromDio(error).userMessage;
    return 'Une erreur inattendue est survenue.';
  }

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';

  static const _messages = <String, String>{
    'NETWORK_ERROR':
        'Impossible de joindre le serveur. Vérifiez votre connexion et l\'adresse du serveur.',
    'TIMEOUT': 'Le serveur met trop de temps à répondre.',
    'internal_error': 'Erreur du serveur. Réessayez plus tard.',
  };

  /// Noms de champs de l'API traduits pour les messages de validation.
  static const _fieldLabels = <String, String>{
    'name': 'Nom',
    'url': 'Adresse',
    'target_type': 'Type',
    'frequency_minutes': 'Fréquence',
    'keywords': 'Mots-clés',
    'category': 'Catégorie',
    'email': 'Email',
    'password': 'Mot de passe',
    'status': 'Statut',
    'notes': 'Notes',
    'q': 'Recherche',
  };
}
