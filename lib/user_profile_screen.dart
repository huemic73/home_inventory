import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'main.dart'; // Import für themeNotifier

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

  @override
  Widget build(BuildContext context) {
    final user = widget.pb.authStore.record;
    final email = user?.getStringValue('email') ?? 'Benutzer';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profil & Sicherheit', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
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
            const Text('Erscheinungsbild', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(32),
              ),
              child: ValueListenableBuilder<ThemeMode>(
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
            ),

            const SizedBox(height: 32),
            const Text('Passwort ändern', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                children: [
                  _buildPasswordField(_oldPasswordController, 'Aktuelles Passwort'),
                  const SizedBox(height: 16),
                  _buildPasswordField(_newPasswordController, 'Neues Passwort'),
                  const SizedBox(height: 16),
                  _buildPasswordField(_confirmPasswordController, 'Neues Passwort bestätigen'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Passwort aktualisieren'),
                    ),
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
    );
  }

  Widget _buildThemeOption(IconData icon, String label, ThemeMode mode, ThemeMode currentMode) {
    final isSelected = currentMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onTap: () => _updateTheme(mode),
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
