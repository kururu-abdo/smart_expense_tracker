import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'models.dart';

class BillingService {
  static const iosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const androidKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');
  bool _configured = false;
  String? _userId;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  String get key =>
      defaultTargetPlatform == TargetPlatform.iOS ? iosKey : androidKey;
  bool get legalConfigured =>
      Uri.tryParse(privacyUrl)?.scheme == 'https' &&
      Uri.tryParse(termsUrl)?.scheme == 'https';
  bool get available => supported && key.isNotEmpty;

  Future<void> identify(String userId) async {
    if (!available) throw const ApiFailure('billing_not_configured');
    if (kReleaseMode && key.startsWith('test_')) {
      throw const ApiFailure('billing_not_configured');
    }
    if (!_configured) {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
      await Purchases.configure(
        PurchasesConfiguration(key)..appUserID = userId,
      );
      _configured = true;
    } else if (_userId != userId) {
      await Purchases.logIn(userId);
    }
    _userId = userId;
  }

  Future<List<Package>> offerings(String userId) async {
    await identify(userId);
    final result = await Purchases.getOfferings();
    return result.current?.availablePackages ?? [];
  }

  Future<void> purchase(String userId, Package package) async {
    if (!legalConfigured) throw const ApiFailure('billing_not_configured');
    await identify(userId);
    await Purchases.purchase(PurchaseParams.package(package));
  }

  Future<void> restore(String userId) async {
    await identify(userId);
    await Purchases.restorePurchases();
  }

  Future<String?> managementUrl(String userId) async {
    await identify(userId);
    return (await Purchases.getCustomerInfo()).managementURL;
  }

  Future<void> logout() async {
    if (_configured) {
      try {
        await Purchases.logOut();
      } finally {
        _userId = null;
      }
    }
  }
}
