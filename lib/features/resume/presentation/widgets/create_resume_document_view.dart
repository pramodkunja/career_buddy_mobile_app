import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_document.dart';

/// Renders a [CreateResumeDocument] natively — same posture as
/// `ManualResumeDocumentView`: the server only ever returns structured JSON
/// for this preview (the real web's own markup is built client-side), so
/// this widget mirrors `build_document()`'s own section `kind` taxonomy
/// using this app's design system, not the web's CSS or a WebView.
class CreateResumeDocumentView extends StatelessWidget {
  const CreateResumeDocumentView({required this.document, super.key});

  final CreateResumeDocument document;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          document.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        if (document.title.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            document.title,
            style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),
        ],
        if (document.contact.isNotEmpty || document.links.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in document.contact)
                _LinkChip(text: c.text, href: c.href),
              for (final l in document.links)
                _LinkChip(text: l.text, href: l.href),
            ],
          ),
        ],
        if (document.address.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            document.address,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final section in document.sections) ...[
          Text(
            section.heading,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          _SectionBodyView(body: section.body),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.text, required this.href});

  final String text;
  final String href;

  Future<void> _open() async {
    if (href.isEmpty) return;
    final uri = Uri.tryParse(href);
    // Opened externally only — never inside this app's own session, same
    // posture as `ManualResumeDocumentView`'s own contact links.
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (href.isEmpty) return Text(text, style: const TextStyle(fontSize: 13));
    return InkWell(
      onTap: _open,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.action,
          decoration: TextDecoration.underline,
        ),
      ),
    );
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

class _EntryView extends StatelessWidget {
  const _EntryView({required this.item});
  final CreateResumeEntryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (item.subtitle.isNotEmpty)
            Text(
              item.subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          if (item.meta.isNotEmpty)
            Text(
              item.meta,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          if (item.link != null)
            _LinkChip(text: item.link!.text, href: item.link!.href),
          for (final p in item.paragraphs)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(p)),
          if (item.bullets.isNotEmpty) ...[
            const SizedBox(height: 4),
            _BulletList(items: item.bullets),
          ],
          for (final group in item.groups) ...[
            const SizedBox(height: 4),
            Text(
              group.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            _BulletList(items: group.bullets),
          ],
          for (final note in item.notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(
                    context,
                  ).style.copyWith(fontSize: 12),
                  children: [
                    TextSpan(
                      text: '${note.label}: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: note.text),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionBodyView extends StatelessWidget {
  const _SectionBodyView({required this.body});
  final CreateResumeSectionBody body;

  @override
  Widget build(BuildContext context) {
    return switch (body) {
      CreateResumeTextBody(:final text) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in text.split('\n'))
            if (paragraph.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(paragraph),
              ),
        ],
      ),
      CreateResumeLinesBody(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: '${item.label}: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: item.text),
                  ],
                ),
              ),
            ),
        ],
      ),
      CreateResumeEntriesBody(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final item in items) _EntryView(item: item)],
      ),
      CreateResumeItemsBody(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (item.text.isNotEmpty)
                    Text(
                      item.text,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (item.detail.isNotEmpty) Text(item.detail),
                  if (item.link != null)
                    _LinkChip(text: item.link!.text, href: item.link!.href),
                ],
              ),
            ),
        ],
      ),
      CreateResumeUnknownBody() => const SizedBox.shrink(),
    };
  }
}
