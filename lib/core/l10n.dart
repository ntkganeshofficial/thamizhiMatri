import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends ChangeNotifier {
  static const _key = 'lang_tamil';
  final SharedPreferences _prefs;
  bool _tamil;

  LanguageController(this._prefs) : _tamil = _prefs.getBool(_key) ?? false;

  bool get isTamil => _tamil;
  Locale get locale => Locale(_tamil ? 'ta' : 'en');

  /// Translates an English UI string; unknown strings (and user data) pass through unchanged.
  /// `{name}` placeholders are replaced from [args].
  String t(String s, [Map<String, String>? args]) {
    var out = _tamil ? (_ta[s] ?? s) : s;
    args?.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }

  static const _enMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _taMonths = [
    'ஜன',
    'பிப்',
    'மார்',
    'ஏப்',
    'மே',
    'ஜூன்',
    'ஜூலை',
    'ஆக',
    'செப்',
    'அக்',
    'நவ',
    'டிச',
  ];

  String date(DateTime d) =>
      '${d.day} ${(_tamil ? _taMonths : _enMonths)[d.month - 1]} ${d.year}';

  String ago(DateTime? d) {
    if (d == null) return t('just now');
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 10) return t('just now');
    if (diff.inMinutes < 60) {
      return t('{n} min ago', {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) return t('{n} hours ago', {'n': '${diff.inHours}'});
    return t('{n} days ago', {'n': '${diff.inDays}'});
  }

  Future<void> setTamil(bool value) async {
    if (_tamil == value) return;
    _tamil = value;
    notifyListeners();
    await _prefs.setBool(_key, value);
  }
}

extension L10n on BuildContext {
  /// For use inside build(); rebuilds when the language changes.
  String tr(String s, [Map<String, String>? args]) =>
      watch<LanguageController>().t(s, args);

  /// For callbacks (snackbars etc.) where watching is not allowed.
  String trRead(String s, [Map<String, String>? args]) =>
      read<LanguageController>().t(s, args);

  String fmtDate(DateTime d) => watch<LanguageController>().date(d);
  String fmtAgo(DateTime? d) => watch<LanguageController>().ago(d);

  bool get isTamil => watch<LanguageController>().isTamil;
}

/// Bundled Google fonts (assets/fonts), so the app needs no network to render text.
class TamilFonts {
  static const display = 'TiroTamil'; // app title
  static const heading = 'NotoSerifTamil'; // headings and names
  static const body = 'MuktaMalar'; // UI text
  static const accent = 'HindMadurai'; // taglines
  static const latinBody = 'Inter';
  static const latinHeading = 'CormorantGaramond';
}

/// Fonts for English and Tamil text; the family follows the active language.
class Fx {
  static TextStyle body(
    bool ta, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    if (ta) {
      return TextStyle(
        fontFamily: TamilFonts.body,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return latin(
      TamilFonts.latinBody,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle serif(
    bool ta, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    if (ta) {
      return tamilHeading(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
    return latin(
      TamilFonts.latinHeading,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Inter and Cormorant Garamond are variable fonts, so the weight axis is set explicitly.
  static TextStyle latin(
    String family, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    final w = fontWeight ?? FontWeight.w400;
    return TextStyle(
      fontFamily: family,
      fontSize: fontSize,
      fontWeight: w,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontVariations: [FontVariation.weight(w.value.toDouble())],
    );
  }

  /// Noto Serif Tamil is a variable font, so the weight axis is set explicitly.
  static TextStyle tamilHeading({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    final w = fontWeight ?? FontWeight.w400;
    return TextStyle(
      fontFamily: TamilFonts.heading,
      fontSize: fontSize,
      fontWeight: w,
      color: color,
      height: height,
      fontVariations: [FontVariation.weight(w.value.toDouble())],
    );
  }
}

const _ta = <String, String>{
  // Welcome / auth
  'Register / Login with Mobile OTP':
      'அலைபேசி கடவுக்குறியீடு(OTP) மூலம் பதிவு / உள்நுழைவு',
  'Continue with Email': 'மின்னஞ்சல் மூலம் தொடரவும்',
  'By continuing, you agree to our': 'தொடர்வதன் மூலம், நீங்கள் எங்கள்',
  'Terms of Service': 'சேவை விதிமுறைகள்',
  'and': 'மற்றும்',
  'Privacy Policy': 'தனியுரிமைக் கொள்கை',
  'Create account': 'கணக்கை உருவாக்கு',
  'Login': 'உள்நுழை',
  'Email': 'மின்னஞ்சல்',
  'Enter a valid email': 'சரியான மின்னஞ்சலை உள்ளிடவும்',
  'Password': 'கடவுச்சொல்',
  'Minimum 6 characters': 'குறைந்தது 6 எழுத்துகள்',
  'Register': 'பதிவு செய்',
  'Already a member? Login': 'ஏற்கனவே உறுப்பினரா? உள்நுழைக',
  'New here? Register free': 'புதியவரா? இலவசமாக பதிவு செய்க',
  'Forgot password?': 'கடவுச்சொல்லை மறந்துவிட்டீர்களா?',
  'Enter your email first': 'முதலில் உங்கள் மின்னஞ்சலை உள்ளிடவும்',
  'Password reset email sent':
      'கடவுச்சொல் மீட்டமைப்பு மின்னஞ்சல் அனுப்பப்பட்டது',
  'Mobile verification': 'அலைபேசி சரிபார்ப்பு',
  'Mobile number': 'அலைபேசி எண்',
  'OTP will be sent to this number':
      'இந்த எண்ணுக்கு கடவுக்குறியீடு(OTP) அனுப்பப்படும்',
  'Send OTP': 'கடவுக்குறியீடு(OTP) அனுப்பு',
  'Enter the OTP sent to': 'அனுப்பப்பட்ட கடவுக்குறியீடு(OTP) ஐ உள்ளிடவும்:',
  'OTP': 'கடவுக்குறியீடு(OTP)',
  'Verify & Continue': 'சரிபார்த்து தொடரவும்',
  'Change number': 'எண்ணை மாற்று',
  'Enter a valid mobile number': 'சரியான அலைபேசி எண்ணை உள்ளிடவும்',
  'Enter the 6-digit OTP': '6 இலக்க கடவுக்குறியீடு(OTP) ஐ உள்ளிடவும்',

  // Profile form
  'Create your profile': 'உங்கள் சுயவிவரத்தை உருவாக்குங்கள்',
  'Edit profile': 'சுயவிவரத்தை திருத்து',
  'Logout': 'வெளியேறு',
  'Profile created for': 'யாருக்காக சுயவிவரம்',
  'Name': 'பெயர்',
  'Gender': 'பாலினம்',
  'Date of birth': 'பிறந்த தேதி',
  'Select': 'தேர்வு செய்',
  'Select date of birth': 'பிறந்த தேதியைத் தேர்வு செய்யவும்',
  'Height': 'உயரம்',
  'Marital status': 'திருமண நிலை',
  'Education': 'கல்வித்தகுதி',
  'Occupation': 'தொழில்',
  'Native district (Tamil Nadu)': 'சொந்த மாவட்டம் (தமிழ்நாடு)',
  'Current city': 'தற்போதைய நகரம்',
  'Country': 'நாடு',
  'Diet': 'உணவுப் பழக்கம்',
  'About me / my expectations': 'என்னைப் பற்றி / என் எதிர்பார்ப்புகள்',
  'Save changes': 'மாற்றங்களைச் சேமி',
  'Create profile': 'சுயவிவரத்தை உருவாக்கு',
  'Required': 'தேவை',
  'Could not save profile': 'சுயவிவரத்தைச் சேமிக்க முடியவில்லை',

  // Discover & navigation
  'Discover': 'தேடல்',
  'Interests': 'விருப்பங்கள்',
  'Shortlist': 'தேர்வு செய்',
  'Account': 'கணக்கு',
  'Filters': 'வடிகட்டிகள்',
  'Matches for you': 'உங்களுக்கான பொருத்தங்கள்',
  'No matches found. Try changing filters.':
      'பொருத்தங்கள் இல்லை. வடிகட்டிகளை மாற்றி முயற்சிக்கவும்.',
  'Error': 'பிழை',
  'Beyond caste and religion. Connected through Tamil.':
      'சாதி மதங்களை கடந்து, தமிழால் இணைவோம்.',
  'Age': 'வயது',
  'Age & height': 'வயது & உயரம்',
  'yrs': 'வயது',
  'cm': 'செ.மீ',
  'Native district': 'சொந்த மாவட்டம்',
  'Any': 'ஏதேனும்',
  'Reset': 'மீட்டமை',
  'Apply': 'பயன்படுத்து',
  'View profile': 'சுயவிவரத்தைப் பார்',

  // Interests / shortlist / account / detail
  'Received': 'பெற்றவை',
  'Sent': 'அனுப்பியவை',
  'Nothing here yet': 'இங்கு இன்னும் எதுவும் இல்லை',
  'Decline': 'நிராகரி',
  'Accept': 'ஏற்றுக்கொள்',
  'Status': 'நிலை',
  'pending': 'நிலுவையில்',
  'accepted': 'ஏற்கப்பட்டது',
  'declined': 'நிராகரிக்கப்பட்டது',
  'No shortlisted profiles': 'தேர்வுப்பட்டியலில் சுயவிவரங்கள் இல்லை',
  'Remove from shortlist': 'தேர்வுப்பட்டியலில் இருந்து நீக்கு',
  'Lives in': 'வசிக்குமிடம்',
  'Profile created by': 'சுயவிவரம் உருவாக்கியவர்',
  'About': 'பற்றி',
  'Interest': 'விருப்பம்',
  'Send Interest': 'விருப்பம் தெரிவி',
  'Interest sent': 'விருப்பம் அனுப்பப்பட்டது',
  'Language': 'மொழி',

  // Option values
  'Myself': 'நான்',
  'Son': 'மகன்',
  'Daughter': 'மகள்',
  'Brother': 'சகோதரர்',
  'Sister': 'சகோதரி',
  'Relative': 'உறவினர்',
  'Friend': 'நண்பர்',
  'Male': 'ஆண்',
  'Female': 'பெண்',
  'Never Married': 'திருமணமாகாதவர்',
  'Divorced': 'விவாகரத்து பெற்றவர்',
  'Widowed': 'விதவை / துணையை இழந்தவர்',
  'Awaiting Divorce': 'விவாகரத்துக்காக காத்திருப்பவர்',
  'Vegetarian': 'சைவம்',
  'Non-Vegetarian': 'அசைவம்',
  'Eggetarian': 'முட்டை சைவம்',
  'High School': 'பள்ளிக் கல்வி',
  'Diploma': 'டிப்ளமோ',
  'Bachelors': 'இளங்கலை',
  'Masters': 'முதுகலை',
  'Doctorate': 'முனைவர்',
  'Professional (CA/Law/Medical)': 'தொழில்முறை (CA/சட்டம்/மருத்துவம்)',
  'Other': 'மற்றவை',
  'India': 'இந்தியா',
  'Sri Lanka': 'இலங்கை',
  'Singapore': 'சிங்கப்பூர்',
  'Malaysia': 'மலேசியா',
  'UAE': 'ஐக்கிய அரபு அமீரகம்',
  'USA': 'அமெரிக்கா',
  'UK': 'ஐக்கிய இராச்சியம்',
  'Canada': 'கனடா',
  'Australia': 'ஆஸ்திரேலியா',
  'Chennai': 'சென்னை',
  'Coimbatore': 'கோயம்புத்தூர்',
  'Madurai': 'மதுரை',
  'Tiruchirappalli': 'திருச்சிராப்பள்ளி',
  'Salem': 'சேலம்',
  'Tirunelveli': 'திருநெல்வேலி',
  'Erode': 'ஈரோடு',
  'Vellore': 'வேலூர்',
  'Thanjavur': 'தஞ்சாவூர்',
  'Thoothukudi': 'தூத்துக்குடி',
  'Dindigul': 'திண்டுக்கல்',
  'Kanchipuram': 'காஞ்சிபுரம்',
  'Cuddalore': 'கடலூர்',
  'Tiruppur': 'திருப்பூர்',
  'Namakkal': 'நாமக்கல்',
  'Karur': 'கரூர்',
  'Virudhunagar': 'விருதுநகர்',
  'Sivaganga': 'சிவகங்கை',
  'Ramanathapuram': 'ராமநாதபுரம்',
  'Kanyakumari': 'கன்னியாகுமரி',
  'Nagapattinam': 'நாகப்பட்டினம்',

  // Navigation and titles
  'Home': 'முகப்பு',
  'Matches': 'பொருத்தங்கள்',
  'Messages': 'செய்திகள்',
  'Search': 'தேடு',
  'View all': 'அனைத்தும் பார்',
  'More': 'மேலும்',
  'Verified': 'சரிபார்க்கப்பட்டது',

  // Relative time
  'just now': 'இப்போது',
  '{n} min ago': '{n} நிமிடங்களுக்கு முன்',
  '{n} hours ago': '{n} மணி நேரத்திற்கு முன்',
  '{n} days ago': '{n} நாட்களுக்கு முன்',
  'Last seen {when}': 'கடைசியாக பார்த்தது: {when}',

  // Profile form
  'Hobbies & interests': 'பொழுதுபோக்குகள் & ஆர்வங்கள்',
  'Shared only with members whose interest you accept':
      'நீங்கள் விருப்பத்தை ஏற்ற உறுப்பினர்களுடன் மட்டுமே பகிரப்படும்',
  'Partner preferences': 'துணை விருப்பத்தேர்வுகள்',

  // Cards and detail
  'Photo requested': 'புகைப்படம் கோரப்பட்டது',
  'Request her to add photo': 'புகைப்படம் சேர்க்கக் கோருங்கள்',
  'Request him to add photo': 'புகைப்படம் சேர்க்கக் கோருங்கள்',
  'NEWLY JOINED': 'புதிதாக இணைந்தவர்',
  'Shortlisted': 'தேர்வானது',
  'Phone number not available': 'தொலைபேசி எண் கிடைக்கவில்லை',
  'Send Message': 'செய்தி',
  'Call Now': 'அழை',
  'He declined your interest': 'அவர் உங்கள் விருப்பத்தை நிராகரித்தார்',
  'She declined your interest': 'அவர் உங்கள் விருப்பத்தை நிராகரித்தார்',
  'You declined this interest': 'நீங்கள் இந்த விருப்பத்தை நிராகரித்தீர்கள்',

  // Chat
  'Could not send message': 'செய்தியை அனுப்ப முடியவில்லை',
  'Say hello to start the conversation':
      'உரையாடலைத் தொடங்க வணக்கம் சொல்லுங்கள்',
  'Type a message': 'செய்தியை உள்ளிடவும்',
  'Chat with members who accepted your interest':
      'உங்கள் விருப்பத்தை ஏற்றவர்களுடன் உரையாடுங்கள்',
  'No conversations yet. Accepted interests appear here.':
      'உரையாடல்கள் இல்லை. ஏற்கப்பட்ட விருப்பங்கள் இங்கே தோன்றும்.',
  'Say hello': 'வணக்கம் சொல்லுங்கள்',

  // Interests
  'Interests Received': 'பெற்ற விருப்பங்கள்',
  'Interests Sent': 'அனுப்பிய விருப்பங்கள்',
  'All': 'அனைத்தும்',
  'Pending': 'நிலுவையில்',
  'Accepted / Replied': 'ஏற்றவை / பதிலளித்தவை',
  'Search by name or ID': 'பெயர் அல்லது ஐடி மூலம் தேடு',
  'You have no interests yet': 'உங்களுக்கு இன்னும் விருப்பங்கள் இல்லை',
  'You have no {kind} interests': '{kind} விருப்பங்கள் எதுவும் இல்லை',
  'All interests received': 'பெற்ற அனைத்து விருப்பங்கள்',
  'Pending interests received': 'பெற்ற நிலுவை விருப்பங்கள்',
  'Accepted interests received': 'பெற்ற ஏற்கப்பட்ட விருப்பங்கள்',
  'Declined interests received': 'பெற்ற நிராகரித்த விருப்பங்கள்',
  'All interests sent': 'அனுப்பிய அனைத்து விருப்பங்கள்',
  'Pending interests sent': 'அனுப்பிய நிலுவை விருப்பங்கள்',
  'Accepted interests sent': 'அனுப்பிய ஏற்கப்பட்ட விருப்பங்கள்',
  'Declined interests sent': 'அனுப்பிய நிராகரித்த விருப்பங்கள்',
  'You accepted {pn} interest': 'நீங்கள் அவரது விருப்பத்தை ஏற்றீர்கள்',
  'You declined {pn} interest': 'நீங்கள் அவரது விருப்பத்தை நிராகரித்தீர்கள்',
  '{pro} sent you an interest': 'அவர் உங்களுக்கு விருப்பம் அனுப்பினார்',
  '{pro} accepted your interest': 'அவர் உங்கள் விருப்பத்தை ஏற்றார்',
  '{pro} declined your interest': 'அவர் உங்கள் விருப்பத்தை நிராகரித்தார்',
  'You sent {obj} an interest': 'நீங்கள் அவருக்கு விருப்பம் அனுப்பினீர்கள்',

  // Matches
  'All matches': 'அனைத்து பொருத்தங்கள்',
  'Newly joined': 'புதிதாக இணைந்தவர்கள்',
  'Sort by': 'வரிசைப்படுத்து',
  'Relevance': 'பொருத்தம்',
  'Newest first': 'புதியவை முதலில்',
  'Age: low to high': 'வயது: குறைந்தது முதல்',
  'Age: high to low': 'வயது: அதிகம் முதல்',
  'Not seen': 'பார்க்காதவை',
  'With photo': 'புகைப்படத்துடன்',
  '{n} matches': '{n} பொருத்தங்கள்',
  '{n} members': '{n} உறுப்பினர்கள்',
  'Set this partner preference in Edit profile to see matches': 'பொருத்தங்களைக் காண சுயவிவரத் திருத்தத்தில் இந்த துணை விருப்பத்தை அமைக்கவும்',
  'Shortlisted by you': 'நீங்கள் தேர்வு செய்தவர்கள்',
  'Viewed you': 'உங்களைப் பார்த்தவர்கள்',
  'Shortlisted you': 'உங்களைத் தேர்வு செய்தவர்கள்',
  'Viewed by you': 'நீங்கள் பார்த்தவர்கள்',
  'Photo requests sent': 'அனுப்பிய புகைப்பட கோரிக்கைகள்',
  'Nearby matches': 'அருகிலுள்ள பொருத்தங்கள்',
  'Photo matches': 'புகைப்படப் பொருத்தங்கள்',
  'Mutual matches': 'பரஸ்பரப் பொருத்தங்கள்',
  'Looking for you': 'உங்களைத் தேடுபவர்கள்',
  'Education preference': 'கல்வி விருப்பம்',
  'Location preference': 'இட விருப்பம்',
  'NRI matches': 'வெளிநாடு வாழ் பொருத்தங்கள்',
  'Members who match your partner preferences':
      'உங்கள் துணை விருப்பத்திற்குப் பொருந்தும் உறுப்பினர்கள்',
  'Matches who joined within the last 30 days':
      'கடந்த 30 நாட்களில் இணைந்தவர்கள்',
  'Matches you have shortlisted': 'நீங்கள் தேர்வு செய்த பொருத்தங்கள்',
  'Matches who have viewed your profile': 'உங்கள் சுயவிவரத்தைப் பார்த்தவர்கள்',
  'Matches who have shortlisted your profile':
      'உங்கள் சுயவிவரத்தைத் தேர்வு செய்தவர்கள்',
  'Matches you have viewed': 'நீங்கள் பார்த்த பொருத்தங்கள்',
  'Members you asked to add a photo':
      'புகைப்படம் சேர்க்கக் கோரிய உறுப்பினர்கள்',
  'Matches near your location': 'உங்கள் இடத்திற்கு அருகிலுள்ள பொருத்தங்கள்',
  'Matches that have added photos': 'புகைப்படம் சேர்த்த பொருத்தங்கள்',
  'Matches whose profile match your preferences and vice versa':
      'ஒருவருக்கொருவர் விருப்பத்திற்குப் பொருந்தும் பொருத்தங்கள்',
  'Matches whose preferences match your profile':
      'உங்கள் சுயவிவரம் அவர்கள் விருப்பத்திற்குப் பொருந்தும் பொருத்தங்கள்',
  'Matches based on your preferred education':
      'உங்கள் விருப்பக் கல்வியின் அடிப்படையிலான பொருத்தங்கள்',
  'Matches from your preferred district':
      'உங்கள் விருப்ப மாவட்டத்தைச் சேர்ந்த பொருத்தங்கள்',
  'Matches from outside India':
      'இந்தியாவுக்கு வெளியிலிருந்து வரும் பொருத்தங்கள்',
  'Based on activity': 'செயல்பாட்டின் அடிப்படையில்',
  'Recently joined & nearby matches':
      'புதிதாக இணைந்த & அருகிலுள்ள பொருத்தங்கள்',
  'Based on profile details': 'சுயவிவர விவரங்களின் அடிப்படையில்',
  'Members who are looking for someone like you':
      'உங்களைப் போன்ற ஒருவரைத் தேடும் உறுப்பினர்கள்',
  'Matches based on preferences': 'விருப்பங்களின் அடிப்படையிலான பொருத்தங்கள்',

  // Home dashboard
  'All Matches ({n})': 'அனைத்து பொருத்தங்கள் ({n})',
  'Who Viewed You ({n})': 'உங்களைப் பார்த்தவர்கள் ({n})',
  'Who Shortlisted You ({n})': 'உங்களைத் தேர்வு செய்தவர்கள் ({n})',
  'Photo requests sent ({n})': 'அனுப்பிய புகைப்பட கோரிக்கைகள் ({n})',
  'Profiles You Shortlisted ({n})': 'நீங்கள் தேர்வு செய்த சுயவிவரங்கள் ({n})',
  'Profiles You Viewed ({n})': 'நீங்கள் பார்த்த சுயவிவரங்கள் ({n})',
  'Members who viewed your profile':
      'உங்கள் சுயவிவரத்தைப் பார்த்த உறுப்பினர்கள்',
  'Members who shortlisted your profile':
      'உங்கள் சுயவிவரத்தைத் தேர்வு செய்த உறுப்பினர்கள்',
  'Members that you have shortlisted': 'நீங்கள் தேர்வு செய்த உறுப்பினர்கள்',
  'Members that you have viewed': 'நீங்கள் பார்த்த உறுப்பினர்கள்',
  'Viewed on: {date}': 'பார்த்த நாள்: {date}',
  'Shortlisted on: {date}': 'தேர்வு செய்த நாள்: {date}',
  'Photo pending': 'புகைப்படம் நிலுவையில்',
  'Complete Your Profile': 'உங்கள் சுயவிவரத்தை நிறைவு செய்யுங்கள்',
  'Profile completeness score': 'சுயவிவர நிறைவு மதிப்பெண்',
  'Add photo': 'புகைப்படம் சேர்',
  'Add hobbies': 'பொழுதுபோக்குகளைச் சேர்',
  'Set partner preferences': 'துணை விருப்பங்களை அமை',
  '{n} members asked you to add a photo':
      '{n} உறுப்பினர்கள் உங்கள் புகைப்படத்தைக் கோரினர்',
  'Search by name, ID, city or occupation':
      'பெயர், ஐடி, நகரம் அல்லது தொழில் மூலம் தேடு',

  // Premium and payments
  'Premium': 'பிரீமியம்',
  'Premium until {date}': 'பிரீமியம்: {date} வரை',
  'Premium active until {date}': 'பிரீமியம் {date} வரை செயலில் உள்ளது',
  '{n} free profile views left': 'இலவச சுயவிவரப் பார்வைகள்: {n} மீதம்',
  'You have used your {n} free profile views':
      'உங்களின் {n} இலவச சுயவிவரப் பார்வைகளையும் பயன்படுத்திவிட்டீர்கள்',
  'Unlimited profile views, with Call and Message access for accepted interests.': 'வரம்பற்ற சுயவிவரப் பார்வைகள்; ஏற்கப்பட்ட விருப்பங்களுக்கு அழைப்பு மற்றும் செய்தி வசதி.',
  'Choose a plan': 'திட்டத்தைத் தேர்வு செய்யுங்கள்',
  '1 month': '1 மாதம்',
  '{n} months': '{n} மாதங்கள்',
  'Best value': 'சிறந்த மதிப்பு',
  'Pay ₹{price}': '₹{price} செலுத்து',
  'Payments are available in the mobile app':
      'கட்டணம் செலுத்துதல் மொபைல் செயலியில் மட்டுமே உள்ளது',
  'Secure payment by Razorpay (UPI, cards, netbanking)':
      'Razorpay மூலம் பாதுகாப்பான கட்டணம் (UPI, அட்டைகள், நெட்பேங்கிங்)',
  'Could not start the payment': 'கட்டணத்தைத் தொடங்க முடியவில்லை',
  'Payment successful': 'கட்டணம் வெற்றிகரமாக செலுத்தப்பட்டது',
  'Payment received but could not be confirmed. Please contact support.': 'கட்டணம் பெறப்பட்டது ஆனால் உறுதிப்படுத்த முடியவில்லை. ஆதரவைத் தொடர்பு கொள்ளவும்.',
  'Payment failed': 'கட்டணம் தோல்வியடைந்தது',
  'Plans & payments': 'திட்டங்கள் & கட்டணங்கள்',
  'Checking your plan, please try again':
      'உங்கள் திட்டத்தைச் சரிபார்க்கிறோம், மீண்டும் முயற்சிக்கவும்',
  'Photos (up to {n})': 'புகைப்படங்கள் (அதிகபட்சம் {n})',
  'The first photo is your main profile photo': 'முதல் புகைப்படம் உங்கள் முதன்மை சுயவிவரப் புகைப்படம்',
  'Main': 'முதன்மை',
  'Location': 'இருப்பிடம்',
  'Any age': 'எந்த வயதும்',
  'All partner preferences are optional': 'துணை விருப்பத்தேர்வுகள் அனைத்தும் விருப்பத்திற்குரியவை',
  'Professional preference': 'தொழில் விருப்பம்',
  'Matches based on your preferred occupation': 'உங்கள் விருப்பத் தொழிலின் அடிப்படையிலான பொருத்தங்கள்',
  'All Matches': 'அனைத்து பொருத்தங்கள்',
  'Who Viewed You': 'உங்களைப் பார்த்தவர்கள்',
  'Who Shortlisted You': 'உங்களைத் தேர்வு செய்தவர்கள்',
  'Profiles You Shortlisted': 'நீங்கள் தேர்வு செய்த சுயவிவரங்கள்',
  'Profiles You Viewed': 'நீங்கள் பார்த்த சுயவிவரங்கள்',
  'Free profile views:': 'இலவச சுயவிவரப் பார்வைகள்:',
  'left': 'மீதம்',
  'Deactivate account': 'கணக்கை முடக்கு',
  'Hide your profile. You can come back any time.': 'உங்கள் சுயவிவரத்தை மறைக்கவும். எப்போது வேண்டுமானாலும் திரும்பலாம்.',
  'Delete account': 'கணக்கை நீக்கு',
  'Permanently erase your profile and data.': 'உங்கள் சுயவிவரம் மற்றும் தரவை நிரந்தரமாக அழிக்கவும்.',
  'Delete account permanently?': 'கணக்கை நிரந்தரமாக நீக்கவா?',
  'Your profile, photos, chats and interests will be erased and cannot be recovered.': 'உங்கள் சுயவிவரம், புகைப்படங்கள், உரையாடல்கள், விருப்பங்கள் அழிக்கப்படும்; மீட்க முடியாது.',
  'Your profile will be hidden from everyone. You can reactivate it any time by logging in again.': 'உங்கள் சுயவிவரம் அனைவரிடமிருந்தும் மறைக்கப்படும். மீண்டும் உள்நுழைந்து எப்போது வேண்டுமானாலும் செயல்படுத்தலாம்.',
  'Why are you leaving?': 'ஏன் விலகுகிறீர்கள்?',
  'I found my match on Thamizhi': 'தமிழி மூலம் எனக்கு துணை கிடைத்தது',
  'I found my match elsewhere': 'வேறு இடத்தில் துணை கிடைத்தது',
  'I want to take a break': 'சிறிது இடைவெளி எடுக்க விரும்புகிறேன்',
  'Too many unwanted interests or messages': 'தேவையற்ற விருப்பங்கள் / செய்திகள் அதிகம்',
  'Privacy concerns': 'தனியுரிமை கவலைகள்',
  'I am not getting suitable matches': 'பொருத்தமான வரன்கள் கிடைக்கவில்லை',
  'Anything else you would like to tell us? (optional)': 'வேறு ஏதேனும் சொல்ல விரும்புகிறீர்களா? (விருப்பம்)',
  'Delete my account': 'என் கணக்கை நீக்கு',
  'Deactivate my account': 'என் கணக்கை முடக்கு',
  'Your account is deactivated': 'உங்கள் கணக்கு முடக்கப்பட்டுள்ளது',
  'Your profile is hidden from other members. Reactivate it to be visible again.': 'உங்கள் சுயவிவரம் மற்றவர்களுக்குத் தெரியாது. மீண்டும் தெரிய செயல்படுத்துங்கள்.',
  'Reactivate my profile': 'என் சுயவிவரத்தை மீண்டும் செயல்படுத்து',
  'Something went wrong. Please try again.': 'ஏதோ தவறு நடந்தது. மீண்டும் முயற்சிக்கவும்.',
  'Cancel': 'ரத்து செய்',
  'Delete': 'நீக்கு',
  'Withdraw interest': 'விருப்பத்தை திரும்பப் பெறு',
  'Withdraw this interest?': 'இந்த விருப்பத்தை திரும்பப் பெறவா?',
  'They will no longer see it. You can send it again later.': 'அவர்களுக்கு இது இனி தெரியாது. பின்னர் மீண்டும் அனுப்பலாம்.',
  'Withdraw': 'திரும்பப் பெறு',
  'Interest withdrawn': 'விருப்பம் திரும்பப் பெறப்பட்டது',
  'You will lose chat and contact access with this member. You can send an interest again later.': 'இந்த உறுப்பினருடனான உரையாடல் மற்றும் தொடர்பு அணுகலை இழப்பீர்கள். பின்னர் மீண்டும் விருப்பம் அனுப்பலாம்.',
  'Add a profile': 'சுயவிவரம் சேர்',
  'Managed profiles': 'நிர்வகிக்கும் சுயவிவரங்கள்',
  'Create and run profiles for other people': 'மற்றவர்களுக்கான சுயவிவரங்களை உருவாக்கி நிர்வகிக்கவும்',
  'Acting as {name}': '{name} ஆக செயல்படுகிறீர்கள்',
  'Exit': 'வெளியேறு',
  'Managed profile - full access': 'நிர்வகிக்கும் சுயவிவரம் - முழு அணுகல்',
  'Stop acting as this profile': 'இந்த சுயவிவரமாகச் செயல்படுவதை நிறுத்து',
  'No managed profiles yet. Tap "Add a profile" to create one.': 'இன்னும் நிர்வகிக்கும் சுயவிவரங்கள் இல்லை. உருவாக்க "சுயவிவரம் சேர்" அழுத்தவும்.',
  'Delete this profile?': 'இந்த சுயவிவரத்தை நீக்கவா?',
  'The profile and its photos will be removed. This cannot be undone.': 'சுயவிவரமும் புகைப்படங்களும் நீக்கப்படும். மீட்க முடியாது.',
  'Open': 'திற',
  'This profile no longer exists.': 'இந்த சுயவிவரம் இனி இல்லை.',
  'Ariyalur': 'அரியலூர்',
  'Chengalpattu': 'செங்கல்பட்டு',
  'Dharmapuri': 'தருமபுரி',
  'Kallakurichi': 'கள்ளக்குறிச்சி',
  'Krishnagiri': 'கிருஷ்ணகிரி',
  'Mayiladuthurai': 'மயிலாடுதுறை',
  'Nilgiris': 'நீலகிரி',
  'Perambalur': 'பெரம்பலூர்',
  'Pudukkottai': 'புதுக்கோட்டை',
  'Ranipet': 'ராணிப்பேட்டை',
  'Tenkasi': 'தென்காசி',
  'Theni': 'தேனி',
  'Tirupathur': 'திருப்பத்தூர்',
  'Tiruvallur': 'திருவள்ளூர்',
  'Tiruvannamalai': 'திருவண்ணாமலை',
  'Tiruvarur': 'திருவாரூர்',
  'Viluppuram': 'விழுப்புரம்',
};
