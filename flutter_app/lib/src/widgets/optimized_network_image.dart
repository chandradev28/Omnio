import 'package:flutter/material.dart';

class OptimizedNetworkImage extends StatelessWidget {
  const OptimizedNetworkImage({
    super.key,
    required this.url,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
  });

  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final double ratio = MediaQuery.devicePixelRatioOf(context);
    final double? finiteWidth = width != null && width!.isFinite ? width : null;
    final double? finiteHeight =
        height != null && height!.isFinite ? height : null;
    final int? resolvedCacheWidth = cacheWidth ??
        (finiteWidth == null ? null : (finiteWidth * ratio).round());
    final int? resolvedCacheHeight = cacheHeight ??
        (finiteHeight == null ? null : (finiteHeight * ratio).round());

    return Image.network(
      url,
      fit: fit,
      width: finiteWidth,
      height: finiteHeight,
      alignment: alignment,
      cacheWidth: resolvedCacheWidth,
      cacheHeight: resolvedCacheHeight,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      errorBuilder: errorBuilder,
    );
  }
}
