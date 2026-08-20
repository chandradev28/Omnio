String getImageUrl(String? path, [String size = 'w500']) {
  if (path == null || path.isEmpty) {
    return 'https://via.placeholder.com/500x750?text=No+Image';
  }

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }

  return 'https://image.tmdb.org/t/p/$size$path';
}

/// Returns the direct TMDB image first, then image proxies for networks that
/// block image.tmdb.org even when the API route is available through WARP.
List<String> getImageCandidates(String? path, [String size = 'w500']) {
  final String direct = getImageUrl(path, size);
  if (!direct.contains('image.tmdb.org')) {
    return <String>[direct];
  }

  final String encoded = Uri.encodeComponent(direct);
  return <String>[
    direct,
    'https://wsrv.nl/?url=$encoded',
    'https://images.weserv.nl/?url=$encoded',
  ];
}
