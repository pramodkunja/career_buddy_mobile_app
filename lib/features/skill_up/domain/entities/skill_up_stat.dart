/// A single "number + label" stat tile.
///
/// Reproduces two visually different but structurally identical bits of
/// the real `static/001 Career Buddy/index.html`: the hero's
/// `<div class="stats"><div><div class="num mono">…</div><div
/// class="lbl">…</div></div>…</div>` row, and the Sitemap tab's "Platform
/// at a glance" aside (`<aside class="glance"><div class="row"><span>…
/// </span><span class="v mono">…</span></div>…`). Both are label+value
/// pairs, just with the value/label order swapped in the markup.
class SkillUpStat {
  const SkillUpStat({required this.value, required this.label});

  final String value;
  final String label;
}
