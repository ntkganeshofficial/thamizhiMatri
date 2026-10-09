import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'core/constants.dart';
import 'core/l10n.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'services/translation_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final options = DefaultFirebaseOptions.currentPlatform;
  final configured = !options.apiKey.startsWith('YOUR_');
  if (configured) {
    await Firebase.initializeApp(options: options);
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ThamizhiApp(
      firebaseConfigured: configured,
      language: LanguageController(prefs),
    ),
  );
}

class ThamizhiApp extends StatelessWidget {
  final bool firebaseConfigured;
  final LanguageController language;
  const ThamizhiApp({
    super.key,
    required this.firebaseConfigured,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    // Providers must sit above MaterialApp so pushed routes can read them.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: language),
        ChangeNotifierProvider(create: (_) => TranslationController(language)),
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => ProfileService()),
      ],
      child: Consumer<LanguageController>(
        builder: (context, lang, _) => MaterialApp(
          title: AppStrings.nameEnglish,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: lang.locale,
          supportedLocales: const [Locale('en'), Locale('ta')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: firebaseConfigured
              ? const AuthGate()
              : const _FirebaseSetupScreen(),
        ),
      ),
    );
  }
}

class _FirebaseSetupScreen extends StatelessWidget {
  const _FirebaseSetupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SelectableText(
            'Firebase is not configured yet.\n\n'
            '1. dart pub global activate flutterfire_cli\n'
            '2. flutterfire configure\n\n'
            'This replaces lib/firebase_options.dart with your Firebase project settings.',
          ),
        ),
      ),
    );
  }
}
