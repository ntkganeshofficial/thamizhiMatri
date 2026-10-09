import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../models/profile.dart';
import '../services/activity_controller.dart';
import '../services/profile_service.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/profile_card.dart';
import 'profile_detail_screen.dart';

/// Free-text search by name, member ID, city, occupation or district, plus advanced filters.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _query = TextEditingController();
  SearchFilters _filters = SearchFilters();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final updated = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FilterSheet(initial: _filters),
    );
    if (updated != null) setState(() => _filters = updated);
  }

  bool _matchesText(Profile p, String q) =>
      p.name.toLowerCase().contains(q) ||
      p.code.toLowerCase().contains(q) ||
      p.city.toLowerCase().contains(q) ||
      p.occupation.toLowerCase().contains(q) ||
      p.nativeDistrict.toLowerCase().contains(q);

  @override
  Widget build(BuildContext context) {
    final a = context.watch<ActivityController>();
    final ta = context.isTamil;
    final q = _query.text.trim().toLowerCase();
    final results = a.pool
        .where((p) => _filters.accepts(p) && (q.isEmpty || _matchesText(p, q)))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          context.tr('Search'),
          style: Fx.serif(
            ta,
            fontSize: ta ? 30 : 52,
            fontWeight: FontWeight.w600,
            color: AppColors.maroon,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.tr(
                    'Search by name, ID, city or occupation',
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_query.clear),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: _openFilters,
              icon: Badge(
                isLabelVisible: !_filters.isDefault,
                smallSize: 8,
                child: const Icon(Icons.tune),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('{n} members', {'n': '${results.length}'}),
          style: Fx.body(ta, fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        if (a.poolLoading && a.pool.isEmpty)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                context.tr('No matches found. Try changing filters.'),
              ),
            ),
          )
        else
          for (final p in results)
            ProfileCard(profile: p, onTap: () => openProfile(context, p)),
      ],
    );
  }
}
