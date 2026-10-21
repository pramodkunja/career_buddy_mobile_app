import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../resume/domain/entities/career_department.dart';

/// Phase 47 — loads the real Non-IT Skill Up curriculum from the bundled
/// `assets/data/nonit_skillup_departments.json` (byte-for-byte copy of the
/// real `static/data/nonit_departments.json`, confirmed to be the actual
/// `data-src` the `#depth-nonit` section fetches — see `pubspec.yaml`'s own
/// doc comment for why this is a *different* file from the Phase 43
/// `nonit_departments.json` asset despite the identical real-web filename).
///
/// Reuses [CareerDepartmentGroup]/[CareerDepartment]/[CareerRole] (the
/// resume feature's own "department/role browsing tree" entities) rather
/// than a parallel Skill-Up-only hierarchy — the same cross-feature-entity
/// precedent already established by `InterviewAnalyticsResult` reusing the
/// dashboard feature's `RecommendedJob`, since this genuinely is the same
/// real-world shape (group → department → role), just a different JSON
/// source and, uniquely for these roles, a non-null [CareerRole.coursePath].
///
/// `category` is `'tech'`/`'nt'`, the same 2 values Phase 43's own Non-IT
/// parsing already uses for "Non-IT · Technical"/"Non-IT · Non-Technical" —
/// genuinely the same two tracks, not a new taxonomy.
class SkillUpNonItAssetDataSource {
  List<CareerDepartmentGroup>? _cache;

  Future<List<CareerDepartmentGroup>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(
      'assets/data/nonit_skillup_departments.json',
    );
    final groups = jsonDecode(raw) as List<dynamic>;
    _cache = [
      for (final group in groups)
        () {
          final g = group as List<dynamic>;
          final label = g[0] as String;
          final category = label.endsWith('Non-Technical') ? 'nt' : 'tech';
          return CareerDepartmentGroup(
            label: label,
            departments: [
              for (final dept in g[1] as List<dynamic>)
                () {
                  final d = dept as List<dynamic>;
                  final name = d[0] as String;
                  final icon = d[1] as String;
                  final roles = d[2] as List<dynamic>;
                  return CareerDepartment(
                    category: category,
                    icon: icon,
                    name: name,
                    roles: [
                      for (final role in roles) _parseRole(role as List<dynamic>),
                    ],
                  );
                }(),
            ],
          );
        }(),
    ];
    return _cache!;
  }

  /// One role entry: `[name, [skills], coursePath?]` — unlike Phase 43's
  /// Non-IT asset, `skills` here is already a real array (not a single
  /// comma-separated string to split), so it's used as-is, matching the real
  /// `roleView()`'s own flat skill-chip rendering (one unlabeled group).
  CareerRole _parseRole(List<dynamic> role) {
    final name = role[0] as String;
    final skills = (role[1] as List<dynamic>).cast<String>();
    final coursePath = role.length > 2 ? role[2] as String? : null;
    return CareerRole(
      name: name,
      skillGroups: [CareerRoleSkillGroup(label: 'Role skills', skills: skills)],
      coursePath: coursePath,
    );
  }
}
