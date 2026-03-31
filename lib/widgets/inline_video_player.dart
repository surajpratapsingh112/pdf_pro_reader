import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../theme.dart';

class InlineVideoPlayer extends StatefulWidget {
  final String videoPath;
  final VoidCallback onClose;

  const InlineVideoPlayer({
    super.key,
    required this.videoPath,
    required this.onClose,
  });

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  VideoPlayerController? _videoCtrl;
  ChewieController?      _chewieCtrl;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _videoCtrl = VideoPlayerController.file(File(widget.videoPath));
      await _videoCtrl!.initialize();

      _chewieCtrl = ChewieController(
        videoPlayerController: _videoCtrl!,
        autoPlay:        true,
        looping:         false,
        allowFullScreen: true,
        allowMuting:     true,
        showControls:    true,
        materialProgressColors: ChewieProgressColors(
          playedColor:     AppColors.accent,
          handleColor:     AppColors.accent,
          backgroundColor: AppColors.card,
          bufferedColor:   AppColors.accent2,
        ),
      );
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: AppColors.cyan, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          // ── Header bar ──
          Container(
            color: AppColors.bar,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: AppColors.cyan, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Video Playing',
                    style: TextStyle(color: AppColors.cyan,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(Icons.close, color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),
          // ── Video ──
          Expanded(
            child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : _error != null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Error: $_error',
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                      textAlign: TextAlign.center)))
                : Chewie(controller: _chewieCtrl!),
          ),
        ],
      ),
    );
  }
}
