import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'room_list_screen.dart';
import 'login_screen.dart';

// Globaler Notifier für das Theme
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Gespeichertes Theme laden
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('themeMode') ?? 0;
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
    
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Heiminventarisierung',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
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
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3F51B5),
              brightness: Brightness.dark,
              surface: const Color(0xFF1A1C1E),
              onSurface: Colors.white,
              primary: const Color(0xFF9FA8DA),
              onPrimary: const Color(0xFF1A1C1E),
              primaryContainer: const Color(0xFF3F51B5).withAlpha(100),
              onPrimaryContainer: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF1A1C1E),
            drawerTheme: const DrawerThemeData(
              backgroundColor: Color(0xFF1A1C1E),
              surfaceTintColor: Colors.transparent,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
              titleLarge: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              bodyMedium: const TextStyle(color: Colors.white70),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xFF2D2F36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          home: AuthCheck(pb: pb),
        );
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  final PocketBase pb;
  const AuthCheck({super.key, required this.pb});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final bool isLoggedIn = widget.pb.authStore.isValid;

    if (!isLoggedIn) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen(pb: widget.pb)),
        );
      }
      return;
    }

    // Gespeichertes Setting prüfen
    final prefs = await SharedPreferences.getInstance();
    final bool useBiometrics = prefs.getBool('useBiometrics') ?? false;

    if (useBiometrics && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
        final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

        if (canAuthenticate) {
          final bool didAuthenticate = await auth.authenticate(
            localizedReason: 'Bitte authentifiziere dich, um dein Inventar zu öffnen',
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: false, // Erlaubt auch PIN/Muster als Fallback
            ),
          );

          if (didAuthenticate && mounted) {
            _navigateToHome();
            return;
          }
        }
      } catch (e) {
        debugPrint('Biometrie-Fehler: $e');
      }
    }

    // Falls Web oder Biometrie fehlschlägt/nicht verfügbar, aber PB-Token valide ist
    if (mounted) _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => RoomListScreen(pb: widget.pb)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
