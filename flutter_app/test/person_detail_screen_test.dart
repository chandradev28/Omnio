import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/src/models/tmdb_media_models.dart';
import 'package:flutter_app/src/screens/person_detail_screen.dart';
import 'package:flutter_app/src/services/tmdb_person_service.dart';

class FakePeople extends TmdbPersonService {
  bool fail = false;
  int? requestedId;
  @override
  Future<List<CastItem>> search(String name) async => [
        CastItem.fromJson({'id': 123, 'name': name}),
      ];
  @override
  Future<PersonDetail> fetch(int id) async {
    requestedId = id;
    if (fail) throw Exception('offline');
    return PersonDetail.fromJson({
      'name': 'Test Actor',
      'biography': 'A complete biography.',
      'place_of_birth': 'London',
    });
  }
}

void main() {
  testWidgets('addon names require choosing a person before fetching biography',
      (tester) async {
    final service = FakePeople();
    await tester.pumpWidget(MaterialApp(
        home: PersonDetailScreen(
            member: CastItem.fromJson({'id': 0, 'name': 'Test Actor'}),
            service: service)));
    await tester.pumpAndSettle();
    expect(service.requestedId, isNull);
    expect(find.text('Choose the matching person'), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(service.requestedId, 123);
    expect(find.text('Birthplace: London'), findsOneWidget);
    expect(find.text('A complete biography.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TMDB failure is recoverable with retry', (tester) async {
    final service = FakePeople()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: PersonDetailScreen(
            member: CastItem.fromJson({'id': 123, 'name': 'Test Actor'}),
            service: service)));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('A complete biography.'), findsOneWidget);
  });
}
