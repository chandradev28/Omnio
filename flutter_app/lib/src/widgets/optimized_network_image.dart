import 'package:flutter/material.dart';

import '../services/tmdb_image.dart';

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
    this.filterQuality = FilterQuality.high,
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

    final List<String> candidates = getImageCandidates(url);
    return _buildImage(
      candidates,
      0,
      fit: fit,
      width: finiteWidth,
      height: finiteHeight,
      alignment: alignment,
      cacheWidth: resolvedCacheWidth,
      cacheHeight: resolvedCacheHeight,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
    );
  }

  Widget _buildImage(
    List<String> candidates,
    int index, {
    required BoxFit? fit,
    required double? width,
    required double? height,
    required AlignmentGeometry alignment,
    required int? cacheWidth,
    required int? cacheHeight,
    required FilterQuality filterQuality,
    required ImageErrorWidgetBuilder? errorBuilder,
  }) {
    return Image.network(
      candidates[index],
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: filterQuality,
      isAntiAlias: true,
      gaplessPlayback: true,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        if (index + 1 < candidates.length) {
          return _buildImage(
            candidates,
            index + 1,
            fit: fit,
            width: width,
            height: height,
            alignment: alignment,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: filterQuality,
            errorBuilder: errorBuilder,
          );
        }
        return errorBuilder?.call(context, error, stackTrace) ??
            const SizedBox.shrink();
      },
    );
  }
}
