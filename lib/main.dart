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
    
    // PocketBase RecordModel has a toJson() method.
    final modelData = newRecord is RecordModel ? newRecord.toJson() : newRecord;
    
    prefs.setString('pb_auth', jsonEncode({
      'token': newToken,
      'model': modelData,
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
        final token = decoded['token'] as String;
        final modelData = decoded['model'];
        
        RecordModel? model;
        if (modelData != null && modelData is Map<String, dynamic>) {
          try {
            model = RecordModel.fromJson(modelData);
          } catch (e) {
            debugPrint('RecordModel.fromJson fehlgeschlagen: $e');
            // Fallback: model bleibt null, Token reicht oft für isValid
          }
        }

        store.handleInitialLoad(token, model);
      } catch (e) {
        debugPrint('Fehler beim Laden des Auth-Stores: $raw - Error: $e');
      }
    }
    return store;
  }

  // Hilfsmethode, um den internen Status zu setzen, ohne erneut in Prefs zu schreiben
  void handleInitialLoad(String newToken, dynamic newRecord) {
    super.save(newToken, newRecord);
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
  bool _authFailed = false;

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
      setState(() {
        _authFailed = false;
      });
      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Bitte authentifiziere dich, um dein Inventar zu öffnen',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );

        if (didAuthenticate && mounted) {
          _navigateToHome();
          return;
        } else {
          setState(() {
            _authFailed = true;
          });
          return;
        }
      } catch (e) {
        debugPrint('Biometrie-Fehler: $e');
        setState(() {
          _authFailed = true;
        });
        return;
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
    if (_authFailed) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.indigo.shade900 : Colors.indigo.shade50).withAlpha(128),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: isDark ? Colors.indigo.shade200 : Colors.indigo,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'App gesperrt',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bitte authentifiziere dich, um fortzufahren.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checkAuth,
                    icon: const Icon(Icons.fingerprint, size: 28),
                    label: const Text('Entsperren', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _goToLogin,
                  child: Text(
                    'Mit anderem Konto anmelden',
                    style: TextStyle(color: isDark ? Colors.indigo.shade200 : Colors.indigo),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Colors.indigo),
      ),
    );
  }
}
