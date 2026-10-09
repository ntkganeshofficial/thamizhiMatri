import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/contact.dart';
import '../core/l10n.dart';
import '../services/translation_controller.dart';
import '../core/nav.dart';
import '../models/profile.dart';
import '../services/activity_controller.dart';
import '../services/profile_service.dart';
import '../widgets/match_card.dart';
import '../widgets/photo_gallery.dart';
import '../widgets/profile_card.dart';
import 'chat_screen.dart';
import 'paywall_screen.dart';

/// Opens a profile, spending one of the free views, or the paywall once they are used up.
void openProfile(BuildContext context, Profile profile) {
  switch (context.read<ActivityController>().requestProfileView(profile.uid)) {
    case ViewAccess.allowed:
      pushScreen(context, ProfileDetailScreen(other: profile));
    case ViewAccess.needsPayment:
      pushScreen(context, const PaywallScreen());
    case ViewAccess.loading:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.trRead('Checking your plan, please try again')),
        ),
      );
  }
}

/// Asks before taking back a pending interest; returns true if it was withdrawn.
Future<bool> confirmWithdrawInterest(
  BuildContext context,
  ProfileService service,
  Interest interest,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('Withdraw this interest?')),
      content: Text(
        ctx.tr(
          interest.status == 'accepted'
              ? 'You will lose chat and contact access with this member. You can send an interest again later.'
              : 'They will no longer see it. You can send it again later.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.tr('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.tr('Withdraw')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final doneMsg = context.trRead('Interest withdrawn');
  final failMsg = context.trRead('Something went wrong. Please try again.');
  final messenger = ScaffoldMessenger.of(context);
  try {
    await service.withdrawInterest(interest.id);
    messenger.showSnackBar(SnackBar(content: Text(doneMsg)));
    return true;
  } catch (e) {
    debugPrint('withdrawInterest failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(failMsg)));
    return false;
  }
}

class ProfileDetailScreen extends StatefulWidget {
  final Profile other;
  const ProfileDetailScreen({super.key, required this.other});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  @override
  void initState() {
    super.initState();
    final me = context.read<ActivityController>().me;
    if (me.uid != widget.other.uid) {
      context
          .read<ProfileService>()
          .recordView(me.uid, widget.other.uid)
          .catchError((Object e) {
            debugPrint('recordView failed: $e');
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.other;
    final activity = context.watch<ActivityController>();
    final service = context.read<ProfileService>();
    final me = activity.me;
    final text = Theme.of(context).textTheme;
    final shortlisted = activity.isShortlisted(other.uid);
    final requested = activity.photoRequested(other.uid);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tx(other.name)),
        actions: [
          IconButton(
            tooltip: context.tr(
              shortlisted ? 'Remove from shortlist' : 'Shortlist',
            ),
            icon: Icon(shortlisted ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () =>
                service.toggleShortlist(me.uid, other.uid, !shortlisted),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!activity.isPremium && !activity.managed)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.tr('{n} free profile views left', {
                  'n': '${activity.freeViewsLeft}',
                }),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (other.hasPhoto)
            PhotoGallery(photos: other.photos)
          else
            Center(child: ProfileAvatar(profile: other, radius: 64)),
          if (!other.hasPhoto)
            Center(
              child: TextButton(
                onPressed: requested
                    ? null
                    : () => service.requestPhoto(me.uid, other.uid),
                child: Text(
                  context.tr(
                    requested
                        ? 'Photo requested'
                        : (other.gender == 'Female'
                              ? 'Request her to add photo'
                              : 'Request him to add photo'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              context.tx(other.name),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              '${other.age} ${context.tr('yrs')} \u2022 ${other.heightCm} ${context.tr('cm')}',
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '${other.code} | ${context.tr('Last seen {when}', {'when': context.fmtAgo(other.lastSeen)})}',
              style: text.bodySmall?.copyWith(color: Colors.black45),
            ),
          ),
          if (other.verified)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Center(child: VerifiedBadge()),
            ),
          const SizedBox(height: 20),
          _row(context, 'Marital status', context.tr(other.maritalStatus)),
          _row(context, 'Education', context.tr(other.education)),
          _row(context, 'Occupation', context.tx(other.occupation)),
          _row(context, 'Native district', context.tr(other.nativeDistrict)),
          _row(
            context,
            'Lives in',
            '${context.tx(other.city)}, ${context.tr(other.country)}',
          ),
          _row(context, 'Diet', context.tr(other.diet)),
          if (other.hobbies.isNotEmpty)
            _row(context, 'Hobbies & interests', context.tx(other.hobbies)),
          _row(context, 'Profile created by', context.tr(other.profileFor)),
          const Divider(height: 32),
          Text(context.tr('About'), style: text.titleMedium),
          const SizedBox(height: 8),
          Text(context.tx(other.about)),
          if (other.hasPartnerPrefs) ...[
            const Divider(height: 32),
            Text(context.tr('Partner preferences'), style: text.titleMedium),
            const SizedBox(height: 8),
            _row(context, 'Age', '${other.prefMinAge} - ${other.prefMaxAge}'),
            if (other.prefEducation != null)
              _row(context, 'Education', context.tr(other.prefEducation!)),
            if (other.prefOccupation != null)
              _row(context, 'Occupation', context.tx(other.prefOccupation!)),
            if (other.prefDistrict != null)
              _row(context, 'Location', context.tr(other.prefDistrict!)),
          ],
          const SizedBox(height: 24),
          _InterestActions(other: other),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            context.tr(label),
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _InterestActions extends StatelessWidget {
  final Profile other;
  const _InterestActions({required this.other});

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityController>();
    final service = context.read<ProfileService>();
    final me = activity.me;
    final interest = activity.interestWith(other.uid);

    if (interest == null) {
      return FilledButton.icon(
        onPressed: () async {
          final sentMsg = context.trRead('Interest sent');
          await service.sendInterest(me.uid, other.uid);
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(sentMsg)));
          }
        },
        icon: const Icon(Icons.favorite),
        label: Text(context.tr('Send Interest')),
      );
    }

    if (interest.status == 'accepted') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => pushScreen(context, ChatScreen(other: other)),
            icon: const Icon(Icons.mail_outline),
            label: Text(context.tr('Send Message')),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.maroon,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () =>
                      contactMember(context, other.uid, whatsapp: false),
                  icon: const Icon(Icons.call_outlined),
                  label: Text(context.tr('Call Now')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25A244),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () =>
                      contactMember(context, other.uid, whatsapp: true),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
          if (interest.fromUid == me.uid)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.maroon),
              onPressed: () =>
                  confirmWithdrawInterest(context, service, interest),
              icon: const Icon(Icons.undo, size: 18),
              label: Text(context.tr('Withdraw interest')),
            ),
        ],
      );
    }

    final iSent = interest.fromUid == me.uid;
    if (!iSent && interest.status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => service.respondToInterest(interest.id, false),
              child: Text(context.tr('Decline')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => service.respondToInterest(interest.id, true),
              child: Text(context.tr('Accept')),
            ),
          ),
        ],
      );
    }

    if (iSent && interest.status == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonal(
            onPressed: null,
            child: Text(context.tr('Interest sent')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.maroon,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => confirmWithdrawInterest(context, service, interest),
            icon: const Icon(Icons.undo),
            label: Text(context.tr('Withdraw interest')),
          ),
        ],
      );
    }

    final label = iSent
        ? (interest.status == 'pending'
              ? 'Interest sent'
              : 'She declined your interest')
        : 'You declined this interest';
    return FilledButton.tonal(
      onPressed: null,
      child: Text(
        context.tr(
          iSent && interest.status == 'declined' && other.gender == 'Male'
              ? 'He declined your interest'
              : label,
        ),
      ),
    );
  }
}
