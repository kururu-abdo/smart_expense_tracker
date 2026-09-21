import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masar/core/controller.dart';
import 'package:masar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppController> demo(
  WidgetTester tester, {
  String locale = 'en',
  bool dark = false,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({'locale': locale, 'dark': dark});
  final c = AppController(await SharedPreferences.getInstance());
  await c.startDemo(today: DateTime(2026, 9, 20));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [controllerProvider.overrideWith((ref) => c)],
      child: const MasarApp(),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) return;
  final previousShadows = debugDisableShadows;
  try {
    debugDisableShadows = false;
    for (final object in tester.allRenderObjects) {
      object.markNeedsPaint();
    }
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('../docs/screenshots');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = previousShadows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final pair in {
      'Manrope': 'Manrope',
      'NotoArabic': 'NotoSansArabic',
    }.entries) {
      final loader = FontLoader(pair.key);
      for (final weight in [400, 500, 600, 700, 800]) {
        loader.addFont(
          rootBundle.load('assets/fonts/${pair.value}-$weight.ttf'),
        );
      }
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('English dashboard renders without overflow', (tester) async {
    await demo(tester);
    expect(find.text('This month’s balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'dashboard-en');
  });
  testWidgets('Arabic dashboard uses RTL and renders without overflow', (
    tester,
  ) async {
    await demo(tester, locale: 'ar');
    expect(find.text('رصيد الشهر'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('رصيد الشهر'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    await capture(tester, 'dashboard-ar');
  });
  testWidgets('Tablet and dark layouts render without overflow', (
    tester,
  ) async {
    await demo(tester, dark: true, size: const Size(1200, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'dashboard-tablet-dark');
  });
  testWidgets('Large Arabic text stays usable on narrow screens', (
    tester,
  ) async {
    await demo(
      tester,
      locale: 'ar',
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.donut_large_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Add expense flow updates dashboard and activity', (
    tester,
  ) async {
    final c = await demo(tester);
    final now = DateTime.now();
    c.month = DateTime(now.year, now.month);
    await c.refresh();
    await tester.pumpAndSettle();
    final before = c.overview.expense;
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final amount = find.widgetWithText(TextFormField, 'Amount');
    await tester.enterText(amount, '12.50');
    final note = find.widgetWithText(TextFormField, 'What was it for?');
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Widget test coffee');
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(c.overview.expense, before + 1250);
    await tester.tap(find.byIcon(Icons.swap_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Widget test coffee'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Settings changes language and theme; demo paywall cannot buy', (
    tester,
  ) async {
    final c = await demo(tester);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(c.dark, isTrue);
    await c.setLocale('ar');
    await tester.pumpAndSettle();
    expect(find.text('الوضع الداكن'), findsOneWidget);
    await tester.tap(find.text('اكتشف بريميوم').first);
    await tester.pumpAndSettle();
    expect(find.text('سجّل دخولك بحسابك عشان تشترك.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await capture(tester, 'premium-ar');
  });
}
