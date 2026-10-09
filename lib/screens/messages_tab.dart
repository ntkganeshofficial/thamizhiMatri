import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../services/translation_controller.dart';
import '../core/nav.dart';
import '../services/activity_controller.dart';
import '../widgets/profile_card.dart';
import 'chat_screen.dart';

/// Conversations with members whose interest was accepted.
class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityController>();
    final ta = context.isTamil;
    final byUid = {for (final c in activity.chats) c.otherUid: c};
    final uids = {...activity.connections, ...byUid.keys}.toList()
      ..sort(
        (a, b) => (byUid[b]?.lastAt ?? DateTime(2000)).compareTo(
          byUid[a]?.lastAt ?? DateTime(2000),
        ),
      );
    final profiles = [for (final u in uids) ?activity.profile(u)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          context.tr('Messages'),
          style: Fx.serif(
            ta,
            fontSize: ta ? 30 : 52,
            fontWeight: FontWeight.w600,
            color: AppColors.maroon,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(width: 32, height: 1, color: AppColors.gold),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                context.tr('Chat with members who accepted your interest'),
                style: Fx.body(ta, fontSize: 15, color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (profiles.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                context.tr(
                  'No conversations yet. Accepted interests appear here.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        for (final p in profiles)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ProfileAvatar(profile: p, radius: 28),
              title: Text(
                context.tx(p.name),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                (byUid[p.uid]?.lastMessage.isNotEmpty ?? false)
                    ? byUid[p.uid]!.lastMessage
                    : context.tr('Say hello'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: byUid[p.uid]?.lastAt == null
                  ? null
                  : Text(
                      context.fmtAgo(byUid[p.uid]!.lastAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
              onTap: () => pushScreen(context, ChatScreen(other: p)),
            ),
          ),
      ],
    );
  }
}
