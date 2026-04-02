// PDF Pro Reader - Main Entry Point
// Video-enabled PDF viewer for Android & Windows

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:video_player_win/video_player_win.dart';

import 'screens/home_screen.dart';
import 'screens/reader_screen.dart';
import 'theme.dart';

/// Global navigator key — used to push ReaderScreen when a new PDF intent
/// arrives while the app is already running in the background.
final _navKey = GlobalKey<NavigatorState>();

/// MethodChannel that communicates with MainActivity.kt (Android intent handling).
const _intentChannel = MethodChannel('com.pdfpro/intent');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob (Android only)
  if (Platform.isAndroid) {
    await MobileAds.instance.initialize();
  }

  // Initialize Windows video back-end
  if (Platform.isWindows) {
    WindowsVideoPlayer.registerWith();
  }

  // ── Intent handling (Android) ───────────────────────────────────────────
  // Ask MainActivity if the app was launched by opening a PDF file.
  String? initialPdf;
  if (Platform.isAndroid) {
    try {
      initialPdf =
          await _intentChannel.invokeMethod<String>('getInitialPdf');
    } catch (_) {
      // Not on Android or channel not available — continue normally.
    }
  }

  // Listen for new PDF intents while the app is already running.
  _intentChannel.setMethodCallHandler((call) async {
    if (call.method == 'onNewPdf') {
      final path = call.arguments as String?;
      if (path != null && path.isNotEmpty) {
        _navKey.currentState?.push(
          MaterialPageRoute(builder: (_) => ReaderScreen(pdfPath: path)),
        );
      }
    }
  });

  runApp(PdfProReaderApp(initialPdf: initialPdf));
}

class PdfProReaderApp extends StatelessWidget {
  final String? initialPdf;
  const PdfProReaderApp({super.key, this.initialPdf});

  @override
  Widget build(BuildContext context) {
    // If the app was opened by tapping a PDF in the file manager or WhatsApp,
    // go straight to the reader; otherwise show the home screen.
    final home = (initialPdf != null && initialPdf!.isNotEmpty)
        ? ReaderScreen(pdfPath: initialPdf!)
        : const HomeScreen();

    return MaterialApp(
      navigatorKey: _navKey,
      title: 'PDF Pro Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: home,
    );
  }
}
