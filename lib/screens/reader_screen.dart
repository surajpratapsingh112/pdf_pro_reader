import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pdflib;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme.dart';
import '../models/video_area.dart';
import '../services/pdf_video_service.dart';
import '../services/pdf_enhance_service.dart';
import '../services/prefs_service.dart';
import '../widgets/inline_video_player.dart';

class ReaderScreen extends StatefulWidget {
  final String pdfPath;
  const ReaderScreen({super.key, required this.pdfPath});
  @override State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // PDF
  PdfController? _pdfCtrl;
  int    _curPage    = 1;
  int    _totalPages = 1;
  bool   _loading    = true;
  String? _error;

  // Video
  List<VideoArea>     _videoAreas = [];
  Map<String, String> _videoPaths = {};
  bool _scanningVideos = true;
  final Map<String, bool> _activePlayers = {};

  // Bookmarks
  List<BookmarkItem> _bookmarks    = [];
  bool               _isBookmarked = false;

  // Night mode
  bool _nightMode = false;

  // Page Enhancement
  // Key = 0-based pageIndex (matches pageBuilder); value = enhanced PNG bytes
  final Map<int, Uint8List> _enhancedPages = {};
  bool _enhancingPage = false;

  // UI controls visibility (tap to toggle)
  bool _showControls = true;

  // ── Eraser tool ──────────────────────────────────────────────────────────
  bool   _eraserMode  = false;
  double _eraserSize  = 20.0; // on-screen radius in logical pixels
  /// pageIndex → list of committed stroke points (normalised 0-1)
  final Map<int, List<Map<String, double>>> _eraserPoints = {};
  List<Map<String, double>> _currentEraserStroke = [];
  bool _applyingEraser = false;

