import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/manual_resume_document.dart';

/// Renders a [ManualResumeDocument] natively — the server (`preview_api`)
/// only ever returns structured JSON for this preview, never HTML
/// (confirmed directly: the real web's own markup comes entirely from a
/// client-side JS function, `docHTML()`, `templates/landing.html:8950-8974`
/// — no Django template or server-rendered fragment exists for it
/// anywhere). This widget mirrors `docHTML()`'s own per-section-`kind`
/// switch so the Flutter preview matches the real one's content and
/// structure, using this app's own design system rather than the web's CSS
/// (per the task's own instruction), and carries none of the "untrusted
/// HTML" risk a WebView would (there is no HTML to execute scripts from —
/// everything rendered here is this app's own typed Flutter widget tree
/// built from plain strings/lists).
class ManualResumeDocumentView extends StatelessWidget {
  const ManualResumeDocumentView({required this.document, super.key});

  final ManualResumeDocument document;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(document.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        if (document.title.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(document.title, style: const TextStyle(fontSize: 15, color: AppColors.textMuted)),
        ],
        if (document.contact.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [for (final c in document.contact) _ContactChip(contact: c)],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final section in document.sections) ...[
          _SectionView(section: section),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.contact});

  final ManualResumeContact contact;

  Future<void> _open() async {
    if (contact.href.isEmpty) return;
    final uri = Uri.tryParse(contact.href);
    // Only ever opened externally (the OS's own app chooser/browser), never
    // inside this app's own WebView/session — a malicious or malformed
    // `href` can at worst open the device browser, exactly like tapping any
    // other external link already does elsewhere in this app
    // (`resume_builder_screen.dart`'s own `launchUrl` usage).
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(contact.text, style: const TextStyle(fontSize: 13));
    if (contact.href.isEmpty) return text;
    return InkWell(
      onTap: _open,
      child: Text(
        contact.text,
        style: const TextStyle(fontSize: 13, color: AppColors.action, decoration: TextDecoration.underline),
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final ManualResumeDocumentSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.heading, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _SectionBodyView(body: section.body),
      ],
    );
  }
}

class _SectionBodyView extends StatelessWidget {
  const _SectionBodyView({required this.body});

  final ManualResumeSectionBody body;

  @override
  Widget build(BuildContext context) {
    return switch (body) {
      ManualResumeTextBody(:final text) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in text.split('\n'))
            if (paragraph.trim().isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(paragraph)),
        ],
      ),
      ManualResumeBulletsBody(:final items) => _BulletList(items: items),
      ManualResumeJobsBody(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final item in items) _WorkItemView(item: item)],
      ),
      ManualResumeProjectsBody(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final item in items) _WorkItemView(item: item, showTech: true)],
      ),
      ManualResumeSkillsBody(:final groups) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(text: '${group.label}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: group.items.join(', ')),
                  ],
                ),
              ),
            ),
        ],
      ),
      ManualResumeCompactBody(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${item.title} — ${item.subtitle} (${item.dates})'),
            ),
        ],
      ),
      ManualResumeEducationBody(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (item.meta.isNotEmpty) Text(item.meta, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      ManualResumeDeclarationSectionBody(:final declaration) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(declaration.text),
          const SizedBox(height: 8),
          Text('Place: ${declaration.place}'),
          Text('Date: ${declaration.date}'),
          const SizedBox(height: 8),
          Text(declaration.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      ManualResumeUnknownBody() => const SizedBox.shrink(),
    };
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('•  $item'),
          ),
      ],
    );
  }
}

class _WorkItemView extends StatelessWidget {
  const _WorkItemView({required this.item, this.showTech = false});

  final ManualResumeWorkItem item;
  final bool showTech;

  @override
  Widget build(BuildContext context) {
    final dateLine = [item.dates, item.duration].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (item.subtitle.isNotEmpty || item.location.isNotEmpty)
            Text(
              [item.subtitle, item.location].where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          if (dateLine.isNotEmpty) Text(dateLine, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (showTech && item.tech.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(item.tech, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 4),
          _BulletList(items: item.bullets),
        ],
      ),
    );
  }
}
