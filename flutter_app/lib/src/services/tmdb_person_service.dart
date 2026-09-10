import '../models/tmdb_media_models.dart';
import 'tmdb_http_service.dart';

class PersonCredit {
  const PersonCredit(this.media, this.role);
  final MediaSummary media;
  final String role;
}

class PersonDetail {
  PersonDetail.fromJson(Map<String, dynamic> json)
      : name = json['name']?.toString() ?? '',
        biography = json['biography']?.toString() ?? '',
        profilePath = json['profile_path'] as String?,
        birthday = json['birthday'] as String?,
        deathday = json['deathday'] as String?,
        birthplace = json['place_of_birth'] as String?,
        department = json['known_for_department'] as String?,
        aliases =
            (json['also_known_as'] as List? ?? []).whereType<String>().toList(),
        credits = _credits(json['combined_credits']),
        photos = ((json['images'] as Map?)?['profiles'] as List? ?? [])
            .whereType<Map>()
            .map((p) => p['file_path'])
            .whereType<String>()
            .toList();

  final String name, biography;
  final String? profilePath, birthday, deathday, birthplace, department;
  final List<String> aliases, photos;
  final List<PersonCredit> credits;

  static List<PersonCredit> _credits(dynamic payload) {
    if (payload is! Map) return [];
    final Map<String, PersonCredit> result = {};
    for (final item in [
      ...(payload['cast'] as List? ?? []),
      ...(payload['crew'] as List? ?? [])
    ]) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! num ||
          !['movie', 'tv'].contains(item['media_type'])) continue;
      final media = MediaSummary.fromJson(item);
      final key = '${media.mediaType}:${media.id}';
      final role = (item['character'] ?? item['job'] ?? '').toString();
      final existing = result[key];
      result[key] = PersonCredit(
          media,
          existing == null || existing.role == role
              ? role
              : [existing.role, role].where((s) => s.isNotEmpty).join(' / '));
    }
    return result.values.toList()
      ..sort((a, b) => b.media.releaseDate.compareTo(a.media.releaseDate));
  }
}

class TmdbPersonService {
  TmdbPersonService({TmdbHttpService? http})
      : _http = http ?? TmdbHttpService();
  final TmdbHttpService _http;

  Future<PersonDetail> fetch(int id) async => PersonDetail.fromJson(
        await _http.getJson('/person/$id', params: {
          'append_to_response': 'combined_credits,images',
          'language': 'en-US',
        }),
      );

  Future<List<CastItem>> search(String name) async {
    final json = await _http.getJson('/search/person', params: {'query': name});
    return (json['results'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((item) => item['id'] is int)
        .map(CastItem.fromJson)
        .toList();
  }
}
