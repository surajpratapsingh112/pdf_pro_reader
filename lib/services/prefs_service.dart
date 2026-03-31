// Preferences Service
// Stores: recent files, bookmarks, reading progress, settings

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentFile {
  final String path;
  final String name;
  final int    lastPage;
  final int    totalPages;
  final DateTime openedAt;

  RecentFile({
    required this.path,
    required this.name,
    required this.lastPage,
    required this.totalPages,
    required this.openedAt,
  });

  Map<String, dynamic> toJson() => {
    'path': path, 'name': name,
    'lastPage': lastPage, 'totalPages': totalPages,
    'openedAt': openedAt.toIso8601String(),
  };

  factory RecentFile.fromJson(Map<String, dynamic> j) => RecentFile(
    path:       j['path'],
    name:       j['name'],
    lastPage:   j['lastPage'] ?? 1,
    totalPages: j['totalPages'] ?? 1,
    openedAt:   DateTime.parse(j['openedAt']),
  );
}

class BookmarkItem {
  final String pdfPath;
  final int    page;
  final String label;
  final DateTime createdAt;

  BookmarkItem({
    required this.pdfPath,
    required this.page,
    required this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'pdfPath': pdfPath, 'page': page,
    'label': label, 'createdAt': createdAt.toIso8601String(),
  };
  factory BookmarkItem.fromJson(Map<String, dynamic> j) => BookmarkItem(
    pdfPath:   j['pdfPath'],
    page:      j['page'],
    label:     j['label'],
    createdAt: DateTime.parse(j['createdAt']),
  );
}

class PrefsService {
  static const _keyRecent    = 'recent_files';
  static const _keyBookmarks = 'bookmarks';
  static const _keyNightMode = 'night_mode';

  // ── Recent Files ────────────────────────────────────────────────────────

  static Future<List<RecentFile>> getRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_keyRecent) ?? [];
    return raw.map((s) => RecentFile.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> addRecentFile(RecentFile file) async {
    final prefs = await SharedPreferences.getInstance();
    var list    = await getRecentFiles();
    list.removeWhere((f) => f.path == file.path);
    list.insert(0, file);
    if (list.length > 20) list = list.sublist(0, 20);
    await prefs.setStringList(
        _keyRecent, list.map((f) => jsonEncode(f.toJson())).toList());
  }

  static Future<void> updateReadingProgress(
      String path, int page, int total) async {
    final list = await getRecentFiles();
    final idx  = list.indexWhere((f) => f.path == path);
    if (idx == -1) return;
    list[idx] = RecentFile(
      path: list[idx].path, name: list[idx].name,
      lastPage: page, totalPages: total,
      openedAt: list[idx].openedAt,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _keyRecent, list.map((f) => jsonEncode(f.toJson())).toList());
  }

  static Future<int?> getSavedPage(String path) async {
    final list = await getRecentFiles();
    final f    = list.where((f) => f.path == path).firstOrNull;
    return f?.lastPage;
  }

  // ── Bookmarks ────────────────────────────────────────────────────────────

  static Future<List<BookmarkItem>> getBookmarks(String pdfPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList('${_keyBookmarks}_$pdfPath') ?? [];
    return raw.map((s) => BookmarkItem.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> addBookmark(BookmarkItem bm) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = await getBookmarks(bm.pdfPath);
    list.removeWhere((b) => b.page == bm.page);
    list.add(bm);
    list.sort((a, b) => a.page.compareTo(b.page));
    await prefs.setStringList(
        '${_keyBookmarks}_${bm.pdfPath}',
        list.map((b) => jsonEncode(b.toJson())).toList());
  }

  static Future<void> removeBookmark(String pdfPath, int page) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = await getBookmarks(pdfPath);
    list.removeWhere((b) => b.page == page);
    await prefs.setStringList(
        '${_keyBookmarks}_$pdfPath',
        list.map((b) => jsonEncode(b.toJson())).toList());
  }

  static Future<bool> isBookmarked(String pdfPath, int page) async {
    final list = await getBookmarks(pdfPath);
    return list.any((b) => b.page == page);
  }

  // ── Night Mode ───────────────────────────────────────────────────────────

  static Future<bool> getNightMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNightMode) ?? false;
  }

  static Future<void> setNightMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNightMode, value);
  }
}
