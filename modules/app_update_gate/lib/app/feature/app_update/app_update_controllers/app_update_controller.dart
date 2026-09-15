import 'package:flutter_starter/app/feature/app_update/app_update_logic/app_update_api_service.dart';
import 'package:flutter_starter/app/feature/app_update/app_update_logic/app_update_store.dart';
import 'package:flutter_starter/app/feature/app_update/app_update_models/app_update_info.dart';
import 'package:flutter_starter/app/feature/app_update/app_update_models/semantic_version.dart';
import 'package:flutter_starter/app/feature/app_update/app_update_presentation/force_update_screen.dart';
import 'package:flutter_starter/app/feature/app_update/app_update_presentation/soft_update_sheet.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/utils/platform_utils.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';
import 'package:flutter_starter/app/widgets/layout/custom_bottom_sheet.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateController extends GetxController {
  final AppUpdateRepo _repo = AppUpdateRepo();

  final RxBool isLoadingCheck = false.obs;
  final RxBool isLaunchingStore = false.obs;

  /// The running build, e.g. "1.4.2".
  String currentVersion = '';
  String buildNumber = '';
  String packageName = '';

  /// Last payload from the backend; null until [runGate] has fetched one.
  AppUpdateInfo? info;
  AppUpdateAction action = AppUpdateAction.none;

  /// How long "Remind me later" silences the soft sheet.
  static Duration snoozeFor = const Duration(days: 1);

  /// Caps the version check. The core Dio client waits 50s, which is far too
  /// long to hold a launch on; a timeout resolves to [AppUpdateAction.none].
  static Duration fetchTimeout = const Duration(seconds: 8);

  /// Test hooks — set these to exercise both paths without a backend.
  static AppUpdateInfo? debugInfo;
  static String? debugCurrentVersion;

  String get platformKey => PlatformUtils.isIOS ? 'ios' : 'android';

  /// Backend link for this platform, falling back to a store link we can build.
  String get storeUrl {
    final fromBackend = info?.urlFor(isIOS: PlatformUtils.isIOS) ?? '';
    if (fromBackend.isNotEmpty) return fromBackend;
    if (PlatformUtils.isIOS) {
      final id = info?.iosAppId ?? '';
      return id.isEmpty ? '' : 'https://apps.apple.com/app/id$id';
    }
    return packageName.isEmpty
        ? ''
        : 'https://play.google.com/store/apps/details?id=$packageName';
  }

  /// Runs the gate and shows the matching UI. Safe to call on every launch.
  /// Fire it without awaiting from a screen that is already routed — awaiting
  /// it on the splash's critical path parks the user behind a network call.
  Future<AppUpdateAction> runGate({bool showUi = true}) async {
    action = await _decide();
    update();

    if (!showUi) return action;
    if (action == AppUpdateAction.force) {
      Get.offAll(() => const ForceUpdateScreen());
    } else if (action == AppUpdateAction.soft) {
      await showSoftUpdateSheet();
    }
    return action;
  }

  /// Fetch + compare. Anything unknown resolves to [AppUpdateAction.none] —
  /// a broken gate must never lock users out of the app.
  Future<AppUpdateAction> _decide() async {
    isLoadingCheck.value = true;
    try {
      await _readPackageInfo();

      info =
          debugInfo ??
          await _repo
              .fetchVersionGate(
                platform: platformKey,
                currentVersion: currentVersion,
                buildNumber: buildNumber,
              )
              .timeout(fetchTimeout);

      final AppUpdateInfo? gate = info;
      if (gate == null) return AppUpdateAction.none;

      // An unreadable running version is our fault, not the user's — let it by.
      final running = SemanticVersion.tryParse(currentVersion);
      if (running == null) return AppUpdateAction.none;

      final minimum = SemanticVersion.tryParse(gate.minSupportedVersion);
      final latest = SemanticVersion.tryParse(gate.latestVersion);

      // Below the minimum supported build, or the backend pulled the switch.
      if (minimum != null && running < minimum) return AppUpdateAction.force;
      if (gate.force && latest != null && running < latest) {
        return AppUpdateAction.force;
      }

      if (latest == null || running >= latest) return AppUpdateAction.none;
      if (await _isSnoozed(gate.latestVersion)) return AppUpdateAction.none;
      return AppUpdateAction.soft;
    } catch (e) {
      devPrint('$e', tag: 'AppUpdate');
      return AppUpdateAction.none;
    } finally {
      isLoadingCheck.value = false;
    }
  }

  Future<void> _readPackageInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    currentVersion = debugCurrentVersion ?? pkg.version;
    buildNumber = pkg.buildNumber;
    packageName = pkg.packageName;
  }

  // A newer release re-arms the sheet even inside an active snooze window.
  Future<bool> _isSnoozed(String version) async {
    if (version.isEmpty) return false;
    if (await AppUpdateStore.snoozedVersion() != version) return false;
    final at = await AppUpdateStore.snoozedAt();
    if (at == null) return false;
    return DateTime.now().difference(at) < snoozeFor;
  }

  /// Shows the dismissible sheet; any way out counts as "remind me later".
  Future<void> showSoftUpdateSheet() async {
    final target = info?.latestVersion ?? '';
    await showCustomBottomSheet<void>(
      sheetTitle: info?.title.isNotEmpty == true
          ? info!.title
          : 'Update available'.tr,
      height: R.h(380),
      content: const SoftUpdateSheet(),
    );
    await AppUpdateStore.snooze(target);
  }

  /// Hands the store link to the OS.
  Future<bool> openStore() async {
    final uri = Uri.tryParse(storeUrl);
    if (storeUrl.isEmpty || uri == null) {
      _warn('No store link was provided for this platform.'.tr);
      return false;
    }

    isLaunchingStore.value = true;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _warn('Could not open the store.'.tr);
      return opened;
    } catch (e) {
      devPrint('$e', tag: 'AppUpdate');
      _warn('Could not open the store.'.tr);
      return false;
    } finally {
      isLaunchingStore.value = false;
    }
  }

  /// Clears the snooze so the next check shows the sheet again.
  Future<void> resetSnooze() => AppUpdateStore.clear();

  void _warn(String description) {
    final context = Get.context;
    if (context == null) return;
    showCustomSnackBar(
      context: context,
      type: SnackBarType.Warning,
      title: 'Update'.tr,
      description: description,
    );
  }
}
