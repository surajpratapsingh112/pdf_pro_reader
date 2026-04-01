// PDF Page Enhancement Service
// Pure Dart port of pdf_enhancer.py (PageCleaner, TextDarkener, MarkRemover).
// All heavy processing runs in a background isolate via compute() so the UI
// never freezes.

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // compute()
import 'package:image/image.dart' as img;

// ── Configuration ────────────────────────────────────────────────────────────

class EnhanceConfig {
  final String? cleanMode;      // 'bw' | 'color' | 'shadow' | null (off)
  final double  cleanStrength;  // 0.5 → 1.5
  final bool    darkenText;
  final double  darkenStrength; // 1.0 → 3.0
  final bool    removeMarks;
  final String  markType;       // see kMarkTypes below

  const EnhanceConfig({
    this.cleanMode,
    this.cleanStrength  = 1.0,
    this.darkenText     = false,
    this.darkenStrength = 1.8,
    this.removeMarks    = false,
    this.markType       = 'blue_pen',
  });

  bool get hasAnyEffect =>
      cleanMode != null || darkenText || removeMarks;

  // Serializable for compute()
  Map<String, dynamic> toMap() => {
    'cleanMode':      cleanMode,
    'cleanStrength':  cleanStrength,
    'darkenText':     darkenText,
    'darkenStrength': darkenStrength,
    'removeMarks':    removeMarks,
    'markType':       markType,
  };
  factory EnhanceConfig.fromMap(Map<String, dynamic> m) => EnhanceConfig(
    cleanMode:      m['cleanMode']      as String?,
    cleanStrength:  (m['cleanStrength'] as num).toDouble(),
    darkenText:     m['darkenText']     as bool,
    darkenStrength: (m['darkenStrength'] as num).toDouble(),
    removeMarks:    m['removeMarks']    as bool,
    markType:       m['markType']       as String,
  );
}

const kMarkTypes = {
  'blue_pen':   'Blue Pen',
  'red_pen':    'Red Pen',
  'green_pen':  'Green Pen',
  'pencil':     'Pencil (Gray)',
  'yellow_hi':  'Yellow Highlighter',
  'pink_hi':    'Pink Highlighter',
};

// ── Public API ────────────────────────────────────────────────────────────────

class PdfEnhanceService {
  /// Apply [config] to [pngBytes] (PNG image of a PDF page).
  /// Returns enhanced PNG bytes. Runs in a background isolate.
  static Future<Uint8List> enhance(Uint8List pngBytes, EnhanceConfig config) {
    return compute(_enhanceIsolate, {
      'bytes':  pngBytes,
      'config': config.toMap(),
    });
  }

  // ── Isolate entry ─────────────────────────────────────────────────────────

