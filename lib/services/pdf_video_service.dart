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
  static const _videoExtensions = {'.mp4', '.avi', '.mov', '.wmv', '.mkv', '.webm'};

  /// Extract all embedded video areas and their bytes from a PDF file.
  static Future<({List<VideoArea> areas, Map<String, String> videoPaths})>
      extractFromPdf(String pdfPath) async {
    final bytes = await File(pdfPath).readAsBytes();
    final areas = _scanVideoAreas(bytes);
    final names = areas.map((a) => a.name).toSet();
    final paths = await _extractVideos(bytes, names, pdfPath);
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
    final jsRe = RegExp(
      r"""exportDataObject\s*\(\s*\{[^}]*cName\s*:\s*["']([^"']+)["']""",
      caseSensitive: false,
    );
    final rectRe  = RegExp(r'/Rect\s*\[([0-9.\s\-]+)\]');
    final mediaBoxes = _extractMediaBoxes(content);

    for (final jsMatch in jsRe.allMatches(content)) {
      final vname = jsMatch.group(1)!;
      if (!_isVideoName(vname)) continue;

      final start  = (jsMatch.start - 4000).clamp(0, content.length);
      final end    = (jsMatch.end   +  500).clamp(0, content.length);
      final window = content.substring(start, end);

      final pageIdx = _guessPageIndex(content, jsMatch.start);

      final rectMatches = rectRe.allMatches(window);
      if (rectMatches.isEmpty) continue;

      final nums = rectMatches.last.group(1)!.trim()
          .split(RegExp(r'\s+'))
          .map(double.tryParse)
          .whereType<double>()
          .toList();
      if (nums.length < 4) continue;

      final pdfX0 = nums[0]; final pdfY0 = nums[1];
      final pdfX1 = nums[2]; final pdfY1 = nums[3];
      final pageH = pageIdx < mediaBoxes.length ? mediaBoxes[pageIdx] : 842.0;

      areas.add(VideoArea(
        pageIndex: pageIdx,
        x0: pdfX0,
        y0: pageH - pdfY1,   // PDF y=bottom → screen y=top
        x1: pdfX1,
        y1: pageH - pdfY0,
        name: vname,
      ));
    }
  }

  static List<double> _extractMediaBoxes(String content) {
    final re = RegExp(
        r'/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+[\d.]+\s+([\d.]+)\s*\]');
    return re.allMatches(content)
        .map((m) => double.tryParse(m.group(1)!) ?? 842.0)
        .toList();
  }

  static int _guessPageIndex(String content, int pos) {
    final re = RegExp(r'/Type\s*/Page(?!\s*/Pages)');
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
        if (videoBytes == null) continue;
        final tmp = File(p.join(tmpDir.path, 'pdfpro_$name'));
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
    final nameRe = RegExp(
        r'\(' + escapedName + r'\)\s+(\d+)\s+(\d+)\s+R',
        caseSensitive: false);
    final nameMatch = nameRe.firstMatch(content);
    if (nameMatch == null) {
      return _extractViaStreamSearch(content, rawBytes, filename);
    }

    final objNum = int.parse(nameMatch.group(1)!);
    final genNum = int.parse(nameMatch.group(2)!);

    final fsObjRe = RegExp(
        r'\b' + RegExp.escape('$objNum $genNum') + r'\s+obj\s*(<<[\s\S]*?>>)',
        dotAll: true);
    final fsMatch = fsObjRe.firstMatch(content);
    if (fsMatch == null) return _extractViaStreamSearch(content, rawBytes, filename);

    final efRe = RegExp(r'/EF\s*<<[^>]*?/F\s+(\d+)\s+(\d+)\s+R');
    final efMatch = efRe.firstMatch(fsMatch.group(1)!);
    if (efMatch == null) return _extractViaStreamSearch(content, rawBytes, filename);

    return _readStreamObject(
        content, rawBytes,
        int.parse(efMatch.group(1)!),
        int.parse(efMatch.group(2)!));
  }

  static Uint8List? _readStreamObject(
      String content, Uint8List rawBytes, int objNum, int genNum) {
    final objRe = RegExp(
        r'\b' + RegExp.escape('$objNum $genNum') +
        r'\s+obj\s*<<([\s\S]*?)>>\s*stream',
        dotAll: true);
    final objMatch = objRe.firstMatch(content);
    if (objMatch == null) return null;

    final dictStr = objMatch.group(1)!;
    final lenMatch = RegExp(r'/Length\s+(\d+)').firstMatch(dictStr);
    if (lenMatch == null) return null;
    final length = int.parse(lenMatch.group(1)!);

    int dataStart = objMatch.end;
    if (dataStart < rawBytes.length && rawBytes[dataStart] == 0x0D) dataStart++;
    if (dataStart < rawBytes.length && rawBytes[dataStart] == 0x0A) dataStart++;
    if (dataStart + length > rawBytes.length) return null;

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
    // MP4 magic: box size (4 bytes) + 'ftyp'
    if (ext == '.mp4' || ext == '.mov') {
      const ftyp = [0x66, 0x74, 0x79, 0x70];
      for (int i = 4; i < rawBytes.length - 8; i++) {
        if (rawBytes[i]   == ftyp[0] && rawBytes[i+1] == ftyp[1] &&
            rawBytes[i+2] == ftyp[2] && rawBytes[i+3] == ftyp[3]) {
          final start = i - 4;
          final end   = content.indexOf('endstream', start);
          if (end != -1) return rawBytes.sublist(start, end);
        }
      }
    }
    return null;
  }

  static void _log(String msg) => print('[PdfVideoService] $msg'); // ignore: avoid_print
}
