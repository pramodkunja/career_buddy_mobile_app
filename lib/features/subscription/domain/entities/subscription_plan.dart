/// The three real plan tiers (`users/models.py:102-106 PLAN_CHOICES`) — the
/// identifier sent as `plan_type` to `create_razorpay_order`/
/// `verify_razorpay_payment` (see `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md`
/// §1). [free] is never purchasable (no price, no checkout) — it exists
/// here only so [SubscriptionCatalog.all] can render all three plan cards
/// side by side, matching `templates/pro.html`.
enum PlanTier { free, normal, pro }

/// A plan's static, verified copy — price, label, and feature list, all
/// transcribed verbatim from `templates/pro.html:140-360` (re-verified
/// directly against source for this phase, not inherited by assumption from
/// Phase 1 — see the discovery report §3). This is deliberately NOT a
/// server-fetched model: the backend has no JSON endpoint for plan
/// definitions either (only the HTML page), and this copy changes about as
/// often as the web template itself does.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.tier,
    required this.label,
    required this.tagline,
    required this.basePriceRupees,
    required this.features,
  });

  final PlanTier tier;
  final String label;
  final String tagline;

  /// Base price before GST, in rupees. `0` for [PlanTier.free]. The
  /// authoritative total (base + 18% GST) is never computed here — it comes
  /// back from `create_razorpay_order`'s own `amount` field once a real
  /// order exists (`docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §3: the web
  /// itself only shows GST at that point, never ahead of it).
  final int basePriceRupees;

  final List<String> features;

  /// The exact string this plan's tier is sent as — `request.POST['plan_type']`
  /// server-side. `null` for [PlanTier.free] (never posted to checkout).
  String? get planTypeParam => switch (tier) {
    PlanTier.free => null,
    PlanTier.normal => 'normal',
    PlanTier.pro => 'pro',
  };
}

/// Static catalog of all three plans — `templates/pro.html:140-360`.
abstract final class SubscriptionCatalog {
  // Phase 67 (UI-E-001/002/004/007/008): every feature line below was
  // re-verified directly against `templates/pro.html:140-335` — several had
  // drifted from the real page (a factually wrong "Unlimited" resume-parse
  // count on Free instead of the real "4", a "70 or above" mock-interview
  // threshold that the website actually says is "90" on both Normal and
  // Pro, a fabricated "Grammar & Vocabulary Practice Exercises" bullet on
  // Normal that doesn't exist on the real card, and a missing real bullet
  // in its place). The 2 "not included" bullets Free's real card also shows
  // (red X icon, `feature-item disabled` CSS class) are intentionally still
  // not reproduced here — `PlanCard` has no disabled/excluded visual
  // treatment at all yet, and showing them with the same green check-circle
  // every other bullet uses would be more misleading than omitting them;
  // left for a future phase alongside that UI work.
  static const free = SubscriptionPlan(
    tier: PlanTier.free,
    label: 'Free Plan',
    tagline: 'Essential access to begin learning Business English.',
    basePriceRupees: 0,
    features: [
      'Skill Up English & Vocabulary and Grammar',
      'Access to only 1 Activity (the first one you open)',
      '4 Resume Parsing & ATS Score Analyses',
    ],
  );

  static const normal = SubscriptionPlan(
    tier: PlanTier.normal,
    label: 'Normal User',
    tagline: 'Starter plan for communication and English skills.',
    basePriceRupees: 499,
    features: [
      'Full access to Activities Section (Speaking, Writing, Negotiation, Roleplay)',
      'Full Skill Up access (English, Aptitude, Tech Center & Non-IT Center) with certificates for scoring 70 or above',
      'Access to Student Dashboard & learning analytics',
      'Unlimited Resume Parsing & ATS Score Analysis (Extract text, density & format check)',
      'AI Mock Interviews (open when your resume scores 90% or above in ATS)',
      '5 Matched Job Recommendations (unlocked by scoring 90 or above in the mock interview)',
    ],
  );

  static const pro = SubscriptionPlan(
    tier: PlanTier.pro,
    label: 'Pro User',
    tagline: 'Complete suite for resume parsing, AI mock interviews and job matching.',
    basePriceRupees: 999,
    features: [
      'Everything in Normal Plan (Skill Up, Activities, Certificates & Dashboard)',
      'Unlimited Resume Parsing & ATS Score Analysis (Extract text, density & format check)',
      'AI Mock Interviews (Voice/Non-Voice/Service Desk + Technical)',
      'Score Evaluation with AI feedback',
      'Unlimited Matched Job Recommendations (unlocked by scoring 90 or above in the mock interview)',
      'Direct Job Applications with auto-attached PDF/DOCX resumes',
    ],
  );

  static const List<SubscriptionPlan> all = [free, normal, pro];
}
