import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/profile_card.dart';
import 'home_screen.dart';
import 'profile_form_screen.dart';

/// Admin-only: create, edit, delete and act as profiles that belong to other people.
class ManagedProfilesScreen extends StatelessWidget {
  const ManagedProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfileService>();
    final adminUid = context.read<AuthService>().currentUser!.uid;
    final ta = context.isTamil;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Managed profiles'))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(context.tr('Add a profile')),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileFormScreen(
              uid: service.newProfileId(),
              managedBy: adminUid,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Profile>>(
        stream: service.watchManagedProfiles(adminUid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(context.tr('Something went wrong. Please try again.')));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = [...snap.data!]
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.tr('No managed profiles yet. Tap "Add a profile" to create one.'),
                  textAlign: TextAlign.center,
                  style: Fx.body(ta, fontSize: 15, color: Colors.black54),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: list.length,
            itemBuilder: (_, i) => _ManagedCard(profile: list[i], adminUid: adminUid),
          );
        },
      ),
    );
  }
}

class _ManagedCard extends StatelessWidget {
  final Profile profile;
  final String adminUid;
  const _ManagedCard({required this.profile, required this.adminUid});

  Future<void> _delete(BuildContext context) async {
    final service = context.read<ProfileService>();
    final messenger = ScaffoldMessenger.of(context);
    final failMsg = context.trRead('Something went wrong. Please try again.');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Delete this profile?')),
        content: Text(
          ctx.tr('The profile and its photos will be removed. This cannot be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('Cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await service.deleteManagedProfile(profile);
    } catch (e) {
      debugPrint('deleteManagedProfile failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(failMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = context.isTamil;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(profile: profile, radius: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: Fx.body(ta, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${profile.code} \u00b7 ${profile.age} ${context.tr('yrs')} \u00b7 ${context.tr(profile.gender)}',
                        style: Fx.body(ta, fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ActAs(profileId: profile.uid, adminUid: adminUid),
                      ),
                    ),
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(context.tr('Open')),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Edit profile'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileFormScreen(
                        uid: profile.uid,
                        initial: profile,
                        managedBy: adminUid,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Delete'),
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  onPressed: () => _delete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the full app (matches, interests, chats) as a managed profile, kept live with its stored data.
class _ActAs extends StatelessWidget {
  final String profileId;
  final String adminUid;
  const _ActAs({required this.profileId, required this.adminUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Profile?>(
      stream: context.read<ProfileService>().watchProfile(profileId),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snap.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : Text(context.tr('This profile no longer exists.')),
            ),
          );
        }
        return HomeScreen(me: p, managerUid: adminUid);
      },
    );
  }
}
