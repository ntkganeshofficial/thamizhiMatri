import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../models/profile.dart';
import '../services/activity_controller.dart';
import '../services/profile_service.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/match_card.dart';
import 'profile_detail_screen.dart';

enum MatchCategory {
  all,
  newlyJoined,
  shortlistedBy,
  viewedMe,
  shortlistedMe,
  viewedBy,
  photoRequestsSent,
  nearby,
  photos,
  mutual,
  lookingForYou,
  educationPref,
  professionalPref,
  locationPref,
  nri,
}

extension MatchCategoryInfo on MatchCategory {
  String get title => switch (this) {
    MatchCategory.all => 'All matches',
    MatchCategory.newlyJoined => 'Newly joined',
    MatchCategory.shortlistedBy => 'Shortlisted by you',
    MatchCategory.viewedMe => 'Viewed you',
    MatchCategory.shortlistedMe => 'Shortlisted you',
    MatchCategory.viewedBy => 'Viewed by you',
    MatchCategory.photoRequestsSent => 'Photo requests sent',
    MatchCategory.nearby => 'Nearby matches',
    MatchCategory.photos => 'Photo matches',
    MatchCategory.mutual => 'Mutual matches',
    MatchCategory.lookingForYou => 'Looking for you',
    MatchCategory.educationPref => 'Education preference',
    MatchCategory.professionalPref => 'Professional preference',
    MatchCategory.locationPref => 'Location preference',
    MatchCategory.nri => 'NRI matches',
  };

  String get subtitle => switch (this) {
    MatchCategory.all => 'Members who match your partner preferences',
    MatchCategory.newlyJoined => 'Matches who joined within the last 30 days',
    MatchCategory.shortlistedBy => 'Matches you have shortlisted',
    MatchCategory.viewedMe => 'Matches who have viewed your profile',
    MatchCategory.shortlistedMe => 'Matches who have shortlisted your profile',
    MatchCategory.viewedBy => 'Matches you have viewed',
    MatchCategory.photoRequestsSent => 'Members you asked to add a photo',
    MatchCategory.nearby => 'Matches near your location',
    MatchCategory.photos => 'Matches that have added photos',
    MatchCategory.mutual =>
      'Matches whose profile match your preferences and vice versa',
    MatchCategory.lookingForYou =>
      'Matches whose preferences match your profile',
    MatchCategory.educationPref => 'Matches based on your preferred education',
    MatchCategory.professionalPref => 'Matches based on your preferred occupation',
    MatchCategory.locationPref => 'Matches from your preferred district',
    MatchCategory.nri => 'Matches from outside India',
  };

  IconData get icon => switch (this) {
    MatchCategory.all => Icons.people_outline,
    MatchCategory.newlyJoined => Icons.person_add_alt,
    MatchCategory.shortlistedBy => Icons.star,
    MatchCategory.viewedMe => Icons.visibility_outlined,
    MatchCategory.shortlistedMe => Icons.star_border,
    MatchCategory.viewedBy => Icons.manage_search,
    MatchCategory.photoRequestsSent => Icons.add_a_photo_outlined,
    MatchCategory.nearby => Icons.near_me_outlined,
    MatchCategory.photos => Icons.photo_library_outlined,
    MatchCategory.mutual => Icons.handshake_outlined,
    MatchCategory.lookingForYou => Icons.person_search_outlined,
    MatchCategory.educationPref => Icons.school_outlined,
    MatchCategory.professionalPref => Icons.work_outline,
    MatchCategory.locationPref => Icons.place_outlined,
    MatchCategory.nri => Icons.public,
  };
}

