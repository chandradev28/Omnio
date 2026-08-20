import 'package:flutter/material.dart';

import '../services/tmdb_image.dart';
import '../theme/app_colors.dart';
import 'optimized_network_image.dart';

class TitleLogo extends StatelessWidget {
  const TitleLogo({
    super.key,
    required this.title,
    this.logoPath,
    this.maxLines = 2,
    this.textAlign = TextAlign.center,
    this.logoHeight = 86,
    this.maxLogoWidth = 300,
    this.textStyle,
  });

  final String title;
  final String? logoPath;
  final int maxLines;
  final TextAlign textAlign;
  final double logoHeight;
  final double maxLogoWidth;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final String? path = logoPath;
    if (path != null && path.trim().isNotEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxLogoWidth,
          maxHeight: logoHeight,
        ),
        child: OptimizedNetworkImage(
          url: getImageUrl(path, 'w500'),
          fit: BoxFit.contain,
          cacheWidth: 900,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return _TextFallback(
              title: title,
              maxLines: maxLines,
              textAlign: textAlign,
              textStyle: textStyle,
            );
          },
        ),
      );
    }

    return _TextFallback(
      title: title,
      maxLines: maxLines,
      textAlign: textAlign,
      textStyle: textStyle,
    );
  }
}

class _TextFallback extends StatelessWidget {
  const _TextFallback({
    required this.title,
    required this.maxLines,
    required this.textAlign,
    this.textStyle,
  });

  final String title;
  final int maxLines;
  final TextAlign textAlign;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: textStyle ??
          const TextStyle(
            color: AppColors.text,
            fontSize: 34,
            height: 0.95,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
          ),
    );
  }
}
