import 'package:flutter/material.dart';

import '../core/app_theme.dart';

Widget _networkImage(String url, {BoxFit fit = BoxFit.cover}) => Image.network(
  url,
  fit: fit,
  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
  loadingBuilder: (_, child, progress) => progress == null
      ? child
      : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  errorBuilder: (_, _, _) => const Center(
    child: Icon(Icons.broken_image_outlined, color: Colors.black38),
  ),
);

/// Swipeable photos with thumbnails; tap a photo to open the zoomable full-screen viewer.
class PhotoGallery extends StatefulWidget {
  final List<String> photos;
  const PhotoGallery({super.key, required this.photos});

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openViewer(int index) async {
    final result = await showDialog<int>(
      context: context,
      useSafeArea: false,
      builder: (_) =>
          PhotoViewerDialog(photos: widget.photos, initialIndex: index),
    );
    if (result != null && result != _page && _controller.hasClients) {
      _controller.jumpToPage(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _openViewer(i),
                    child: ColoredBox(
                      color: Colors.grey.shade300,
                      child: _networkImage(photos[i]),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.zoom_out_map,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < photos.length; i++)
                GestureDetector(
                  onTap: () => _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        width: 2,
                        color: i == _page
                            ? AppColors.maroon
                            : Colors.transparent,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColoredBox(
                        color: Colors.grey.shade300,
                        child: _networkImage(photos[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Full-screen swipeable viewer with pinch / double-tap zoom. Pops with the last viewed index.
class PhotoViewerDialog extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const PhotoViewerDialog({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<PhotoViewerDialog> {
  late final PageController _controller;
  late int _page = widget.initialIndex;
  final _zoomControllers = <int, TransformationController>{};
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _zoomFor(int i) =>
      _zoomControllers.putIfAbsent(i, TransformationController.new);

  void _toggleZoom(int i, Offset focal) {
    final c = _zoomFor(i);
    final zoomedIn = c.value.getMaxScaleOnAxis() > 1.01;
    const scale = 2.5;
    // Keeps the tapped point fixed on screen while scaling.
    c.value = zoomedIn
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..setEntry(0, 0, scale)
            ..setEntry(1, 1, scale)
            ..setEntry(0, 3, -focal.dx * (scale - 1))
            ..setEntry(1, 3, -focal.dy * (scale - 1)));
    setState(() => _zoomed = !zoomedIn);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: photos.length,
            // Let the image pan freely while zoomed in instead of changing page.
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            onPageChanged: (i) => setState(() {
              _page = i;
              _zoomed = false;
            }),
            itemBuilder: (_, i) {
              Offset tapAt = Offset.zero;
              return GestureDetector(
                onDoubleTapDown: (d) => tapAt = d.localPosition,
                onDoubleTap: () => _toggleZoom(i, tapAt),
                child: InteractiveViewer(
                  transformationController: _zoomFor(i),
                  minScale: 1,
                  maxScale: 5,
                  onInteractionEnd: (_) => setState(
                    () => _zoomed =
                        _zoomFor(i).value.getMaxScaleOnAxis() > 1.01,
                  ),
                  child: SizedBox.expand(
                    child: _networkImage(photos[i], fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(_page),
                  ),
                  const Spacer(),
                  if (photos.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${_page + 1} / ${photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
