import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _enableNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Dark Mode Toggle
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark themes'),
            value: _isDarkMode,
            onChanged: (bool value) {
              setState(() {
                _isDarkMode = value;
                // TODO: Implement theme switching logic
              });
            },
            secondary: const Icon(Icons.dark_mode),
          ),

          const Divider(),

          // Notifications Toggle
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive updates and alerts'),
            value: _enableNotifications,
            onChanged: (bool value) {
              setState(() {
                _enableNotifications = value;
                // TODO: Implement notification settings
              });
            },
            secondary: const Icon(Icons.notifications),
          ),

          const Divider(),

          // About Section
          ListTile(
            title: const Text('About'),
            subtitle: const Text('Sugar Cane Classifier App'),
            leading: const Icon(Icons.info_outline),
            onTap: () {
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About Sugar Cane Classifier'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Version: 1.0.0'),
                SizedBox(height: 8),
                Text('Developed to help farmers and researchers identify sugar cane varieties quickly and accurately.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}