import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme.dart';
import '../services/admob_service.dart';
import '../services/prefs_service.dart';
import 'reader_screen.dart';

// ── Feature data model ────────────────────────────────────────────────────────

class _FeatureInfo {
  final IconData    icon;
  final Color       color;
  final String      title;
  final String      subtitle;
  final String      headline;
  final String      description;
  final List<String> steps;
  final bool        isStar;

  const _FeatureInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.headline,
    required this.description,
    this.steps  = const [],
    this.isStar = false,
  });
}

// ── All features (index 0 = Video — the hero feature) ────────────────────────

const List<_FeatureInfo> _kFeatures = [

  _FeatureInfo(
    icon:     Icons.videocam,
    color:    AppColors.cyan,
    title:    'Video in PDF',
    subtitle: 'World\'s First — Only here!',
    isStar:   true,
    headline: 'The World\'s First PDF Viewer with Inline Video Playback!',
    description:
      'No other PDF viewer in existence can play embedded videos directly '
      'inside the PDF page — not a single competing app offers this. '
      'PDF Pro Reader is the world\'s first and only app that plays a video '
      'right inside the exact box on the PDF page where it was embedded, '
      'with full audio support.\n\n'
      'To embed a video into a PDF, you need our companion desktop app '
      '"PDF Pro Suite" for Windows (coming soon). Once the video is embedded, '
      'PDF Pro Reader automatically detects it and plays it inline — '
      'no popup window, no redirection, just play right on the page.',
    steps: [
      'On your Windows PC, open "PDF Pro Suite" (companion app — coming soon).',
      'Open any PDF and choose the "Embed Video" tool.',
      'Draw a box on the page where you want the video to appear.',
      'Select your video file — it gets embedded into the PDF.',
      'Transfer the video-embedded PDF to your Android phone.',
      'Open the PDF in PDF Pro Reader.',
      'A cyan-bordered play button appears on the page — tap it.',
      'The video plays inline, right inside that box, with full sound!',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.auto_fix_high,
    color:    Color(0xFF7C4DFF),
    title:    'Enhance Page',
    subtitle: 'Clean, Darken, Fix scans',
    headline: 'Transform Any Scanned or Old PDF into a Crystal-Clear Document',
    description:
      'Scanned documents often suffer from yellowing, stains, shadows, '
      'faded text or pen marks. The Enhance Page tool provides three '
      'powerful cleaning modes plus text darkening and mark removal:\n\n'
      '• B&W Clean — Remove yellowing; pure white background with sharp black text\n'
      '• Color Clean — Histogram stretch + gamma correction for vivid color docs\n'
      '• Shadow Clean — Fix uneven lighting in camera-photographed documents\n'
      '• Text Darkening — Make faded text darker without altering the background\n'
      '• Mark Removal — Erase pen, pencil, and highlighter marks by color',
    steps: [
      'Open any PDF and navigate to the page you want to enhance.',
      'Tap the ⋮ menu → "✨ Enhance Page".',
      'Choose a Page Cleaning mode: B&W / Color / Shadow (or leave Off).',
      'Adjust the Strength slider.',
      'Toggle "Text Darkening" on if the text is faded.',
      'Toggle "Mark Removal" on and select the mark colour.',
      'Tap "Apply to This Page" — processing runs in the background.',
      'The enhanced result appears on the page automatically.',
      'Tap "Done ✓" in the top bar to save your changes.',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.edit_off,
    color:    Color(0xFFEF5350),
    title:    'Eraser Tool',
    subtitle: 'Draw to erase content',
    headline: 'Erase Unwanted Content with Your Finger',
    description:
      'Draw over any area on the page with your finger to erase it — '
      'works exactly like a white eraser on the page image. '
      'Adjust the eraser size with the slider for precision.\n\n'
      '⚠️  Legal Warning: This tool is intended for personal documents only '
      '— your own notes, study material, and drafts. Using it to alter '
      'official, legal, or government documents may constitute forgery '
      'as per the law of your country.',
    steps: [
      'Tap ⋮ menu → "✏️ Eraser Tool".',
      'Read the legal warning carefully and tap "I Understand".',
      'A red control bar appears at the bottom — adjust eraser size with the slider.',
      'Draw freely on the page with your finger — white circles erase content.',
      'Tap "Apply Eraser" — changes are baked into the page image.',
      'Tap "Done ✓" in the top bar to save.',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.save,
    color:    Color(0xFF00BCD4),
    title:    'Save Changes',
    subtitle: 'Original or new file',
    headline: 'Save Your Enhanced or Erased PDF',
    description:
      'After enhancing pages or using the eraser, save your changes '
      'permanently with two options:\n\n'
      '• Save to Original — overwrites the original file in place\n'
      '• Save as New File — creates a separate "_enhanced.pdf" file\n\n'
      'The app renders all pages and builds a complete PDF before saving. '
      'A progress indicator is shown during this process.',
    steps: [
      'Make changes using Enhance Page and/or the Eraser Tool.',
      'A green "Done ✓" button appears in the top bar.',
      'Tap "Done ✓".',
      'Choose "Save to Original" or "Save as New File".',
      'Wait for "Building PDF…" to complete.',
      'A confirmation message shows the saved file name.',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.print,
    color:    Color(0xFF607D8B),
    title:    'Print PDF',
    subtitle: 'Via any WiFi printer',
    headline: 'Print the PDF Directly from Your Phone',
    description:
      'Send the PDF to any WiFi-connected printer directly from your phone. '
      'The app uses the Android system print service, which supports '
      'all major wireless printers and also allows you to save as PDF.\n\n'
      'If you have made enhancements, the modified version is printed.',
    steps: [
      'Tap ⋮ menu → "🖨️ Print PDF".',
      'The app builds the PDF (with any enhancements applied).',
      'The Android Print dialog opens.',
      'Select your printer or choose "Save as PDF".',
      'Set copies, orientation, and page range as needed.',
      'Tap "Print".',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.ios_share,
    color:    Color(0xFF4CAF50),
    title:    'Share Full PDF',
    subtitle: 'WhatsApp, Email, Drive…',
    headline: 'Share the Complete PDF via Any App',
    description:
      'Share the full PDF file through any app on your phone — '
      'messaging apps, email, cloud storage, and more.\n\n'
      'If no changes have been made, the original file is shared directly '
      '(instant). If enhancements or erasures have been applied, '
      'the modified PDF is built first and then shared.',
    steps: [
      'Tap ⋮ menu → "📤 Share Full PDF".',
      'If modifications exist, the app builds the PDF first.',
      'The system Share Sheet opens.',
      'Select your destination app and send.',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.share,
    color:    Color(0xFF2196F3),
    title:    'Share Page',
    subtitle: 'Single page as image',
    headline: 'Share a Single Page as a High-Quality Image',
    description:
      'When you only need to share one important page rather than the '
      'whole PDF, use this feature. The current page is rendered as a '
      'high-quality JPEG image and shared through the system share sheet.',
    steps: [
      'Navigate to the page you want to share.',
      'Tap ⋮ menu → "📤 Share Page".',
      'The page is converted to an image.',
      'Choose your destination from the Share Sheet.',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.bookmark,
    color:    Color(0xFFFF9800),
    title:    'Bookmarks',
    subtitle: 'Mark important pages',
    headline: 'Bookmark Important Pages for Instant Access',
    description:
      'Bookmark any page so you can jump back to it instantly at any time. '
      'Bookmarks are saved permanently — closing and reopening the app '
      'or even restarting your phone will not lose them.',
    steps: [
      'Navigate to the page you want to bookmark.',
      'Tap the 🔖 icon in the top bar — the page is bookmarked.',
      'Tap it again to remove the bookmark.',
      'To view all bookmarks: ⋮ menu → "🔖 Bookmarks".',
      'Tap any bookmark in the list to jump directly to that page.',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.history,
    color:    Color(0xFF8BC34A),
    title:    'Reading Progress',
    subtitle: 'Auto-resume where you left',
    headline: 'Resume Exactly Where You Left Off',
    description:
      'Your reading position is saved automatically every few pages. '
      'Close the PDF, restart the app, or even reboot your phone — '
      'the next time you open the file it picks up right where you stopped.\n\n'
      'The Recent tab shows a progress bar for every file.',
    steps: [
      'Open any PDF and read to any page.',
      'Close the PDF or the app — progress is saved automatically.',
      'On the Home screen, check the Recent tab for the progress bar.',
      'Tap the file — it opens to the exact page you left.',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.dark_mode,
    color:    Color(0xFF9C27B0),
    title:    'Night Mode',
    subtitle: 'Easy on your eyes',
    headline: 'Read Comfortably in the Dark',
    description:
      'Night Mode inverts the page colours — white background becomes black, '
      'black text becomes white — greatly reducing eye strain when reading '
      'in low light or at night.\n\n'
      'The setting is remembered across sessions; toggling it once is enough.',
    steps: [
      'Tap ⋮ menu → "🌙 Night Mode".',
      'The screen inverts instantly.',
      'To return to day mode: ⋮ menu → "☀ Day Mode".',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.zoom_in,
    color:    Color(0xFFFF5722),
    title:    'Pinch Zoom',
    subtitle: 'Smooth zoom up to 4×',
    headline: 'Smooth Pinch-to-Zoom up to 4×',
    description:
      'Use two fingers to pinch and zoom any PDF page up to 4× magnification. '
      'Pan around the zoomed page with a single finger. '
      'Double-tap to reset to fit-to-screen view.',
    steps: [
      'Open any PDF — the page fits the screen by default.',
      'Place two fingers on the screen and spread them apart to zoom in.',
      'Pinch inward to zoom out.',
      'Drag with one finger to pan around the zoomed view.',
      'Double-tap to reset to the default fit view.',
    ],
  ),

  _FeatureInfo(
    icon:     Icons.input,
    color:    Color(0xFF009688),
    title:    'Go to Page',
    subtitle: 'Jump to any page instantly',
    headline: 'Jump to Any Page Instantly',
    description:
      'In long PDFs, scrolling through hundreds of pages is slow. '
      'Type any page number and jump there in one tap. '
      'The page counter at the bottom of the screen is also tappable.',
    steps: [
      'Tap ⋮ menu → "📄 Go to Page".',
      'Type the page number.',
      'Tap "Go" — you arrive at that page instantly.',
      'Alternatively, tap the "5 / 120" page counter at the bottom.',
    ],
  ),
];

// ── Home Screen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  // ── Ads & data
  BannerAd?        _bannerAd;
  bool             _bannerLoaded = false;
  List<RecentFile> _recentFiles  = [];
  late TabController _tabCtrl;

  // ── Highlight tracking
  int? _lastOpenedIdx;

  // ── Animations
  late AnimationController _introCtrl;   // logo + hero card entrance
  late AnimationController _pulseCtrl;   // play-button heartbeat
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    // ── Intro animation (runs once on load)
    _introCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _introCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.14), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _introCtrl, curve: Curves.easeOutCubic));

    // ── Pulse animation (loops forever)
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _introCtrl.forward();
    _loadBannerAd();
    _loadRecent();
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _pulseCtrl.dispose();
    _tabCtrl.dispose();
    _bannerAd?.dispose();
    super.dispose();
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

  // ── PDF opening ──────────────────────────────────────────────────────────

  Future<void> _openPdf({String? forcePath}) async {
    String? pdfPath = forcePath;

    if (pdfPath == null) {
      if (Platform.isAndroid) {
        final sdkInt = await _getAndroidSdkInt();
        if (sdkInt < 33) {
          final status = await Permission.storage.request();
          if (status.isPermanentlyDenied || status.isDenied) {
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
        MaterialPageRoute(
          builder: (_) => ReaderScreen(pdfPath: pdfPath!)),
      );
      _loadRecent();
    }
  }

  Future<int> _getAndroidSdkInt() async {
    try { return Platform.isAndroid ? 33 : 0; } catch (_) { return 33; }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Permission Required',
          style: TextStyle(
            color: AppColors.accent, fontWeight: FontWeight.bold)),
        content: const Text(
          'Storage permission is required to open PDF files.\n\n'
          'Please tap "Open Settings" and enable storage or files '
          'permission for this app.',
          style: TextStyle(color: AppColors.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
              style: TextStyle(color: AppColors.sub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent),
            onPressed: () { Navigator.pop(context); openAppSettings(); },
            child: const Text('Open Settings',
              style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Pro Reader'),
        bottom: TabBar(
          controller:          _tabCtrl,
          indicatorColor:      AppColors.accent,
          labelColor:          AppColors.accent,
          unselectedLabelColor: AppColors.sub,
          tabs: const [
            Tab(icon: Icon(Icons.home),    text: 'Home'),
            Tab(icon: Icon(Icons.history), text: 'Recent'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAbout),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildHomeTab(), _buildRecentTab()],
          ),
        ),
        if (_bannerLoaded && _bannerAd != null)
          SizedBox(
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!)),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SafeArea(
        child: FloatingActionButton.extended(
          onPressed:       _openPdf,
          backgroundColor: AppColors.accent,
          icon:  const Icon(Icons.folder_open),
          label: const Text('Open PDF',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ── Home Tab ─────────────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Animated logo block ───────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Center(
                child: Column(children: [
                  // Logo with subtle scale-in
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _introCtrl, curve: Curves.easeOutBack)),
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent2, AppColors.accent],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(
                          color:      AppColors.accent.withOpacity(.45),
                          blurRadius: 22,
                          offset:     const Offset(0, 7))],
                      ),
                      child: const Icon(Icons.picture_as_pdf,
                        size: 52, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('PDF Pro Reader',
                    style: TextStyle(
                      color:      AppColors.text,
                      fontSize:   26,
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.cyan.withOpacity(.2),
                        AppColors.accent.withOpacity(.15),
                      ]),
                      border: Border.all(
                        color: AppColors.cyan.withOpacity(.5)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "🌍  World's First Video-in-PDF Viewer",
                      style: TextStyle(
                        color:      AppColors.cyan,
                        fontSize:   12,
                        fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap any feature card to learn more',
                    style: TextStyle(color: AppColors.sub, fontSize: 11)),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Animated hero card ────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _buildVideoHeroCard(),
            ),
          ),

          const SizedBox(height: 24),

          // ── Section header ────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.apps, color: AppColors.accent, size: 16),
            const SizedBox(width: 6),
            const Text('All Features',
              style: TextStyle(
                color:      AppColors.text,
                fontSize:   15,
                fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        AppColors.accent.withOpacity(.15),
                borderRadius: BorderRadius.circular(10)),
              child: Text('${_kFeatures.length} features',
                style: const TextStyle(
                  color: AppColors.accent, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 10),

          // ── Staggered feature grid ────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics:    const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:  2,
              crossAxisSpacing: 10,
              mainAxisSpacing:  10,
              childAspectRatio: 1.55,
            ),
            itemCount:   _kFeatures.length,
            itemBuilder: (ctx, i) {
              // stagger each tile by 60 ms
              return TweenAnimationBuilder<double>(
                tween:    Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 350 + i * 55),
                curve:    Curves.easeOutCubic,
                builder:  (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 18 * (1 - v)),
                    child: child)),
                child: _FeatureTile(
                  info:          _kFeatures[i],
                  isHighlighted: _lastOpenedIdx == i,
                  onTileOpen:    () => setState(
                    () => _lastOpenedIdx = i),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Video Hero Card ───────────────────────────────────────────────────────

  Widget _buildVideoHeroCard() {
    return GestureDetector(
      onTap: () {
        setState(() => _lastOpenedIdx = 0);
        _FeatureTile.showDetailDialog(context, _kFeatures.first);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [Color(0xFF0D1B2A), Color(0xFF001F2D), Color(0xFF003344)],
            stops:  [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.cyan.withOpacity(.7), width: 1.5),
          boxShadow: [BoxShadow(
            color:       AppColors.cyan.withOpacity(.22),
            blurRadius:  24,
            spreadRadius: 1,
            offset:      const Offset(0, 5))],
        ),
        child: Stack(children: [
          // background glow blob
          Positioned(
            right: -25, top: -25,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.cyan.withOpacity(.11),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.cyan.withOpacity(.3),
                      AppColors.accent.withOpacity(.2),
                    ]),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.cyan.withOpacity(.55)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: AppColors.cyan, size: 11),
                      SizedBox(width: 5),
                      Text('WORLD\'S FIRST  ·  NO OTHER APP CAN DO THIS',
                        style: TextStyle(
                          color:       AppColors.cyan,
                          fontSize:    9,
                          fontWeight:  FontWeight.bold,
                          letterSpacing: 0.6)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pulsing play button + title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Animated pulsing glow ring
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: child),
                      child: Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            AppColors.cyan.withOpacity(.55),
                            AppColors.cyan.withOpacity(.12),
                          ]),
                          border: Border.all(
                            color: AppColors.cyan, width: 2),
                          boxShadow: [BoxShadow(
                            color:       AppColors.cyan.withOpacity(.5),
                            blurRadius:  18,
                            spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.play_circle_fill,
                          color: AppColors.cyan, size: 36),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('VIDEO  IN  PDF',
                            style: TextStyle(
                              color:        AppColors.cyan,
                              fontSize:     20,
                              fontWeight:   FontWeight.w900,
                              letterSpacing: 1.4)),
                          const SizedBox(height: 4),
                          Text(
                            'Videos play directly inside\nthe PDF page — with full audio.',
                            style: TextStyle(
                              color:      Colors.white.withOpacity(.75),
                              fontSize:   12,
                              height:     1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // "No other app" comparison strip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.28),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(.07)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _compBadge('Other\nViewers', false),
                      const Icon(Icons.arrow_forward,
                        color: Colors.white24, size: 16),
                      _compBadge('PDF Pro\nReader', true),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Only PDF Pro Reader plays\nvideo inside the PDF page.',
                          style: TextStyle(
                            color:    Colors.white.withOpacity(.45),
                            fontSize: 10,
                            height:   1.4),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Tap CTA
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.cyan.withOpacity(.22),
                      AppColors.accent.withOpacity(.18),
                    ]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.cyan.withOpacity(.45)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app,
                        color: AppColors.cyan, size: 16),
                      SizedBox(width: 8),
                      Text('Tap to see how it works — step by step',
                        style: TextStyle(
                          color:      AppColors.cyan,
                          fontSize:   12,
                          fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Coming soon teaser
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.computer,
                      color: Colors.white.withOpacity(.32), size: 12),
                    const SizedBox(width: 5),
                    Text(
                      'Requires PDF Pro Suite (Windows desktop app)  —  Coming Soon',
                      style: TextStyle(
                        color:    Colors.white.withOpacity(.32),
                        fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _compBadge(String label, bool isUs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUs
            ? AppColors.cyan.withOpacity(.18)
            : Colors.red.withOpacity(.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUs
              ? AppColors.cyan.withOpacity(.55)
              : Colors.red.withOpacity(.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isUs ? '✅' : '❌',
          style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 3),
        Text(label,
          style: TextStyle(
            color:      isUs ? AppColors.cyan : Colors.red.shade300,
            fontSize:   9,
            fontWeight: FontWeight.bold,
            height:     1.2),
          textAlign: TextAlign.center),
      ]),
    );
  }

  // ── Recent Tab ───────────────────────────────────────────────────────────

  Widget _buildRecentTab() {
    if (_recentFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppColors.sub),
            SizedBox(height: 12),
            Text('No recent files',
              style: TextStyle(color: AppColors.sub)),
            SizedBox(height: 4),
            Text('Open a PDF to get started',
              style: TextStyle(color: AppColors.sub, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding:   const EdgeInsets.all(12),
      itemCount: _recentFiles.length,
      itemBuilder: (ctx, i) {
        final f   = _recentFiles[i];
        final pct = f.totalPages > 0
            ? (f.lastPage / f.totalPages * 100).round() : 0;
        return Card(
          color:  AppColors.card,
          margin: const EdgeInsets.only(bottom: 10),
          shape:  RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap:         () => _openPdf(forcePath: f.path),
            borderRadius:  BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:        AppColors.accent.withOpacity(.15),
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
                          color:      AppColors.text,
                          fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value:           f.totalPages > 0
                              ? f.lastPage / f.totalPages : 0,
                          backgroundColor: AppColors.accent2,
                          color:           AppColors.accent,
                          minHeight:       4)),
                      const SizedBox(height: 4),
                      Text(
                        'Page ${f.lastPage} of ${f.totalPages}  ($pct%)',
                        style: const TextStyle(
                          color: AppColors.sub, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.sub),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ── About ────────────────────────────────────────────────────────────────

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('PDF Pro Reader',
          style: TextStyle(color: AppColors.accent)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.1.0',
              style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
              "World's first PDF viewer that plays embedded videos "
              "directly inside the PDF page — inline, no popup, "
              "with full audio.",
              style: TextStyle(color: AppColors.sub, fontSize: 13)),
            SizedBox(height: 12),
            Text('12 Features:',
              style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              '🎬  Video in PDF (World First)\n'
              '✨  Page Enhancement (Clean / Darken / Marks)\n'
              '✏️  Eraser Tool (with legal warning)\n'
              '💾  Save — original or new file\n'
              '🖨️  Print via system print dialog\n'
              '📤  Share full PDF or single page\n'
              '🔖  Bookmarks — saved permanently\n'
              '📖  Reading progress — auto resume\n'
              '🌙  Night Mode — easy on the eyes\n'
              '🔍  Pinch Zoom — up to 4×\n'
              '📄  Go to Page — instant jump\n'
              '🎨  Page-by-page enhancement',
              style: TextStyle(
                color: AppColors.sub, fontSize: 12, height: 1.55)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
              style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
  }
}

// ── Feature Tile ──────────────────────────────────────────────────────────────

class _FeatureTile extends StatelessWidget {
  final _FeatureInfo info;
  final bool         isHighlighted; // true = last opened by user
  final VoidCallback onTileOpen;    // called before dialog opens

  const _FeatureTile({
    required this.info,
    required this.onTileOpen,
    this.isHighlighted = false,
  });

  // ── Static helper so the hero card can also trigger the detail dialog ──
  static void showDetailDialog(BuildContext context, _FeatureInfo info) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 24),
        title: Row(children: [
          Icon(info.icon, color: info.color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(info.title,
              style: TextStyle(
                color:      info.color,
                fontWeight: FontWeight.bold,
                fontSize:   15))),
          if (info.isStar)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        info.color.withOpacity(.18),
                borderRadius: BorderRadius.circular(4)),
              child: Text('★ UNIQUE',
                style: TextStyle(
                  color:      info.color,
                  fontSize:   9,
                  fontWeight: FontWeight.bold))),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                // Headline
                if (info.headline.isNotEmpty) ...[
                  Text(info.headline,
                    style: const TextStyle(
                      color:      AppColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize:   13)),
                  const Divider(color: Colors.white12, height: 20),
                ],
                // Description
                Text(info.description,
                  style: const TextStyle(
                    color:    AppColors.sub,
                    fontSize: 13,
                    height:   1.55)),
                // Steps
                if (info.steps.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Icon(Icons.list_alt, color: info.color, size: 15),
                    const SizedBox(width: 6),
                    Text('How to use — Step by Step',
                      style: TextStyle(
                        color:      info.color,
                        fontWeight: FontWeight.bold,
                        fontSize:   13)),
                  ]),
                  const SizedBox(height: 10),
                  ...info.steps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color:  info.color.withOpacity(.2),
                            shape:  BoxShape.circle),
                          child: Center(
                            child: Text('${e.key + 1}',
                              style: TextStyle(
                                color:      info.color,
                                fontSize:   11,
                                fontWeight: FontWeight.bold)))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value,
                            style: const TextStyle(
                              color:    AppColors.sub,
                              fontSize: 12,
                              height:   1.4))),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it  ✓',
              style: TextStyle(
                color:      info.color,
                fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Highlighted style — shown for the last tile the user opened
    final highlightBorder = isHighlighted
        ? Border.all(color: info.color, width: 2.0)
        : Border.all(color: info.color.withOpacity(.28));
    final highlightBg = isHighlighted
        ? info.color.withOpacity(.18)
        : info.color.withOpacity(.07);
    final highlightShadow = isHighlighted
        ? [BoxShadow(
            color:       info.color.withOpacity(.28),
            blurRadius:  10,
            spreadRadius: 1)]
        : <BoxShadow>[];

    return Material(
      color:        Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onTileOpen();
          showDetailDialog(context, info);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve:    Curves.easeOut,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color:        highlightBg,
            border:       highlightBorder,
            borderRadius: BorderRadius.circular(12),
            boxShadow:    highlightShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(info.icon, color: info.color, size: 20),
                const Spacer(),
                if (info.isStar)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color:        info.color.withOpacity(.2),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: info.color.withOpacity(.5))),
                    child: Text('★',
                      style: TextStyle(
                        color:      info.color,
                        fontSize:   9,
                        fontWeight: FontWeight.bold))),
                const SizedBox(width: 4),
                Icon(Icons.info_outline,
                  color: info.color.withOpacity(isHighlighted ? .7 : .35),
                  size: 13),
              ]),
              const Spacer(),
              Text(info.title,
                style: TextStyle(
                  color:      info.color,
                  fontSize:   12,
                  fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(info.subtitle,
                style: TextStyle(
                  color:    isHighlighted
                      ? info.color.withOpacity(.7)
                      : AppColors.sub,
                  fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
