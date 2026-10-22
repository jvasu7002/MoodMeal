import 'package:flutter/material.dart';
import 'package:moodmeal/auth/auth_wrapper.dart';
import 'package:moodmeal/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =====================================================
  // FIREBASE
  // =====================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // =====================================================
  // LOAD SAVED THEME
  // =====================================================

  final prefs = await SharedPreferences.getInstance();

  final bool isDark =
      prefs.getBool("darkMode") ?? false;

  themeNotifier.value =
      isDark ? ThemeMode.dark : ThemeMode.light;

  // =====================================================
  // RUN APP
  // =====================================================

  runApp(const MoodMealApp());
}


// =====================================================
// MOODMEAL APP
// =====================================================

class MoodMealApp extends StatelessWidget {
  const MoodMealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (
        context,
        ThemeMode currentMode,
        child,
      ) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          title: "MoodMeal",

          // =================================================
          // THEME MODE
          // =================================================

          themeMode: currentMode,

          // =================================================
          // LIGHT THEME
          // =================================================

          theme: ThemeData(
            brightness: Brightness.light,
            colorSchemeSeed: Colors.orange,
            useMaterial3: true,
          ),

          // =================================================
          // DARK THEME
          // =================================================

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.orange,
            useMaterial3: true,
          ),

          // =================================================
          // ROUTES
          // =================================================

          routes: {
            "/ask-moodmeal": (context) =>
                const AskMoodMealScreen(),
          },

          // =================================================
          // AUTHENTICATION
          // =================================================

          home: AuthWrapper(),
        );
      },
    );
  }
}