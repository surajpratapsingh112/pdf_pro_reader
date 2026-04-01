import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme.dart';
import '../services/admob_service.dart';
import '../services/prefs_service.dart';
import 'reader_screen.dart';

// ── Feature info model ────────────────────────────────────────────────────────

class _FeatureInfo {
  final IconData    icon;
  final Color       color;
  final String      title;
  final String      subtitle;
  final String      headline;    // bold first line in dialog
  final String      description;
  final List<String> steps;
  final bool        isStar;      // show ★ UNIQUE badge

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

// ── All app features (order = display order on home screen) ──────────────────

const List<_FeatureInfo> _kFeatures = [

  // ── STAR FEATURE — Video in PDF ──────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.videocam,
    color:    AppColors.cyan,
    title:    '🎬 Video in PDF',
    subtitle: 'World\'s First — Only here!',
    headline: 'दुनिया का पहला PDF Viewer जो PDF के अंदर Video Play करे!',
    isStar:   true,
    description:
      'किसी भी दूसरे PDF Viewer में — Adobe, Xodo, Google Drive — सब में '
      'यह काम नहीं होता। PDF Pro Reader एकमात्र ऐसा App है जो PDF Page के '
      'उसी Box में Video inline play करता है जिस Box पर आप tap करते हैं।\n\n'
      'Video embed करने के लिए आपको हमारी companion desktop app '
      '"PDF Pro Suite" (Windows) use करनी होगी जो जल्द ही available होगी। '
      'उस app से एक बार video embed करें — बस, हर बार PDF Pro Reader में '
      'वह video automatically detect और play होगी।',
    steps: [
      'PDF Pro Suite (desktop companion app) में कोई PDF open करें।',
      '"Embed Video" tool से उस page पर एक box draw करें जहाँ video दिखानी है।',
      'अपनी video file select करें — वह PDF में embed हो जाएगी।',
      'वह PDF अपने Android phone पर transfer करें।',
      'PDF Pro Reader में वह PDF open करें।',
      'Page पर cyan (नीला) bordered box दिखेगा — उस पर tap करें।',
      'Video ठीक उसी box के अंदर play होगी — पूरी sound के साथ! 🎬',
    ],
  ),

