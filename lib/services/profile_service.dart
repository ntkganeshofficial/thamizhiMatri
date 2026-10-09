import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/profile.dart';

class SearchFilters {
  int minAge;
  int maxAge;
  String? district;
  String? education;
  String? maritalStatus;
  String? diet;
  String? country;

  SearchFilters({
    this.minAge = 18,
    this.maxAge = 70,
    this.district,
    this.education,
    this.maritalStatus,
    this.diet,
    this.country,
  });

  bool get isDefault =>
      minAge == 18 &&
      maxAge == 70 &&
      district == null &&
      education == null &&
      maritalStatus == null &&
      diet == null &&
      country == null;

  bool accepts(Profile p) =>
      p.age >= minAge &&
      p.age <= maxAge &&
      (district == null || p.nativeDistrict == district) &&
      (education == null || p.education == education) &&
      (maritalStatus == null || p.maritalStatus == maritalStatus) &&
      (diet == null || p.diet == diet) &&
      (country == null || p.country == country);
}

class ProfileService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) =>
      _db.collection('profiles').doc(uid);
  static String pairId(String a, String b) => '${a}_$b';
  static String chatId(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // Profiles
  Stream<Profile?> watchProfile(String uid) =>
      _profileRef(uid)
          .snapshots()
          .map((s) => s.exists ? Profile.fromDoc(s) : null);

  Future<Profile?> getProfile(String uid) async {
    final s = await _profileRef(uid).get();
    return s.exists ? Profile.fromDoc(s) : null;
  }

  Future<void> saveProfile(Profile p, {bool isNew = false}) =>
      _profileRef(p.uid).set({
        ...p.toMap(),
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // Admin: profiles created on behalf of other people
  Stream<bool> watchIsAdmin(String uid) => _db
      .collection('admins')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists)
      .handleError((Object _) => false);

  Stream<List<Profile>> watchManagedProfiles(String adminUid) => _db
      .collection('profiles')
      .where('managedBy', isEqualTo: adminUid)
      .snapshots()
      .map((s) => s.docs.map(Profile.fromDoc).toList());

  String newProfileId() => _db.collection('profiles').doc().id;

  Future<void> deleteManagedProfile(Profile p) async {
    await _profileRef(p.uid).collection('private').doc('contact').delete();
    for (final url in p.photos) {
      await deletePhotoByUrl(url);
    }
    await _profileRef(p.uid).delete();
  }

  Future<void> touchLastSeen(String uid) => _profileRef(uid)
      .set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  /// Uploads a new photo under a unique name and returns its download URL.
  Future<String> uploadPhoto(String uid, XFile file, {String? adminUid}) async {
    // Storage rules key on the signed-in uid, so a managed profile's photos carry the admin's uid first.
    final prefix = adminUid == null ? uid : '${adminUid}_$uid';
    final ref = _storage.ref(
      'profile_photos/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putData(
      await file.readAsBytes(),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Best-effort removal of a photo the member deleted.
  Future<void> deletePhotoByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Already gone or not ours to delete; the profile no longer references it.
    }
  }

  /// Phone numbers live in a private sub-document, readable only by the owner and accepted matches.
  Future<void> savePhone(String uid, String phone) =>
      _profileRef(uid)
          .collection('private')
          .doc('contact')
          .set({'phone': phone});

  Future<String?> getPhone(String uid) async {
    try {
      final s = await _profileRef(uid)
          .collection('private')
          .doc('contact')
          .get();
      return s.data()?['phone'] as String?;
    } on FirebaseException {
      return null;
    }
  }

  /// Opposite-gender profiles; all further filtering happens client-side to avoid composite indexes.
  Future<List<Profile>> oppositeProfiles(Profile me) async {
    final snap = await _db
        .collection('profiles')
        .where('gender', isEqualTo: me.oppositeGender)
        .limit(300)
        .get();
    return snap.docs
        .map(Profile.fromDoc)
        .where((p) => p.uid != me.uid && p.active)
        .toList();
  }

  Future<List<Profile>> getProfiles(Iterable<String> uids) async {
    final result = await Future.wait(uids.map(getProfile));
    return result.whereType<Profile>().where((p) => p.active).toList();
  }

  // Account removal
  Future<void> deactivateAccount(String uid, String reason, String note) {
    final batch = _db.batch()
      ..update(_profileRef(uid), {
        'active': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      })
      ..set(_db.collection('accountFeedback').doc(), {
        'uid': uid,
        'action': 'deactivate',
        'reason': reason,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    return batch.commit();
  }

  Future<void> reactivateAccount(String uid) => _profileRef(uid).update({
    'active': true,
    'lastSeen': FieldValue.serverTimestamp(),
  });

  /// Deletes the member's data and login on the server; the caller must sign out afterwards.
  Future<void> deleteAccount(String reason, String note) =>
      FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('deleteAccount').call({'reason': reason, 'note': note});

  // Interests
  Future<void> sendInterest(String fromUid, String toUid) =>
      _db.collection('interests').doc(pairId(fromUid, toUid)).set({
        'fromUid': fromUid,
        'toUid': toUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> withdrawInterest(String interestId) =>
      _db.collection('interests').doc(interestId).delete();

  Future<void> respondToInterest(String interestId, bool accept) =>
      _db.collection('interests').doc(interestId).update({
        'status': accept ? 'accepted' : 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Interest>> receivedInterests(String uid) => _db
      .collection('interests')
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(Interest.fromDoc).toList());

  Stream<List<Interest>> sentInterests(String uid) => _db
      .collection('interests')
      .where('fromUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(Interest.fromDoc).toList());

  // Shortlists: shortlists/{from_to}
  Stream<Map<String, DateTime?>> watchShortlistedBy(String uid) =>
      _pairStream('shortlists', 'fromUid', uid, 'toUid', 'createdAt');

  Stream<Map<String, DateTime?>> watchShortlistedMe(String uid) =>
      _pairStream('shortlists', 'toUid', uid, 'fromUid', 'createdAt');

  Future<void> toggleShortlist(String uid, String profileId, bool add) {
    final ref = _db.collection('shortlists').doc(pairId(uid, profileId));
    return add
        ? ref.set({
            'fromUid': uid,
            'toUid': profileId,
            'createdAt': FieldValue.serverTimestamp(),
          })
        : ref.delete();
  }

  // Profile views: views/{viewer_target}
  Future<void> recordView(String viewerUid, String targetUid) =>
      _db.collection('views').doc(pairId(viewerUid, targetUid)).set({
        'viewerUid': viewerUid,
        'targetUid': targetUid,
        'viewedAt': FieldValue.serverTimestamp(),
      });

  Stream<Map<String, DateTime?>> watchViewsBy(String uid) =>
      _pairStream('views', 'viewerUid', uid, 'targetUid', 'viewedAt');

  Stream<Map<String, DateTime?>> watchViewsOf(String uid) =>
      _pairStream('views', 'targetUid', uid, 'viewerUid', 'viewedAt');

  // Photo requests: photoRequests/{from_to}
  Future<void> requestPhoto(String fromUid, String toUid) =>
      _db.collection('photoRequests').doc(pairId(fromUid, toUid)).set({
        'fromUid': fromUid,
        'toUid': toUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Stream<Map<String, DateTime?>> watchPhotoRequestsSent(String uid) =>
      _pairStream('photoRequests', 'fromUid', uid, 'toUid', 'createdAt');

  Stream<Map<String, DateTime?>> watchPhotoRequestsReceived(String uid) =>
      _pairStream('photoRequests', 'toUid', uid, 'fromUid', 'createdAt');

  Stream<Map<String, DateTime?>> _pairStream(
    String collection,
    String matchField,
    String uid,
    String otherField,
    String dateField,
  ) {
    return _db
        .collection(collection)
        .where(matchField, isEqualTo: uid)
        .snapshots()
        .map(
          (s) => {
            for (final d in s.docs)
              d.data()[otherField] as String:
                  (d.data()[dateField] as Timestamp?)?.toDate(),
          },
        );
  }

  // Entitlements: free-view counter (client) and premium expiry (server only)
  Stream<Entitlement> watchEntitlement(String uid) => _db
      .collection('entitlements')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? Entitlement.fromDoc(s) : const Entitlement());

  Future<void> ensureEntitlement(String uid) async {
    final ref = _db.collection('entitlements').doc(uid);
    if (!(await ref.get()).exists) await ref.set({'freeViewsUsed': 0});
  }

  Future<void> consumeFreeView(String uid) => _db
      .collection('entitlements')
      .doc(uid)
      .update({'freeViewsUsed': FieldValue.increment(1)});

  // Chats: chats/{a_b} with messages sub-collection
  /// For a profile an admin manages, pass [managerUid]; the query then runs on the chat's managers list.
  Stream<List<ChatSummary>> watchChats(String uid, {String? managerUid}) {
    final chats = _db.collection('chats');
    final query = managerUid == null
        ? chats.where('participants', arrayContains: uid)
        : chats.where('managers', arrayContains: managerUid);
    return query.snapshots().map(
      (s) => [
        for (final d in s.docs)
          if ((d.data()['participants'] as List).contains(uid))
            ChatSummary(
              otherUid: (d.data()['participants'] as List)
                  .cast<String>()
                  .firstWhere((p) => p != uid),
              lastMessage: d.data()['lastMessage'] ?? '',
              lastAt: (d.data()['lastAt'] as Timestamp?)?.toDate(),
            ),
      ],
    );
  }

  Stream<List<ChatMessage>> watchMessages(String a, String b) => _db
      .collection('chats')
      .doc(chatId(a, b))
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  Future<void> sendMessage(String from, String to, String text) async {
    final chat = _db.collection('chats').doc(chatId(from, to));
    // Admins running either profile need to find this chat later.
    final managers = <String>{};
    for (final uid in [from, to]) {
      final m = (await _profileRef(uid).get()).data()?['managedBy'];
      if (m is String) managers.add(m);
    }
    final batch = _db.batch()
      ..set(chat, {
        'participants': [from, to]..sort(),
        if (managers.isNotEmpty) 'managers': FieldValue.arrayUnion(managers.toList()),
        'lastMessage': text,
        'lastAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true))
      ..set(chat.collection('messages').doc(), {
        'senderUid': from,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    return batch.commit();
  }
}
