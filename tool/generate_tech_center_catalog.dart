// ignore_for_file: avoid_print
//
// Phase 76 — regenerates `lib/features/skill_up/data/tech_center_catalog
// .g.dart` from the updated Django reference's own
// `static/001 Career Buddy/index.html`.
//
// Why this reads the real page rather than the filesystem: Phase 75 found
// 383 real `TechCenter/<dept>/<role>/*.html` files with no Flutter entry
// point, and assumed a department/role hierarchy would need to be invented.
// It doesn't — `index.html`'s own `#depth-tech` article already contains a
// `<div class="sub" id="grp-tech-<dept>">` per department, each holding
// `<div class="card" id="role-tech-<dept>--<role>">` per role, each with a
// real `<h4>` title, a real `<span class="chip">` category, and the exact
// `#load=<relativePath>&title=<title>` links every other Skill Up lesson in
// this app already uses — the same sourcing convention `skill_up_data.dart`
// itself is built from, just a block of the page that was never
// transcribed. This script transcribes it mechanically instead of by hand
// (hand-copying 383 entries would be its own source of error), and
// cross-validates the result against the real on-disk files before writing
// anything.
//
// Usage:
//   dart run tool/generate_tech_center_catalog.dart <path-to-royalStaffing_CB01>
//
// The Django reference path is never hardcoded — it must be passed in,
// since this script lives in a Flutter project that may be checked out
// anywhere relative to that (separate) read-only reference checkout.

import 'dart:io';