  // ── Page Enhancement ─────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.auto_fix_high,
    color:    Color(0xFF7C4DFF),
    title:    '✨ Enhance Page',
    subtitle: 'Clean, Darken, Fix scans',
    headline: 'पुरानी या Scanned PDF को Crystal Clear बनाएं',
    description:
      'किसी भी scanned document में yellowing, stains, shadows, faded text '
      'या pen marks हो सकते हैं। Enhance Page feature 3 powerful tools देता है:\n\n'
      '• B&W Clean — पीलापन हटाएं, pure white background + sharp black text\n'
      '• Color Clean — Histogram stretch + gamma — color documents bright करें\n'
      '• Shadow Clean — Camera से खींचे docs की uneven lighting fix करें\n'
      '• Text Darkening — faded text को बिना background छुए darker बनाएं\n'
      '• Mark Removal — Blue/Red/Green pen, Pencil, Highlighter marks हटाएं',
    steps: [
      'PDF open करें और उस page पर जाएं जिसे enhance करना है।',
      'ऊपर ⋮ menu → "✨ Enhance Page" tap करें।',
      'Page Cleaning mode choose करें: B&W / Color / Shadow।',
      'Strength slider adjust करें।',
      'Text Darkening ON करें अगर text faded हो।',
      'Mark Removal ON करें और अपना mark type select करें।',
      '"Apply to This Page" tap करें — background में process होगा।',
      'Result automatically page पर दिखेगा।',
      'AppBar में "Done ✓" tap करके save करें।',
    ],
  ),

  // ── Eraser Tool ──────────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.edit_off,
    color:    Color(0xFFEF5350),
    title:    '✏️ Eraser Tool',
    subtitle: 'Finger se erase karo',
    headline: 'Finger से अनचाहा Content मिटाएं',
    description:
      'अपनी personal PDF notes, study material या drafts में जो content '
      'नहीं चाहिए उसे finger से erase करें। एक white eraser की तरह काम करता है।\n\n'
      '⚠️ Legal Warning: यह feature सिर्फ personal documents के लिए है। '
      'Official, legal या government documents पर use करना IPC Section 463 '
      '(Forgery) के अंतर्गत आ सकता है।',
    steps: [
      '⋮ Menu → "✏️ Eraser Tool" tap करें।',
      'Legal warning पढ़ें और "I Understand" press करें।',
      'Bottom bar में Size slider से eraser size adjust करें।',
      'Finger से page पर drag करें — white circles से erase होगा।',
      '"Apply Eraser" button tap करें — background में bake होगा।',
      'AppBar में "Done ✓" tap करके save करें।',
    ],
  ),

  // ── Save PDF ─────────────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.save,
    color:    Color(0xFF00BCD4),
    title:    '💾 Save Changes',
    subtitle: 'Original या New file में',
    headline: 'Enhanced / Erased PDF को Save करें',
    description:
      'Page enhance करने या eraser use करने के बाद changes को permanent '
      'save करें। दो options मिलते हैं:\n\n'
      '• Save to Original — वही original file overwrite होगी\n'
      '• Save as New File — अलग "_enhanced.pdf" नाम से नई file बनेगी\n\n'
      'Save करने से पहले app सभी pages render करके एक complete PDF बनाती है।',
    steps: [
      'Page enhance या erase करने के बाद AppBar में हरा "Done ✓" button दिखेगा।',
      '"Done ✓" tap करें।',
      '"Save to Original" या "Save as New File" choose करें।',
      '"Building PDF…" progress show होगा।',
      'Save complete होने पर file path का notification आएगा।',
    ],
  ),

  // ── Print PDF ────────────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.print,
    color:    Color(0xFF607D8B),
    title:    '🖨️ Print PDF',
    subtitle: 'WiFi Printer से print करो',
    headline: 'PDF को directly Print करें',
    description:
      'Phone से directly WiFi printer पर PDF print करें। '
      'Android का built-in Print system use होता है जो Google Cloud Print, '
      'HP Print, Samsung Print आदि सभी को support करता है।\n\n'
      'Enhanced pages हों तो वे modified version print होंगे।',
    steps: [
      '⋮ Menu → "🖨️ Print PDF" tap करें।',
      'App PDF build करेगी (enhanced pages के साथ)।',
      'Android Print dialog open होगा।',
      'Printer choose करें या "Save as PDF" select करें।',
      'Copies, orientation, page range set करें।',
      '"Print" button tap करें।',
    ],
  ),

  // ── Share Full PDF ───────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.ios_share,
    color:    Color(0xFF4CAF50),
    title:    '📤 Share Full PDF',
    subtitle: 'WhatsApp, Gmail, Drive...',
    headline: 'पूरी PDF को कहीं भी Share करें',
    description:
      'Enhanced / erased PDF को WhatsApp, Gmail, Google Drive, Telegram, '
      'और किसी भी app पर share करें।\n\n'
      'अगर कोई changes नहीं हैं तो original file directly share होती है '
      '(fastest)। Changes हों तो पहले modified PDF build होगी, फिर share।',
    steps: [
      '⋮ Menu → "📤 Share Full PDF" tap करें।',
      'अगर modifications हैं तो "Building PDF…" दिखेगा।',
      'Android Share Sheet open होगी।',
      'WhatsApp, Gmail, Drive — जो चाहें choose करें।',
    ],
  ),

  // ── Share Page as Image ──────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.share,
    color:    Color(0xFF2196F3),
    title:    '📸 Share Page',
    subtitle: 'Single page as image',
    headline: 'किसी एक Page को Image के रूप में Share करें',
    description:
      'जब आपको पूरी PDF नहीं बल्कि सिर्फ एक important page share करनी हो '
      'तो यह feature use करें। Page को high-quality JPEG image में convert '
      'करके share करता है।',
    steps: [
      'उस page पर जाएं जो share करनी है।',
      '⋮ Menu → "📤 Share Page" tap करें।',
      'Page image बनेगी।',
      'Share Sheet में destination choose करें।',
    ],
  ),

  // ── Bookmarks ────────────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.bookmark,
    color:    Color(0xFFFF9800),
    title:    '🔖 Bookmarks',
    subtitle: 'Important pages mark करो',
    headline: 'अपने Important Pages Bookmark करें',
    description:
      'किसी भी page को bookmark करें ताकि बाद में सीधे वहाँ jump कर सकें। '
      'Bookmarks automatically save रहते हैं — app close करके फिर open करें, '
      'bookmarks वैसे ही रहेंगे।',
    steps: [
      'उस page पर जाएं जिसे bookmark करना है।',
      'AppBar में 🔖 icon tap करें — page bookmark हो जाएगा।',
      'फिर से tap करने पर bookmark remove होगा।',
      'सारे bookmarks देखने के लिए ⋮ Menu → "🔖 Bookmarks" tap करें।',
      'List में किसी bookmark पर tap करें — directly उस page पर jump होगा।',
    ],
  ),

  // ── Reading Progress ─────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.history,
    color:    Color(0xFF8BC34A),
    title:    '📖 Reading Progress',
    subtitle: 'Resume where you left',
    headline: 'जहाँ छोड़ा वहाँ से Resume करें',
    description:
      'PDF बंद करें, phone restart करें — अगली बार open करने पर '
      'automatically वही page खुलेगा जहाँ आप थे। '
      'Recent tab में हर file की progress % में दिखती है।',
    steps: [
      'PDF open करें और किसी page पर पहुँचें।',
      'App या PDF close करें — progress automatically save होती है।',
      'Home screen पर Recent tab में file का progress bar दिखेगा।',
      'File tap करें — ठीक वहीं से continue होगा।',
    ],
  ),

  // ── Night Mode ───────────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.dark_mode,
    color:    Color(0xFF9C27B0),
    title:    '🌙 Night Mode',
    subtitle: 'आँखों के लिए आरामदायक',
    headline: 'रात में पढ़ें — आँखों पर ज़ोर नहीं',
    description:
      'Night Mode screen को invert करता है जिससे white background '
      'black हो जाती है और black text white हो जाता है। '
      'रात में या अंधेरे में पढ़ने के लिए perfect।\n\n'
      'Setting automatically save रहती है — app close करें, खोलें, '
      'Night Mode वैसे ही रहेगा।',
    steps: [
      '⋮ Menu → "🌙 Night Mode" tap करें।',
      'Screen instantly invert होगी।',
      'वापस Day Mode के लिए ⋮ Menu → "☀ Day Mode" tap करें।',
    ],
  ),

  // ── Pinch Zoom ───────────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.zoom_in,
    color:    Color(0xFFFF5722),
    title:    '🔍 Pinch Zoom',
    subtitle: 'Smooth zoom in/out',
    headline: 'Smooth Pinch-to-Zoom',
    description:
      'दोनों उंगलियों से pinch करके zoom in/out करें। '
      '4× तक zoom in हो सकता है। Double tap करने पर fit-to-screen पर '
      'वापस आ जाता है। Swipe करके page scroll करें।',
    steps: [
      'PDF open करने पर page normally fit होगा।',
      'दो उंगलियाँ screen पर रखें और फैलाएं — zoom in होगा।',
      'उंगलियाँ सिकोड़ें — zoom out होगा।',
      'Zoom में swipe करके page navigate करें।',
      'Page tap करें — controls show/hide होंगे।',
    ],
  ),

  // ── Go to Page ───────────────────────────────────────────────────────────
  _FeatureInfo(
    icon:     Icons.input,
    color:    Color(0xFF009688),
    title:    '📄 Go to Page',
    subtitle: 'Direct page jump',
    headline: 'किसी भी Page पर सीधे Jump करें',
    description:
      'बड़ी PDF में manually scroll करने की ज़रूरत नहीं। '
      'Page number type करें और directly उस page पर jump करें। '
      'Bottom bar में page number भी tap करने योग्य है।',
    steps: [
      '⋮ Menu → "📄 Go to Page" tap करें।',
      'Page number type करें।',
      '"Go" tap करें — directly उस page पर पहुँचेंगे।',
      'या bottom bar में "5 / 120" जैसा text tap करें।',
    ],
  ),
];

