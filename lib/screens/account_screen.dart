import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/l10n.dart';
import '../services/translation_controller.dart';
import '../core/nav.dart';
import '../services/activity_controller.dart';
import '../services/auth_service.dart';
import '../widgets/language_toggle.dart';
import '../widgets/match_card.dart';
import '../widgets/profile_card.dart';
import 'account_removal_screen.dart';
import 'managed_profiles_screen.dart';
import 'profile_form_screen.dart';
import 'paywall_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityController>();
    final me = activity.me;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Account'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: ProfileAvatar(profile: me, radius: 56)),
          const SizedBox(height: 12),
          Center(child: Text(context.tx(me.name), style: text.headlineSmall)),
          Center(
            child: Text(
              me.code,
              style: text.bodySmall?.copyWith(color: Colors.black45),
            ),
          ),
          if (me.verified)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Center(child: VerifiedBadge()),
            ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${me.age} ${context.tr('yrs')} \u2022 ${context.tx(me.city)}, ${context.tr(me.country)}',
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(context.tr('Edit profile')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileFormScreen(
                  uid: me.uid,
                  initial: me,
                  managedBy: me.managedBy,
                ),
              ),
            ),
          ),
          if (activity.isAdmin && !activity.managed)
            ListTile(
              leading: const Icon(Icons.supervisor_account_outlined),
              title: Text(context.tr('Managed profiles')),
              subtitle: Text(context.tr('Create and run profiles for other people')),
              onTap: () => pushScreen(context, const ManagedProfilesScreen()),
            ),
          if (!activity.managed) ...[
          ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: Text(context.tr('Plans & payments')),
            onTap: () => pushScreen(context, const PaywallScreen()),
          ),
],
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.tr('Language')),
            trailing: const LanguageToggle(),
          ),
          if (activity.managed)
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: Text(context.tr('Stop acting as this profile')),
              onTap: () => Navigator.of(context)
                ..pop()
                ..pop(),
            )
          else ...[
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(context.tr('Logout')),
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              context.read<AuthService>().signOut();
            },
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.pause_circle_outline),
            title: Text(context.tr('Deactivate account')),
            subtitle: Text(context.tr('Hide your profile. You can come back any time.')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountRemovalScreen(
                  mode: AccountRemoval.deactivate,
                  uid: me.uid,
                ),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
            title: Text(
              context.tr('Delete account'),
              style: TextStyle(color: Colors.red.shade700),
            ),
            subtitle: Text(context.tr('Permanently erase your profile and data.')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountRemovalScreen(
                  mode: AccountRemoval.delete,
                  uid: me.uid,
                ),
              ),
            ),
          ),
],
          const SizedBox(height: 24),
          Center(
            child: Text(
              AppStrings.taglineTamil,
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
