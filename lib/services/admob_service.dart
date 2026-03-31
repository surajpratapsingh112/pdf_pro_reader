// AdMob Monetization Service
// Banner + Interstitial ads

import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  // ── Ad Unit IDs ──────────────────────────────────────────────────────────
  // TODO: Replace test IDs with real IDs from AdMob console after approval

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // TEST ID (replace with real ID before publishing)
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    return 'ca-app-pub-3940256099942544/6300978111';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      // TEST ID (replace with real ID before publishing)
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    return 'ca-app-pub-3940256099942544/1033173712';
  }

  // ── Banner Ad ────────────────────────────────────────────────────────────
  static BannerAd? createBannerAd({required void Function(Ad) onLoaded}) {
    if (!Platform.isAndroid) return null;
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
  }

  // ── Interstitial Ad ──────────────────────────────────────────────────────
  static Future<InterstitialAd?> loadInterstitial() async {
    if (!Platform.isAndroid) return null;
    InterstitialAd? ad;
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded:       (loadedAd) { ad = loadedAd; },
        onAdFailedToLoad: (error)    {},
      ),
    );
    return ad;
  }
}
