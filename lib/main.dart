// PDF Pro Reader - Main Entry Point
// Video-enabled PDF viewer for Android & Windows

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:video_player_win/video_player_win.dart';
import 'dart:io' show Platform;

import 'screens/home_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob
  if (Platform.isAndroid) {
    await MobileAds.instance.initialize();
  }

  // Initialize Windows video player
  if (Platform.isWindows) {
    WindowsVideoPlayer.registerWith();
  }

  runApp(const PdfProReaderApp());
}

class PdfProReaderApp extends StatelessWidget {
  const PdfProReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Pro Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
