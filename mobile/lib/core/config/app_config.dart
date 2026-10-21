import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serveur par défaut : backend local (Linux). Sur téléphone, saisir l'adresse du PC
/// (`http://<IP-du-PC>:8000`) ou du serveur HTTPS dans l'écran de connexion.
const kDefaultServerUrl = 'http://localhost:8000';
const kApiPrefix = '/api/v1';
const kAppName = 'FreelanceRadar';
const kAppVersion = '1.0.0';

/// Injecté dans `main()` (voir `ProviderScope.overrides`).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider doit être surchargé dans main()'),
);

/// URL du serveur (sans `/api/v1`), persistée localement.
class ServerUrlNotifier extends Notifier<String> {
  static const _key = 'server_url';

  @override
  String build() => ref.read(sharedPreferencesProvider).getString(_key) ?? kDefaultServerUrl;

  Future<void> update(String url) async {
    final normalized = normalize(url);
    await ref.read(sharedPreferencesProvider).setString(_key, normalized);
    state = normalized;
  }

  Future<void> reset() => update(kDefaultServerUrl);

  /// `192.168.1.10:8000/` -> `http://192.168.1.10:8000`
  static String normalize(String url) {
    var value = url.trim();
    if (value.isEmpty) return kDefaultServerUrl;
    if (!value.startsWith(RegExp(r'https?://'))) value = 'http://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith(kApiPrefix)) value = value.substring(0, value.length - kApiPrefix.length);
    return value;
  }
}

final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);
