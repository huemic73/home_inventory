import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'web_download_helper.dart'
    if (dart.library.html) 'web_download_helper_web.dart';

class AppBackupService {
  static Future<void> exportBackup(PocketBase pb, BuildContext context) async {
    final progressNotifier = ValueNotifier<String>('Daten werden geladen...');
    
    // Lade-Dialog anzeigen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Backup erstellen'),
        content: ValueListenableBuilder<String>(
          valueListenable: progressNotifier,
          builder: (context, val, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(val, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Daten aus PocketBase laden
      progressNotifier.value = 'Tags werden geladen...';
      final tags = await pb.collection('tags').getFullList();
      
      progressNotifier.value = 'Bereiche & Container werden geladen...';
      final nodes = await pb.collection('nodes').getFullList();
      
      progressNotifier.value = 'Gegenstände werden geladen...';
      final items = await pb.collection('items').getFullList();

      // 2. JSON-Datenstruktur aufbauen
      final Map<String, dynamic> backupData = {
        'version': 1.0,
        'exportedAt': DateTime.now().toIso8601String(),
        'tags': tags.map((t) => {
          'id': t.id,
          'name': t.getStringValue('name'),
          'color': t.getStringValue('color'),
        }).toList(),
        'nodes': nodes.map((n) => {
          'id': n.id,
          'name': n.getStringValue('name'),
          'type': n.getStringValue('type'),
          'parent': n.getStringValue('parent'),
          'icon': n.getStringValue('icon'),
          'photo': n.getStringValue('photo'),
          'description': n.getStringValue('description'),
          'tags': n.getListValue<String>('tags'),
          'labelId': n.getStringValue('labelId'),
        }).toList(),
        'items': items.map((i) => {
          'id': i.id,
          'name': i.getStringValue('name'),
          'description': i.getStringValue('description'),
          'quantity': i.getIntValue('quantity'),
          'node': i.getStringValue('node'),
          'tags': i.getListValue<String>('tags'),
          'photo': i.getStringValue('photo'),
        }).toList(),
      };

      final archive = Archive();

      // JSON in das Archiv schreiben
      final jsonString = jsonEncode(backupData);
      final jsonBytes = utf8.encode(jsonString);
      archive.addFile(ArchiveFile('backup_data.json', jsonBytes.length, jsonBytes));

      // 3. Bilder herunterladen und ins Archiv packen
      int currentImage = 0;
      final totalImages = nodes.where((n) => n.getStringValue('photo').isNotEmpty).length +
          items.where((i) => i.getStringValue('photo').isNotEmpty).length;

      // Nodes Fotos
      for (var node in nodes) {
        final photoName = node.getStringValue('photo');
        if (photoName.isNotEmpty) {
          currentImage++;
          progressNotifier.value = 'Foto $currentImage von $totalImages wird heruntergeladen...';
          
          try {
            final imageUrl = pb.files.getUrl(node, photoName).toString();
            final response = await http.get(Uri.parse(imageUrl));
            if (response.statusCode == 200) {
              archive.addFile(ArchiveFile(
                'photos/nodes_photo_${node.id}.jpg',
                response.bodyBytes.length,
                response.bodyBytes,
              ));
            }
          } catch (e) {
            debugPrint('Fehler beim Download von Node-Foto (${node.id}): $e');
          }
        }
      }

      // Items Fotos
      for (var item in items) {
        final photoName = item.getStringValue('photo');
        if (photoName.isNotEmpty) {
          currentImage++;
          progressNotifier.value = 'Foto $currentImage von $totalImages wird heruntergeladen...';
          
          try {
            final imageUrl = pb.files.getUrl(item, photoName).toString();
            final response = await http.get(Uri.parse(imageUrl));
            if (response.statusCode == 200) {
              archive.addFile(ArchiveFile(
                'photos/items_photo_${item.id}.jpg',
                response.bodyBytes.length,
                response.bodyBytes,
              ));
            }
          } catch (e) {
            debugPrint('Fehler beim Download von Item-Foto (${item.id}): $e');
          }
        }
      }

      // 4. ZIP erstellen und speichern
      progressNotifier.value = 'Backup-Datei wird komprimiert...';
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      final dateStr = DateTime.now().toIso8601String().split('T')[0];

      if (kIsWeb) {
        if (context.mounted) Navigator.pop(context);
        saveFileWeb(zipBytes, 'heiminventar_backup_$dateStr.zip');
      } else {
        final tempDir = await getTemporaryDirectory();
        final backupFile = File('${tempDir.path}/heiminventar_backup_$dateStr.zip');
        await backupFile.writeAsBytes(zipBytes);

        // Dialog schließen
        if (context.mounted) Navigator.pop(context);

        // 5. Teilen Dialog öffnen
        await Share.shareXFiles(
          [XFile(backupFile.path)],
          subject: 'Heiminventar Backup vom $dateStr',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dialog schließen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Backup-Export: $e')),
        );
      }
    }
  }

  static Future<void> importBackup(PocketBase pb, BuildContext context) async {
    // 1. Datei auswählen
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    
    if (result == null || result.files.single.path == null) {
      return; // Nutzer hat abgebrochen
    }

    if (!context.mounted) return;

    // Bestätigung einfordern
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daten überschreiben?'),
        content: const Text(
          'Achtung: Dies löscht alle aktuellen Räume, Container, Gegenstände und Tags in der App und ersetzt sie durch die Daten aus dem Backup.\n\nMöchtest du fortfahren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Jetzt überschreiben'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!context.mounted) return;

    final progressNotifier = ValueNotifier<String>('Backup wird entpackt...');
    
    // Lade-Dialog anzeigen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Backup einspielen'),
        content: ValueListenableBuilder<String>(
          valueListenable: progressNotifier,
          builder: (context, val, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(val, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );

    try {
      // 2. ZIP entpacken
      final List<int> bytes;
      if (kIsWeb) {
        bytes = result.files.single.bytes!;
      } else {
        final file = File(result.files.single.path!);
        bytes = await file.readAsBytes();
      }
      final archive = ZipDecoder().decodeBytes(bytes);

      // Finde die JSON-Datei
      final jsonFile = archive.firstWhere(
        (f) => f.name == 'backup_data.json',
        orElse: () => throw Exception('backup_data.json nicht im Archiv gefunden.'),
      );

      final jsonContent = utf8.decode(jsonFile.content as List<int>);
      final Map<String, dynamic> backupData = jsonDecode(jsonContent);

      // 3. Bestehende Daten löschen
      progressNotifier.value = 'Aktuelle Gegenstände werden gelöscht...';
      final existingItems = await pb.collection('items').getFullList();
      for (var item in existingItems) {
        await pb.collection('items').delete(item.id);
      }

      progressNotifier.value = 'Aktuelle Bereiche & Container werden gelöscht...';
      final existingNodes = await pb.collection('nodes').getFullList();
      for (var node in existingNodes) {
        await pb.collection('nodes').delete(node.id);
      }

      progressNotifier.value = 'Aktuelle Tags werden gelöscht...';
      final existingTags = await pb.collection('tags').getFullList();
      for (var tag in existingTags) {
        await pb.collection('tags').delete(tag.id);
      }

      // Finde alle Fotos im Archiv
      final Map<String, ArchiveFile> photoFiles = {};
      for (var f in archive) {
        if (f.name.startsWith('photos/')) {
          photoFiles[f.name] = f;
        }
      }

      // 4. Daten importieren
      // A. Tags erstellen
      final List<dynamic> backupTags = backupData['tags'] ?? [];
      for (var i = 0; i < backupTags.length; i++) {
        final tag = backupTags[i];
        progressNotifier.value = 'Tag ${i + 1} von ${backupTags.length} wird importiert...';
        await pb.collection('tags').create(body: {
          'id': tag['id'],
          'name': tag['name'],
          'color': tag['color'],
        });
      }

      // B. Nodes erstellen
      final List<dynamic> backupNodes = backupData['nodes'] ?? [];
      for (var i = 0; i < backupNodes.length; i++) {
        final node = backupNodes[i];
        progressNotifier.value = 'Bereich ${i + 1} von ${backupNodes.length} wird importiert...';
        
        final nodeId = node['id'];
        final Map<String, dynamic> body = {
          'id': nodeId,
          'name': node['name'],
          'type': node['type'],
          'parent': node['parent']?.isEmpty == true ? null : node['parent'],
          'icon': node['icon'],
          'description': node['description'] ?? '',
          'tags': node['tags'] ?? [],
          'labelId': node['labelId'] ?? '',
        };

        // Prüfen, ob ein Foto im Backup existiert
        final photoPath = 'photos/nodes_photo_$nodeId.jpg';
        final photoFile = photoFiles[photoPath];

        if (photoFile != null) {
          final fileBytes = photoFile.content as List<int>;
          final multipartFile = http.MultipartFile.fromBytes(
            'photo',
            fileBytes,
            filename: 'photo.jpg',
          );
          await pb.collection('nodes').create(body: body, files: [multipartFile]);
        } else {
          await pb.collection('nodes').create(body: body);
        }
      }

      // C. Items erstellen
      final List<dynamic> backupItems = backupData['items'] ?? [];
      for (var i = 0; i < backupItems.length; i++) {
        final item = backupItems[i];
        progressNotifier.value = 'Gegenstand ${i + 1} von ${backupItems.length} wird importiert...';
        
        final itemId = item['id'];
        final Map<String, dynamic> body = {
          'id': itemId,
          'name': item['name'],
          'description': item['description'] ?? '',
          'quantity': item['quantity'] ?? 1,
          'node': item['node']?.isEmpty == true ? null : item['node'],
          'tags': item['tags'] ?? [],
        };

        // Prüfen, ob ein Foto im Backup existiert
        final photoPath = 'photos/items_photo_$itemId.jpg';
        final photoFile = photoFiles[photoPath];

        if (photoFile != null) {
          final fileBytes = photoFile.content as List<int>;
          final multipartFile = http.MultipartFile.fromBytes(
            'photo',
            fileBytes,
            filename: 'photo.jpg',
          );
          await pb.collection('items').create(body: body, files: [multipartFile]);
        } else {
          await pb.collection('items').create(body: body);
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // Lade-Dialog schließen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup erfolgreich wiederhergestellt!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Lade-Dialog schließen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Einspielen des Backups: $e')),
        );
      }
    }
  }
}
