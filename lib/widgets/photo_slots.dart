import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../models/profile.dart';

/// One photo in the profile form: an already-uploaded [url] or a freshly picked [bytes] preview.
class PhotoSlot {
  final String? url;
  final XFile? file;
  final Uint8List? bytes;
  const PhotoSlot.existing(String this.url) : file = null, bytes = null;
  const PhotoSlot.picked(XFile this.file, Uint8List this.bytes) : url = null;
}

/// Three square photo slots; the first one is the main profile photo.
class PhotoSlotsRow extends StatelessWidget {
  final List<PhotoSlot> slots;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const PhotoSlotsRow({
    super.key,
    required this.slots,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Photos (up to {n})', {'n': '${Profile.maxPhotos}'}),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('The first photo is your main profile photo'),
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < Profile.maxPhotos; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: i < slots.length
                      ? _Filled(
                          slot: slots[i],
                          isMain: i == 0,
                          onRemove: () => onRemove(i),
                        )
                      : _Empty(onTap: onAdd),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onTap;
  const _Empty({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
        ),
        child: const Icon(
          Icons.add_a_photo_outlined,
          color: AppColors.maroon,
          size: 30,
        ),
      ),
    );
  }
}

class _Filled extends StatelessWidget {
  final PhotoSlot slot;
  final bool isMain;
  final VoidCallback onRemove;
  const _Filled({
    required this.slot,
    required this.isMain,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final Widget image = slot.bytes != null
        ? Image.memory(slot.bytes!, fit: BoxFit.cover)
        : Image.network(
            slot.url!,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
        if (isMain)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.maroon,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.tr('Main'),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 13,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
