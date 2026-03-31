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
        final status = await Permission.storage.request();
        if (status.isDenied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission chahiye PDF kholne ke liye')));
          return;
        }
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
      if (result?.files.single.path == null) return;
      pdfPath = result!.files.single.path!;
    }

    // Save to recent
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
      _loadRecent(); // Refresh after returning
    }
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
      // FAB with safe area — stays above home indicator
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

  // ── Home Tab ─────────────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + title
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
              const Text('Duniya ka pehla Video PDF Viewer',
                style: TextStyle(color: AppColors.cyan, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 32),

          // Feature grid
          const Text('App Ki Khasiyatein',
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
                subtitle: 'Sirf hamare app mein!',
              ),
              _FeatureTile(
                icon: Icons.bookmark,
                color: Color(0xFFFF9800),
                title: 'Bookmarks',
                subtitle: 'Pages mark karein',
              ),
              _FeatureTile(
                icon: Icons.history,
                color: Color(0xFF4CAF50),
                title: 'Reading Progress',
                subtitle: 'Jahan chhoda wahan se shuru',
              ),
              _FeatureTile(
                icon: Icons.dark_mode,
                color: Color(0xFF9C27B0),
                title: 'Night Mode',
                subtitle: 'Aankhon ko aaraam',
              ),
              _FeatureTile(
                icon: Icons.share,
                color: Color(0xFF2196F3),
                title: 'Page Share',
                subtitle: 'Page image se share karein',
              ),
              _FeatureTile(
                icon: Icons.zoom_in,
                color: Color(0xFFFF5722),
                title: 'Pinch Zoom',
                subtitle: 'Smooth zoom in/out',
              ),
            ],
          ),
          const SizedBox(height: 80), // FAB space
        ],
      ),
    );
  }

  // ── Recent Tab ────────────────────────────────────────────────────────────

  Widget _buildRecentTab() {
    if (_recentFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppColors.sub),
            SizedBox(height: 12),
            Text('Koi recent file nahi', style: TextStyle(color: AppColors.sub)),
            SizedBox(height: 4),
            Text('Pehle koi PDF kholein',
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
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: f.totalPages > 0 ? f.lastPage/f.totalPages : 0,
                            backgroundColor: AppColors.accent2,
                            color: AppColors.accent,
                            minHeight: 4),
                        ),
                        const SizedBox(height: 4),
                        Text('Page ${f.lastPage}/${f.totalPages} ($pct%)',
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
            Text('Duniya ka pehla PDF viewer jo embedded videos ko '
                 'seedha PDF ke andar play karta hai!',
              style: TextStyle(color: AppColors.sub, fontSize: 13)),
            SizedBox(height: 12),
            Text('Features:',
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              '• Video PDF ke andar play hoti hai\n'
              '• Bookmarks — pages mark karein\n'
              '• Reading progress yaad rahti hai\n'
              '• Night mode — aankhon ke liye\n'
              '• Page ko image se share karein\n'
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
