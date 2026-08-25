import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/services/tmdb_http_service.dart';

void main() {
  test('normalizes pasted TMDB credentials', () {
    expect(
      TmdbHttpService.normalizeCredential('  Bearer abc.def.ghi  '),
      'abc.def.ghi',
    );
    expect(
      TmdbHttpService.normalizeCredential('"v3-api-key"'),
      'v3-api-key',
    );
  });
}
