import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import 'profile_service.dart';

enum ViewAccess { allowed, needsPayment, loading }

/// Live view of everything the signed-in member has done or received, shared by all tabs.
class ActivityController extends ChangeNotifier {
  Profile me;
  final ProfileService _service;
  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, Profile> _cache = {};
  bool _disposed = false;

  List<Profile> pool = const [];
  bool poolLoading = true;
  Object? poolError;

  Map<String, DateTime?> shortlistedBy = const {};
  Map<String, DateTime?> shortlistedMe = const {};
  Map<String, DateTime?> viewedBy = const {};
  Map<String, DateTime?> viewedMe = const {};
  Map<String, DateTime?> photoRequestsSent = const {};
  Map<String, DateTime?> photoRequestsReceived = const {};
  List<Interest> sent = const [];
  List<Interest> received = const [];
  List<ChatSummary> chats = const [];

  static const freeViewLimit = 2;
  Entitlement entitlement = const Entitlement();
  bool entitlementLoaded = false;

  /// Set when an admin is acting as one of their managed profiles.
  final String? managerUid;
  bool get managed => managerUid != null;
  bool isAdmin = false;

  ActivityController(this.me, this._service, {this.managerUid}) {
    final uid = me.uid;
    _listen(_service.watchShortlistedBy(uid), (v) => shortlistedBy = v);
    _listen(_service.watchShortlistedMe(uid), (v) => shortlistedMe = v);
    _listen(_service.watchViewsBy(uid), (v) => viewedBy = v);
    _listen(_service.watchViewsOf(uid), (v) => viewedMe = v);
    _listen(_service.watchPhotoRequestsSent(uid), (v) => photoRequestsSent = v);
    _listen(
      _service.watchPhotoRequestsReceived(uid),
      (v) => photoRequestsReceived = v,
    );
    _listen(_service.sentInterests(uid), (v) => sent = v);
    _listen(_service.receivedInterests(uid), (v) => received = v);
    _listen(_service.watchChats(uid, managerUid: managerUid), (v) => chats = v);
    if (managed) {
      entitlementLoaded = true;
    } else {
      _listen(_service.watchIsAdmin(uid), (v) => isAdmin = v);
      _listen(_service.watchEntitlement(uid), (v) {
        entitlement = v;
        entitlementLoaded = true;
      });
      _service
          .ensureEntitlement(uid)
          .catchError((Object e) => debugPrint('ensureEntitlement failed: $e'));
    }
    loadPool();
  }

  void _listen<T>(Stream<T> stream, void Function(T) assign) {
    _subs.add(
      stream.listen(
        (v) {
          assign(v);
          notifyListeners();
          _fetchMissingProfiles();
        },
        onError: (Object e) =>
            debugPrint('ActivityController stream error: $e'),
      ),
    );
  }

  /// Called when the member edits their own profile.
  void updateMe(Profile p) {
    if (_disposed) return;
    final genderChanged = p.gender != me.gender;
    me = p;
    notifyListeners();
    if (genderChanged) loadPool();
  }

  Future<void> loadPool() async {
    poolLoading = true;
    poolError = null;
    notifyListeners();
    try {
      pool = await _service.oppositeProfiles(me);
      for (final p in pool) {
        _cache[p.uid] = p;
      }
    } catch (e) {
      poolError = e;
    }
    poolLoading = false;
    if (!_disposed) notifyListeners();
    _fetchMissingProfiles();
  }

  Set<String> get _referencedUids => {
    ...shortlistedBy.keys,
    ...shortlistedMe.keys,
    ...viewedBy.keys,
    ...viewedMe.keys,
    ...photoRequestsSent.keys,
    ...photoRequestsReceived.keys,
    for (final i in sent) i.toUid,
    for (final i in received) i.fromUid,
    for (final c in chats) c.otherUid,
  };

  Future<void> _fetchMissingProfiles() async {
    final missing = _referencedUids
        .where((u) => !_cache.containsKey(u))
        .toList();
    if (missing.isEmpty) return;
    final loaded = await _service.getProfiles(missing);
    for (final p in loaded) {
      _cache[p.uid] = p;
    }
    // Remember absent profiles so we do not refetch them forever.
    for (final u in missing) {
      _cache.putIfAbsent(u, () => _placeholder(u));
    }
    if (!_disposed) notifyListeners();
  }

  Profile _placeholder(String uid) => Profile(
    uid: uid,
    name: '',
    profileFor: '',
    gender: '',
    dob: DateTime(1900),
    heightCm: 0,
    maritalStatus: '',
    education: '',
    occupation: '',
    nativeDistrict: '',
    city: '',
    country: '',
    diet: '',
    about: '',
  );

  Profile? profile(String uid) {
    final p = _cache[uid];
    return (p == null || p.name.isEmpty) ? null : p;
  }

  /// Profiles for [uids], newest first according to [dates], skipping unknown ones.
  List<Profile> profilesByDate(Map<String, DateTime?> dates) {
    final keys = dates.keys.toList()
      ..sort(
        (a, b) =>
            (dates[b] ?? DateTime.now()).compareTo(dates[a] ?? DateTime.now()),
      );
    return [for (final k in keys) ?profile(k)];
  }

  bool isShortlisted(String uid) => shortlistedBy.containsKey(uid);
  bool photoRequested(String uid) => photoRequestsSent.containsKey(uid);

  /// The interest between me and [uid] in either direction, if any.
  Interest? interestWith(String uid) {
    for (final i in sent) {
      if (i.toUid == uid) return i;
    }
    for (final i in received) {
      if (i.fromUid == uid) return i;
    }
    return null;
  }

  bool isConnected(String uid) => interestWith(uid)?.status == 'accepted';

  /// Members I can message or call: accepted interests in either direction.
  List<String> get connections => [
    for (final i in sent)
      if (i.status == 'accepted') i.toUid,
    for (final i in received)
      if (i.status == 'accepted') i.fromUid,
  ];

  int get pendingReceived =>
      received.where((i) => i.status == 'pending').length;

  bool get isPremium => entitlement.isPremium;
  int get freeViewsLeft =>
      (freeViewLimit - entitlement.freeViewsUsed).clamp(0, freeViewLimit);

  /// Decides whether [targetUid]'s profile may be opened and, for free members, uses up one free view.
  ViewAccess requestProfileView(String targetUid) {
    if (targetUid == me.uid || isPremium || managed) return ViewAccess.allowed;
    if (!entitlementLoaded) return ViewAccess.loading;
    if (freeViewsLeft == 0) return ViewAccess.needsPayment;
    // Count locally first so rapid taps cannot exceed the limit; the stream corrects it if the write fails.
    entitlement = entitlement.withViewUsed();
    notifyListeners();
    _service
        .consumeFreeView(me.uid)
        .catchError((Object e) => debugPrint('consumeFreeView failed: $e'));
    return ViewAccess.allowed;
  }

  /// "All matches": opposite-gender members who fit my partner preferences.
  List<Profile> get matches =>
      pool.where((p) => p.fitsPreferencesOf(me)).toList();

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
