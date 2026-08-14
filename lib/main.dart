import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'room_list_screen.dart';
import 'login_screen.dart';

// Globaler Notifier für das Theme
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Gespeichertes Theme laden
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('themeMode') ?? 0; // 0 = system, 1 = light, 2 = dark
  themeNotifier.value = ThemeMode.values[themeIndex];

  runApp(const HomeInventoryApp());
}

class HomeInventoryApp extends StatelessWidget {
  const HomeInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    const String pcIp = '192.168.178.54';
    
    String baseUrl = 'http://127.0.0.1:8090';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      baseUrl = 'http://$pcIp:8090';
    }

    final pb = PocketBase(baseUrl);
    final bool isLoggedIn = pb.authStore.isValid;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Heiminventarisierung',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // Helles Theme
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3F51B5),
              surface: const Color(0xFFF8F9FE),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8F9FE),
            textTheme: GoogleFonts.outfitTextTheme(),
            cardTheme: CardThemeData(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
          ),
          // Dunkles Theme
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3F51B5),
              brightness: Brightness.dark,
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xFF1E1E26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
          ),
          home: isLoggedIn ? RoomListScreen(pb: pb) : LoginScreen(pb: pb),
        );
      },
    );
  }
}
