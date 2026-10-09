import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

enum AccountRemoval { deactivate, delete }

const _reasons = <(String, String)>[
  ('found_here', 'I found my match on Thamizhi'),
  ('found_elsewhere', 'I found my match elsewhere'),
  ('break', 'I want to take a break'),
  ('unwanted_contact', 'Too many unwanted interests or messages'),
  ('privacy', 'Privacy concerns'),
  ('poor_matches', 'I am not getting suitable matches'),
  ('other', 'Other'),
];

/// Asks for a reason, then either hides the profile (reversible) or deletes the account for good.
class AccountRemovalScreen extends StatefulWidget {
  final AccountRemoval mode;
  final String uid;
  const AccountRemovalScreen({super.key, required this.mode, required this.uid});

  @override
  State<AccountRemovalScreen> createState() => _AccountRemovalScreenState();
}

class _AccountRemovalScreenState extends State<AccountRemovalScreen> {
  final _note = TextEditingController();
  String? _reason;
  bool _busy = false;

  bool get _isDelete => widget.mode == AccountRemoval.delete;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('Delete account permanently?')),
          content: Text(
            ctx.tr(
              'Your profile, photos, chats and interests will be erased and cannot be recovered.',
            ),
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
      ) ??
      false;

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    if (_isDelete && !await _confirmDelete()) return;
    if (!mounted) return;

    final service = context.read<ProfileService>();
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failMessage = context.trRead('Something went wrong. Please try again.');
    final note = _note.text.trim();
    setState(() => _busy = true);
    try {
      if (_isDelete) {
        await service.deleteAccount(reason, note);
        navigator.popUntil((r) => r.isFirst);
        await auth.signOut();
      } else {
        await service.deactivateAccount(widget.uid, reason, note);
        navigator.popUntil((r) => r.isFirst);
      }
    } catch (e) {
      debugPrint('account removal failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(failMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = context.isTamil;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(_isDelete ? 'Delete account' : 'Deactivate account'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr(
              _isDelete
                  ? 'Your profile, photos, chats and interests will be erased and cannot be recovered.'
                  : 'Your profile will be hidden from everyone. You can reactivate it any time by logging in again.',
            ),
            style: Fx.body(ta, fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('Why are you leaving?'),
            style: Fx.serif(
              ta,
              fontSize: ta ? 20 : 22,
              fontWeight: FontWeight.w700,
              color: AppColors.maroon,
            ),
          ),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) {
              if (!_busy) setState(() => _reason = v);
            },
            child: Column(
              children: [
                for (final (code, label) in _reasons)
                  RadioListTile<String>(
                    value: code,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.maroon,
                    title: Text(context.tr(label)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 500,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: context.tr('Anything else you would like to tell us? (optional)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _isDelete ? Colors.red.shade700 : AppColors.maroon,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _reason == null || _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(context.tr(_isDelete ? 'Delete my account' : 'Deactivate my account')),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the app while a member's profile is deactivated.
class DeactivatedScreen extends StatefulWidget {
  final String uid;
  const DeactivatedScreen({super.key, required this.uid});

  @override
  State<DeactivatedScreen> createState() => _DeactivatedScreenState();
}

class _DeactivatedScreenState extends State<DeactivatedScreen> {
  bool _busy = false;

  Future<void> _reactivate() async {
    setState(() => _busy = true);
    try {
      await context.read<ProfileService>().reactivateAccount(widget.uid);
    } catch (e) {
      debugPrint('reactivate failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Something went wrong. Please try again.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = context.isTamil;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.pause_circle_outline, size: 72, color: AppColors.gold),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Your account is deactivated'),
                    textAlign: TextAlign.center,
                    style: Fx.serif(
                      ta,
                      fontSize: ta ? 22 : 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.maroon,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('Your profile is hidden from other members. Reactivate it to be visible again.'),
                    textAlign: TextAlign.center,
                    style: Fx.body(ta, fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _busy ? null : _reactivate,
                    child: Text(context.tr('Reactivate my profile')),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => context.read<AuthService>().signOut(),
                    child: Text(context.tr('Logout')),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountRemovalScreen(
                                mode: AccountRemoval.delete,
                                uid: widget.uid,
                              ),
                            ),
                          ),
                    child: Text(context.tr('Delete account')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
