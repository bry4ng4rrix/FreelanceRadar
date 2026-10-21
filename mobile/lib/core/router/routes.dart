/// Chemins de navigation de l'application (`context.push(Routes.offer(id))`).
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';

  // Onglets principaux (barre de navigation).
  static const home = '/home';
  static const offers = '/offers';
  static const notifications = '/notifications';
  static const sources = '/sources';
  static const profile = '/profile';

  // Profil.
  static const profileEdit = '/profile/edit';
  static const skills = '/profile/skills';
  static const settings = '/profile/settings';

  // Détails.
  static String offer(int id) => '/offers/$id';
  static String source(int id) => '/sources/$id';
}
