import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'main.dart'; // Import für themeNotifier
import 'ui_components.dart';
import 'backup_service.dart';

class UserProfileScreen extends StatefulWidget {
  final PocketBase pb;
  const UserProfileScreen({super.key, required this.pb});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _useBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useBiometrics = prefs.getBool('useBiometrics') ?? false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useBiometrics', value);
    setState(() => _useBiometrics = value);
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _logout() {
    widget.pb.authStore.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen(pb: widget.pb)),
      (route) => false,
    );
  }

  Future<void> _updateTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwörter stimmen nicht überein')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = widget.pb.authStore.record!.id;
      await widget.pb.collection('users').update(
        userId,
        body: {
          'oldPassword': _oldPasswordController.text,
          'password': _newPasswordController.text,
          'passwordConfirm': _confirmPasswordController.text,
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort erfolgreich geändert!')),
        );
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showThemeBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Erscheinungsbild wählen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, currentMode, _) {
                  return Column(
                    children: [
                      _buildThemeOption(Icons.brightness_auto, 'Systemstandard', ThemeMode.system, currentMode),
                      _buildThemeOption(Icons.light_mode_outlined, 'Hell', ThemeMode.light, currentMode),
                      _buildThemeOption(Icons.dark_mode_outlined, 'Dunkel', ThemeMode.dark, currentMode),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Passwort ändern'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPasswordField(_oldPasswordController, 'Aktuelles Passwort'),
                const SizedBox(height: 16),
                _buildPasswordField(_newPasswordController, 'Neues Passwort'),
                const SizedBox(height: 16),
                _buildPasswordField(_confirmPasswordController, 'Neues Passwort bestätigen'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setDialogState(() => _isLoading = true);
                      await _changePassword();
                      setDialogState(() => _isLoading = false);
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    },
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Backup & Datensicherheit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Backup erstellen'),
                subtitle: const Text('Daten & Bilder als ZIP exportieren und sichern'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  AppBackupService.exportBackup(widget.pb, context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Backup einspielen'),
                subtitle: const Text('Daten aus einer ZIP-Backup-Datei wiederherstellen'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  AppBackupService.importBackup(widget.pb, context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.pb.authStore.record;
    final email = user?.getStringValue('email') ?? 'Benutzer';
    final isAdmin = user?.getBoolValue('admin') ?? false;

    return InventoryPageLayout(
      title: 'Profil & Sicherheit',
      subtitle: 'Dein Konto & Einstellungen',
      slivers: [
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(20),
                        child: Icon(Icons.person, size: 30, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Angemeldet als', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(email, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                const Text('Einstellungen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    children: [
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeNotifier,
                        builder: (context, mode, _) {
                          String themeStr = 'Systemstandard';
                          if (mode == ThemeMode.light) themeStr = 'Hell';
                          if (mode == ThemeMode.dark) themeStr = 'Dunkel';
                          return ListTile(
                            leading: const Icon(Icons.palette_outlined),
                            title: const Text('Erscheinungsbild'),
                            subtitle: Text('Aktuell: $themeStr'),
                            trailing: const Icon(Icons.chevron_right),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            onTap: _showThemeBottomSheet,
                          );
                        },
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Biometrischer Login'),
                        subtitle: const Text('App-Start schützen'),
                        value: _useBiometrics,
                        onChanged: _toggleBiometrics,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Passwort ändern'),
                        subtitle: const Text('Sicherheitsschlüssel aktualisieren'),
                        trailing: const Icon(Icons.chevron_right),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        onTap: _showChangePasswordDialog,
                      ),
                      if (isAdmin)
                        ListTile(
                          leading: const Icon(Icons.cloud_sync_outlined),
                          title: const Text('Backup & Datensicherheit'),
                          subtitle: const Text('Daten exportieren oder einspielen'),
                          trailing: const Icon(Icons.chevron_right),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          onTap: _showBackupBottomSheet,
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Abmelden'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(IconData icon, String label, ThemeMode mode, ThemeMode currentMode) {
    final isSelected = currentMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onTap: () {
        Navigator.pop(context);
        _updateTheme(mode);
      },
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}
