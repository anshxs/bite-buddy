import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/database_service.dart';
import 'edit_user_profile_screen.dart';
import 'history_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _dbService.getUserProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditUserProfileScreen()),
    );
    
    // Refresh profile data if changes were made
    if (result == true) {
      _loadUserProfile();
    }
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HistoryScreen()),
    );
  }

  void _navigateToOnboarding() {
    Navigator.pushReplacementNamed(context, '/onboarding');
  }

  Future<void> _clearAllData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Data'),
        content: Text(
          'This will delete all your food logs, progress history, and profile data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _dbService.clearAllData();
              
              // Clear SharedPreferences too
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All data cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              
              // Navigate back to onboarding
              Navigator.pushReplacementNamed(context, '/onboarding');
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 234, 234, 234),
      appBar: AppBar(
        
        title: Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 235, 235, 235),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(),
                  SizedBox(height: 16),
                  Text('Loading settings...'),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.all(16.0),
              children: [
                // User Profile Card
                if (_userProfile != null) _buildUserProfileCard(),
                
                SizedBox(height: 16),

                // Profile Settings Section
                _buildSectionTitle('Profile'),
                _buildSettingsCard([
                  _buildSettingsTile(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information and goals',
                    onTap: _navigateToEditProfile,
                  ),
                  _buildSettingsTile(
                    icon: Icons.history,
                    title: 'Progress History',
                    subtitle: 'View your nutrition and progress history',
                    onTap: _navigateToHistory,
                  ),
                ]),

                SizedBox(height: 16),

                // App Settings Section
                _buildSectionTitle('App Settings'),
                _buildSettingsCard([
                  _buildSettingsTile(
                    icon: Icons.refresh,
                    title: 'Reset Onboarding',
                    subtitle: 'Go through the setup process again',
                    onTap: _navigateToOnboarding,
                  ),
                ]),

                SizedBox(height: 16),

                // Data Management Section
                _buildSectionTitle('Data Management'),
                _buildSettingsCard([
                  _buildSettingsTile(
                    icon: Icons.delete_outline,
                    title: 'Clear All Data',
                    subtitle: 'Delete all your data and start fresh',
                    onTap: _clearAllData,
                    isDestructive: true,
                  ),
                ]),

                SizedBox(height: 24),

                // App Info
                Card(
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          CupertinoIcons.info,
                          size: 32,
                          color: Colors.grey[600],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'BiteBuddy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'AI-Powered Nutrition Tracker',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUserProfileCard() {
    final weight = (_userProfile!['weight'] as num?)?.toDouble() ?? 0.0;
    final height = (_userProfile!['height'] as num?)?.toDouble() ?? 0.0;
    final dailyCalories = (_userProfile!['daily_calories'] as num?)?.toInt() ?? 0;
    final goal = _userProfile!['goal'] as String? ?? 'Not set';
    
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: Icon(
                    Icons.person,
                    size: 32,
                    color: Colors.blue[700],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      //SizedBox(height: 4),
                      Text(
                        'Goal: $goal',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildProfileStat('Weight', '${weight.toInt()} kg'),
                ),
                Expanded(
                  child: _buildProfileStat('Height', '${height.toInt()} cm'),
                ),
                Expanded(
                  child: _buildProfileStat('Daily Goal', '$dailyCalories kcal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 0, 127, 246),
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 8, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color.fromARGB(255, 83, 83, 83),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red[50] 
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive 
              ? Colors.red[700] 
              : Colors.grey[700],
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isDestructive ? Colors.red[700] : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }
}