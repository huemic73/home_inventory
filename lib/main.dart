import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
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
      title: 'Home Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // Die App startet nun mit der Raum-Übersicht
      home: RoomListScreen(pb: pb),
    );
  }
}
