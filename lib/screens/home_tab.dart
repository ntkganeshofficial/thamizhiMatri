import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../services/translation_controller.dart';
import '../core/nav.dart';
import '../models/profile.dart';
import '../services/activity_controller.dart';
import '../widgets/match_card.dart';
import '../widgets/mini_profile_card.dart';
import '../widgets/profile_card.dart';
import 'matches_tab.dart';
import 'paywall_screen.dart';
import 'profile_detail_screen.dart';
import 'profile_form_screen.dart';

/// Dashboard: profile completeness plus carousels of recent activity.
class HomeTab extends StatelessWidget {
  final void Function(MatchCategory) onOpenMatches;
  final VoidCallback onOpenInterests;
  final VoidCallback onOpenAccount;

  const HomeTab({
    super.key,
    required this.onOpenMatches,
    required this.onOpenInterests,
    required this.onOpenAccount,
  });

  void _editProfile(BuildContext context, Profile me) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProfileFormScreen(
        uid: me.uid,
        initial: me,
        managedBy: me.managedBy,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = context.watch<ActivityController>();
    final me = a.me;
    final ta = context.isTamil;
    String yearsAndHeight(Profile p) =>
        '${p.age} ${context.tr('yrs')}, ${p.heightCm} ${context.tr('cm')}';
    String viewedOn(Map<String, DateTime?> m, Profile p) => m[p.uid] == null
        ? yearsAndHeight(p)
        : context.tr('Viewed on: {date}', {'date': context.fmtDate(m[p.uid]!)});
    String shortlistedOn(Map<String, DateTime?> m, Profile p) =>
        m[p.uid] == null
        ? yearsAndHeight(p)
        : context.tr('Shortlisted on: {date}', {
            'date': context.fmtDate(m[p.uid]!),
          });

    final matches = a.matches;
    final viewedMe = a.profilesByDate(a.viewedMe);
    final shortlistedMe = a.profilesByDate(a.shortlistedMe);
    final shortlistedBy = a.profilesByDate(a.shortlistedBy);
    final viewedBy = a.profilesByDate(a.viewedBy);
    final photoReqs = a.profilesByDate(a.photoRequestsSent);

    Widget carousel(
      String titleKey,
      String subtitleKey,
      List<Profile> list,
      String Function(Profile) sub,
      MatchCategory category,
    ) {
      if (list.isEmpty) return const SizedBox.shrink();
      return ProfileCarousel(
        title: context.tr(titleKey),
        count: list.length,
        subtitle: context.tr(subtitleKey),
        profiles: list.take(10).toList(),
        subtitleFor: sub,
        onOpen: (p) => openProfile(context, p),
        onViewAll: () => onOpenMatches(category),
      );
    }

    return RefreshIndicator(
      onRefresh: a.loadPool,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '\u0ba4\u0bae\u0bbf\u0bb4\u0bbf',
                      style: TextStyle(
                        fontFamily: TamilFonts.display,
                        fontSize: 34,
                        color: AppColors.maroon,
                      ),
                    ),
                    Text(
                      'THAMIZHI \u00b7 INAI THEDAL',
                      style: Fx.latin(
                        TamilFonts.latinBody,
                        fontSize: 13,
                        letterSpacing: 0.4,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Interests'),
                onPressed: onOpenInterests,
                icon: Badge(
                  isLabelVisible: a.pendingReceived > 0,
                  label: Text('${a.pendingReceived}'),
                  child: const Icon(Icons.notifications_none, size: 28),
                ),
              ),
              IconButton(
                onPressed: onOpenAccount,
                icon: const Icon(Icons.menu, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                InkWell(
                  onTap: onOpenAccount,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        ProfileAvatar(profile: me, radius: 32),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tx(me.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Fx.serif(
                                  ta,
                                  fontSize: ta ? 20 : 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.maroon,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    me.code,
                                    style: Fx.body(
                                      ta,
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  if (me.verified) ...[
                                    const SizedBox(width: 8),
                                    const VerifiedBadge(),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: a.managed
                      ? null
                      : () => pushScreen(context, const PaywallScreen()),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    color: AppColors.gold.withValues(alpha: 0.18),
                    child: a.managed
                        ? Row(
                            children: [
                              const Icon(
                                Icons.supervisor_account_outlined,
                                size: 20,
                                color: AppColors.maroon,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr('Managed profile - full access'),
                                  style: Fx.body(
                                    ta,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.maroon,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : a.isPremium
                        ? Row(
                            children: [
                              const Icon(
                                Icons.workspace_premium_outlined,
                                size: 20,
                                color: AppColors.maroon,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr('Premium until {date}', {
                                    'date': context.fmtDate(
                                      a.entitlement.premiumUntil!,
                                    ),
                                  }),
                                  style: Fx.body(
                                    ta,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.maroon,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(
                                Icons.visibility_outlined,
                                size: 20,
                                color: AppColors.maroon,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr('Free profile views:'),
                                  style: Fx.body(
                                    ta,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                '${a.freeViewsLeft}',
                                style: Fx.latin(
                                  TamilFonts.latinHeading,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.maroon,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('left'),
                                style: Fx.body(
                                  ta,
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (me.completeness < 100)
            _CompletenessCard(me: me, onEdit: () => _editProfile(context, me)),
          if (a.photoRequestsReceived.isNotEmpty && !me.hasPhoto)
            Card(
              color: AppColors.gold.withValues(alpha: 0.15),
              margin: const EdgeInsets.only(bottom: 20),
              child: ListTile(
                leading: const Icon(
                  Icons.add_a_photo_outlined,
                  color: AppColors.maroon,
                ),
                title: Text(
                  context.tr('{n} members asked you to add a photo', {
                    'n': '${a.photoRequestsReceived.length}',
                  }),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editProfile(context, me),
              ),
            ),
          if (a.poolLoading && a.pool.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          carousel(
            'All Matches',
            'Members who match your partner preferences',
            matches,
            yearsAndHeight,
            MatchCategory.all,
          ),
          carousel(
            'Who Viewed You',
            'Members who viewed your profile',
            viewedMe,
            (p) => viewedOn(a.viewedMe, p),
            MatchCategory.viewedMe,
          ),
          carousel(
            'Who Shortlisted You',
            'Members who shortlisted your profile',
            shortlistedMe,
            (p) => shortlistedOn(a.shortlistedMe, p),
            MatchCategory.shortlistedMe,
          ),
          carousel(
            'Photo requests sent',
            'Members you asked to add a photo',
            photoReqs,
            (p) => p.hasPhoto ? yearsAndHeight(p) : context.tr('Photo pending'),
            MatchCategory.photoRequestsSent,
          ),
          carousel(
            'Profiles You Shortlisted',
            'Members that you have shortlisted',
            shortlistedBy,
            (p) => shortlistedOn(a.shortlistedBy, p),
            MatchCategory.shortlistedBy,
          ),
          carousel(
            'Profiles You Viewed',
            'Members that you have viewed',
            viewedBy,
            (p) => viewedOn(a.viewedBy, p),
            MatchCategory.viewedBy,
          ),
          Center(child: Container(width: 36, height: 1, color: AppColors.gold)),
          const SizedBox(height: 12),
          Text(
            context.tr('Beyond caste and religion. Connected through Tamil.'),
            textAlign: TextAlign.center,
            style: Fx.body(ta, fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _CompletenessCard extends StatelessWidget {
  final Profile me;
  final VoidCallback onEdit;
  const _CompletenessCard({required this.me, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final ta = context.isTamil;
    final items = {
      'photo': (Icons.add_a_photo_outlined, 'Add photo'),
      'hobbies': (Icons.favorite_border, 'Add hobbies'),
      'prefs': (Icons.tune, 'Set partner preferences'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Complete Your Profile'),
            style: Fx.serif(
              ta,
              fontSize: ta ? 20 : 24,
              fontWeight: FontWeight.w700,
              color: AppColors.maroon,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                context.tr('Profile completeness score'),
                style: Fx.body(ta, fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(width: 8),
              Text(
                '${me.completeness}%',
                style: Fx.body(ta, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: me.completeness / 100,
              minHeight: 8,
              color: AppColors.maroon,
              backgroundColor: AppColors.maroon.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final key in me.missingItems)
                ActionChip(
                  avatar: Icon(
                    items[key]!.$1,
                    size: 18,
                    color: AppColors.maroon,
                  ),
                  label: Text(context.tr(items[key]!.$2)),
                  onPressed: onEdit,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
