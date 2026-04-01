/// Represents an embedded video area on a PDF page
class VideoArea {
  final int    pageIndex;   // 0-based page number
  final double x0, y0;     // top-left  (PDF points, y from top)
  final double x1, y1;     // bottom-right
  final String name;        // embedded file name (e.g. "video.mp4")
  final double pageWidth;   // PDF page width  in points (from MediaBox)
  final double pageHeight;  // PDF page height in points (from MediaBox)

  const VideoArea({
    required this.pageIndex,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required this.name,
    this.pageWidth  = 595.0,
    this.pageHeight = 842.0,
  });

  double get width  => x1 - x0;
  double get height => y1 - y0;

  @override
  String toString() =>
      'VideoArea($name, page:$pageIndex, [$x0,$y0,$x1,$y1], '
      'pageSize:${pageWidth}x$pageHeight)';
}
