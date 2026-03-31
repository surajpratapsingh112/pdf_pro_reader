import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme.dart';
import '../models/video_area.dart';
import '../services/pdf_video_service.dart';
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

  // UI controls visibility (tap to toggle)
  bool _showControls = true;

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
          _showSnack('${result.videoPaths.length} video(s) found — tap cyan box to play 🎬');
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

  // ── Navigation bar ─────────────────────────────────────────────────────────

  Widget _buildNavBar(double bottomPad) {
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
        await _shareCurrentPage();
        break;
      case 'goto':
        _goToPage();
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
                          setState(() => _activePlayers[e.key] = true);
                          Navigator.pop(context);
                          _showVideoPlayer(e.key, e.value);
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

  void _showVideoPlayer(String name, String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 280,
          child: InlineVideoPlayer(
            videoPath: path,
            onClose: () {
              setState(() => _activePlayers.remove(name));
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
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

  Future<void> _shareCurrentPage() async {
    try {
      _showSnack('Preparing page for sharing...');
      final docFuture = _pdfCtrl?.document;
      if (docFuture == null) return;
      final doc  = await docFuture;
      final page = await doc.getPage(_curPage);
      final img  = await page.render(
        width:   page.width  * 2,
        height:  page.height * 2,
        format:  PdfPageImageFormat.jpeg,
        quality: 90,
      );
      if (img == null) return;
      final tmp = File(p.join(
        (await getTemporaryDirectory()).path,
        'pdf_page_$_curPage.jpg'));
      await tmp.writeAsBytes(img.bytes);
      await Share.shareXFiles(
        [XFile(tmp.path)],
        text: 'Shared from PDF Pro Reader — Page $_curPage',
      );
    } catch (e) {
      _showSnack('Share failed: $e');
    }
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