const _moreGroups = <(String, List<MatchCategory>)>[
  (
    'Based on activity',
    [
      MatchCategory.shortlistedBy,
      MatchCategory.viewedMe,
      MatchCategory.shortlistedMe,
      MatchCategory.viewedBy,
      MatchCategory.photoRequestsSent,
    ],
  ),
  (
    'Recently joined & nearby matches',
    [MatchCategory.newlyJoined, MatchCategory.nearby],
  ),
  ('Based on profile details', [MatchCategory.photos]),
  (
    'Members who are looking for someone like you',
    [MatchCategory.mutual, MatchCategory.lookingForYou],
  ),
  (
    'Matches based on preferences',
    [
      MatchCategory.educationPref,
      MatchCategory.professionalPref,
      MatchCategory.locationPref,
      MatchCategory.nri,
    ],
  ),
];

enum _Sort { relevance, newest, ageAsc, ageDesc }

const _sortLabels = {
  _Sort.relevance: 'Relevance',
  _Sort.newest: 'Newest first',
  _Sort.ageAsc: 'Age: low to high',
  _Sort.ageDesc: 'Age: high to low',
};

class MatchesTab extends StatefulWidget {
  final ValueNotifier<MatchCategory> category;
  const MatchesTab({super.key, required this.category});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  SearchFilters _filters = SearchFilters();
  _Sort _sort = _Sort.relevance;
  bool _notSeen = false;
  bool _photoOnly = false;

  List<Profile> _base(ActivityController a, MatchCategory c) {
    final me = a.me;
    return switch (c) {
      MatchCategory.all => a.matches,
      MatchCategory.newlyJoined => a.pool.where((p) => p.isNew).toList(),
      MatchCategory.shortlistedBy => a.profilesByDate(a.shortlistedBy),
      MatchCategory.viewedMe => a.profilesByDate(a.viewedMe),
      MatchCategory.shortlistedMe => a.profilesByDate(a.shortlistedMe),
      MatchCategory.viewedBy => a.profilesByDate(a.viewedBy),
      MatchCategory.photoRequestsSent => a.profilesByDate(a.photoRequestsSent),
      MatchCategory.nearby =>
        a.pool
            .where(
              (p) =>
                  (me.city.isNotEmpty &&
                      p.city.toLowerCase() == me.city.toLowerCase()) ||
                  (me.nativeDistrict.isNotEmpty &&
                      p.nativeDistrict == me.nativeDistrict),
            )
            .toList(),
      MatchCategory.photos => a.pool.where((p) => p.hasPhoto).toList(),
      MatchCategory.mutual =>
        a.pool
            .where((p) => p.fitsPreferencesOf(me) && me.fitsPreferencesOf(p))
            .toList(),
      MatchCategory.lookingForYou =>
        a.pool.where((p) => me.fitsPreferencesOf(p)).toList(),
      MatchCategory.professionalPref =>
        me.prefOccupation == null
            ? []
            : a.pool
                  .where(
                    (p) => p.occupation.toLowerCase().contains(
                      me.prefOccupation!.toLowerCase(),
                    ),
                  )
                  .toList(),
      MatchCategory.educationPref =>
        me.prefEducation == null
            ? []
            : a.pool.where((p) => p.education == me.prefEducation).toList(),
      MatchCategory.locationPref =>
        me.prefDistrict == null
            ? []
            : a.pool.where((p) => p.nativeDistrict == me.prefDistrict).toList(),
      MatchCategory.nri =>
        a.pool
            .where((p) => p.country.isNotEmpty && p.country != 'India')
            .toList(),
    };
  }

  List<Profile> _visible(ActivityController a, MatchCategory c) {
    var list = _base(a, c).where(_filters.accepts).toList();
    if (_notSeen) {
      list = list.where((p) => !a.viewedBy.containsKey(p.uid)).toList();
    }
    if (_photoOnly) list = list.where((p) => p.hasPhoto).toList();
    switch (_sort) {
      case _Sort.relevance:
        break;
      case _Sort.newest:
        list.sort(
          (x, y) => (y.createdAt ?? DateTime(2000)).compareTo(
            x.createdAt ?? DateTime(2000),
          ),
        );
      case _Sort.ageAsc:
        list.sort((x, y) => x.age.compareTo(y.age));
      case _Sort.ageDesc:
        list.sort((x, y) => y.age.compareTo(x.age));
    }
    return list;
  }

