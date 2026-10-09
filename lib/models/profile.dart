import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

/// Reads the photo list, falling back to the single legacy photoUrl field.
List<String> _photos(Map<String, dynamic> d) {
  final list = d['photos'];
  if (list is List) return list.whereType<String>().toList();
  final single = d['photoUrl'];
  return single is String && single.isNotEmpty ? [single] : [];
}

class Profile {
  final String uid;
  final String name;
  final String profileFor;
  final String gender;
  final DateTime dob;
  final int heightCm;
  final String maritalStatus;
  final String education;
  final String occupation;
  final String nativeDistrict;
  final String city;
  final String country;
  final String diet;
  final String about;
  final String hobbies;
  final List<String> photos;
  final bool verified;
  final bool active;
  /// Uid of the admin who runs this profile on someone's behalf; null for self-registered members.
  final String? managedBy;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final int prefMinAge;
  final int prefMaxAge;
  final String? prefEducation;
  final String? prefDistrict;
  final String? prefOccupation;

  const Profile({
    required this.uid,
    required this.name,
    required this.profileFor,
    required this.gender,
    required this.dob,
    required this.heightCm,
    required this.maritalStatus,
    required this.education,
    required this.occupation,
    required this.nativeDistrict,
    required this.city,
    required this.country,
    required this.diet,
    required this.about,
    this.hobbies = '',
    this.photos = const [],
    this.verified = false,
    this.active = true,
    this.managedBy,
    this.createdAt,
    this.lastSeen,
    this.prefMinAge = 18,
    this.prefMaxAge = 70,
    this.prefEducation,
    this.prefDistrict,
    this.prefOccupation,
  });

  int get age {
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  String get oppositeGender => gender == 'Male' ? 'Female' : 'Male';
  bool get hasPhoto => photos.isNotEmpty;

  /// The main photo, shown on cards and avatars.
  String get photoUrl => photos.isEmpty ? '' : photos.first;

  static const maxPhotos = 3;
  bool get isNew =>
      createdAt != null && DateTime.now().difference(createdAt!).inDays <= 30;

  /// Short public member ID derived from the uid.
  String get code {
    final n =
        uid.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xFFFFFF) %
        10000000;
    return 'TIT${n.toString().padLeft(7, '0')}';
  }

  bool get hasPartnerPrefs =>
      prefEducation != null ||
      prefDistrict != null ||
      prefOccupation != null ||
      prefMinAge != 18 ||
      prefMaxAge != 70;

  /// 0-100 profile completeness.
  int get completeness {
    var s = 0;
    if (hasPhoto) s += 20;
    if (about.length >= 20) s += 15;
    if (hobbies.isNotEmpty) s += 15;
    if (occupation.isNotEmpty) s += 10;
    if (education.isNotEmpty) s += 10;
    if (nativeDistrict.isNotEmpty) s += 10;
    if (city.isNotEmpty) s += 10;
    if (hasPartnerPrefs) s += 10;
    return s;
  }

  /// Keys of the profile items still missing, in priority order.
  List<String> get missingItems => [
    if (!hasPhoto) 'photo',
    if (hobbies.isEmpty) 'hobbies',
    if (!hasPartnerPrefs) 'prefs',
  ];

  /// Does this profile satisfy [viewer]'s partner preferences?
  bool fitsPreferencesOf(Profile viewer) =>
      age >= viewer.prefMinAge &&
      age <= viewer.prefMaxAge &&
      (viewer.prefEducation == null || education == viewer.prefEducation) &&
      (viewer.prefDistrict == null || nativeDistrict == viewer.prefDistrict) &&
      (viewer.prefOccupation == null ||
          occupation.toLowerCase().contains(viewer.prefOccupation!.toLowerCase()));

  Map<String, dynamic> toMap() => {
    'name': name,
    'profileFor': profileFor,
    'gender': gender,
    'dob': Timestamp.fromDate(dob),
    'heightCm': heightCm,
    'maritalStatus': maritalStatus,
    'education': education,
    'occupation': occupation,
    'nativeDistrict': nativeDistrict,
    'city': city,
    'country': country,
    'diet': diet,
    'about': about,
    'hobbies': hobbies,
    'photos': photos,
    'photoUrl': photoUrl,
    'verified': verified,
    if (managedBy != null) 'managedBy': managedBy,
    'prefMinAge': prefMinAge,
    'prefMaxAge': prefMaxAge,
    'prefEducation': prefEducation,
    'prefDistrict': prefDistrict,
    'prefOccupation': prefOccupation,
  };

  factory Profile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Profile(
      uid: doc.id,
      name: d['name'] ?? '',
      profileFor: d['profileFor'] ?? 'Myself',
      gender: d['gender'] ?? 'Male',
      dob: (d['dob'] as Timestamp).toDate(),
      heightCm: (d['heightCm'] ?? 160) as int,
      maritalStatus: d['maritalStatus'] ?? '',
      education: d['education'] ?? '',
      occupation: d['occupation'] ?? '',
      nativeDistrict: d['nativeDistrict'] ?? '',
      city: d['city'] ?? '',
      country: d['country'] ?? '',
      diet: d['diet'] ?? '',
      about: d['about'] ?? '',
      hobbies: d['hobbies'] ?? '',
      photos: _photos(d),
      verified: d['verified'] ?? false,
      active: d['active'] ?? true,
      managedBy: d['managedBy'],
      createdAt: _ts(d['createdAt']),
      lastSeen: _ts(d['lastSeen']),
      prefMinAge: (d['prefMinAge'] ?? 18) as int,
      prefMaxAge: (d['prefMaxAge'] ?? 70) as int,
      prefEducation: d['prefEducation'],
      prefDistrict: d['prefDistrict'],
      prefOccupation: d['prefOccupation'],
    );
  }
}

class Interest {
  final String id;
  final String fromUid;
  final String toUid;
  final String status; // pending | accepted | declined
  final DateTime? createdAt;
  final DateTime? respondedAt;

  const Interest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  /// Date shown on the card: when it was answered, else when it was sent.
  DateTime? get date => respondedAt ?? createdAt;

  factory Interest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Interest(
      id: doc.id,
      fromUid: d['fromUid'],
      toUid: d['toUid'],
      status: d['status'] ?? 'pending',
      createdAt: _ts(d['createdAt']),
      respondedAt: _ts(d['respondedAt']),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    this.createdAt,
  });

  factory ChatMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return ChatMessage(
      id: doc.id,
      senderUid: d['senderUid'],
      text: d['text'] ?? '',
      createdAt: _ts(d['createdAt']),
    );
  }
}

class ChatSummary {
  final String otherUid;
  final String lastMessage;
  final DateTime? lastAt;

  const ChatSummary({
    required this.otherUid,
    required this.lastMessage,
    this.lastAt,
  });
}

/// Free-view counter and paid access window for one member.
class Entitlement {
  final int freeViewsUsed;
  final DateTime? premiumUntil;

  const Entitlement({this.freeViewsUsed = 0, this.premiumUntil});

  bool get isPremium =>
      premiumUntil != null && premiumUntil!.isAfter(DateTime.now());

  Entitlement withViewUsed() =>
      Entitlement(freeViewsUsed: freeViewsUsed + 1, premiumUntil: premiumUntil);

  factory Entitlement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Entitlement(
      freeViewsUsed: (d['freeViewsUsed'] ?? 0) as int,
      premiumUntil: _ts(d['premiumUntil']),
    );
  }
}
