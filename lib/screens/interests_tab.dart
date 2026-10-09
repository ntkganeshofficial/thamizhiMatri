import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../services/translation_controller.dart';
import '../core/nav.dart';
import '../models/profile.dart';
import '../services/activity_controller.dart';
import '../services/profile_service.dart';
import '../widgets/profile_card.dart';
import 'chat_screen.dart';
import 'profile_detail_screen.dart';
import '../core/contact.dart';

class InterestsTab extends StatefulWidget {
  const InterestsTab({super.key});

  @override
  State<InterestsTab> createState() => _InterestsTabState();
}

class _InterestsTabState extends State<InterestsTab> {
  bool _received = true;
  String _filter = 'all'; // all | pending | accepted | declined
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  static const _filters = ['all', 'pending', 'accepted', 'declined'];
  static const _filterLabels = {
    'all': 'All',
    'pending': 'Pending',
    'accepted': 'Accepted / Replied',
    'declined': 'Declined',
  };

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityController>();
    final ta = context.isTamil;
    final all = (_received ? activity.received : activity.sent).toList()
      ..sort(
        (a, b) =>
            (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()),
      );
    int count(String f) =>
        f == 'all' ? all.length : all.where((i) => i.status == f).length;

    final q = _query.text.trim().toLowerCase();
    final shown = all.where((i) {
      if (_filter != 'all' && i.status != _filter) return false;
      if (q.isEmpty) return true;
      final p = activity.profile(_received ? i.fromUid : i.toUid);
      return p != null &&
          (p.name.toLowerCase().contains(q) ||
              p.code.toLowerCase().contains(q));
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          context.tr('Interests'),
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
            _TopTab(
              label: context.tr('Interests Received'),
              selected: _received,
              onTap: () => setState(() => _received = true),
            ),
            const SizedBox(width: 24),
            _TopTab(
              label: context.tr('Interests Sent'),
              selected: !_received,
              onTap: () => setState(() => _received = false),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${context.tr(_filterLabels[f]!)}${f == 'all' || count(f) > 0 ? ' (${count(f)})' : ''}',
                    ),
                    selected: _filter == f,
                    selectedColor: AppColors.maroon.withValues(alpha: 0.15),
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _searching
                  ? TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: context.tr('Search by name or ID'),
                        isDense: true,
                      ),
                    )
                  : Text(
                      _headline(context, count(_filter)),
                      style: Fx.body(
                        ta,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            IconButton(
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query.clear();
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: AppColors.gold.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    _filter == 'all'
                        ? 'You have no interests yet'
                        : 'You have no {kind} interests',
                    {'kind': context.tr(_filter)},
                  ),
                ),
              ],
            ),
          ),
        for (final i in shown) _InterestCard(interest: i, received: _received),
      ],
    );
  }

  String _headline(BuildContext context, int n) {
    const words = {
      'all': 'All',
      'pending': 'Pending',
      'accepted': 'Accepted',
      'declined': 'Declined',
    };
    return '${context.tr('${words[_filter]} interests ${_received ? 'received' : 'sent'}')} ($n)';
  }
}

class _TopTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TopTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.maroon : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppColors.maroon : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _InterestCard extends StatelessWidget {
  final Interest interest;
  final bool received;
  const _InterestCard({required this.interest, required this.received});

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityController>();
    final service = context.read<ProfileService>();
    final p = activity.profile(received ? interest.fromUid : interest.toUid);
    if (p == null) return const SizedBox.shrink();
    final ta = context.isTamil;
    final female = p.gender == 'Female';
    final args = {
      'pn': female ? 'her' : 'his',
      'pro': female ? 'She' : 'He',
      'obj': female ? 'her' : 'him',
    };
    final date = interest.date == null
        ? ''
        : ' - ${context.fmtDate(interest.date!)}';
    final String status;
    if (received) {
      status = switch (interest.status) {
        'accepted' => context.tr('You accepted {pn} interest', args),
        'declined' => context.tr('You declined {pn} interest', args),
        _ => context.tr('{pro} sent you an interest', args),
      };
    } else {
      status = switch (interest.status) {
        'accepted' => context.tr('{pro} accepted your interest', args),
        'declined' => context.tr('{pro} declined your interest', args),
        _ => context.tr('You sent {obj} an interest', args),
      };
    }
    final facts = [
      '${p.age} ${context.tr('yrs')}',
      "${p.heightCm} ${context.tr('cm')}",
      context.tr(p.education),
      context.tx(p.occupation),
      context.tr(p.nativeDistrict),
    ].where((s) => s.isNotEmpty).join(' \u00b7 ');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => openProfile(context, p),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(profile: p, radius: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tx(p.name),
                          style: Fx.body(
                            ta,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          facts,
                          style: Fx.body(
                            ta,
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'view') openProfile(context, p);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Text(context.tr('View profile')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$status$date',
              style: Fx.body(ta, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            if (interest.status == 'accepted')
              Column(
                children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.maroon,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: () =>
                          contactMember(context, p.uid, whatsapp: false),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: Text(context.tr('Call Now')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: () =>
                          pushScreen(context, ChatScreen(other: p)),
                      icon: const Icon(Icons.mail_outline, size: 18),
                      label: Text(context.tr('Send Message')),
                    ),
                  ),
                ],
              ),
              if (!received)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.maroon),
                  onPressed: () =>
                      confirmWithdrawInterest(context, service, interest),
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text(context.tr('Withdraw interest')),
                ),
                ],
              )
            else if (received && interest.status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: () =>
                          service.respondToInterest(interest.id, false),
                      child: Text(context.tr('Decline')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: () =>
                          service.respondToInterest(interest.id, true),
                      child: Text(context.tr('Accept')),
                    ),
                  ),
                ],
              )
            else if (!received && interest.status == 'pending')
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.maroon,
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () =>
                    confirmWithdrawInterest(context, service, interest),
                icon: const Icon(Icons.undo, size: 18),
                label: Text(context.tr('Withdraw interest')),
              ),
          ],
        ),
      ),
    );
  }
}