// ── Home screen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
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
        MaterialPageRoute(builder: (_) => ReaderScreen(pdfPath: pdfPath!)),
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
          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
        content: const Text(
          'Storage permission is required to open PDF files.\n\n'
          'Please tap "Open Settings" and enable the storage permission.',
          style: TextStyle(color: AppColors.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.sub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () { Navigator.pop(context); openAppSettings(); },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white))),
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
          controller: _tabCtrl,
          indicatorColor: AppColors.accent,
          labelColor:     AppColors.accent,
          unselectedLabelColor: AppColors.sub,
          tabs: const [
            Tab(icon: Icon(Icons.home),    text: 'Home'),
            Tab(icon: Icon(Icons.history), text: 'Recent'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline), onPressed: _showAbout),
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

  // ── Home Tab ─────────────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App logo + tagline ──────────────────────────────────────────
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
                child: const Icon(Icons.picture_as_pdf,
                  size: 52, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('PDF Pro Reader',
                style: TextStyle(color: AppColors.text, fontSize: 26,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.cyan.withOpacity(.2),
                             AppColors.accent.withOpacity(.15)]),
                  border: Border.all(color: AppColors.cyan.withOpacity(.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "🌍  World's First Video-in-PDF Viewer",
                  style: TextStyle(color: AppColors.cyan, fontSize: 12,
                    fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap any feature below to learn more ↓',
                style: TextStyle(color: AppColors.sub, fontSize: 11)),
            ]),
          ),

          const SizedBox(height: 28),

          // ── Star feature banner ─────────────────────────────────────────
          _buildStarBanner(),

          const SizedBox(height: 24),

          // ── Features grid ───────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.apps, color: AppColors.accent, size: 16),
              const SizedBox(width: 6),
              const Text('All Features',
                style: TextStyle(color: AppColors.text, fontSize: 15,
                  fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_kFeatures.length} features',
                  style: const TextStyle(
                    color: AppColors.accent, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:   2,
              crossAxisSpacing: 10,
              mainAxisSpacing:  10,
              childAspectRatio: 1.55,
            ),
            itemCount: _kFeatures.length,
            itemBuilder: (ctx, i) => _FeatureTile(info: _kFeatures[i]),
          ),
        ],
      ),
    );
  }

  // ── Star feature — Video in PDF Hero Card ────────────────────────────────

  Widget _buildStarBanner() {
    return GestureDetector(
      onTap: () => _FeatureTile.showDetailDialog(context, _kFeatures.first),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A), // deep navy
              Color(0xFF001F2D), // darker navy
              Color(0xFF003344), // subtle cyan tint
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cyan.withOpacity(.7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color:       AppColors.cyan.withOpacity(.25),
              blurRadius:  22,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── background glow blob ───────────────────────────────────
            Positioned(
              right: -30, top: -30,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.cyan.withOpacity(.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            // ── content ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Row 1 — badge
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.cyan.withOpacity(.35),
                          AppColors.accent.withOpacity(.25),
                        ]),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.cyan.withOpacity(.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: AppColors.cyan, size: 11),
                          SizedBox(width: 4),
                          Text('WORLD\'S FIRST  ·  INDIA\'S ONLY',
                            style: TextStyle(
                              color: AppColors.cyan,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // Row 2 — big play icon + title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // glowing play circle
                      Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            AppColors.cyan.withOpacity(.5),
                            AppColors.cyan.withOpacity(.15),
                          ]),
                          border: Border.all(
                            color: AppColors.cyan, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color:      AppColors.cyan.withOpacity(.45),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_circle_fill,
                          color: AppColors.cyan, size: 34),
                      ),
                      const SizedBox(width: 14),
                      // title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('VIDEO  IN  PDF',
                              style: TextStyle(
                                color: AppColors.cyan,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              )),
                            const SizedBox(height: 3),
                            Text('PDF के Page के अंदर Video play करें!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 3 — competition comparison
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(.07)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('दूसरे apps क्या कर सकते हैं?',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.5),
                            fontSize: 10)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _compBadge('Adobe',  false),
                            _compBadge('Xodo',   false),
                            _compBadge('Google', false),
                            _compBadge('WPS',    false),
                            _compBadge('हमारी', true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Row 4 — CTA button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.cyan.withOpacity(.25),
                          AppColors.accent.withOpacity(.2),
                        ]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.cyan.withOpacity(.5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app,
                            color: AppColors.cyan, size: 16),
                          SizedBox(width: 7),
                          Text('Tap करें — देखें यह कैसे काम करता है',
                            style: TextStyle(
                              color: AppColors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Row 5 — coming soon teaser
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.computer,
                        color: Colors.white.withOpacity(.35), size: 12),
                      const SizedBox(width: 5),
                      Text(
                        'Video embed करने के लिए  '
                        'PDF Pro Suite (Desktop)  —  Coming Soon',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.38),
                          fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Comparison badge widget (used inside star banner).
  Widget _compBadge(String label, bool isUs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUs
            ? AppColors.cyan.withOpacity(.2)
            : Colors.red.withOpacity(.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isUs
              ? AppColors.cyan.withOpacity(.6)
              : Colors.red.withOpacity(.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(isUs ? '✅' : '❌',
          style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 3),
        Text(label,
          style: TextStyle(
            color: isUs ? AppColors.cyan : Colors.red.shade300,
            fontSize: 10,
            fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.all(12),
      itemCount: _recentFiles.length,
      itemBuilder: (ctx, i) {
        final f   = _recentFiles[i];
        final pct = f.totalPages > 0
            ? (f.lastPage / f.totalPages * 100).round() : 0;
        return Card(
          color: AppColors.card,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap:          () => _openPdf(forcePath: f.path),
            borderRadius:   BorderRadius.circular(12),
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
                            color: AppColors.text,
                            fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: f.totalPages > 0
                                ? f.lastPage / f.totalPages : 0,
                            backgroundColor: AppColors.accent2,
                            color:           AppColors.accent,
                            minHeight:       4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Page ${f.lastPage} of ${f.totalPages} ($pct%)',
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

  // ── About dialog ─────────────────────────────────────────────────────────

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
            Text('Version: 1.1.0',
              style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
              "World's first PDF viewer that plays embedded videos "
              "directly inside the PDF page — no popup, inline only!",
              style: TextStyle(color: AppColors.sub, fontSize: 13)),
            SizedBox(height: 12),
            Text('12 Features:', style: TextStyle(
              color: AppColors.text, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              '🎬  Video in PDF (World First)\n'
              '✨  Page Enhancement (Clean / Darken / Marks)\n'
              '✏️  Eraser Tool with legal warning\n'
              '💾  Save to original or new file\n'
              '🖨️  Print via system print dialog\n'
              '📤  Share full PDF or single page\n'
              '🔖  Bookmarks — saved permanently\n'
              '📖  Reading progress — auto resume\n'
              '🌙  Night mode — eye comfort\n'
              '🔍  Pinch zoom — up to 4×\n'
              '📄  Go to page — instant jump\n'
              '🎨  Page-by-page enhancement',
              style: TextStyle(color: AppColors.sub, fontSize: 12,
                height: 1.55)),
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

// ── Feature Tile widget ───────────────────────────────────────────────────────

class _FeatureTile extends StatelessWidget {
  final _FeatureInfo info;
  const _FeatureTile({required this.info});

  /// Static helper so the star banner can also open the detail dialog.
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
                color: info.color,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
          ),
          if (info.isStar)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: info.color.withOpacity(.18),
                borderRadius: BorderRadius.circular(4)),
              child: Text('★ UNIQUE',
                style: TextStyle(
                  color: info.color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
            ),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Headline
                if (info.headline.isNotEmpty) ...[
                  Text(info.headline,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
                  const Divider(color: Colors.white12, height: 20),
                ],

                // Description
                Text(info.description,
                  style: const TextStyle(
                    color: AppColors.sub,
                    fontSize: 13,
                    height: 1.55)),

                // Steps
                if (info.steps.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Icon(Icons.list_alt,
                      color: info.color, size: 15),
                    const SizedBox(width: 6),
                    Text('How to use — Steps',
                      style: TextStyle(
                        color: info.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
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
                            color: info.color.withOpacity(.2),
                            shape: BoxShape.circle),
                          child: Center(
                            child: Text('${e.key + 1}',
                              style: TextStyle(
                                color: info.color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value,
                            style: const TextStyle(
                              color: AppColors.sub,
                              fontSize: 12,
                              height: 1.4)),
                        ),
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
            child: Text('Got it ✓',
              style: TextStyle(
                color: info.color,
                fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Video tile gets a special deep-navy style to match hero card ─────
    if (info.isStar) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDetailDialog(context, info),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1B2A), Color(0xFF003344)],
              ),
              border: Border.all(
                color: AppColors.cyan.withOpacity(.65), width: 1.5),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withOpacity(.18),
                  blurRadius: 10, spreadRadius: 1),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.videocam,
                    color: AppColors.cyan, size: 20),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(.2),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: AppColors.cyan.withOpacity(.5))),
                    child: const Text('★ #1',
                      style: TextStyle(
                        color: AppColors.cyan, fontSize: 8,
                        fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline,
                    color: AppColors.cyan.withOpacity(.5), size: 13),
                ]),
                const Spacer(),
                const Text('🎬 Video in PDF',
                  style: TextStyle(
                    color: AppColors.cyan, fontSize: 12,
                    fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('World\'s First!',
                  style: TextStyle(
                    color: AppColors.cyan.withOpacity(.6), fontSize: 10),
                  maxLines: 1),
              ],
            ),
          ),
        ),
      );
    }

    // ── All other tiles — standard style ─────────────────────────────────
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:        () => showDetailDialog(context, info),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color:  info.color.withOpacity(.07),
            border: Border.all(color: info.color.withOpacity(.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(info.icon, color: info.color, size: 20),
                  const Spacer(),
                  Icon(Icons.info_outline,
                    color: info.color.withOpacity(.4), size: 13),
                ],
              ),
              const Spacer(),
              Text(info.title,
                style: TextStyle(
                  color: info.color, fontSize: 12,
                  fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(info.subtitle,
                style: const TextStyle(
                  color: AppColors.sub, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
