import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/contact.dart';
import '../core/l10n.dart';
import '../services/translation_controller.dart';
import '../models/profile.dart';
import '../services/activity_controller.dart';
import '../services/profile_service.dart';
import 'profile_card.dart';

/// Large match card: photo, badges, key facts and quick actions.
class MatchCard extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;
  const MatchCard({super.key, required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final border = AppColors.gold.withValues(alpha: 0.6);
    final ta = context.isTamil;
    final activity = context.watch<ActivityController>();
    final connected = activity.isConnected(profile.uid);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(profile: profile),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tx(profile.name),
                        style: Fx.serif(
                          ta,
                          fontSize: ta ? 24 : 34,
                          fontWeight: FontWeight.w700,
                          color: AppColors.maroon,
                        ),
                      ),
                    ),
                    if (profile.verified) const VerifiedBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${profile.code} | ${context.tr('Last seen {when}', {'when': context.fmtAgo(profile.lastSeen)})}',
                  style: Fx.body(ta, fontSize: 12, color: Colors.black45),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${context.tx(profile.city)}, ${context.tr(profile.country)}',
                        style: Fx.body(ta, fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: border, height: 1),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Field(
                        'Age & height',
                        '${profile.age} ${context.tr('yrs')} \u00b7 ${profile.heightCm} ${context.tr('cm')}',
                      ),
                    ),
                    Expanded(
                      child: _Field(
                        'Marital status',
                        context.tr(profile.maritalStatus),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Field('Education', context.tr(profile.education)),
                    ),
                    Expanded(
                      child: _Field(
                        'Occupation',
                        context.tx(profile.occupation),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: AppColors.maroon,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    context.tr('View profile'),
                                    style: Fx.body(
                                      ta,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (connected) ...[
                      const SizedBox(width: 8),
                      ContactIconButton(
                        icon: Icons.call_outlined,
                        onTap: () => contactMember(
                          context,
                          profile.uid,
                          whatsapp: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ContactIconButton(
                        icon: Icons.chat_outlined,
                        color: const Color(0xFF25A244),
                        onTap: () =>
                            contactMember(context, profile.uid, whatsapp: true),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified, size: 18, color: Color(0xFF1E88E5)),
        const SizedBox(width: 4),
        Text(
          context.tr('Verified'),
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E88E5)),
        ),
      ],
    );
  }
}

class ContactIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const ContactIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.maroon,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        minimumSize: const Size(48, 52),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      child: Icon(icon),
    );
  }
}

class _Header extends StatelessWidget {
  final Profile profile;
  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    final line = AppColors.gold.withValues(alpha: 0.7);
    final activity = context.watch<ActivityController>();
    final shortlisted = activity.isShortlisted(profile.uid);
    final requested = activity.photoRequested(profile.uid);
    final service = context.read<ProfileService>();
    final me = activity.me;
    return Container(
      height: profile.hasPhoto ? 200 : 232,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.maroon.withValues(alpha: 0.12), AppColors.cream],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 34,
            left: 22,
            child: Container(width: 34, height: 1, color: line),
          ),
          Positioned(
            bottom: 34,
            right: 22,
            child: Container(width: 34, height: 1, color: line),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold),
                ),
                child: ProfileAvatar(profile: profile, radius: 66),
              ),
              if (!profile.hasPhoto) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.maroon,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: AppColors.maroon.withValues(alpha: 0.4),
                    ),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: requested
                      ? null
                      : () => service.requestPhoto(me.uid, profile.uid),
                  child: Text(
                    context.tr(
                      requested
                          ? 'Photo requested'
                          : (profile.gender == 'Female'
                                ? 'Request her to add photo'
                                : 'Request him to add photo'),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
          if (profile.isNew)
            Positioned(
              top: 14,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.maroon,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Text(
                  context.tr('NEWLY JOINED'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: AppColors.maroon,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () =>
                    service.toggleShortlist(me.uid, profile.uid, !shortlisted),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        shortlisted ? Icons.bookmark : Icons.bookmark_border,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr(shortlisted ? 'Shortlisted' : 'Shortlist'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final ta = context.isTamil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(label).toUpperCase(),
          style: Fx.body(
            ta,
            fontSize: 11,
            letterSpacing: 0.6,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Fx.body(
            ta,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
