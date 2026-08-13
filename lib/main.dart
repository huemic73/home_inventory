import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:google_fonts/google_fonts.dart'; // Import hinzugefügt
import 'room_list_screen.dart';

void main() {
  runApp(const HomeInventoryApp());
}

class HomeInventoryApp extends StatelessWidget {
  const HomeInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Ersetze diese IP mit der echten IPv4-Adresse deines PCs (aus ipconfig)
    // 10.0.2.2 ist nur für den Emulator!
    const String pcIp = '192.168.178.77'; // Hier die PC-IP eintragen (z.B. .20)
    
    String baseUrl = 'http://127.0.0.1:8090';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Wenn echtes Handy genutzt wird -> PC IP, sonst Emulator IP
      baseUrl = 'http://$pcIp:8090';
    }

    final pb = PocketBase(baseUrl);

    return MaterialApp(
      title: 'Heiminventarisierung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5), // Indigo-Blau
          surface: const Color(0xFFF8F9FE),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        // Moderne Schriftart 'Outfit' für die gesamte App
        textTheme: GoogleFonts.outfitTextTheme(
          const TextTheme(
            headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E)),
            titleLarge: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF3F51B5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: RoomListScreen(pb: pb),
    );
  }
}
