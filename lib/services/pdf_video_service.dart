// PDF Video Service
// Reads embedded video data from PDF files (created by PDF Pro app)
// Pure Dart implementation - no native plugins needed

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/video_area.dart';

class PdfVideoService {
  static const _videoExtensions = {'.mp4', '.avi', '.mov', '.wmv', '.mkv', '.webm', '.gif'};

  /// Extract all embedded video areas and their bytes from a PDF file.
  static Future<({List<VideoArea> areas, Map<String, String> videoPaths})>
      extractFromPdf(String pdfPath) async {
    final bytes = await File(pdfPath).readAsBytes();
    final areas = _scanVideoAreas(bytes);
    _log('Found ${areas.length} video area(s): ${areas.map((a) => a.name)}');
    final names = areas.map((a) => a.name).toSet();
    final paths = await _extractVideos(bytes, names, pdfPath);
    _log('Extracted ${paths.length} video(s): ${paths.keys}');
    return (areas: areas, videoPaths: paths);
  }

  // ── Step 1: Scan PDF for video annotation areas ──────────────────────────

  static List<VideoArea> _scanVideoAreas(Uint8List bytes) {
    final areas   = <VideoArea>[];
    final content = latin1.decode(bytes, allowInvalid: true);
    _scanAnnotations(content, areas);
    return areas;
  }

  static void _scanAnnotations(String content, List<VideoArea> areas) {
    // PDF string literals escape parentheses as \( and \).
    final jsRe = RegExp(
      r"""exportDataObject\s*\\?\(\s*\{[^}]*cName\s*:\s*["']([^"']+)["']""",
      caseSensitive: false,
    );

    final rectRe     = RegExp(r'/Rect\s*\[?\s*([0-9.\-\s]+?)\s*\]');
    final mediaBoxes = _extractMediaBoxes(content);

    // Build ordered list of page-object numbers so we can map
    // the /P reference in each annotation → correct 0-based page index.
    // This is far more reliable than counting /Type/Page occurrences by
    // file position, because pikepdf writes annotation objects AFTER all
    // page objects — making the position-based heuristic always return the
    // last page index for every annotation.
    final pageObjNums = _getPageObjectNumbers(content);
    _log('Page object numbers (in order): $pageObjNums');

    for (final jsMatch in jsRe.allMatches(content)) {
      final vname = jsMatch.group(1)!;
      _log('cName match: "$vname"');
      if (!_isVideoName(vname)) {
        _log('  -> skipped (not a video extension)');
        continue;
      }

      // Find the start of the annotation object that contains this jsMatch by
      // searching backwards for the nearest "N 0 obj" marker.  This prevents
      // rectRe.firstMatch from picking up a /Rect belonging to an EARLIER
      // annotation object when the backward window is too wide.
      final lookBack = content.substring(
          (jsMatch.start - 2000).clamp(0, content.length), jsMatch.start);
      final objMarkerRe = RegExp(r'\d+\s+0\s+obj');
      int objRelPos = 0;
      for (final m in objMarkerRe.allMatches(lookBack)) {
        objRelPos = m.start; // keep updating → last match = nearest object start
      }
      final objAbsStart =
          (jsMatch.start - 2000).clamp(0, content.length) + objRelPos;

      // /P comes AFTER the JS in the annotation dict; extend window forward.
      final winEnd = (jsMatch.end + 1500).clamp(0, content.length);
      final window = content.substring(objAbsStart, winEnd);

      // ── Determine page index via /P reference ─────────────────────────
      // Each Link annotation written by pikepdf contains  /P N 0 R
      // pointing to its parent page object.  Find N, then look it up in
      // pageObjNums to get the 0-based page index.
      int pageIdx = 0;
      final pRefRe = RegExp(r'/P\s+(\d+)\s+\d+\s+R');
      final pMatch = pRefRe.firstMatch(window);
      if (pMatch != null) {
        final pageObjNum = int.parse(pMatch.group(1)!);
        final idx = pageObjNums.indexOf(pageObjNum);
        pageIdx = idx >= 0 ? idx : 0;
        _log('  -> pageIndex=$pageIdx (via /P $pageObjNum)');
      } else {
        // Fallback: position-based heuristic (works for single-video PDFs)
        pageIdx = _guessPageIndex(content, jsMatch.start);
        _log('  -> pageIndex=$pageIdx (heuristic fallback, no /P found)');
      }

      final rectMatch = rectRe.firstMatch(window);
      if (rectMatch == null) {
        _log('  -> no /Rect found in window');
        continue;
      }

      final nums = rectMatch.group(1)!.trim()
          .split(RegExp(r'[\s,]+'))
          .map(double.tryParse)
          .whereType<double>()
          .toList();
      if (nums.length < 4) {
        _log('  -> bad rect nums: $nums');
        continue;
      }

      final box   = pageIdx < mediaBoxes.length ? mediaBoxes[pageIdx]
                                                 : (width: 595.0, height: 842.0);
      final pageW = box.width;
      final pageH = box.height;

      final pdfX0 = nums[0]; final pdfY0 = nums[1];
      final pdfX1 = nums[2]; final pdfY1 = nums[3];

      // PDF y=0 is at bottom; convert to screen y=0 at top
      final area = VideoArea(
        pageIndex:  pageIdx,
        x0:         pdfX0,
        y0:         pageH - pdfY1,
        x1:         pdfX1,
        y1:         pageH - pdfY0,
        name:       vname,
        pageWidth:  pageW,
        pageHeight: pageH,
      );
      _log('  -> VideoArea: $area');
      areas.add(area);
    }
  }

