import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/screens/onboarding_screen.dart';

import 'support/ad_test_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final locale in const [Locale('zh', 'TW'), Locale('en')]) {
    for (final configuration in const [
      (size: Size(320, 568), scale: 1.0),
      (size: Size(320, 568), scale: 1.3),
      (size: Size(390, 844), scale: 1.3),
    ]) {
      testWidgets(
        'only regions scroll and database actions stay visible in $locale at $configuration',
        (tester) async {
          final controller = await createAdTestController();
          addTearDown(controller.dispose);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = configuration.size;
          tester.view.padding = FakeViewPadding(top: 24, bottom: 34);
          addTearDown(() {
            tester.view.resetDevicePixelRatio();
            tester.view.resetPhysicalSize();
            tester.view.resetPadding();
          });

          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(configuration.scale)),
                child: child!,
              ),
              home: AppControllerScope(
                controller: controller,
                child: const OnboardingScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(OnboardingScreen)),
          );
          await tester.ensureVisible(find.text(l10n.onboardingStart));
          await tester.tap(find.text(l10n.onboardingStart));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(l10n.onboardingChooseManually));
          await tester.tap(find.text(l10n.onboardingChooseManually));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final download = find.widgetWithText(
            FilledButton,
            l10n.commonDownload,
          );
          final back = find.widgetWithText(OutlinedButton, l10n.commonBack);
          final later = find.widgetWithText(FilledButton, l10n.commonLater);
          final title = find.text(l10n.onboardingDownloadTitle);
          final regions = find.ancestor(
            of: find.byType(FilterChip).first,
            matching: find.byType(SingleChildScrollView),
          );
          expect(regions, findsOneWidget);
          final positions = {
            for (final finder in [download, back, later, title])
              finder: tester.getRect(finder),
          };
          for (final action in [download, back, later]) {
            expect(action.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(action).bottom,
              lessThanOrEqualTo(configuration.size.height - 34),
            );
            expect(
              find.ancestor(
                of: action,
                matching: find.byType(SingleChildScrollView),
              ),
              findsNothing,
            );
          }

          expect(tester.getSize(regions).height, greaterThanOrEqualTo(64));
          await tester.scrollUntilVisible(
            find.text(downloadableBusProviders().last.label),
            200,
            scrollable: find.descendant(
              of: regions,
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(downloadableBusProviders().last.label).hitTestable(),
            findsOneWidget,
          );
          for (final entry in positions.entries) {
            expect(tester.getRect(entry.key), entry.value);
          }
          expect(tester.takeException(), isNull);

          await tester.tap(later);
          await tester.pumpAndSettle();
          expect(controller.settings.hasCompletedOnboarding, isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