  static Uint8List _enhanceIsolate(Map<String, dynamic> args) {
    final bytes  = args['bytes']  as Uint8List;
    final config = EnhanceConfig.fromMap(
        args['config'] as Map<String, dynamic>);

    img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    if (config.cleanMode != null) {
      image = _applyClean(image, config.cleanMode!, config.cleanStrength);
    }
    if (config.darkenText) {
      image = _applyTextDarkening(image, config.darkenStrength);
    }
    if (config.removeMarks) {
      image = _applyMarkRemoval(image, config.markType);
    }

    return img.encodePng(image);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FEATURE 1 — PAGE CLEANING
  // ════════════════════════════════════════════════════════════════════════════

  static img.Image _applyClean(
      img.Image src, String mode, double strength) {
    switch (mode) {
      case 'bw':     return _cleanBW(src, strength);
      case 'color':  return _cleanColor(src, strength);
      case 'shadow': return _cleanShadow(src, strength);
      default:       return src;
    }
  }

  /// B&W Clean: Adaptive threshold → pure white background + sharp black text.
  /// Best for: text-only docs, forms, scanned contracts.
  static img.Image _cleanBW(img.Image src, double strength) {
    final W = src.width, H = src.height;

    // block size (larger = more aggressive); must be odd
    int block = (31 * (0.5 + 0.5 * strength)).round();
    if (block.isEven) block++;
    block = block.clamp(11, 101);
    final C = (8 * strength).round().clamp(2, 20);

    // --- Build grayscale flat array ---
    final gray = Uint8List(W * H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final p = src.getPixel(x, y);
        gray[y * W + x] =
            (p.r * 0.299 + p.g * 0.587 + p.b * 0.114).round().clamp(0, 255);
      }
    }

    // --- Integral image for O(1) local mean ---
    final integral = Float64List((W + 1) * (H + 1));
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        integral[(y + 1) * (W + 1) + (x + 1)] = gray[y * W + x].toDouble()
            + integral[y * (W + 1) + (x + 1)]
            + integral[(y + 1) * (W + 1) + x]
            - integral[y * (W + 1) + x];
      }
    }

    // --- Adaptive threshold ---
    final result = img.Image(width: W, height: H);
    final half   = block ~/ 2;
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final x1 = (x - half).clamp(0, W - 1);
        final y1 = (y - half).clamp(0, H - 1);
        final x2 = (x + half).clamp(0, W - 1);
        final y2 = (y + half).clamp(0, H - 1);
        final area = ((x2 - x1 + 1) * (y2 - y1 + 1)).toDouble();
        final sum  = integral[(y2+1)*(W+1)+(x2+1)]
                   - integral[y1*(W+1)+(x2+1)]
                   - integral[(y2+1)*(W+1)+x1]
                   + integral[y1*(W+1)+x1];
        final mean = sum / area;
        final val  = gray[y * W + x] < (mean - C) ? 0 : 255;
        result.setPixelRgb(x, y, val, val, val);
      }
    }
    return result;
  }

  /// Color Clean: Histogram stretch + gamma correction.
  /// Best for: documents with colored text / logos.
  static img.Image _cleanColor(img.Image src, double strength) {
    final W = src.width, H = src.height;
    final gamma = (0.80 + (1.0 - strength) * 0.1).clamp(0.6, 1.0);

    // Collect luminance for 2%–98% histogram stretch
    final lums = List<double>.filled(W * H, 0);
    int i = 0;
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final p = src.getPixel(x, y);
        lums[i++] = p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
      }
    }
    lums.sort();
    final minL  = lums[(lums.length * 0.02).round()].clamp(0.0, 255.0);
    final maxL  = lums[(lums.length * 0.98).round()].clamp(0.0, 255.0);
    final range = (maxL - minL).clamp(1.0, 255.0);

    final result = img.Image(width: W, height: H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final p = src.getPixel(x, y);
        double r = ((p.r - minL) / range * 255).clamp(0.0, 255.0);
        double g = ((p.g - minL) / range * 255).clamp(0.0, 255.0);
        double b = ((p.b - minL) / range * 255).clamp(0.0, 255.0);
        // Gamma < 1 brightens background toward white
        // math.pow returns num → cast to double explicitly
        r = (math.pow(r / 255, gamma) * 255).toDouble().clamp(0.0, 255.0);
        g = (math.pow(g / 255, gamma) * 255).toDouble().clamp(0.0, 255.0);
        b = (math.pow(b / 255, gamma) * 255).toDouble().clamp(0.0, 255.0);
        result.setPixelRgb(x, y, r.round(), g.round(), b.round());
      }
    }
    return result;
  }

  /// Shadow Clean: Divide each channel by its blurred background.
  /// Best for: camera-photographed docs with uneven lighting.
  static img.Image _cleanShadow(img.Image src, double strength) {
    final W = src.width, H = src.height;
    final radius = (40 * strength).round().clamp(25, 80);

    // Extract channels
    final rArr = Uint8List(W * H), gArr = Uint8List(W * H),
          bArr = Uint8List(W * H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final p = src.getPixel(x, y);
        rArr[y*W+x] = p.r.toInt(); gArr[y*W+x] = p.g.toInt();
        bArr[y*W+x] = p.b.toInt();
      }
    }

    // Background ≈ heavily blurred version of each channel
    final bgR = _boxBlurGray(rArr, W, H, radius);
    final bgG = _boxBlurGray(gArr, W, H, radius);
    final bgB = _boxBlurGray(bArr, W, H, radius);

    final result = img.Image(width: W, height: H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final idx = y * W + x;
        final r   = bgR[idx] > 0 ? (rArr[idx]/bgR[idx]*215).clamp(0,255) : 255.0;
        final g   = bgG[idx] > 0 ? (gArr[idx]/bgG[idx]*215).clamp(0,255) : 255.0;
        final b   = bgB[idx] > 0 ? (bArr[idx]/bgB[idx]*215).clamp(0,255) : 255.0;
        final lum = r * 0.299 + g * 0.587 + b * 0.114;
        // Push very bright areas to pure white
        if (lum > 195) {
          result.setPixelRgb(x, y, 255, 255, 255);
        } else {
          result.setPixelRgb(x, y, r.round(), g.round(), b.round());
        }
      }
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FEATURE 2 — TEXT DARKENING
  // ════════════════════════════════════════════════════════════════════════════

  /// Darken only text pixels (darker than local mean) without touching background.
  static img.Image _applyTextDarkening(img.Image src, double strength) {
    final W = src.width, H = src.height;

    // Build grayscale
    final gray = Uint8List(W * H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final p = src.getPixel(x, y);
        gray[y*W+x] =
            (p.r*0.299 + p.g*0.587 + p.b*0.114).round().clamp(0, 255);
      }
    }

    // Integral image for local mean (radius=16 block)
    final integral = Float64List((W + 1) * (H + 1));
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        integral[(y+1)*(W+1)+(x+1)] = gray[y*W+x].toDouble()
            + integral[y*(W+1)+(x+1)]
            + integral[(y+1)*(W+1)+x]
            - integral[y*(W+1)+x];
      }
    }

    const half   = 16;
    final result = img.Image(width: W, height: H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final x1   = (x-half).clamp(0,W-1), y1 = (y-half).clamp(0,H-1);
        final x2   = (x+half).clamp(0,W-1), y2 = (y+half).clamp(0,H-1);
        final area = ((x2-x1+1)*(y2-y1+1)).toDouble();
        final sum  = integral[(y2+1)*(W+1)+(x2+1)]
                   - integral[y1*(W+1)+(x2+1)]
                   - integral[(y2+1)*(W+1)+x1]
                   + integral[y1*(W+1)+x1];
        final localMean = sum / area;
        final gv  = gray[y*W+x].toDouble();
        final p   = src.getPixel(x, y);
        double r  = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();

        if (gv < localMean - 8) {
          // Text pixel → darken
          r = (r / strength).clamp(0, 255);
          g = (g / strength).clamp(0, 255);
          b = (b / strength).clamp(0, 255);
        } else if (gv > localMean + 5) {
          // Background pixel → slightly whiten
          r = (r * 1.06).clamp(0, 255);
          g = (g * 1.06).clamp(0, 255);
          b = (b * 1.06).clamp(0, 255);
        }
        result.setPixelRgb(x, y, r.round(), g.round(), b.round());
      }
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FEATURE 3 — MARK REMOVAL
  // ════════════════════════════════════════════════════════════════════════════

  /// Detect colored/pencil marks and fill with surrounding background.
  static img.Image _applyMarkRemoval(img.Image src, String markType) {
    final W = src.width, H = src.height;

    // Build grayscale and background estimate for pencil detection
    final gray = Uint8List(W * H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final p = src.getPixel(x, y);
        gray[y*W+x] =
            (p.r*0.299 + p.g*0.587 + p.b*0.114).round().clamp(0, 255);
      }
    }
    final bgBlur = _boxBlurGray(gray, W, H, 28);

    // --- Build mark mask ---
    final mask = Uint8List(W * H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final p   = src.getPixel(x, y);
        final r   = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
        final gv  = gray[y*W+x];
        bool isMark = false;

        switch (markType) {
          case 'blue_pen':
            isMark = b > 90 && b > r * 1.35 && b > g * 1.15 &&
                     gv < 200 && (r + g) < 310;
            break;
          case 'red_pen':
            isMark = r > 130 && r > b * 1.7 && r > g * 1.4 && gv < 220;
            break;
          case 'green_pen':
            isMark = g > 110 && g > r * 1.25 && g > b * 1.25 && gv < 220;
            break;
          case 'pencil':
            final bgVal = bgBlur[y*W+x];
            final isGray = (r-g).abs() < 38 && (g-b).abs() < 38;
            isMark = isGray && gv > 45 && gv < 215 && (bgVal - gv) > 16;
            break;
          case 'yellow_hi':
            isMark = r > 170 && g > 165 && b < 130 && gv > 140;
            break;
          case 'pink_hi':
            isMark = r > 170 && b > 100 && g < (r - 35) && gv > 120;
            break;
        }
        if (isMark) mask[y*W+x] = 1;
      }
    }

    // Dilate mask by 1 pixel to cover stroke edges
    final dilated = Uint8List(W * H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        if (mask[y*W+x] == 1) {
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              final nx = (x+dx).clamp(0,W-1), ny = (y+dy).clamp(0,H-1);
              dilated[ny*W+nx] = 1;
            }
          }
        }
      }
    }

    // --- Fill mark pixels with surrounding background ---
    final result = img.Image(width: W, height: H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        if (dilated[y*W+x] == 0) {
          // Non-mark pixel: copy original
          final p = src.getPixel(x, y);
          result.setPixelRgb(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt());
        } else {
          // Mark pixel: fill with average of nearby clean pixels
          int sumR = 0, sumG = 0, sumB = 0, cnt = 0;
          for (int dy = -10; dy <= 10; dy += 2) {
            for (int dx = -10; dx <= 10; dx += 2) {
              final nx = (x+dx).clamp(0,W-1), ny = (y+dy).clamp(0,H-1);
              if (dilated[ny*W+nx] == 0) {
                final np = src.getPixel(nx, ny);
                sumR += np.r.toInt(); sumG += np.g.toInt();
                sumB += np.b.toInt(); cnt++;
              }
            }
          }
          if (cnt > 0) {
            result.setPixelRgb(x, y, sumR~/cnt, sumG~/cnt, sumB~/cnt);
          } else {
            result.setPixelRgb(x, y, 255, 255, 255); // fallback: white
          }
        }
      }
    }
    return result;
  }

  // ── Utility: Box blur using integral image ─────────────────────────────────

  static Uint8List _boxBlurGray(Uint8List gray, int W, int H, int radius) {
    final integral = Float64List((W + 1) * (H + 1));
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        integral[(y+1)*(W+1)+(x+1)] = gray[y*W+x].toDouble()
            + integral[y*(W+1)+(x+1)]
            + integral[(y+1)*(W+1)+x]
            - integral[y*(W+1)+x];
      }
    }
    final result = Uint8List(W * H);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final x1   = (x-radius).clamp(0,W-1), y1 = (y-radius).clamp(0,H-1);
        final x2   = (x+radius).clamp(0,W-1), y2 = (y+radius).clamp(0,H-1);
        final area = ((x2-x1+1)*(y2-y1+1)).toDouble();
        final sum  = integral[(y2+1)*(W+1)+(x2+1)]
                   - integral[y1*(W+1)+(x2+1)]
                   - integral[(y2+1)*(W+1)+x1]
                   + integral[y1*(W+1)+x1];
        result[y*W+x] = (sum/area).round().clamp(0, 255);
      }
    }
    return result;
  }
}
