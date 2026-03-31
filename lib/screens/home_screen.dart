import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme.dart';
import '../services/admob_service.dart';
import '../services/prefs_service.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  BannerAd?        _bannerAd;
  bool             _bannerLoaded = false;
  List<RecentFile> _recentFiles  = [];
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadBannerAd();
    _loadRecent();
  }

  void _loadBannerAd() {
    _bannerAd = AdMobService.createBannerAd(
      onLoaded: (ad) => setState(() => _bannerLoaded = true),
    );
    _bannerAd?.load();
  }

  Future<void> _loadRecent() async {
    final r = await PrefsService.getRecentFiles();
    if (mounted) setState(() => _recentFiles = r);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _openPdf({String? forcePath}) async {
    String? pdfPath = forcePath;

    if (pdfPath == null) {
      if (Platform.isAndroid) {
        // Android 13+ (SDK 33+) — no storage permission needed, use media permissions
        // Android < 13 — request storage permission
        final sdkInt = await _getAndroidSdkInt();
        if (sdkInt < 33) {
          final status = await Permission.storage.request();
          if (status.isPermanentlyDenied) {
            _showPermissionDialog();
            return;
          }
          if (status.isDenied) {
            _showPermissionDialog();
            return;
          }
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
      if (result?.files.single.path == null) return;
      pdfPath = result!.files.single.path!;
    }

    final name = pdfPath.split(Platform.pathSeparator).last;
    await PrefsService.addRecentFile(RecentFile(
      path: pdfPath, name: name,
      lastPage: 1, totalPages: 1,
      openedAt: DateTime.now(),
    ));

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderScreen(pdfPath: pdfPath!)),
      );
      _loadRecent();
    }
  }

  Future<int> _getAndroidSdkInt() async {
    try {
      if (!Platform.isAndroid) return 0;
      // Default to 33+ to skip legacy storage permission on modern devices
      return 33;
    } catch (_) {
      return 33;
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Permission Required',
          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
        content: const Text(
          'Storage permission is required to open PDF files.\n\n'
          'Please tap "Open Settings" and enable the storage or files permission for this app.',
          style: TextStyle(color: AppColors.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.sub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Opens directly to app settings page
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Pro Reader'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.accent,
          labelColor:     AppColors.accent,
          unselectedLabelColor: AppColors.sub,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Home'),
            Tab(icon: Icon(Icons.history), text: 'Recent'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: _showAbout),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildHomeTab(),
                _buildRecentTab(),
              ],
            ),
          ),
          if (_bannerLoaded && _bannerAd != null)
            SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SafeArea(
        child: FloatingActionButton.extended(
          onPressed: _openPdf,
          backgroundColor: AppColors.accent,
          icon: const Icon(Icons.folder_open),
          label: const Text('Open PDF',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent2, AppColors.accent],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                    color: AppColors.accent.withOpacity(.4),
                    blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.picture_as_pdf, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('PDF Pro Reader',
                style: TextStyle(color: AppColors.text, fontSize: 26,
                  fontWeight: FontWeight.bold)),
              const Text("World's First Video PDF Viewer",
                style: TextStyle(color: AppColors.cyan, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 32),

          const Text('App Features',
            style: TextStyle(color: AppColors.text, fontSize: 16,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: const [
              _FeatureTile(
                icon: Icons.videocam,
                color: AppColors.cyan,
                title: 'Video in PDF',
                subtitle: 'Only in our app!',
              ),
              _FeatureTile(
                icon: Icons.bookmark,
                color: Color(0xFFFF9800),
                title: 'Bookmarks',
                subtitle: 'Mark your pages',
              ),
              _FeatureTile(
                icon: Icons.history,
                color: Color(0xFF4CAF50),
                title: 'Reading Progress',
                subtitle: 'Resume where you left',
              ),
              _FeatureTile(
                icon: Icons.dark_mode,
                color: Color(0xFF9C27B0),
                title: 'Night Mode',
                subtitle: 'Easy on the eyes',
              ),
              _FeatureTile(
                icon: Icons.share,
                color: Color(0xFF2196F3),
                title: 'Share Page',
                subtitle: 'Share as image',
              ),
              _FeatureTile(
                icon: Icons.zoom_in,
                color: Color(0xFFFF5722),
                title: 'Pinch Zoom',
                subtitle: 'Smooth zoom in/out',
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildRecentTab() {
    if (_recentFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppColors.sub),
            SizedBox(height: 12),
            Text('No recent files', style: TextStyle(color: AppColors.sub)),
            SizedBox(height: 4),
            Text('Open a PDF to get started',
              style: TextStyle(color: AppColors.sub, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _recentFiles.length,
      itemBuilder: (ctx, i) {
        final f = _recentFiles[i];
        final pct = f.totalPages > 0
            ? (f.lastPage / f.totalPages * 100).round() : 0;
        return Card(
          color: AppColors.card,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _openPdf(forcePath: f.path),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(.15),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.picture_as_pdf,
                      color: AppColors.accent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name,
                          style: const TextStyle(
                            color: AppColors.text, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: f.totalPages > 0 ? f.lastPage/f.totalPages : 0,
                            backgroundColor: AppColors.accent2,
                            color: AppColors.accent,
                            minHeight: 4),
                        ),
                        const SizedBox(height: 4),
                        Text('Page ${f.lastPage} of ${f.totalPages} ($pct%)',
                          style: const TextStyle(
                            color: AppColors.sub, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.sub),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('PDF Pro Reader', style: TextStyle(color: AppColors.accent)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0',
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("World's first PDF viewer that plays embedded videos directly inside PDF!",
              style: TextStyle(color: AppColors.sub, fontSize: 13)),
            SizedBox(height: 12),
            Text('Features:',
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              '• Video playback inside PDF\n'
              '• Bookmarks — mark your pages\n'
              '• Reading progress saved\n'
              '• Night mode — eye comfort\n'
              '• Share page as image\n'
              '• Pinch zoom — smooth zoom\n'
              '• Android & Windows support',
              style: TextStyle(color: AppColors.sub, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;
  const _FeatureTile({required this.icon, required this.color,
    required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        border: Border.all(color: color.withOpacity(.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(title,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(subtitle,
            style: const TextStyle(color: AppColors.sub, fontSize: 11)),
        ],
      ),
    );
  }
}
