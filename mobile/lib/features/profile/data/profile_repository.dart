import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'profile_models.dart';

/// Accès à l'API du profil (`/profile`) et des compétences (`/profile/skills`).
class ProfileRepository {
  const ProfileRepository(this._api);

  final ApiClient _api;

  /// Le serveur crée le profil vide au premier accès.
  Future<Profile> getProfile() => _api.getObject('/profile', Profile.fromJson);

  Future<Profile> updateProfile(Map<String, dynamic> changes) async =>
      Profile.fromJson(asJsonMap(await _api.patch('/profile', body: changes)));

  Future<List<Skill>> listSkills() => _api.getList('/profile/skills', Skill.fromJson);

  /// Refusée (409) si la compétence existe déjà (sans tenir compte de la casse).
  Future<Skill> createSkill(SkillInput input) async =>
      Skill.fromJson(asJsonMap(await _api.post('/profile/skills', body: input.toJson())));

  Future<Skill> updateSkill(int id, SkillInput input) async =>
      Skill.fromJson(asJsonMap(await _api.patch('/profile/skills/$id', body: input.toJson())));

  Future<void> deleteSkill(int id) => _api.delete('/profile/skills/$id');
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);