  // ── Unsaved changes ──────────────────────────────────────────────────────
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _openPdf();
    _scanVideos();
    _loadBookmarks();
    _loadNightMode();
  }

  @override
  void dispose() {
    PrefsService.updateReadingProgress(widget.pdfPath, _curPage, _totalPages);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    _pdfCtrl?.dispose();
    super.dispose();
  }

  Future<void> _openPdf() async {
    try {
      final doc       = await PdfDocument.openFile(widget.pdfPath);
      final savedPage = await PrefsService.getSavedPage(widget.pdfPath);
      _pdfCtrl = PdfController(
        document:    Future.value(doc),
        initialPage: savedPage ?? 1,
      );
      if (mounted) {
        setState(() {
          _loading    = false;
          _totalPages = doc.pagesCount;
          _curPage    = savedPage ?? 1;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _scanVideos() async {
    try {
      final result = await PdfVideoService.extractFromPdf(widget.pdfPath);
      if (mounted) {
        setState(() {
          _videoAreas     = result.areas;
          _videoPaths     = result.videoPaths;
          _scanningVideos = false;
        });
        if (result.videoPaths.isNotEmpty) {
          _showSnack('${result.videoPaths.length} video(s) found — tap the cyan box to play 🎬');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _scanningVideos = false);
    }
  }

  Future<void> _loadBookmarks() async {
    final bm = await PrefsService.getBookmarks(widget.pdfPath);
    final ib = await PrefsService.isBookmarked(widget.pdfPath, _curPage);
    if (mounted) setState(() { _bookmarks = bm; _isBookmarked = ib; });
  }

  Future<void> _loadNightMode() async {
    final nm = await PrefsService.getNightMode();
    if (mounted) setState(() => _nightMode = nm);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq        = MediaQuery.of(context);
    final topPad    = mq.padding.top;
    final bottomPad = mq.padding.bottom;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKey,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        backgroundColor: _nightMode ? Colors.black : AppColors.bg,
        appBar: _showControls ? _buildAppBar(topPad) : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : _error != null
                ? _buildError()
                : _buildViewer(topPad, bottomPad),
        bottomNavigationBar: _showControls ? _buildNavBar(bottomPad) : null,
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(double topPad) {
    final fname = widget.pdfPath.split(Platform.pathSeparator).last;
    return AppBar(
      backgroundColor: AppColors.bar.withOpacity(0.96),
      elevation: 0,
      title: Text(
        fname.length > 22 ? '...${fname.substring(fname.length - 22)}' : fname,
        style: const TextStyle(fontSize: 13)),
      actions: [
        if (_videoPaths.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(.15),
                  border: Border.all(color: AppColors.cyan),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam, color: AppColors.cyan, size: 13),
                  const SizedBox(width: 3),
                  Text('${_videoPaths.length}',
                    style: const TextStyle(color: AppColors.cyan,
                      fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
        if (_scanningVideos)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan)))),
        // ── Done button — visible when there are unsaved edits ────────────
        if (_hasUnsavedChanges || _eraserPoints.isNotEmpty)
          TextButton.icon(
            onPressed: _showDoneActions,
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
            label: const Text('Done',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        IconButton(
          icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          color: _isBookmarked ? const Color(0xFFFF9800) : AppColors.sub,
          tooltip: 'Bookmark this page',
          onPressed: _toggleBookmark,
        ),
        PopupMenuButton<String>(
          color: AppColors.card,
          onSelected: _onMenuAction,
          itemBuilder: (_) => [
            _menuItem('nightmode', _nightMode ? '☀  Day Mode' : '🌙  Night Mode', Icons.dark_mode),
            _menuItem('bookmarks', '🔖  Bookmarks', Icons.bookmarks),
            _menuItem('share',     '📤  Share Page', Icons.share),
            _menuItem('goto',      '📄  Go to Page', Icons.input),
            _menuItem('enhance',
              _enhancedPages.containsKey(_curPage - 1)
                ? '✨  Enhanced ✓' : '✨  Enhance Page',
              Icons.auto_fix_high),
            if (_enhancedPages.containsKey(_curPage - 1))
              _menuItem('reset_enhance', '↩  Reset Page', Icons.refresh),
            _menuItem('eraser',    '✏️  Eraser Tool',    Icons.edit_off),
            _menuItem('share_pdf', '📤  Share Full PDF', Icons.ios_share),
            _menuItem('print',     '🖨️  Print PDF',      Icons.print),
            if (_hasUnsavedChanges)
              _menuItem('save_pdf', '💾  Save Changes',  Icons.save),
            if (_videoPaths.isNotEmpty)
              _menuItem('videos', '🎬  Play Video', Icons.videocam),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String val, String text, IconData icon) =>
    PopupMenuItem(value: val,
      child: Row(children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: AppColors.text, fontSize: 13)),
      ]));

  // ── Viewer ─────────────────────────────────────────────────────────────────

  Widget _buildViewer(double topPad, double bottomPad) {
    final topSafe    = _showControls ? 0.0 : topPad;
    final bottomSafe = _showControls ? 0.0 : bottomPad;

    return ColorFiltered(
      colorFilter: _nightMode
        ? const ColorFilter.matrix([
            -1, 0, 0, 0, 255,
             0,-1, 0, 0, 255,
             0, 0,-1, 0, 255,
             0, 0, 0, 1,   0,
          ])
        : const ColorFilter.matrix([
            1, 0, 0, 0, 0,
            0, 1, 0, 0, 0,
            0, 0, 1, 0, 0,
            0, 0, 0, 1, 0,
          ]),
      child: Padding(
        padding: EdgeInsets.only(top: topSafe, bottom: bottomSafe),
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: PdfView(
            controller:    _pdfCtrl!,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            builders: PdfViewBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(color: AppColors.accent)),
              pageLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(color: AppColors.accent)),
              pageBuilder: _buildPageWithVideos,
            ),
          ),
        ),
      ),
    );
  }

  void _onPageChanged(int page) async {
    final ib = await PrefsService.isBookmarked(widget.pdfPath, page);
    if (mounted) setState(() { _curPage = page; _isBookmarked = ib; });
    if (page % 5 == 0) {
      PrefsService.updateReadingProgress(widget.pdfPath, page, _totalPages);
    }
  }

  // ── Page builder with video overlays ──────────────────────────────────────

  PhotoViewGalleryPageOptions _buildPageWithVideos(
    BuildContext context,
    Future<PdfPageImage?> pageImage,
    int pageIndex,
    PdfDocument doc,
  ) {
    final screenSize = MediaQuery.of(context).size;
    // Collect videos for this page once (used inside FutureBuilder)
    final pageVideos = _videoAreas
        .where((v) => v.pageIndex == pageIndex)
        .toList();

    return PhotoViewGalleryPageOptions.customChild(
      childSize: screenSize,
      initialScale: PhotoViewComputedScale.contained,
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 4.0,
      child: FutureBuilder<PdfPageImage?>(
        future: pageImage,
        builder: (ctx, snapshot) {
          final img = snapshot.data;
          if (img == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent));
          }

          return LayoutBuilder(
            builder: (ctx2, constraints) {
              final sw = constraints.maxWidth;
              final sh = constraints.maxHeight;
              // Use enhanced bytes if user applied enhancement to this page
              final displayBytes = _enhancedPages[pageIndex] ?? img.bytes;
              // Collect unapplied eraser points for this page
              final pageEraserPts = <Map<String, double>>[
                ...(_eraserPoints[pageIndex] ?? []),
                if (pageIndex == _curPage - 1) ..._currentEraserStroke,
              ];
              return Stack(
                children: [
                  // PDF page image (original or enhanced)
                  Positioned.fill(
                    child: Image.memory(
                      displayBytes,
                      fit:    BoxFit.fill,
                      width:  sw,
                      height: sh,
                    ),
                  ),
                  // Video overlay buttons
                  for (final v in pageVideos)
                    _buildVideoOverlay(v, sw, sh),
                  // ── Eraser drawing overlay ────────────────────────────────
                  if (pageEraserPts.isNotEmpty ||
                      (_eraserMode && pageIndex == _curPage - 1))
                    Positioned.fill(
                      child: _eraserMode && pageIndex == _curPage - 1
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) =>
                                  _onEraserPanStart(d, sw, sh, pageIndex),
                              onPanUpdate: (d) =>
                                  _onEraserPanUpdate(d, sw, sh, pageIndex),
                              onPanEnd: (_) => _onEraserPanEnd(pageIndex),
                              child: CustomPaint(
                                painter: _EraserPainter(points: pageEraserPts),
                              ),
                            )
                          : CustomPaint(
                              painter: _EraserPainter(points: pageEraserPts),
                            ),
                    ),
                  // Loading overlay while enhancing this page
                  if (_enhancingPage && pageIndex == _curPage - 1)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.accent),
                            SizedBox(height: 12),
                            Text('Enhancing page, please wait…',
                              style: TextStyle(color: Colors.white,
                                fontSize: 14, decoration: TextDecoration.none)),
                          ],
                        )),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVideoOverlay(VideoArea v, double sw, double sh) {
    final path      = _videoPaths[v.name];
    final isPlaying = _activePlayers[v.name] == true;
    final isGif     = v.name.toLowerCase().endsWith('.gif');

    final sx = sw / v.pageWidth;
    final sy = sh / v.pageHeight;

    return Positioned(
      left:   v.x0 * sx,
      top:    v.y0 * sy,
      width:  (v.x1 - v.x0) * sx,
      height: (v.y1 - v.y0) * sy,
      child: isGif
          // ── GIF: autoplay as soon as path is available, no tap needed ──
          ? path != null
              ? _buildInlineGif(path, v.name)
              : const Center(child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.green)))
          // ── VIDEO: tap to play ──────────────────────────────────────────
          : isPlaying && path != null
              ? InlineVideoPlayer(
                  videoPath: path,
                  onClose:   () => setState(() => _activePlayers.remove(v.name)),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (path != null) {
                      setState(() => _activePlayers[v.name] = true);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.cyan, width: 3),
                      color:  AppColors.cyan.withOpacity(.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: path != null
                          ? const Icon(Icons.play_circle_fill,
                              color: AppColors.cyan, size: 52)
                          : const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.cyan)),
                    ),
                  ),
                ),
    );
  }

  Widget _buildInlineGif(String path, String name) {
    // GIF autoplays and loops continuously — no controls needed
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        File(path),
        fit: BoxFit.fill,
        gaplessPlayback: true,
      ),
    );
  }

  // ── Navigation bar ─────────────────────────────────────────────────────────

  Widget _buildNavBar(double bottomPad) {
    if (_eraserMode) return _buildEraserBar(bottomPad);
    final pct = _totalPages > 0 ? _curPage / _totalPages : 0.0;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bar,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(.07))),
        ),
        padding: EdgeInsets.only(
          left: 12, right: 12, top: 6,
          bottom: bottomPad > 0 ? 4 : 8,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value:           pct.toDouble(),
              backgroundColor: AppColors.accent2.withOpacity(.3),
              color:           AppColors.accent,
              minHeight:       3),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _curPage > 1 ? _prevPage : null,
                icon: const Icon(Icons.chevron_left, size: 28),
                color: AppColors.accent,
                disabledColor: AppColors.sub,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              GestureDetector(
                onTap: _goToPage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent2.withOpacity(.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$_curPage / $_totalPages',
                    style: const TextStyle(
                      color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              IconButton(
                onPressed: _curPage < _totalPages ? _nextPage : null,
                icon: const Icon(Icons.chevron_right, size: 28),
                color: AppColors.accent,
                disabledColor: AppColors.sub,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _prevPage() => _pdfCtrl?.previousPage(
    duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
  void _nextPage() => _pdfCtrl?.nextPage(
    duration: const Duration(milliseconds: 200), curve: Curves.easeOut);

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) _nextPage();
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowUp)  _prevPage();
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await PrefsService.removeBookmark(widget.pdfPath, _curPage);
      _showSnack('Bookmark removed — Page $_curPage');
    } else {
      await PrefsService.addBookmark(BookmarkItem(
        pdfPath:   widget.pdfPath,
        page:      _curPage,
        label:     'Page $_curPage',
        createdAt: DateTime.now(),
      ));
      _showSnack('Bookmark added ✅ — Page $_curPage');
    }
    await _loadBookmarks();
  }

  Future<void> _onMenuAction(String action) async {
    switch (action) {
      case 'nightmode':
        final nm = !_nightMode;
        await PrefsService.setNightMode(nm);
        setState(() => _nightMode = nm);
        _showSnack(nm ? '🌙 Night Mode ON' : '☀ Day Mode ON');
        break;
      case 'bookmarks':
        _showBookmarksSheet();
        break;
      case 'share':
        _showShareDialog();
        break;
      case 'goto':
        _goToPage();
        break;
      case 'enhance':
        _showEnhanceSheet();
        break;
      case 'reset_enhance':
        setState(() => _enhancedPages.remove(_curPage - 1));
        _showSnack('Page reset to original.');
        break;
      case 'eraser':
        _showEraserWarning();
        break;
      case 'save_pdf':
        _showSaveDialog();
        break;
      case 'print':
        _printPdf();
        break;
      case 'share_pdf':
        _showShareDialog();
        break;
      case 'videos':
        _showVideosSheet();
        break;
    }
  }

  void _showVideosSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.sub.withOpacity(.4),
              borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Videos (${_videoPaths.length})',
              style: const TextStyle(color: AppColors.text,
                fontWeight: FontWeight.bold, fontSize: 16))),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _videoPaths.entries.map((e) {
                final isPlaying = _activePlayers[e.key] == true;
                return ListTile(
                  leading: const Icon(Icons.videocam, color: AppColors.cyan),
                  title: Text(e.key,
                    style: const TextStyle(color: AppColors.text)),
                  subtitle: Text(
                    _videoAreas.where((v) => v.name == e.key).isNotEmpty
                      ? 'Page ${_videoAreas.firstWhere((v) => v.name == e.key).pageIndex + 1}'
                      : '',
                    style: const TextStyle(color: AppColors.sub, fontSize: 11)),
                  trailing: isPlaying
                    ? IconButton(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        onPressed: () {
                          setState(() => _activePlayers.remove(e.key));
                          Navigator.pop(context);
                        })
                    : IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: AppColors.cyan),
                        onPressed: () {
                          // Jump to the page that has this video, then play inline
                          final area = _videoAreas
                              .where((v) => v.name == e.key)
                              .firstOrNull;
                          if (area != null) {
                            _pdfCtrl?.jumpToPage(area.pageIndex + 1);
                          }
                          setState(() => _activePlayers[e.key] = true);
                          Navigator.pop(context);
                        }),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // ── Page Enhancement ───────────────────────────────────────────────────────

  void _showEnhanceSheet() {
    // Local mutable state lives inside StatefulBuilder
    String? cleanMode;
    double  cleanStrength   = 1.0;
    bool    darkenText      = false;
    double  darkenStrength  = 1.8;
    bool    removeMarks     = false;
    String  markType        = 'blue_pen';
    String  applyScope      = 'page'; // 'page' | 'document'

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget sectionTitle(IconData icon, String label) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              Icon(icon, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold,
                fontSize: 14)),
            ]),
          );

          Widget strengthSlider(double val, double min, double max,
              String label, void Function(double) onChanged) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text(label, style: const TextStyle(
                  color: AppColors.sub, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value:        val,
                    min:          min,
                    max:          max,
                    divisions:    10,
                    activeColor:  AppColors.accent,
                    inactiveColor: AppColors.accent2.withOpacity(.3),
                    label:        val.toStringAsFixed(1),
                    onChanged:    onChanged,
                  ),
                ),
                Text(val.toStringAsFixed(1),
                  style: const TextStyle(color: AppColors.sub, fontSize: 12)),
              ]),
            );

          return DraggableScrollableSheet(
            expand:          false,
            initialChildSize: 0.72,
            maxChildSize:    0.95,
            builder: (_, scrollCtrl) => ListView(
              controller: scrollCtrl,
              children: [
                // ── Drag handle ──
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.sub.withOpacity(.4),
                      borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Center(child: Text('✨  Enhance Page',
                  style: TextStyle(color: AppColors.text,
                    fontWeight: FontWeight.bold, fontSize: 16))),
                const SizedBox(height: 4),

                // ── SECTION 1: Page Cleaning ─────────────────────────────
                const Divider(color: Colors.white12, height: 20),
                sectionTitle(Icons.cleaning_services, 'Page Cleaning'),
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 6),
                  child: Text(
                    'Remove yellowing, stains and shadows from scanned pages.',
                    style: TextStyle(color: AppColors.sub, fontSize: 11)),
                ),
                // Mode radio buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final entry in {
                        null:     'Off',
                        'bw':     'B&W Clean',
                        'color':  'Color',
                        'shadow': 'Shadow',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value,
                            style: const TextStyle(fontSize: 12)),
                          selected:        cleanMode == entry.key,
                          selectedColor:   AppColors.accent,
                          backgroundColor: AppColors.accent2.withOpacity(.2),
                          labelStyle: TextStyle(
                            color: cleanMode == entry.key
                              ? Colors.white : AppColors.sub),
                          onSelected: (_) =>
                            setLocal(() => cleanMode = entry.key),
                        ),
                    ],
                  ),
                ),
                if (cleanMode != null)
                  strengthSlider(cleanStrength, 0.5, 1.5, 'Strength  ',
                    (v) => setLocal(() => cleanStrength = v)),

                // ── SECTION 2: Text Darkening ────────────────────────────
                const Divider(color: Colors.white12, height: 20),
                sectionTitle(Icons.text_fields, 'Brighten & Darken Text'),
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 4),
                  child: Text(
                    'Darken faded or light text without altering the background.',
                    style: TextStyle(color: AppColors.sub, fontSize: 11)),
                ),
                SwitchListTile(
                  value:     darkenText,
                  onChanged: (v) => setLocal(() => darkenText = v),
                  title: const Text('Enable Text Darkening',
                    style: TextStyle(color: AppColors.text, fontSize: 13)),
                  activeColor: AppColors.accent,
                  dense: true,
                ),
                if (darkenText)
                  strengthSlider(darkenStrength, 1.0, 3.0, 'Strength  ',
                    (v) => setLocal(() => darkenStrength = v)),

                // ── SECTION 3: Mark Removal ──────────────────────────────
                const Divider(color: Colors.white12, height: 20),
                sectionTitle(Icons.edit_off, 'Remove Pen / Pencil Marks'),
                SwitchListTile(
                  value:     removeMarks,
                  onChanged: (v) => setLocal(() => removeMarks = v),
                  title: const Text('Enable Mark Removal',
                    style: TextStyle(color: AppColors.text, fontSize: 13)),
                  activeColor: AppColors.accent,
                  dense: true,
                ),
                if (removeMarks) ...[
                  // Mark type selector
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                    child: Wrap(
                      spacing: 6, runSpacing: 4,
                      children: kMarkTypes.entries.map((e) => ChoiceChip(
                        label: Text(e.value,
                          style: const TextStyle(fontSize: 11)),
                        selected:        markType == e.key,
                        selectedColor:   AppColors.accent,
                        backgroundColor: AppColors.accent2.withOpacity(.2),
                        labelStyle: TextStyle(
                          color: markType == e.key
                            ? Colors.white : AppColors.sub),
                        onSelected: (_) =>
                          setLocal(() => markType = e.key),
                      )).toList(),
                    ),
                  ),
                  // Legal disclaimer
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:  Colors.orange.withOpacity(.1),
                      border: Border.all(color: Colors.orange.withOpacity(.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 16),
                        SizedBox(width: 6),
                        Expanded(child: Text(
                          'For personal documents only — your own notes, '
                          'textbooks and drafts. Using this on official, '
                          'legal or government documents may constitute '
                          'forgery as per the law of your country.',
                          style: TextStyle(
                            color: Colors.orange, fontSize: 11))),
                      ],
                    ),
                  ),
                ],

                // ── Apply scope selector ─────────────────────────────────
                const Divider(color: Colors.white12, height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Apply To',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setLocal(() => applyScope = 'page'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: applyScope == 'page'
                                  ? AppColors.accent
                                  : AppColors.accent2.withOpacity(.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: applyScope == 'page'
                                    ? AppColors.accent
                                    : AppColors.accent2.withOpacity(.3)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.article,
                                    color: applyScope == 'page'
                                      ? Colors.white : AppColors.sub,
                                    size: 20),
                                  const SizedBox(height: 4),
                                  Text('This Page',
                                    style: TextStyle(
                                      color: applyScope == 'page'
                                        ? Colors.white : AppColors.sub,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                                  Text('Page $_curPage only',
                                    style: TextStyle(
                                      color: applyScope == 'page'
                                        ? Colors.white70 : AppColors.sub,
                                      fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                              setLocal(() => applyScope = 'document'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: applyScope == 'document'
                                  ? AppColors.accent
                                  : AppColors.accent2.withOpacity(.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: applyScope == 'document'
                                    ? AppColors.accent
                                    : AppColors.accent2.withOpacity(.3)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_stories,
                                    color: applyScope == 'document'
                                      ? Colors.white : AppColors.sub,
                                    size: 20),
                                  const SizedBox(height: 4),
                                  Text('Entire Document',
                                    style: TextStyle(
                                      color: applyScope == 'document'
                                        ? Colors.white : AppColors.sub,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                                  Text('All $_totalPages pages',
                                    style: TextStyle(
                                      color: applyScope == 'document'
                                        ? Colors.white70 : AppColors.sub,
                                      fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),

                // ── Apply / Reset buttons ────────────────────────────────
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    if (_enhancedPages.containsKey(_curPage - 1) &&
                        applyScope == 'page')
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() =>
                              _enhancedPages.remove(_curPage - 1));
                            Navigator.pop(ctx);
                            _showSnack('Page reset to original.');
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.sub,
                            side: const BorderSide(color: AppColors.sub)),
                        ),
                      ),
                    if (_enhancedPages.containsKey(_curPage - 1) &&
                        applyScope == 'page')
                      const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final config = EnhanceConfig(
                            cleanMode:      cleanMode,
                            cleanStrength:  cleanStrength,
                            darkenText:     darkenText,
                            darkenStrength: darkenStrength,
                            removeMarks:    removeMarks,
                            markType:       markType,
                          );
                          if (!config.hasAnyEffect) {
                            _showSnack('Please select at least one enhancement option.');
                            return;
                          }
                          Navigator.pop(ctx);
                          if (applyScope == 'document') {
                            _applyEnhancementToDocument(config);
                          } else {
                            _applyEnhancement(config);
                          }
                        },
                        icon: Icon(
                          applyScope == 'document'
                            ? Icons.auto_stories
                            : Icons.auto_fix_high,
                          size: 16),
                        label: Text(applyScope == 'document'
                          ? 'Enhance All $_totalPages Pages'
                          : 'Apply to This Page'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _applyEnhancement(EnhanceConfig config) async {
    setState(() => _enhancingPage = true);
    try {
      // Render the current page at 2× resolution for quality enhancement
      final docFuture = _pdfCtrl?.document;
      if (docFuture == null) return;
      final doc     = await docFuture;
      final page    = await doc.getPage(_curPage);          // 1-based
      final rendered = await page.render(
        width:  page.width  * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      if (rendered == null) {
        _showSnack('Could not render page for enhancement');
        return;
      }

      // Run enhancement in background isolate
      final enhanced = await PdfEnhanceService.enhance(rendered.bytes, config);

      if (mounted) {
        setState(() {
          _enhancedPages[_curPage - 1] = enhanced; // store as 0-based index
          _enhancingPage = false;
          _hasUnsavedChanges = true;
        });
        _showSnack('✨ Page enhanced successfully! Tap Done to save.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enhancingPage = false);
        _showSnack('Enhancement failed: $e');
      }
    }
  }

  /// Enhances every page of the document with the given config.
  /// Shows a live progress dialog — "Processing page X of Y…"
  Future<void> _applyEnhancementToDocument(EnhanceConfig config) async {
    final progressNotifier =
        ValueNotifier<String>('Processing page 1 of $_totalPages…');

    // Non-dismissible progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          title: const Row(children: [
            Icon(Icons.auto_stories, color: AppColors.accent, size: 18),
            SizedBox(width: 8),
            Text('Enhancing Document',
              style: TextStyle(color: AppColors.text, fontSize: 14)),
          ]),
          content: ValueListenableBuilder<String>(
            valueListenable: progressNotifier,
            builder: (_, msg, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 12),
                Text(msg,
                  style: const TextStyle(
                    color: AppColors.text, fontSize: 13),
                  textAlign: TextAlign.center),
                const SizedBox(height: 4),
                const Text('Please wait — do not close the app',
                  style: TextStyle(color: AppColors.sub, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final doc = await _pdfCtrl!.document;
      for (int i = 0; i < _totalPages; i++) {
        if (!mounted) break;
        progressNotifier.value =
            'Processing page ${i + 1} of $_totalPages…';

        final page     = await doc.getPage(i + 1);
        final rendered = await page.render(
          width:  page.width  * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();
        if (rendered == null) continue;

        final enhanced =
            await PdfEnhanceService.enhance(rendered.bytes, config);
        if (mounted) setState(() => _enhancedPages[i] = enhanced);
      }

      if (mounted) {
        Navigator.pop(context); // close progress dialog
        setState(() => _hasUnsavedChanges = true);
        _showSnack(
          '✨ All $_totalPages pages enhanced! Tap Done to save.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack('Enhancement failed: $e');
      }
    } finally {
      progressNotifier.dispose();
    }
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        if (_bookmarks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bookmark_border, color: AppColors.sub, size: 48),
              SizedBox(height: 12),
              Text('No bookmarks yet',
                style: TextStyle(color: AppColors.sub, fontSize: 15)),
              SizedBox(height: 4),
              Text('Tap the bookmark icon to mark a page',
                style: TextStyle(color: AppColors.sub, fontSize: 12)),
            ]),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.sub.withOpacity(.4),
                borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Bookmarks (${_bookmarks.length})',
                style: const TextStyle(color: AppColors.text,
                  fontWeight: FontWeight.bold, fontSize: 16))),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _bookmarks.map((bm) => ListTile(
                  leading: const Icon(Icons.bookmark, color: Color(0xFFFF9800)),
                  title: Text(bm.label,
                    style: const TextStyle(color: AppColors.text)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.sub, size: 18),
                    onPressed: () async {
                      await PrefsService.removeBookmark(widget.pdfPath, bm.page);
                      if (mounted) Navigator.pop(context);
                      _loadBookmarks();
                    },
                  ),
                  onTap: () {
                    _pdfCtrl?.jumpToPage(bm.page);
                    Navigator.pop(context);
                  },
                )).toList(),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        );
      },
    );
  }

  void _goToPage() {
    showDialog(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController(text: '$_curPage');
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Go To Page',
            style: TextStyle(color: AppColors.text)),
          content: TextField(
            controller:   ctrl,
            keyboardType: TextInputType.number,
            autofocus:    true,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: '1 – $_totalPages',
              hintStyle: const TextStyle(color: AppColors.sub),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent)),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent, width: 2)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.sub))),
            TextButton(
              onPressed: () {
                final pg = int.tryParse(ctrl.text);
                if (pg != null && pg >= 1 && pg <= _totalPages) {
                  _pdfCtrl?.jumpToPage(pg);
                }
                Navigator.pop(context);
              },
              child: const Text('Go', style: TextStyle(color: AppColors.accent))),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ERASER TOOL
  // ════════════════════════════════════════════════════════════════════════════

  void _showEraserWarning() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Text('Eraser Tool — Legal Warning',
            style: TextStyle(color: AppColors.text, fontSize: 15)),
        ]),
        content: const Text(
          'The Eraser Tool permanently removes visible content from the '
          'page image. This action cannot be undone once saved.\n\n'
          '⚠️  For personal use only — your own notes, study material, '
          'and drafts. Erasing content from official, legal, or government '
          'documents may constitute forgery as per the law of your country.\n\n'
          'Do you wish to continue?',
          style: TextStyle(color: AppColors.sub, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
              style: TextStyle(color: AppColors.sub))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _eraserMode = true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('I Understand',
              style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildEraserBar(double bottomPad) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF7B0000).withOpacity(0.97),
          border: Border(
              top: BorderSide(color: Colors.red.withOpacity(.4))),
        ),
        padding: EdgeInsets.only(
          left: 12, right: 12, top: 6,
          bottom: bottomPad > 0 ? 4 : 8,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Size control row
          Row(children: [
            const Icon(Icons.edit_off, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            const Text('Eraser  Size:',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
            Expanded(
              child: Slider(
                value:     _eraserSize,
                min:       8,
                max:       60,
                divisions: 13,
                activeColor:   Colors.red.shade300,
                inactiveColor: Colors.white24,
                label: '${_eraserSize.round()}px',
                onChanged: (v) => setState(() => _eraserSize = v),
              ),
            ),
            Text('${_eraserSize.round()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          // Action buttons row
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _eraserPoints.remove(_curPage - 1);
                  _currentEraserStroke = [];
                  _eraserMode = false;
                }),
                icon: const Icon(Icons.close, size: 15),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white30)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _applyingEraser ? null : _applyEraserStrokes,
                icon: _applyingEraser
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 15),
                label: Text(_applyingEraser ? 'Applying…' : 'Apply Eraser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _onEraserPanStart(
      DragStartDetails d, double sw, double sh, int pageIndex) {
    final pt = {
      'nx': (d.localPosition.dx / sw).clamp(0.0, 1.0),
      'ny': (d.localPosition.dy / sh).clamp(0.0, 1.0),
      'nr': _eraserSize / sw,
    };
    setState(() => _currentEraserStroke = [pt]);
  }

  void _onEraserPanUpdate(
      DragUpdateDetails d, double sw, double sh, int pageIndex) {
    final pt = {
      'nx': (d.localPosition.dx / sw).clamp(0.0, 1.0),
      'ny': (d.localPosition.dy / sh).clamp(0.0, 1.0),
      'nr': _eraserSize / sw,
    };
    setState(() =>
        _currentEraserStroke = [..._currentEraserStroke, pt]);
  }

  void _onEraserPanEnd(int pageIndex) {
    setState(() {
      _eraserPoints[pageIndex] = [
        ...(_eraserPoints[pageIndex] ?? []),
        ..._currentEraserStroke,
      ];
      _currentEraserStroke = [];
    });
  }

  Future<void> _applyEraserStrokes() async {
    final pageIndex = _curPage - 1;
    final points = <Map<String, double>>[
      ...(_eraserPoints[pageIndex] ?? []),
      ..._currentEraserStroke,
    ];
    if (points.isEmpty) {
      _showSnack('Draw something with the eraser first');
      return;
    }
    setState(() => _applyingEraser = true);
    try {
      // Get current page bytes (enhanced or freshly rendered)
      Uint8List baseBytes;
      if (_enhancedPages.containsKey(pageIndex)) {
        baseBytes = _enhancedPages[pageIndex]!;
      } else {
        final doc      = await _pdfCtrl!.document;
        final page     = await doc.getPage(_curPage);
        final rendered = await page.render(
          width:  page.width  * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();
        if (rendered == null) {
          _showSnack('Could not render page');
          setState(() => _applyingEraser = false);
          return;
        }
        baseBytes = rendered.bytes;
      }

      final result = await PdfEnhanceService.applyEraser(baseBytes, points);

      if (mounted) {
        setState(() {
          _enhancedPages[pageIndex]  = result;
          _eraserPoints.remove(pageIndex);
          _currentEraserStroke       = [];
          _eraserMode                = false;
          _applyingEraser            = false;
          _hasUnsavedChanges         = true;
        });
        _showSnack('✓ Eraser applied successfully. Tap Done to save.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _applyingEraser = false);
        _showSnack('Eraser failed: $e');
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DONE  ·  SAVE  ·  PRINT  ·  SHARE
  // ════════════════════════════════════════════════════════════════════════════

  /// Called by the green "Done" button.
  void _showDoneActions() {
    if (_eraserPoints.isNotEmpty || _currentEraserStroke.isNotEmpty) {
      // Unapplied strokes — ask user what to do first
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Unapplied Eraser Strokes',
            style: TextStyle(color: AppColors.text)),
          content: const Text(
            'You have eraser strokes that have not been applied yet. '
            'Apply them before saving?',
            style: TextStyle(color: AppColors.sub, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSaveDialog();
              },
              child: const Text('Skip & Save',
                style: TextStyle(color: AppColors.sub))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyEraserStrokes().then((_) {
                  if (mounted) _showSaveDialog();
                });
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent),
              child: const Text('Apply & Save',
                style: TextStyle(color: Colors.white))),
          ],
        ),
      );
    } else {
      _showSaveDialog();
    }
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Save Changes',
          style: TextStyle(color: AppColors.text)),
        content: const Text(
          'How would you like to save the modified PDF?',
          style: TextStyle(color: AppColors.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
              style: TextStyle(color: AppColors.sub))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveToFile(overwriteOriginal: true);
            },
            child: const Text('Save to Original',
              style: TextStyle(color: AppColors.accent))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveToFile(overwriteOriginal: false);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent),
            child: const Text('Save as New File',
              style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Future<void> _saveToFile({required bool overwriteOriginal}) async {
    // Show non-dismissible progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 12),
              Text('Building PDF…',
                style: TextStyle(color: AppColors.text, fontSize: 14)),
              SizedBox(height: 4),
              Text('This may take a moment',
                style: TextStyle(color: AppColors.sub, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
    try {
      final pdfBytes = await _buildModifiedPdf();

      final String savePath;
      if (overwriteOriginal) {
        savePath = widget.pdfPath;
      } else {
        final origName = p.basenameWithoutExtension(widget.pdfPath);
        final docsDir  = await getApplicationDocumentsDirectory();
        savePath = p.join(docsDir.path, '${origName}_enhanced.pdf');
      }

      await File(savePath).writeAsBytes(pdfBytes);

      if (mounted) {
        Navigator.pop(context); // close progress
        setState(() => _hasUnsavedChanges = false);
        _showSavedDialog(savePath);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack('Save failed: $e');
      }
    }
  }

  /// Render every page (using enhanced bytes where available) and build a PDF.
  Future<Uint8List> _buildModifiedPdf() async {
    final pdfDoc  = pw.Document();
    final pdfxDoc = await _pdfCtrl!.document;

    for (int i = 0; i < _totalPages; i++) {
      final pg    = await pdfxDoc.getPage(i + 1);
      final pageW = pg.width;
      final pageH = pg.height;

      Uint8List imgBytes;
      if (_enhancedPages.containsKey(i)) {
        imgBytes = _enhancedPages[i]!;
        await pg.close();
      } else {
        final rendered = await pg.render(
          width:  pageW * 2,   // 2× for quality; render() expects double
          height: pageH * 2,
          format: PdfPageImageFormat.png,
        );
        await pg.close();
        imgBytes = rendered!.bytes;
      }

      final memImg = pw.MemoryImage(imgBytes);
      pdfDoc.addPage(
        pw.Page(
          pageFormat: pdflib.PdfPageFormat(pageW, pageH),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(memImg, fit: pw.BoxFit.fill),
        ),
      );
    }
    return pdfDoc.save();
  }

  Future<void> _printPdf() async {
    try {
      _showSnack('Preparing PDF for print…');
      final pdfBytes = await _buildModifiedPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: p.basename(widget.pdfPath),
      );
    } catch (e) {
      if (mounted) _showSnack('Print failed: $e');
    }
  }

  Future<void> _shareFullPdf() async {
    try {
      if (!_hasUnsavedChanges && _enhancedPages.isEmpty) {
        // No modifications — share the original file directly
        await Share.shareXFiles(
          [XFile(widget.pdfPath)],
          text: 'Shared from PDF Pro Reader',
        );
        return;
      }
      _showSnack('Building PDF for sharing…');
      final pdfBytes = await _buildModifiedPdf();
      final tmp = File(p.join(
        (await getTemporaryDirectory()).path,
        p.basename(widget.pdfPath),
      ));
      await tmp.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(tmp.path)],
        text: 'Shared from PDF Pro Reader',
      );
    } catch (e) {
      if (mounted) _showSnack('Share failed: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // POST-SAVE DIALOG
  // ════════════════════════════════════════════════════════════════════════════

  /// Shown after a successful save: displays the file path and offers
  /// Open File, Share, Print and Close actions.
  void _showSavedDialog(String savePath) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 22),
          SizedBox(width: 8),
          Text('Saved Successfully',
            style: TextStyle(color: AppColors.text, fontSize: 15)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File saved to:',
              style: TextStyle(color: AppColors.sub, fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                savePath,
                style: const TextStyle(
                  color: AppColors.text, fontSize: 11),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
              style: TextStyle(color: AppColors.sub))),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _printPdf();
            },
            icon: const Icon(Icons.print, size: 16,
              color: AppColors.accent),
            label: const Text('Print',
              style: TextStyle(color: AppColors.accent))),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showShareDialog();
            },
            icon: const Icon(Icons.share, size: 16,
              color: AppColors.accent),
            label: const Text('Share',
              style: TextStyle(color: AppColors.accent))),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ReaderScreen(pdfPath: savePath)));
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SHARE DIALOG  (4-way: current page as PDF/Image, full doc as PDF/Images)
  // ════════════════════════════════════════════════════════════════════════════

  void _showShareDialog() {
    final isLargeDoc = _totalPages > 20;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.sub.withOpacity(.4),
              borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text('Share Options',
              style: TextStyle(color: AppColors.text,
                fontWeight: FontWeight.bold, fontSize: 17))),

          // ── Current Page ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Row(children: [
              const Icon(Icons.article_outlined,
                color: AppColors.sub, size: 14),
              const SizedBox(width: 4),
              Text('Current Page  (Page $_curPage)',
                style: const TextStyle(
                  color: AppColors.sub, fontSize: 12)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Expanded(child: _shareOptionTile(
                icon: Icons.picture_as_pdf,
                color: const Color(0xFFE53935),
                title: 'As PDF',
                subtitle: 'Single-page\nPDF file',
                onTap: () {
                  Navigator.pop(context);
                  _shareCurrentPageAsPdf();
                },
              )),
              Expanded(child: _shareOptionTile(
                icon: Icons.image_outlined,
                color: const Color(0xFF1E88E5),
                title: 'As Image',
                subtitle: 'JPEG\nimage file',
                onTap: () {
                  Navigator.pop(context);
                  _shareCurrentPageAsImage();
                },
              )),
            ]),
          ),

          const SizedBox(height: 6),

          // ── Entire Document ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Row(children: [
              const Icon(Icons.auto_stories,
                color: AppColors.sub, size: 14),
              const SizedBox(width: 4),
              Text('Entire Document  ($_totalPages pages)',
                style: const TextStyle(
                  color: AppColors.sub, fontSize: 12)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Expanded(child: _shareOptionTile(
                icon: Icons.picture_as_pdf,
                color: const Color(0xFFE53935),
                title: 'As PDF',
                subtitle: _hasUnsavedChanges
                  ? 'Modified\nPDF file'
                  : 'Original\nPDF file',
                onTap: () {
                  Navigator.pop(context);
                  _shareFullPdf();
                },
              )),
              Expanded(child: _shareOptionTile(
                icon: Icons.photo_library_outlined,
                color: isLargeDoc
                  ? const Color(0xFFFB8C00)
                  : const Color(0xFF43A047),
                title: 'As Images',
                subtitle: isLargeDoc
                  ? '⚠️ Large\n$_totalPages images'
                  : '$_totalPages JPEG\nimages',
                onTap: () {
                  Navigator.pop(context);
                  if (isLargeDoc) {
                    _confirmLargeImageShare();
                  } else {
                    _shareAllPagesAsImages();
                  }
                },
              )),
            ]),
          ),

          SizedBox(
            height: MediaQuery.of(context).padding.bottom + 14),
        ],
      ),
    );
  }

  /// A single tile inside the share dialog.
  Widget _shareOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          border: Border.all(color: color.withOpacity(.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(title,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 3),
            Text(subtitle,
              style: const TextStyle(
                color: AppColors.sub, fontSize: 10),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// Warning dialog before sharing a large document as images.
  void _confirmLargeImageShare() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Text('Large Document',
            style: TextStyle(color: AppColors.text, fontSize: 15)),
        ]),
        content: Text(
          'This document has $_totalPages pages. Sharing as images will '
          'create $_totalPages JPEG files, which may take a while to '
          'prepare and could be a very large share. Continue?',
          style: const TextStyle(
            color: AppColors.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
              style: TextStyle(color: AppColors.sub))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _shareAllPagesAsImages();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent),
            child: const Text('Share Anyway',
              style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  /// Share the current page as a single-page PDF.
  Future<void> _shareCurrentPageAsPdf() async {
    try {
      _showSnack('Preparing PDF for page $_curPage…');
      final doc  = await _pdfCtrl!.document;
      final page = await doc.getPage(_curPage);
      final pageW = page.width;
      final pageH = page.height;

      Uint8List imgBytes;
      if (_enhancedPages.containsKey(_curPage - 1)) {
        imgBytes = _enhancedPages[_curPage - 1]!;
        await page.close();
      } else {
        final rendered = await page.render(
          width:  pageW * 2,
          height: pageH * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();
        if (rendered == null) { _showSnack('Could not render page'); return; }
        imgBytes = rendered.bytes;
      }

      final pdfDoc = pw.Document();
      pdfDoc.addPage(pw.Page(
        pageFormat: pdflib.PdfPageFormat(pageW, pageH),
        margin: pw.EdgeInsets.zero,
        build: (_) =>
          pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.fill),
      ));
      final pdfBytes = await pdfDoc.save();

      final tmp = File(p.join(
        (await getTemporaryDirectory()).path,
        'pdf_page_$_curPage.pdf'));
      await tmp.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(tmp.path)],
        text: 'Page $_curPage from PDF Pro Reader',
      );
    } catch (e) {
      if (mounted) _showSnack('Share failed: $e');
    }
  }

  /// Share the current page as a JPEG image (original implementation renamed).
  Future<void> _shareCurrentPageAsImage() async {
    try {
      _showSnack('Preparing image for page $_curPage…');
      final doc  = await _pdfCtrl!.document;
      final page = await doc.getPage(_curPage);

      Uint8List imgBytes;
      if (_enhancedPages.containsKey(_curPage - 1)) {
        imgBytes = _enhancedPages[_curPage - 1]!;
        await page.close();
      } else {
        final rendered = await page.render(
          width:   page.width  * 2,
          height:  page.height * 2,
          format:  PdfPageImageFormat.jpeg,
          quality: 90,
        );
        await page.close();
        if (rendered == null) { _showSnack('Could not render page'); return; }
        imgBytes = rendered.bytes;
      }

      final tmp = File(p.join(
        (await getTemporaryDirectory()).path,
        'pdf_page_$_curPage.jpg'));
      await tmp.writeAsBytes(imgBytes);
      await Share.shareXFiles(
        [XFile(tmp.path)],
        text: 'Page $_curPage from PDF Pro Reader',
      );
    } catch (e) {
      if (mounted) _showSnack('Share failed: $e');
    }
  }

  /// Share every page of the document as JPEG images.
  Future<void> _shareAllPagesAsImages() async {
    try {
      _showSnack('Preparing $_totalPages images…');
      final doc    = await _pdfCtrl!.document;
      final tmpDir = await getTemporaryDirectory();
      final files  = <XFile>[];

      for (int i = 0; i < _totalPages; i++) {
        final page = await doc.getPage(i + 1);

        Uint8List imgBytes;
        if (_enhancedPages.containsKey(i)) {
          imgBytes = _enhancedPages[i]!;
          await page.close();
        } else {
          final rendered = await page.render(
            width:   page.width  * 2,
            height:  page.height * 2,
            format:  PdfPageImageFormat.jpeg,
            quality: 85,
          );
          await page.close();
          if (rendered == null) continue;
          imgBytes = rendered.bytes;
        }

        final f = File(p.join(tmpDir.path, 'page_${i + 1}.jpg'));
        await f.writeAsBytes(imgBytes);
        files.add(XFile(f.path));
      }

      if (files.isEmpty) { _showSnack('No pages to share'); return; }
      await Share.shareXFiles(
        files,
        text: 'Shared from PDF Pro Reader',
      );
    } catch (e) {
      if (mounted) _showSnack('Share failed: $e');
    }
  }

  Widget _buildError() {
    return SafeArea(
      child: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('PDF could not be loaded',
              style: TextStyle(color: AppColors.text, fontSize: 18),
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_error!,
              style: const TextStyle(color: AppColors.sub, fontSize: 12),
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back')),
          ],
        ),
      )),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.card,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        bottom: 80 + MediaQuery.of(context).padding.bottom,
        left: 16, right: 16,
      ),
      duration: const Duration(seconds: 3),
    ));
  }
}

// ── Eraser Painter ────────────────────────────────────────────────────────────
// Draws white filled circles at each eraser point (normalised coords 0–1).

class _EraserPainter extends CustomPainter {
  final List<Map<String, double>> points;
  const _EraserPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.white.withOpacity(0.93)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Colors.red.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final pt in points) {
      final cx = (pt['nx'] ?? 0.0) * size.width;
      final cy = (pt['ny'] ?? 0.0) * size.height;
      final r  = (pt['nr'] ?? 0.0) * size.width;
      canvas.drawCircle(Offset(cx, cy), r, fill);
      canvas.drawCircle(Offset(cx, cy), r, border);
    }
  }

  @override
  bool shouldRepaint(_EraserPainter old) => old.points != points;
}