  /// Returns the PDF object numbers of all /Type /Page objects,
  /// sorted by their byte position in the file (= page order).
  static List<int> _getPageObjectNumbers(String content) {
    final result = <({int num, int pos})>[];
    final objRe  = RegExp(r'(\d+)\s+0\s+obj', multiLine: true);
    for (final m in objRe.allMatches(content)) {
      // Look ahead up to 1500 chars for /Type /Page (excluding /Pages)
      final ahead = content.substring(
          m.start, (m.start + 1500).clamp(0, content.length));
      if (RegExp(r'/Type\s*/Page(?!s)').hasMatch(ahead)) {
        result.add((num: int.parse(m.group(1)!), pos: m.start));
      }
    }
    result.sort((a, b) => a.pos.compareTo(b.pos));
    return result.map((e) => e.num).toList();
  }

  /// Returns list of (width, height) pairs from all /MediaBox entries.
  static List<({double width, double height})> _extractMediaBoxes(String content) {
    // /MediaBox [minX minY maxX maxY]  — capture maxX (width) and maxY (height)
    final re = RegExp(
        r'/MediaBox\s*\[?\s*[\d.]+\s+[\d.]+\s+([\d.]+)\s+([\d.]+)');
    return re.allMatches(content).map((m) => (
      width:  double.tryParse(m.group(1)!) ?? 595.0,
      height: double.tryParse(m.group(2)!) ?? 842.0,
    )).toList();
  }

  /// Fallback: count /Type /Page occurrences before [pos].
  static int _guessPageIndex(String content, int pos) {
    final re = RegExp(r'/Type\s*/Page(?!s)');
    int count = 0;
    for (final m in re.allMatches(content)) {
      if (m.start >= pos) break;
      count++;
    }
    return (count - 1).clamp(0, 999);
  }

  static bool _isVideoName(String name) =>
      _videoExtensions.contains(p.extension(name).toLowerCase());

  // ── Step 2: Extract video bytes from PDF EmbeddedFiles ──────────────────

  static Future<Map<String, String>> _extractVideos(
    Uint8List bytes, Set<String> names, String pdfPath) async {
    final result  = <String, String>{};
    if (names.isEmpty) return result;

    final content = latin1.decode(bytes, allowInvalid: true);
    final tmpDir  = await getTemporaryDirectory();

    for (final name in names) {
      try {
        final videoBytes = _extractEmbeddedFileBytes(content, bytes, name);
        if (videoBytes == null) {
          _log('Could not extract bytes for: $name');
          continue;
        }
        _log('Extracted ${videoBytes.length} bytes for: $name');
        final tmp = File(p.join(tmpDir.path, 'pdfpro_${name.replaceAll(RegExp(r'[^\w.]'), '_')}'));
        await tmp.writeAsBytes(videoBytes);
        result[name] = tmp.path;
      } catch (e) {
        _log('Error extracting $name: $e');
      }
    }
    return result;
  }

