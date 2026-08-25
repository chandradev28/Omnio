import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/app.dart';
import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/screens/home_screen.dart';
import 'package:flutter_app/src/services/stremio_addons_service.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('shows migrated home shell by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      OmnioApp(
        home: HomeScreen(
          mediaService: const FakeMediaService(),
          settingsRepository: FakeAppSettingsRepository(),
          addonsService: _EmptyAddonsService(),
          watchHistoryRepository: const FakeWatchHistoryRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey<String>('home-menu-button')),
      findsNothing,
    );
    expect(find.text('Streamed'), findsNothing);
    expect(find.text('Powered by your Stremio addons'), findsNothing);
    expect(find.text('Add your first catalog addon'), findsOneWidget);
    expect(find.text('Top 10 Movies This Week'), findsNothing);
    expect(find.text('New Releases'), findsNothing);
  });
}

class _EmptyAddonsService extends StremioAddonsService {
  @override
  Future<List<AddonManifest>> getInstalledAddons() async {
    return const <AddonManifest>[];
  }

  @override
  Future<List<AddonCatalogRow>> fetchAllCatalogRows() async {
    return const <AddonCatalogRow>[];
  }
}
