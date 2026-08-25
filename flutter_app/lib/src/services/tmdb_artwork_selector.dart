import 'dart:math';

/// Picks one of TMDB's strongest images for a specific frame shape.
///
/// TMDB frequently returns dozens of images. Ranking by aspect ratio,
/// resolution, and community votes prevents a wide backdrop from being forced
/// into a portrait card while still allowing a few high-quality variants.
String? selectTmdbArtworkPath(
  dynamic images, {
  required String collection,
  required double targetAspectRatio,
  required int variantSeed,
  int variantPoolSize = 3,
}) {
  if (images is! Map<String, dynamic>) {
    return null;
  }

  final List<_ArtworkCandidate> candidates =
      ((images[collection] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_ArtworkCandidate.fromJson)
          .where((_ArtworkCandidate item) => item.path.isNotEmpty)
          .toList(growable: false);
  if (candidates.isEmpty) {
    return null;
  }

  candidates.sort((_ArtworkCandidate left, _ArtworkCandidate right) {
    return right.scoreFor(targetAspectRatio).compareTo(
          left.scoreFor(targetAspectRatio),
        );
  });

  final int poolLength = min(max(variantPoolSize, 1), candidates.length);
  final int selectedIndex = variantSeed.abs() % poolLength;
  return candidates[selectedIndex].path;
}

class _ArtworkCandidate {
  const _ArtworkCandidate({
    required this.path,
    required this.width,
    required this.height,
    required this.voteAverage,
    required this.voteCount,
  });

  final String path;
  final int width;
  final int height;
  final double voteAverage;
  final int voteCount;

  factory _ArtworkCandidate.fromJson(Map<String, dynamic> json) {
    return _ArtworkCandidate(
      path: json['file_path']?.toString().trim() ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
    );
  }

  double scoreFor(double targetAspectRatio) {
    final double aspectRatio =
        width > 0 && height > 0 ? width / height : targetAspectRatio;
    final double aspectPenalty = (aspectRatio - targetAspectRatio).abs() * 8;
    final double megapixels =
        width > 0 && height > 0 ? (width * height) / 1000000 : 0;
    final double resolutionScore = min(megapixels, 8) * 0.8;
    final double voteScore = min(voteAverage, 10) * 0.18;
    final double confidenceScore = log(voteCount + 1) * 0.22;
    return resolutionScore + voteScore + confidenceScore - aspectPenalty;
  }
}
