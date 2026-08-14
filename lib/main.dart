import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'room_list_screen.dart';
import 'login_screen.dart';

// Globaler Notifier für das Theme
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

/// Ein einfacher Store, der die PocketBase-Anmeldung dauerhaft auf dem Handy speichert
class SharedPreferencesAuthStore extends AuthStore {
  final SharedPreferences prefs;
  SharedPreferencesAuthStore(this.prefs);

  @override
  void save(String newToken, dynamic newRecord) {
    super.save(newToken, newRecord);
    prefs.setString('pb_auth', jsonEncode({
      'token': newToken,
      'model': newRecord,
    }));
  }

  @override
  void clear() {
    super.clear();
    prefs.remove('pb_auth');
  }

  static SharedPreferencesAuthStore load(SharedPreferences prefs) {
    final store = SharedPreferencesAuthStore(prefs);
    final raw = prefs.getString('pb_auth');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        // Da 'model' ein RecordModel sein muss, mappen wir es hier
        // In der neuesten Version reicht oft das token, PocketBase validiert den Rest
        store.save(decoded['token'], decoded['model']);
      } catch (e) {
        debugPrint('Fehler beim Laden des Auth-Stores: $e');
      }
    }
    return store;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  // Theme laden
  final themeIndex = prefs.getInt('themeMode') ?? 0;
  themeNotifier.value = ThemeMode.values[themeIndex];

  // Auth Store laden
  final authStore = SharedPreferencesAuthStore.load(prefs);

  runApp(HomeInventoryApp(prefs: prefs, authStore: authStore));
}

class HomeInventoryApp extends StatelessWidget {
  final SharedPreferences prefs;
  final AuthStore authStore;
  
  const HomeInventoryApp({super.key, required this.prefs, required this.authStore});

  @override
  Widget build(BuildContext context) {
    const String pcIp = '192.168.178.54';
    
    String baseUrl = 'http://127.0.0.1:8090';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      baseUrl = 'http://$pcIp:8090';
    }

    final pb = PocketBase(baseUrl, authStore: authStore);
    
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Heiminventarisierung',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5), surface: const Color(0xFFF8F9FE)),
            scaffoldBackgroundColor: const Color(0xFFF8F9FE),
            textTheme: GoogleFonts.outfitTextTheme(),
            cardTheme: CardThemeData(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
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
            ),
            scaffoldBackgroundColor: const Color(0xFF1A1C1E),
            drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF1A1C1E), surfaceTintColor: Colors.transparent),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
              titleLarge: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              bodyMedium: const TextStyle(color: Colors.white70),
            ),
            cardTheme: CardThemeData(elevation: 0, color: const Color(0xFF2D2F36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
            floatingActionButtonTheme: FloatingActionButtonThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    final bool isLoggedIn = widget.pb.authStore.isValid;

    if (!isLoggedIn) {
      _goToLogin();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final bool useBiometrics = prefs.getBool('useBiometrics') ?? false;

    if (useBiometrics && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Bitte authentifiziere dich, um dein Inventar zu öffnen',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );

        if (didAuthenticate && mounted) {
          _navigateToHome();
          return;
        } else {
          // Falls abgebrochen wurde, bieten wir Login oder erneuten Versuch an
          // Für jetzt bleiben wir auf dem Ladebildschirm oder erzwingen Login
        }
      } catch (e) {
        debugPrint('Biometrie-Fehler: $e');
      }
    }

    if (mounted) _navigateToHome();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoginScreen(pb: widget.pb)));
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => RoomListScreen(pb: widget.pb)));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
