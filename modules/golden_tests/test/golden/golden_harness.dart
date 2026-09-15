// Golden-test plumbing: font loading, the device matrix, and the pump helper
// that renders a widget inside the real app theme so goldens match production.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/localization/app_translations.dart';
import 'package:flutter_starter/app/themes/app_theme.dart';
import 'package:flutter_starter/app/themes/theme_controller.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';

// ── Fonts ──

bool _fontsLoaded = false;

/// Registers every bundled font with the test engine.
///
/// `flutter test` boots with only the placeholder "FlutterTest" font, so any
/// `TextStyle(fontFamily: 'Inter')` — i.e. every [CustomTextStyles] entry — and
/// every icon glyph renders as a filled box until this runs. Call it before the
/// first pump; `test/golden/flutter_test_config.dart` does that automatically.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  TestWidgetsFlutterBinding.ensureInitialized();

  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (value) async => json.decode(value) as List<dynamic>,
  );

  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final assets = (entry['fonts'] as List? ?? []).cast<Map<String, dynamic>>();
    if (assets.isEmpty) continue;
    final loader = FontLoader(_familyOf(entry, assets));
    for (final asset in assets) {
      final path = asset['asset'] as String?;
      if (path != null) loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }

  _fontsLoaded = true;
}

/// Families the engine lets you replace wholesale; everything else keeps the
/// exact name `TextStyle.fontFamily` will ask for.
const Set<String> _engineOverridable = {
  'Roboto',
  '.SF UI Display',
  '.SF UI Text',
  '.SF Pro Text',
  '.SF Pro Display',
};

String _familyOf(Map<String, dynamic> entry, List<Map<String, dynamic>> assets) {
  final family = (entry['family'] as String?) ?? '';
  if (_engineOverridable.contains(family)) return family;
  if (family.startsWith('packages/')) {
    final short = family.split('/').last;
    return _engineOverridable.contains(short) ? short : family;
  }
  // A bare family whose assets live in a package must be namespaced back.
  for (final asset in assets) {
    final path = asset['asset'] as String? ?? '';
    if (path.startsWith('packages/')) {
      return 'packages/${path.split('/')[1]}/$family';
    }
  }
  return family;
}

// ── Device matrix ──

/// Figma reference size — `R` derives its scale from this.
const Size kPhoneSize = Size(375, 812);
const Size kTabletSize = Size(834, 1112);

/// One row of the matrix: a size, a brightness and a text scale.
///
/// No devicePixelRatio knob: `matchesGoldenFile` rasterises at 1.0 regardless,
/// so a 2x-DPR row produces a byte-identical PNG and buys nothing.
class GoldenScenario {
  final String name;
  final Size size;
  final Brightness brightness;
  final double textScale;

  const GoldenScenario({
    required this.name,
    this.size = kPhoneSize,
    this.brightness = Brightness.light,
    this.textScale = 1.0,
  });
}

/// The default matrix. Keep it small — every row is a committed PNG.
const List<GoldenScenario> kGoldenMatrix = [
  GoldenScenario(name: 'phone_light'),
  GoldenScenario(name: 'phone_dark', brightness: Brightness.dark),
  GoldenScenario(name: 'phone_text_2x', textScale: 2.0),
  GoldenScenario(name: 'tablet_light', size: kTabletSize),
  GoldenScenario(name: 'tablet_dark', size: kTabletSize, brightness: Brightness.dark),
  GoldenScenario(name: 'tablet_text_2x', size: kTabletSize, textScale: 2.0),
];

/// Phone-only subset, for a widget whose tablet rendering adds nothing.
const List<GoldenScenario> kPhoneOnlyMatrix = [
  GoldenScenario(name: 'phone_light'),
  GoldenScenario(name: 'phone_dark', brightness: Brightness.dark),
  GoldenScenario(name: 'phone_text_2x', textScale: 2.0),
];

// ── Pumping ──

/// The captured surface. Goldens are taken from this, never the raw widget, so
/// every image is exactly one device frame.
///
/// Holds a builder rather than a widget: the subject has to be constructed
/// inside [build] so `R.*` in the test's own code is re-evaluated against the
/// live MediaQuery, and so a rebuild actually produces a new child.
class GoldenSurface extends StatelessWidget {
  final Widget Function() builder;

  const GoldenSurface({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CustomColors.artboardColor(),
      child: Padding(
        padding: R.pad(all: 16),
        child: Center(child: builder()),
      ),
    );
  }
}

/// Renders [build] inside the real `GetMaterialApp` shell: app theme, GetX
/// translations, and a `ThemeController` forced to the scenario's brightness so
/// `CustomColors.*()` resolves the same way it does on device.
///
/// [build] is a closure, not a widget, because `CustomTextStyles`, `R` and
/// `CustomColors` all read live state — building eagerly bakes in the wrong
/// scale and the wrong brightness.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget Function() build, {
  required GoldenScenario scenario,
  bool settle = true,
  Duration pumpFor = const Duration(milliseconds: 300),
}) async {
  await loadAppFonts();

  tester.view.physicalSize = scenario.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());

  // CustomColors asks ThemeController which mode is active, so force it here
  // instead of relying on the host machine's platform brightness.
  Get.reset();
  addTearDown(() => Get.reset());
  Get.put(ThemeController()).themeModeRx.value =
      scenario.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;

  final app = GetMaterialApp(
    debugShowCheckedModeBanner: false,
    translations: AppTranslations(),
    locale: AppTranslations.fallbackLocale,
    fallbackLocale: AppTranslations.fallbackLocale,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: scenario.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scenario.textScale),
      ),
      child: child!,
    ),
    home: GoldenSurface(builder: build),
  );

  await tester.pumpWidget(app);
  settle ? await tester.pumpAndSettle() : await tester.pump(pumpFor);

  // R reads MediaQuery through Get.context, which only exists once the first
  // frame is up — rebuild so a tablet is not measured at the phone fallback.
  tester.element(find.byType(GoldenSurface)).markNeedsBuild();
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

// ── Asserting ──

/// Goldens are per-OS: the same widget rasterises differently on macOS and
/// Linux, so each platform files its own set instead of fighting over one.
String goldenPath(String name) =>
    'goldens/${Platform.operatingSystem}/$name.png';

Future<void> expectGolden(String name) =>
    expectLater(find.byType(GoldenSurface), matchesGoldenFile(goldenPath(name)));

/// Files one golden per matrix row: `<name>_<scenario>.png`.
///
///     goldenMatrixTest('custom_button', () => CustomButton(text: 'Sign In'.tr, onPressed: () {}));
void goldenMatrixTest(
  String name,
  Widget Function() build, {
  List<GoldenScenario> matrix = kGoldenMatrix,
  bool settle = true,
  Duration pumpFor = const Duration(milliseconds: 300),
}) {
  for (final scenario in matrix) {
    testWidgets('$name — ${scenario.name}', (tester) async {
      await pumpGolden(
        tester,
        build,
        scenario: scenario,
        settle: settle,
        pumpFor: pumpFor,
      );
      await expectGolden('${name}_${scenario.name}');
    });
  }
}

// ── Optional tolerant comparator ──

/// Allows up to [tolerance] percent of pixels to differ. Installed only when
/// GOLDEN_TOLERANCE is set, so the default path stays flutter's exact compare.
class TolerantGoldenComparator extends LocalFileComparator {
  final double tolerance;

  TolerantGoldenComparator(Uri basedir, {required this.tolerance})
      : super(basedir.resolve('golden_harness.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    // diffPercent is a 0..1 fraction; tolerance is expressed in percent.
    if (result.passed || result.diffPercent * 100 <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
