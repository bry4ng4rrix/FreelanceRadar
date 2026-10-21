import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceradar/core/auth/app_user.dart';
import 'package:freelanceradar/core/config/app_config.dart';
import 'package:freelanceradar/core/network/api_exception.dart';
import 'package:freelanceradar/core/network/paginated.dart';

DioException _dioError(int status, Object? body) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: request, statusCode: status, data: body),
  );
}

void main() {
  group('Paginated', () {
    test('lit le format de page du serveur et calcule le nombre de pages', () {
      final page = Paginated<int>.fromJson({
        'items': [
          {'id': 1},
          {'id': 2},
        ],
        'total': 45,
        'page': 2,
        'page_size': 20,
      }, (json) => json['id'] as int);
      expect(page.items, [1, 2]);
      expect(page.total, 45);
      expect(page.pages, 3);
      expect(page.hasMore, isTrue);
    });

    test('dernière page et liste vide', () {
      final last = Paginated<int>.fromJson({
        'items': <Object>[],
        'total': 0,
        'page': 1,
        'page_size': 20,
      }, (json) => 0);
      expect(last.pages, 0);
      expect(last.hasMore, isFalse);
    });
  });

  group('ApiException', () {
    test('erreur standard du serveur : message français repris tel quel', () {
      final error = ApiException.fromDio(
        _dioError(409, {
          'error': {
            'code': 'http_409',
            'message': 'Une source porte déjà ce nom.',
            'details': null,
          },
        }),
      );
      expect(error.statusCode, 409);
      expect(error.isConflict, isTrue);
      expect(error.userMessage, 'Une source porte déjà ce nom.');
    });

    test('erreur de validation : champs traduits, sans la valeur saisie', () {
      final error = ApiException.fromDio(
        _dioError(422, {
          'error': {
            'code': 'validation_error',
            'message': 'Paramètres invalides.',
            'details': [
              {
                'loc': ['body', 'frequency_minutes'],
                'msg': 'Input should be greater than or equal to 5',
                'type': 'greater_than_equal',
              },
            ],
          },
        }),
      );
      expect(error.fieldErrors, {'Fréquence': 'Input should be greater than or equal to 5'});
      expect(error.userMessage, 'Fréquence : Input should be greater than or equal to 5');
    });

    test('erreur 500 : message générique', () {
      final error = ApiException.fromDio(
        _dioError(500, {
          'error': {'code': 'internal_error', 'message': 'Erreur interne du serveur.'},
        }),
      );
      expect(error.userMessage, 'Erreur du serveur. Réessayez plus tard.');
    });

    test('serveur injoignable', () {
      final error = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(error.isNetwork, isTrue);
      expect(error.userMessage, contains('Impossible de joindre le serveur'));
    });
  });

  test('AppUser : identifiant entier renvoyé par /auth/me', () {
    final user = AppUser.fromJson({
      'id': 7,
      'email': 'dev@example.com',
      'is_active': true,
      'created_at': '2026-10-21T08:00:00Z',
    });
    expect(user.id, 7);
    expect(user.email, 'dev@example.com');
    expect(AppUser.fromJson(user.toJson()).id, 7);
  });

  test('ServerUrlNotifier.normalize', () {
    expect(ServerUrlNotifier.normalize('192.168.1.10:8000/'), 'http://192.168.1.10:8000');
    expect(
      ServerUrlNotifier.normalize('https://radar.example.com/api/v1'),
      'https://radar.example.com',
    );
    expect(ServerUrlNotifier.normalize('  '), kDefaultServerUrl);
  });
}
