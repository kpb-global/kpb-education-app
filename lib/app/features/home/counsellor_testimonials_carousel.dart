import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_card.dart';
import '../../core/ui/kpb_theme_ext.dart';

/// Horizontal carousel of PUBLISHED counsellor reviews — social proof for Home.
///
/// Fetches `/impact/reviews` on init and renders a scrollable row of testimonial
/// cards (5-star rating, reviewer name, quoted body). It renders nothing
/// ([SizedBox.shrink]) until at least one published review exists — we never
/// fabricate testimonials, mirroring [HomeImpactProof]'s self-hiding pattern.
class CounsellorTestimonialsCarousel extends StatefulWidget {
  const CounsellorTestimonialsCarousel({super.key});

  @override
  State<CounsellorTestimonialsCarousel> createState() =>
      _CounsellorTestimonialsCarouselState();
}

class _CounsellorTestimonialsCarouselState
    extends State<CounsellorTestimonialsCarousel> {
  List<Map<String, dynamic>> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await Get.find<AppController>().apiClient.getPublishedReviews();
      final raw = (data['reviews'] as List<dynamic>?) ?? const [];
      final parsed = raw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      if (mounted) setState(() => _reviews = parsed);
    } catch (_) {
      // Offline / no backend — stay hidden rather than show fabricated proof.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Self-hide until there is real, published social proof to show.
    if (_reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: KpbSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('testimonials_carousel_title'.tr,
                  style: KpbTextStyles.titleMd),
              const SizedBox(height: 2),
              Text(
                'testimonials_carousel_body'
                    .trParams({'count': '${_reviews.length}'}),
                style:
                    TextStyle(fontSize: 13, color: context.kpb.textSecondary),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: _reviews.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: KpbSpacing.sm),
            itemBuilder: (context, index) =>
                _TestimonialCard(review: _reviews[index]),
          ),
        ),
        const SizedBox(height: KpbSpacing.lg),
      ],
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.review});

  final Map<String, dynamic> review;

  int get _rating => (review['rating'] as num?)?.toInt() ?? 0;
  String get _name => (review['reviewerName'] as String?)?.trim() ?? '';
  String get _body => (review['body'] as String?)?.trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final clampedStars = _rating.clamp(0, 5);
    return SizedBox(
      width: 280,
      child: KpbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 5-star rating row (semantics label for accessibility).
            Semantics(
              label: '$clampedStars/5',
              child: Row(
                children: List.generate(5, (i) {
                  final filled = i < clampedStars;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: filled
                        ? KpbColors.warning
                        : context.kpb.textSecondary,
                  );
                }),
              ),
            ),
            const SizedBox(height: KpbSpacing.sm),
            Expanded(
              child: Text(
                _body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: context.kpb.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              _name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: KpbColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
