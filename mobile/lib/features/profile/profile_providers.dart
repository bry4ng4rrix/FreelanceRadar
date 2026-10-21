import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/profile_models.dart';
import 'data/profile_repository.dart';

/// Profil de l'utilisateur connecté, modifiable sur place.
class ProfileNotifier extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() => ref.watch(profileRepositoryProvider).getProfile();

  Future<Profile> save(Map<String, dynamic> changes) async {
    final updated = await ref.read(profileRepositoryProvider).updateProfile(changes);
    if (ref.mounted) state = AsyncData(updated);
    return updated;
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile>(ProfileNotifier.new);

/// Compétences du profil (triées par nom côté serveur), modifiables sur place.
class SkillsNotifier extends AsyncNotifier<List<Skill>> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<List<Skill>> build() => ref.watch(profileRepositoryProvider).listSkills();

  Future<void> add(SkillInput input) async {
    await _repo.createSkill(input);
    await _reload();
  }

  Future<void> edit(int id, SkillInput input) async {
    await _repo.updateSkill(id, input);
    await _reload();
  }

  Future<void> remove(int id) async {
    await _repo.deleteSkill(id);
    final current = state.value;
    if (current != null && ref.mounted) {
      state = AsyncData(current.where((skill) => skill.id != id).toList());
    }
  }

  /// Relit la liste : le serveur fixe l'ordre et normalise les noms.
  Future<void> _reload() async {
    final skills = await _repo.listSkills();
    if (ref.mounted) state = AsyncData(skills);
  }
}

final skillsProvider = AsyncNotifierProvider<SkillsNotifier, List<Skill>>(SkillsNotifier.new);
