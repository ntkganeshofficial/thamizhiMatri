import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../core/nav.dart';
import '../models/profile.dart';
import '../services/activity_controller.dart';
import '../services/profile_service.dart';
import 'account_screen.dart';
import 'home_tab.dart';
import 'interests_tab.dart';
import 'matches_tab.dart';
import 'messages_tab.dart';
import 'search_tab.dart';

class HomeScreen extends StatefulWidget {
  final Profile me;
  /// Set when an admin is acting as this managed profile.
  final String? managerUid;
  const HomeScreen({super.key, required this.me, this.managerUid});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ActivityController _activity;
  final _category = ValueNotifier<MatchCategory>(MatchCategory.all);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final service = context.read<ProfileService>();
    _activity = ActivityController(
      widget.me,
      service,
      managerUid: widget.managerUid,
    );
    if (widget.managerUid == null) {
      service
          .touchLastSeen(widget.me.uid)
          .catchError((Object e) => debugPrint('touchLastSeen failed: $e'));
    }
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    // Notifying listeners while the tree is building is not allowed.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _activity.updateMe(widget.me),
    );
  }

  @override
  void dispose() {
    _activity.dispose();
    _category.dispose();
    super.dispose();
  }

  void _openMatches(MatchCategory c) {
    _category.value = c;
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ActivityController>.value(
      value: _activity,
      child: Builder(
        builder: (context) {
          final pending = context.watch<ActivityController>().pendingReceived;
          final tabs = [
            HomeTab(
              onOpenMatches: _openMatches,
              onOpenInterests: () => setState(() => _index = 2),
              onOpenAccount: () => pushScreen(context, const AccountScreen()),
            ),
            MatchesTab(category: _category),
            const InterestsTab(),
            const MessagesTab(),
            const SearchTab(),
          ];
          return Scaffold(
            backgroundColor: AppColors.cream,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (widget.managerUid != null)
                    Material(
                      color: AppColors.maroon,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.tr('Acting as {name}', {
                                  'name': widget.me.name,
                                }),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.gold,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(context.tr('Exit')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(child: IndexedStack(index: _index, children: tabs)),
                ],
              ),
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
              ),
              child: NavigationBar(
                backgroundColor: AppColors.cream,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                indicatorColor: AppColors.gold.withValues(alpha: 0.25),
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    label: context.tr('Home'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.people_outline),
                    label: context.tr('Matches'),
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: pending > 0,
                      label: Text('$pending'),
                      child: const Icon(Icons.favorite_border),
                    ),
                    label: context.tr('Interests'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: context.tr('Messages'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.search),
                    label: context.tr('Search'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
