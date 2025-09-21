// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _locationTrackingEnabled = true;
  String _selectedLanguage = 'English';
  String _selectedTheme = 'System';
  
  final List<String> _languages = ['English', 'Arabic', 'French', 'Spanish'];
  final List<String> _themes = ['Light', 'Dark', 'System'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _locationTrackingEnabled = prefs.getBool('location_tracking_enabled') ?? true;
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
      _selectedTheme = prefs.getString('selected_theme') ?? 'System';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settings saved'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings,
                      size: 40,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'App Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customize your app experience',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Notifications Section
            _buildSettingsSection(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              children: [
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive attendance reminders and updates',
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSetting('notifications_enabled', value);
                  },
                ),
                _buildSwitchTile(
                  title: 'Sound',
                  subtitle: 'Play sound for notifications',
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                    _saveSetting('sound_enabled', value);
                  },
                ),
                _buildSwitchTile(
                  title: 'Vibration',
                  subtitle: 'Vibrate for notifications',
                  value: _vibrationEnabled,
                  onChanged: (value) {
                    setState(() => _vibrationEnabled = value);
                    _saveSetting('vibration_enabled', value);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Privacy & Security Section
            _buildSettingsSection(
              title: 'Privacy & Security',
              icon: Icons.privacy_tip_outlined,
              children: [
                _buildSwitchTile(
                  title: 'Location Tracking',
                  subtitle: 'Allow app to track location for attendance',
                  value: _locationTrackingEnabled,
                  onChanged: (value) {
                    setState(() => _locationTrackingEnabled = value);
                    _saveSetting('location_tracking_enabled', value);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Appearance Section
            _buildSettingsSection(
              title: 'Appearance',
              icon: Icons.palette_outlined,
              children: [
                _buildDropdownTile(
                  title: 'Language',
                  subtitle: 'Choose your preferred language',
                  value: _selectedLanguage,
                  items: _languages,
                  onChanged: (value) {
                    setState(() => _selectedLanguage = value!);
                    _saveSetting('selected_language', value);
                  },
                ),
                _buildDropdownTile(
                  title: 'Theme',
                  subtitle: 'Choose app theme',
                  value: _selectedTheme,
                  items: _themes,
                  onChanged: (value) {
                    setState(() => _selectedTheme = value!);
                    _saveSetting('selected_theme', value);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Data & Storage Section
            _buildSettingsSection(
              title: 'Data & Storage',
              icon: Icons.storage_outlined,
              children: [
                _buildActionTile(
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  icon: Icons.cleaning_services_outlined,
                  onTap: () => _showClearCacheDialog(),
                ),
                _buildActionTile(
                  title: 'Export Data',
                  subtitle: 'Export your attendance data',
                  icon: Icons.file_download_outlined,
                  onTap: () => _showExportDataDialog(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            underline: const SizedBox(),
            dropdownColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showExportDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Your attendance data will be exported as a CSV file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data export started'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }
}