  Future<void> _openFilters() async {
    final updated = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FilterSheet(initial: _filters),
    );
    if (updated != null) setState(() => _filters = updated);
  }

  Future<void> _openMore() async {
    final picked = await showModalBottomSheet<MatchCategory>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            for (final (group, items) in _moreGroups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(
                  context.tr(group),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.maroon),
                ),
              ),
              for (final c in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(c.icon, color: AppColors.maroon),
                  title: Text(context.tr(c.title)),
                  subtitle: Text(
                    context.tr(c.subtitle),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, c),
                ),
            ],
          ],
        ),
      ),
    );
    if (picked != null) widget.category.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<ActivityController>();
    final ta = context.isTamil;
    return ValueListenableBuilder<MatchCategory>(
      valueListenable: widget.category,
      builder: (context, category, _) {
        final list = _visible(a, category);
        final isMore =
            category != MatchCategory.all &&
            category != MatchCategory.newlyJoined;
        return RefreshIndicator(
          onRefresh: a.loadPool,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.tr('Matches'),
                        style: Fx.serif(
                          ta,
                          fontSize: ta ? 30 : 52,
                          fontWeight: FontWeight.w600,
                          color: AppColors.maroon,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.maroon,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.8),
                      ),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _openFilters,
                    icon: Badge(
                      isLabelVisible: !_filters.isDefault,
                      smallSize: 8,
                      child: const Icon(Icons.tune, size: 20),
                    ),
                    label: Text(
                      context.tr('Filters'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(width: 32, height: 1, color: AppColors.gold),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${context.tr('{n} matches', {'n': '${list.length}'})} \u00b7 ${context.tr(category.title)}',
                      style: Fx.body(ta, fontSize: 15, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip(
                      context,
                      context.tr('All matches'),
                      category == MatchCategory.all,
                      () => widget.category.value = MatchCategory.all,
                    ),
                    _chip(
                      context,
                      context.tr('Newly joined'),
                      category == MatchCategory.newlyJoined,
                      () => widget.category.value = MatchCategory.newlyJoined,
                    ),
                    _chip(
                      context,
                      '${isMore ? context.tr(category.title) : context.tr('More')} \u25be',
                      isMore,
                      _openMore,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    PopupMenuButton<_Sort>(
                      onSelected: (s) => setState(() => _sort = s),
                      itemBuilder: (_) => [
                        for (final s in _Sort.values)
                          PopupMenuItem(
                            value: s,
                            child: Text(context.tr(_sortLabels[s]!)),
                          ),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.sort, size: 18),
                        label: Text(
                          '${context.tr('Sort by')}: ${context.tr(_sortLabels[_sort]!)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(context.tr('Not seen')),
                      selected: _notSeen,
                      onSelected: (v) => setState(() => _notSeen = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(context.tr('With photo')),
                      selected: _photoOnly,
                      onSelected: (v) => setState(() => _photoOnly = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (a.poolLoading && a.pool.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (a.poolError != null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text('${context.tr('Error')}: ${a.poolError}'),
                  ),
                )
              else if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      context.tr(
                        category == MatchCategory.educationPref ||
                                category == MatchCategory.professionalPref ||
                                category == MatchCategory.locationPref
                            ? 'Set this partner preference in Edit profile to see matches'
                            : 'No matches found. Try changing filters.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                for (final p in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: MatchCard(
                      profile: p,
                      onTap: () => openProfile(context, p),
                    ),
                  ),
              const SizedBox(height: 12),
              Center(
                child: Container(width: 36, height: 1, color: AppColors.gold),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'Beyond caste and religion. Connected through Tamil.',
                ),
                textAlign: TextAlign.center,
                style: Fx.body(ta, fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.maroon.withValues(alpha: 0.15),
      onSelected: (_) => onTap(),
    ),
  );
}
