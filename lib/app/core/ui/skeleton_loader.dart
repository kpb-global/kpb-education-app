import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'app_tokens.dart';
import 'kpb_theme_ext.dart';

/// A reusable shimmer-based skeleton loader to improve perceived performance.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? context.kpb.gray400 : context.kpb.gray100,
      highlightColor: isDark ? context.kpb.gray300 : context.kpb.gray50,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? KpbRadius.mdBr,
        ),
      ),
    );
  }

  /// Presets for common UI elements
  factory SkeletonLoader.textLine({double width = 120}) => SkeletonLoader(
        width: width,
        height: 14,
        borderRadius: BorderRadius.circular(4),
      );

  factory SkeletonLoader.card({double height = 100}) => SkeletonLoader(
        width: double.infinity,
        height: height,
        borderRadius: KpbRadius.lgBr,
      );

  factory SkeletonLoader.circle({double size = 40}) => SkeletonLoader(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size / 2),
      );
}
