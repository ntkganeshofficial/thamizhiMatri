import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../services/translation_controller.dart';
import '../models/profile.dart';

/// Compact portrait tile used in the horizontal carousels on the Home tab.
class MiniProfileCard extends StatelessWidget {
  final Profile profile;
  final String subtitle;
  final VoidCallback onTap;
  const MiniProfileCard({
    super.key,
    required this.profile,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ta = context.isTamil;
    return GestureDetector(
      onTap: onTap,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                color: Colors.grey.shade300,
                child: profile.hasPhoto
                    ? Image.network(
                        profile.photoUrl,
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person,
                          size: 64,
                          color: AppColors.maroon.withValues(alpha: 0.35),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 64,
                        color: AppColors.maroon.withValues(alpha: 0.35),
                      ),
              ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tx(profile.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fx.body(
                ta,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fx.body(ta, fontSize: 12, color: Colors.black54),
            ),
          ],
      ),
    );
  }
}

/// Section with a title, count badge, a two-column grid of tiles and a "View all" button.
class ProfileCarousel extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final List<Profile> profiles;
  final String Function(Profile) subtitleFor;
  final void Function(Profile) onOpen;
  final VoidCallback? onViewAll;

  const ProfileCarousel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.profiles,
    required this.subtitleFor,
    required this.onOpen,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final ta = context.isTamil;
    final shown = profiles.take(2).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Fx.serif(
                    ta,
                    fontSize: ta ? 20 : 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.maroon,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.maroon,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Text(
                  '$count',
                  style: Fx.latin(
                    TamilFonts.latinBody,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Fx.body(ta, fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: i < shown.length
                      ? MiniProfileCard(
                          profile: shown[i],
                          subtitle: subtitleFor(shown[i]),
                          onTap: () => onOpen(shown[i]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
          if (onViewAll != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onViewAll,
              child: Text(
                '${context.tr('View all')}  \u2192',
                style: Fx.body(ta, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
