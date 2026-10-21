import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../resume/domain/entities/career_department.dart';
import '../../data/skill_up_nonit_asset_datasource.dart';

final skillUpNonItAssetDataSourceProvider =
    Provider<SkillUpNonItAssetDataSource>((ref) {
      return SkillUpNonItAssetDataSource();
    });

/// Phase 47 — the real Non-IT Skill Up curriculum (21 departments, 202
/// roles). A plain [FutureProvider], not a sealed-state controller — same
/// reasoning as `careerDepartmentsProvider`: bundled static data, nothing
/// to retry against a real backend.
final skillUpNonItDepartmentsProvider =
    FutureProvider<List<CareerDepartmentGroup>>((ref) {
      return ref.watch(skillUpNonItAssetDataSourceProvider).load();
    });
