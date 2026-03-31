/// Represents an embedded video area on a PDF page
class VideoArea {
  final int    pageIndex;  // 0-based page number
  final double x0, y0;    // top-left  (in PDF points, y from top)
  final double x1, y1;    // bottom-right
  final String name;      // embedded file name (e.g. "video.mp4")

  const VideoArea({
    required this.pageIndex,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required this.name,
  });

  double get width  => x1 - x0;
  double get height => y1 - y0;

  /// Scale to screen pixels given page dimensions
  VideoArea scaleTo({
    required double pdfWidth,
    required double pdfHeight,
    required double screenWidth,
    required double screenHeight,
  }) {
    final sx = screenWidth  / pdfWidth;
    final sy = screenHeight / pdfHeight;
    return VideoArea(
      pageIndex: pageIndex,
      x0: x0 * sx,
      y0: y0 * sy,
      x1: x1 * sx,
      y1: y1 * sy,
      name: name,
    );
  }

  @override
  String toString() => 'VideoArea($name, page:$pageIndex, [$x0,$y0,$x1,$y1])';
}