  static Uint8List? _extractEmbeddedFileBytes(
      String content, Uint8List rawBytes, String filename) {
    final escapedName = RegExp.escape(filename);

    // FIX 4: Use \s* (zero-or-more) instead of \s+ because some PDFs write
    // the object reference directly after the closing ) with no space:
    //   (filename.mp4)3 0 R   ← no space between ) and 3
    final nameRe = RegExp(
        r'\(' + escapedName + r'\)\s*(\d+)\s+(\d+)\s+R',
        caseSensitive: false);
    // Use LAST match, not first: each _do_embed_gif call leaves a stale Names
    // array in the file (pikepdf saves without GC).  firstMatch finds the stale
    // entry whose EF stream may be unusable.  The LAST occurrence is always the
    // most-recently-written Names array → the valid embedded file object.
    final nameMatches = nameRe.allMatches(content).toList();
    if (nameMatches.isEmpty) {
      _log('nameRe not found for "$filename" — trying stream search');
      return _extractViaStreamSearch(content, rawBytes, filename);
    }
    final nameMatch = nameMatches.last;

    final objNum = int.parse(nameMatch.group(1)!);
    final genNum = int.parse(nameMatch.group(2)!);
    _log('Filespec object: $objNum $genNum R');

    final fsObjRe = RegExp(
        r'\b' + RegExp.escape('$objNum $genNum') + r'\s+obj\s*(<<[\s\S]*?>>)',
        dotAll: true);
    final fsMatch = fsObjRe.firstMatch(content);
    if (fsMatch == null) {
      _log('fsObjRe not found');
      return _extractViaStreamSearch(content, rawBytes, filename);
    }

    final efRe = RegExp(r'/EF\s*<<[^>]*?/F\s+(\d+)\s+(\d+)\s+R');
    final efMatch = efRe.firstMatch(fsMatch.group(1)!);
    if (efMatch == null) {
      _log('efRe not found in filespec dict');
      return _extractViaStreamSearch(content, rawBytes, filename);
    }

    final streamObj = int.parse(efMatch.group(1)!);
    final streamGen = int.parse(efMatch.group(2)!);
    _log('Stream object: $streamObj $streamGen R');

    return _readStreamObject(content, rawBytes, streamObj, streamGen);
  }

  static Uint8List? _readStreamObject(
      String content, Uint8List rawBytes, int objNum, int genNum) {
    final objRe = RegExp(
        r'\b' + RegExp.escape('$objNum $genNum') +
        r'\s+obj\s*<<([\s\S]*?)>>\s*stream',
        dotAll: true);
    final objMatch = objRe.firstMatch(content);
    if (objMatch == null) {
      _log('stream object $objNum $genNum not found');
      return null;
    }

    final dictStr = objMatch.group(1)!;
    final lenMatch = RegExp(r'/Length\s+(\d+)').firstMatch(dictStr);
    if (lenMatch == null) {
      _log('no /Length in stream dict');
      return null;
    }
    final length = int.parse(lenMatch.group(1)!);
    _log('Stream length: $length bytes');

    // objMatch.end is position in latin-1 decoded string = byte offset in rawBytes
    int dataStart = objMatch.end;
    // Skip CR/LF after "stream" keyword
    if (dataStart < rawBytes.length && rawBytes[dataStart] == 0x0D) dataStart++;
    if (dataStart < rawBytes.length && rawBytes[dataStart] == 0x0A) dataStart++;
    if (dataStart + length > rawBytes.length) {
      _log('Stream extends beyond file: $dataStart + $length > ${rawBytes.length}');
      return null;
    }

    final streamBytes = rawBytes.sublist(dataStart, dataStart + length);

    if (dictStr.contains('/FlateDecode') || dictStr.contains('/Fl ')) {
      try { return Uint8List.fromList(zlib.decode(streamBytes)); }
      catch (_) { return streamBytes; }
    }
    return streamBytes;
  }

  static Uint8List? _extractViaStreamSearch(
      String content, Uint8List rawBytes, String filename) {
    final ext = p.extension(filename).toLowerCase();

    // MP4/MOV magic: 4-byte box size + 'ftyp' at offset 4
    if (ext == '.mp4' || ext == '.mov') {
      const ftyp = [0x66, 0x74, 0x79, 0x70]; // 'ftyp'
      for (int i = 4; i < rawBytes.length - 8; i++) {
        if (rawBytes[i]   == ftyp[0] && rawBytes[i+1] == ftyp[1] &&
            rawBytes[i+2] == ftyp[2] && rawBytes[i+3] == ftyp[3]) {
          final start = i - 4;
          final endIdx = content.indexOf('endstream', start);
          if (endIdx != -1) {
            _log('Found MP4 via magic bytes at $start');
            return rawBytes.sublist(start, endIdx);
          }
        }
      }
    }

    // GIF magic: GIF87a = [47 49 46 38 37 61]  GIF89a = [47 49 46 38 39 61]
    if (ext == '.gif') {
      const gif8 = [0x47, 0x49, 0x46, 0x38]; // 'GIF8'
      for (int i = 0; i < rawBytes.length - 6; i++) {
        if (rawBytes[i]   == gif8[0] && rawBytes[i+1] == gif8[1] &&
            rawBytes[i+2] == gif8[2] && rawBytes[i+3] == gif8[3]) {
          final endIdx = content.indexOf('endstream', i);
          if (endIdx != -1) {
            _log('Found GIF via magic bytes at $i');
            return rawBytes.sublist(i, endIdx);
          }
        }
      }
    }

    _log('Stream search failed for $filename');
    return null;
  }

  static void _log(String msg) =>
      print('[PdfVideoService] $msg'); // ignore: avoid_print
}
