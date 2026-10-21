import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/entities/career_department.dart';

/// Loads the real "Choose Your Path" department/role catalogs from the
/// bundled `assets/data/it_departments.json`/`nonit_departments.json` —
/// genuinely static content on the web itself (one fetched JSON file for
/// IT, one inline JS literal for Non-IT; neither is a per-user API), so
/// bundling it as an asset mirrors `GrammarDataSource`'s own, already-
/// established "static web content reproduced in Flutter" pattern rather
/// than inventing an endpoint that doesn't exist.
class CareerDepartmentsAssetDataSource {
  List<CareerDepartmentGroup>? _itCache;
  List<CareerDepartmentGroup>? _nonItCache;

  /// `splitSk()` (`landing.html:8041-8045`), reproduced exactly: split on
  /// top-level commas/semicolons (ignoring any inside parentheses), trim,
  /// drop a leading "and "/"or ", then capitalize the first letter.
  List<String> _splitSkills(String s) {
    final out = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (final ch in s.split('')) {
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (depth <= 0 && (ch == ',' || ch == ';')) {
        out.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    out.add(buffer.toString());
    return out
        .map((x) => x.trim().replaceFirst(RegExp(r'^(and|or) '), ''))
        .where((x) => x.isNotEmpty)
        .map((x) => x[0].toUpperCase() + x.substring(1))
        .toList();
  }

  /// One IT role's `["Label: a, b", ...]` lines
  /// (`itRole()`/`itSkills()`, `landing.html:8301-8319`) — each line becomes
  /// its own labeled skill group.
  CareerRole _parseItRole(String name, List<dynamic> lines) {
    return CareerRole(
      name: name,
      skillGroups: [
        for (final line in lines.cast<String>())
          () {
            final at = line.indexOf(':');
            final label = at > 0 ? line.substring(0, at).trim() : 'Role skills';
            final body = at > 0 ? line.substring(at + 1) : line;
            return CareerRoleSkillGroup(label: label, skills: _splitSkills(body));
          }(),
      ],
    );
  }

  /// One Non-IT role's single comma-separated skills string
  /// (`customRole(r.n, r.c, r.sub, [['Role skills', r.sk]])`,
  /// `landing.html:8769`) — always exactly one group, labeled "Role
  /// skills".
  CareerRole _parseNonItRole(String name, String skillsLine) {
    return CareerRole(
      name: name,
      skillGroups: [
        CareerRoleSkillGroup(label: 'Role skills', skills: _splitSkills(skillsLine)),
      ],
    );
  }

  Future<List<CareerDepartmentGroup>> _loadIt() async {
    if (_itCache != null) return _itCache!;
    final raw = await rootBundle.loadString('assets/data/it_departments.json');
    final groups = jsonDecode(raw) as List<dynamic>;
    _itCache = [
      for (final group in groups)
        CareerDepartmentGroup(
          label: (group as List<dynamic>)[0] as String,
          departments: [
            for (final dept in (group[1] as List<dynamic>))
              () {
                final d = dept as List<dynamic>;
                final name = d[0] as String;
                final icon = d[1] as String;
                final roles = d[2] as List<dynamic>;
                return CareerDepartment(
                  category: 'it',
                  icon: icon,
                  name: name,
                  roles: [
                    for (final role in roles)
                      _parseItRole(
                        (role as List<dynamic>)[0] as String,
                        role[1] as List<dynamic>,
                      ),
                  ],
                );
              }(),
          ],
        ),
    ];
    return _itCache!;
  }

  Future<List<CareerDepartmentGroup>> _loadNonIt() async {
    if (_nonItCache != null) return _nonItCache!;
    final raw = await rootBundle.loadString('assets/data/nonit_departments.json');
    final depts = jsonDecode(raw) as List<dynamic>;
    final tech = <CareerDepartment>[];
    final nt = <CareerDepartment>[];
    for (final dept in depts) {
      final d = dept as Map<String, dynamic>;
      final category = d['c'] as String; // 'tech' | 'nt'
      final roles = d['r'] as List<dynamic>;
      final department = CareerDepartment(
        category: category,
        icon: d['i'] as String,
        name: d['n'] as String,
        roles: [
          for (final role in roles)
            _parseNonItRole(
              (role as List<dynamic>)[0] as String,
              role[1] as String,
            ),
        ],
      );
      (category == 'tech' ? tech : nt).add(department);
    }
    _nonItCache = [
      CareerDepartmentGroup(label: 'Non-IT · Technical', departments: tech),
      CareerDepartmentGroup(label: 'Non-IT · Non-Technical', departments: nt),
    ];
    return _nonItCache!;
  }

  /// [track] is `'it'` or `'non-it'` — the same 2 values
  /// `RoutePaths`/`career_path`'s own `track` parameter uses.
  Future<List<CareerDepartmentGroup>> load(String track) {
    return track == 'it' ? _loadIt() : _loadNonIt();
  }
}