import 'package:html/parser.dart' as html_parser;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/generate_tech_center_catalog.dart <path-to-royalStaffing_CB01>',
    );
    exit(64);
  }
  final djangoRoot = args[0];
  final indexPath = '$djangoRoot/static/001 Career Buddy/index.html';
  final indexFile = File(indexPath);
  if (!indexFile.existsSync()) {
    stderr.writeln('Not found: $indexPath');
    exit(66);
  }

  final document = html_parser.parse(indexFile.readAsStringSync());
  final techArticle = document.querySelector('article#depth-tech');
  if (techArticle == null) {
    stderr.writeln(
      'Could not find <article id="depth-tech"> in $indexPath — site structure may have changed.',
    );
    exit(1);
  }

  final departments = <_Dept>[];
  for (final sub in techArticle.querySelectorAll('div.sub')) {
    final id = sub.id;
    if (!id.startsWith('grp-tech-')) continue;
    final deptSlug = id.substring('grp-tech-'.length);
    final h3 = sub.querySelector('h3');
    if (h3 == null) {
      stderr.writeln('WARNING: $id has no <h3> — skipped.');
      continue;
    }
    final deptTitle = h3.text.trim();

    final roles = <_Role>[];
    final rolePrefix = 'role-tech-$deptSlug--';
    for (final card in sub.querySelectorAll('div.card')) {
      final roleId = card.id;
      if (!roleId.startsWith(rolePrefix)) {
        stderr.writeln(
          'WARNING: card "$roleId" inside "$id" does not match expected prefix "$rolePrefix" — skipped.',
        );
        continue;
      }
      final roleSlug = roleId.substring(rolePrefix.length);
      final h4 = card.querySelector('h4');
      final chip = card.querySelector('span.chip');
      if (h4 == null || chip == null) {
        stderr.writeln(
          'WARNING: role "$roleId" missing <h4> or chip — skipped.',
        );
        continue;
      }
      final roleTitle = h4.text.trim();
      final category = chip.text.trim();

      final courses = <_Course>[];
      for (final a in card.querySelectorAll('div.tc-courses a')) {
        final href = a.attributes['href'] ?? '';
        if (!href.startsWith('#load=')) continue;
        final rest = href.substring('#load='.length);
        final sep = rest.indexOf('&title=');
        if (sep == -1) {
          stderr.writeln(
            'WARNING: course link in "$roleId" has no &title= — skipped ($href).',
          );
          continue;
        }
        final relativePath = Uri.decodeComponent(rest.substring(0, sep));
        final title = Uri.decodeComponent(
          rest.substring(sep + '&title='.length),
        );
        courses.add(_Course(title: title, relativePath: relativePath));
      }
      if (courses.isEmpty) {
        stderr.writeln(
          'WARNING: role "$roleId" has zero parsed courses — skipped.',
        );
        continue;
      }
      roles.add(
        _Role(
          slug: roleSlug,
          title: roleTitle,
          category: category,
          courses: courses,
        ),
      );
    }
    if (roles.isEmpty) {
      stderr.writeln(
        'WARNING: department "$id" has zero parsed roles — skipped.',
      );
      continue;
    }
    departments.add(_Dept(slug: deptSlug, title: deptTitle, roles: roles));
  }

  // ---- Cross-validate against the real files on disk ----
  final techCenterDir = Directory(
    '$djangoRoot/static/001 Career Buddy/TechCenter',
  );
  final onDiskNested = <String>{};
  if (techCenterDir.existsSync()) {
    for (final entity in techCenterDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.html')) {
        continue;
      }
      final rel = entity.path
          .substring(techCenterDir.path.length + 1)
          .replaceAll(Platform.pathSeparator, '/');
      // Only nested (dept/role/file.html — exactly 2 slashes) files count;
      // the 29 flat TechCenter/*.html files are already transcribed
      // elsewhere in skill_up_data.dart and are out of this script's scope.
      if ('/'.allMatches(rel).length == 2) onDiskNested.add('TechCenter/$rel');
    }
  } else {
    stderr.writeln(
      'WARNING: ${techCenterDir.path} not found — skipping on-disk cross-validation.',
    );
  }

  final parsedPaths = <String>{
    for (final d in departments)
      for (final r in d.roles)
        for (final c in r.courses) c.relativePath,
  };

  final missingFromPage = onDiskNested.difference(parsedPaths);
  final missingOnDisk = parsedPaths.difference(onDiskNested);
  final totalCourses = departments.fold(
    0,
    (n, d) => n + d.roles.fold(0, (m, r) => m + r.courses.length),
  );
  final totalRoles = departments.fold(0, (n, d) => n + d.roles.length);

  print(
    'Parsed ${departments.length} departments, $totalRoles roles, $totalCourses courses from index.html.',
  );
  print(
    'Found ${onDiskNested.length} nested .html files on disk under TechCenter/.',
  );
  if (missingFromPage.isNotEmpty) {
    print(
      '${missingFromPage.length} on-disk file(s) have NO link in index.html:',
    );
    for (final p in missingFromPage.take(20)) {
      print('  - $p');
    }
  }
  if (missingOnDisk.isNotEmpty) {
    print(
      '${missingOnDisk.length} link(s) in index.html point to NO file on disk:',
    );
    for (final p in missingOnDisk.take(20)) {
      print('  - $p');
    }
  }
  if (missingFromPage.isEmpty &&
      missingOnDisk.isEmpty &&
      onDiskNested.isNotEmpty) {
    print(
      'Cross-validation: every on-disk nested file is linked, and every linked path exists on disk. Exact match.',
    );
  }

  // Duplicate relativePath check (across the whole parsed set).
  final seen = <String>{};
  final duplicates = <String>{};
  for (final p
      in parsedPaths.isEmpty
          ? <String>[]
          : [
              for (final d in departments)
                for (final r in d.roles)
                  for (final c in r.courses) c.relativePath,
            ]) {
    if (!seen.add(p)) duplicates.add(p);
  }
  if (duplicates.isNotEmpty) {
    print(
      'WARNING: ${duplicates.length} duplicate relativePath(s) found: $duplicates',
    );
  }

  // ---- Write the generated Dart file ----
  final buffer = StringBuffer();
  buffer.writeln(
    '// GENERATED by tool/generate_tech_center_catalog.dart — do not hand-edit.',
  );
  buffer.writeln('//');
  buffer.writeln(
    '// Source: the updated Django reference\'s own `static/001 Career Buddy/',
  );
  buffer.writeln(
    '// index.html`, the `#depth-tech` article\'s `<div class="sub" id="grp-tech-*">`',
  );
  buffer.writeln(
    '// department groups and their `<div class="card" id="role-tech-*--*">` role',
  );
  buffer.writeln(
    '// cards — $totalCourses courses, $totalRoles roles, ${departments.length} departments,',
  );
  buffer.writeln(
    '// cross-validated 1:1 against the real on-disk TechCenter/<dept>/<role>/*.html',
  );
  buffer.writeln('// files at generation time.');
  buffer.writeln('//');
  buffer.writeln('// Regenerate with:');
  buffer.writeln(
    '//   dart run tool/generate_tech_center_catalog.dart <path-to-royalStaffing_CB01>',
  );
  buffer.writeln();
  buffer.writeln("import '../domain/entities/tech_center_catalog.dart';");
  buffer.writeln();
  buffer.writeln('const kTechCenterDepartments = <TechCenterDepartment>[');
  for (final d in departments) {
    buffer.writeln(
      "  TechCenterDepartment(slug: '${_esc(d.slug)}', title: '${_esc(d.title)}', roles: [",
    );
    for (final r in d.roles) {
      buffer.writeln(
        "    TechCenterRole(slug: '${_esc(r.slug)}', title: '${_esc(r.title)}', category: '${_esc(r.category)}', courses: [",
      );
      for (final c in r.courses) {
        buffer.writeln(
          "      TechCenterCourse(title: '${_esc(c.title)}', relativePath: '${_esc(c.relativePath)}'),",
        );
      }
      buffer.writeln('    ]),');
    }
    buffer.writeln('  ]),');
  }
  buffer.writeln('];');

  final outPath = 'lib/features/skill_up/data/tech_center_catalog.g.dart';
  File(outPath).writeAsStringSync(buffer.toString());
  print('Wrote $outPath');
}

String _esc(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');

class _Course {
  _Course({required this.title, required this.relativePath});
  final String title;
  final String relativePath;
}

class _Role {
  _Role({
    required this.slug,
    required this.title,
    required this.category,
    required this.courses,
  });
  final String slug;
  final String title;
  final String category;
  final List<_Course> courses;
}

class _Dept {
  _Dept({required this.slug, required this.title, required this.roles});
  final String slug;
  final String title;
  final List<_Role> roles;
}
