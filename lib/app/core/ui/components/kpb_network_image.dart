import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../kpb_theme_ext.dart';

/// Network image hardened for low-bandwidth, low-end Android devices.
///
/// Three things matter for our audience and are easy to get wrong per call site:
///  - **Decode memory**: a 2000px hero decoded full-res into RAM janks/OOMs
///    cheap phones. We cap [CachedNetworkImage.memCacheWidth] (and disk cache)
///    to the on-screen width × devicePixelRatio.
///  - **Airtime**: in "Mode données réduites" ([AppController.dataSaverEnabled])
///    a [decorative] image is not fetched at all — a light placeholder shows.
///  - **Flaky network**: a consistent placeholder + error fallback instead of a
///    broken-image glyph.
///
/// Use this instead of [CachedNetworkImage] / `Image.network` directly so the
/// policy lives in one place.
class KpbNetworkImage extends StatelessWidget {
  const KpbNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.targetWidth,
    this.decorative = true,
    this.placeholderIcon,
    this.errorIcon = Icons.broken_image_outlined,
    this.fallbackColor,
    this.iconSize,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Logical width the image is displayed at; used to bound decode memory.
  /// Falls back to [width], then a safe 640px default when unbounded.
  final double? targetWidth;

  /// Decorative images are skipped entirely in data-saver mode. Set false for
  /// images that carry information the user came for.
  final bool decorative;

  /// Shown while loading and when a decorative image is suppressed. Null = none.
  final IconData? placeholderIcon;

  /// Shown when the fetch fails. Null = plain coloured box.
  final IconData? errorIcon;

  /// Background of the placeholder/error box. Defaults to the neutral surface.
  final Color? fallbackColor;

  /// Size of the placeholder/error icon. Null = framework default.
  final double? iconSize;

  bool get _dataSaverOn {
    try {
      return Get.find<AppController>().dataSaverEnabled;
    } catch (_) {
      // Controller not registered (e.g. isolated widget tests) — assume off.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppressed = decorative && _dataSaverOn;
    if (imageUrl.isEmpty || suppressed) {
      return _box(context, placeholderIcon);
    }

    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final logical = targetWidth ?? width ?? 640;
    final memWidth = (logical * dpr).clamp(64, 2048).round();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memWidth,
      maxWidthDiskCache: memWidth,
      placeholder: (_, __) => _box(context, null),
      errorWidget: (_, __, ___) => _box(context, errorIcon),
    );
  }

  Widget _box(BuildContext context, IconData? icon) {
    return Container(
      width: width,
      height: height,
      color: fallbackColor ?? context.kpb.gray100,
      alignment: Alignment.center,
      child: icon == null
          ? null
          : Icon(icon, color: context.kpb.gray400, size: iconSize),
    );
  }
}
