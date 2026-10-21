import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

class _Testimonial {
  const _Testimonial(this.initials, this.color, this.quote, this.name, this.role);
  final String initials;
  final Color color;
  final String quote;
  final String name;
  final String role;
}

/// `#stories` (`templates/landing.html:7246-7319`) — "What our job seekers
/// say" / "What our employers say", 6 real testimonial cards reproduced
/// verbatim from the actual source content (never fabricated, per this
/// phase's own explicit instruction).
class HomeTestimonialsSection extends StatelessWidget {
  const HomeTestimonialsSection({super.key});

  static const _jobSeekers = [
    _Testimonial(
      'PS',
      Color(0xFF185ADB),
      '"CareerBuddy helped me improve my resume and interview skills. The resources and mock interviews were '
          'extremely helpful. Within a few weeks, I started getting calls from top companies and landed my dream job!"',
      'Priya Sharma',
      'Software Engineer · Placed at TechNova Solutions',
    ),
    _Testimonial(
      'RV',
      Color(0xFF7C3AED),
      '"The mock tests and English exercises on CareerBuddy really boosted my confidence. The study material is '
          'easy to follow and very effective. It made my job preparation journey smooth and successful."',
      'Rohit Verma',
      'B.Tech Graduate · Placed at BrightFuture Tech',
    ),
    _Testimonial(
      'AS',
      Color(0xFFDB2777),
      '"CareerBuddy\'s ATS resume optimization and mock technical interviews made a real difference in how I '
          'presented myself to recruiters."',
      'Ananya Sen',
      'Data Analyst · Placed at Apex Global Systems',
    ),
  ];

  static const _employers = [
    _Testimonial(
      'AP',
      Color(0xFFF59E0B),
      '"We posted a job opening on CareerBuddy and started receiving relevant, quality candidates within a day. '
          'The platform is very easy to use and has made our hiring process simple and efficient."',
      'Ankit Patel',
      'HR Manager · TechNova Solutions',
    ),
    _Testimonial(
      'SI',
      Color(0xFF209A52),
      '"The verified candidate profiles on CareerBuddy saved our team a lot of time during screening."',
      'Sneha Iyer',
      'Talent Acquisition Lead · BrightFuture Technologies',
    ),
    _Testimonial(
      'MV',
      Color(0xFF185ADB),
      '"CareerBuddy provided us with top-tier candidates who were pre-screened and genuinely ready to contribute '
          'from day one."',
      'Marcus Vance',
      'VP of HR · Apex Global Systems',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What our job seekers say',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final t in _jobSeekers) _TestimonialCard(testimonial: t),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'What our employers say',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final t in _employers) _TestimonialCard(testimonial: t),
      ],
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial});
  final _Testimonial testimonial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                5,
                (_) => const Icon(Icons.star, size: 15, color: Color(0xFFF59E0B)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              testimonial.quote,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: testimonial.color,
                  child: Text(
                    testimonial.initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testimonial.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        testimonial.role,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
