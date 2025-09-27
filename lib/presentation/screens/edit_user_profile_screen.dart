import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/preference_manager.dart';
import '../../data/models/user_data.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/database_service.dart';

class EditUserProfileScreen extends StatefulWidget {
  @override
  _EditUserProfileScreenState createState() => _EditUserProfileScreenState();
}

class _EditUserProfileScreenState extends State<EditUserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  
  // Form data
  String? gender;
  String? activityLevel;
  String? userGoal;
  
  bool _isLoading = true;
  bool _isSaving = false;

  // Activity level descriptions
  final Map<String, String> activityLevelDescriptions = {
    'Sedentary': 'Little or no exercise, desk job',
    'Light': '1-3 days/week of exercise',
    'Moderate': '3-5 days/week of moderate activity',
    'Active': '6-7 days/week of exercise',
    'Very Active': 'Very intense exercise/sports & physical job'
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = DatabaseService();
      
      // Try to load from database first
      final userProfile = await dbService.getUserProfile();
      if (userProfile != null) {
        _populateFromDatabase(userProfile);
      } else {
        // Fallback to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final prefManager = PreferenceManager(prefs);
        final userData = prefManager.getUserData();
        if (userData != null) {
          _populateFromSharedPrefs(userData);
        } else {
          // Set default values if no data found
          _setDefaultValues();
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      _showErrorSnackBar('Failed to load profile data');
      _setDefaultValues();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setDefaultValues() {
    setState(() {
      gender = gender ?? 'Male';
      activityLevel = activityLevel ?? 'Moderate';
      userGoal = userGoal ?? 'Maintenance';
    });
  }

  void _populateFromDatabase(Map<String, dynamic> profile) {
    setState(() {
      _weightController.text = (profile['weight'] as num?)?.toString() ?? '';
      _heightController.text = (profile['height'] as num?)?.toString() ?? '';
      _ageController.text = (profile['age'] as int?)?.toString() ?? '';
      gender = profile['gender'] as String?;
      activityLevel = profile['activity_level'] as String?;
      userGoal = profile['goal'] as String?;
    });
  }

  void _populateFromSharedPrefs(UserData userData) {
    setState(() {
      _weightController.text = userData.weight.toString();
      _heightController.text = userData.height.toString();
      _ageController.text = userData.age.toString();
      gender = userData.gender;
      activityLevel = userData.activityLevel;
      userGoal = userData.goal;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if all required fields are filled
    if (gender == null || activityLevel == null || userGoal == null) {
      _showErrorSnackBar('Please fill all required fields');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final weight = double.parse(_weightController.text);
      final height = double.parse(_heightController.text);
      final age = int.parse(_ageController.text);

      // Get updated calorie calculation from Gemini
      final geminiService = GeminiService();
      final optimalCalories = await geminiService.calculateOptimalCalories(
        weight: weight,
        height: height,
        age: age,
        gender: gender!,
        activityLevel: activityLevel!,
        goal: userGoal!,
      );

      // Get updated macro breakdown
      final macroBreakdown = await geminiService.getMacroBreakdown(
        calories: optimalCalories,
        goal: userGoal!,
      );

      // Save to database
      final dbService = DatabaseService();
      final userProfileData = {
        'weight': weight,
        'height': height,
        'age': age,
        'gender': gender!,
        'activity_level': activityLevel!,
        'goal': userGoal!,
        'daily_calories': optimalCalories,
        'protein_goal': macroBreakdown['protein'],
        'carbs_goal': macroBreakdown['carbs'],
        'fat_goal': macroBreakdown['fat'],
        'fiber_goal': macroBreakdown['fiber'] ?? 25,
        'sugar_limit': macroBreakdown['sugar'] ?? 50,
      };

      await dbService.saveUserProfile(userProfileData);

      // Also update SharedPreferences for backward compatibility
      final userData = UserData(
        weight: weight,
        height: height,
        age: age,
        activityLevel: activityLevel!,
        gender: gender!,
        goal: userGoal!,
        estimatedCalories: optimalCalories,
        proteinGoal: macroBreakdown['protein'].toDouble(),
        fatGoal: macroBreakdown['fat'].toDouble(),
        carbsGoal: macroBreakdown['carbs'].toDouble(),
      );

      final prefs = await SharedPreferences.getInstance();
      final prefManager = PreferenceManager(prefs);
      await prefManager.saveUserData(userData);

      // Show success message and navigate back
      _showSuccessSnackBar('Profile updated successfully!');
      await Future.delayed(Duration(seconds: 1));
      Navigator.pop(context, true); // Return true to indicate successful update

    } catch (e) {
      print('Error saving profile: $e');
      _showErrorSnackBar('Failed to save profile. Please try again.');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 16),
              Text('Loading your profile...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 32, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Update your details to get personalized recommendations',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Basic Information Section
              _buildSectionTitle('Basic Information'),
              SizedBox(height: 12),

              // Weight Field
              _buildTextField(
                controller: _weightController,
                label: 'Weight (kg)',
                icon: Icons.monitor_weight,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your weight';
                  }
                  final weight = double.tryParse(value);
                  if (weight == null || weight <= 0 || weight > 500) {
                    return 'Please enter a valid weight (1-500 kg)';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Height Field
              _buildTextField(
                controller: _heightController,
                label: 'Height (cm)',
                icon: Icons.height,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your height';
                  }
                  final height = double.tryParse(value);
                  if (height == null || height <= 0 || height > 300) {
                    return 'Please enter a valid height (1-300 cm)';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Age Field
              _buildTextField(
                controller: _ageController,
                label: 'Age (years)',
                icon: Icons.cake,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your age';
                  }
                  final age = int.tryParse(value);
                  if (age == null || age <= 0 || age > 120) {
                    return 'Please enter a valid age (1-120 years)';
                  }
                  return null;
                },
              ),

              SizedBox(height: 24),

              // Preferences Section
              _buildSectionTitle('Preferences'),
              SizedBox(height: 12),

              // Gender Dropdown
              _buildDropdownField(
                label: 'Gender',
                value: gender,
                icon: Icons.person_outline,
                onTap: _showGenderPicker,
              ),

              SizedBox(height: 16),

              // Activity Level Dropdown
              _buildDropdownField(
                label: 'Activity Level',
                value: activityLevel,
                subtitle: activityLevel != null 
                    ? activityLevelDescriptions[activityLevel!]
                    : null,
                icon: Icons.fitness_center,
                onTap: _showActivityLevelPicker,
              ),

              SizedBox(height: 16),

              // Goal Dropdown
              _buildDropdownField(
                label: 'Goal',
                value: userGoal,
                icon: Icons.track_changes,
                onTap: _showGoalPicker,
              ),

              SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Updating Profile...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value ?? 'Select $label',
                    style: TextStyle(
                      fontSize: 16,
                      color: value != null ? Colors.black : Colors.grey[500],
                      fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showGenderPicker() {
    final genderOptions = ['Male', 'Female', 'Other'];
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground,
          child: Column(
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Select Gender',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      child: Text('Done'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: CupertinoColors.systemBackground,
                  itemExtent: 50,
                  scrollController: FixedExtentScrollController(
                    initialItem: gender != null ? genderOptions.indexOf(gender!) : 0,
                  ),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      gender = genderOptions[index];
                    });
                  },
                  children: genderOptions.map((genderOption) {
                    return Center(
                      child: Text(
                        genderOption,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showActivityLevelPicker() {
    final activityOptions = activityLevelDescriptions.keys.toList();
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground,
          child: Column(
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Activity Level',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      child: Text('Done'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: CupertinoColors.systemBackground,
                  itemExtent: 60,
                  scrollController: FixedExtentScrollController(
                    initialItem: activityLevel != null 
                        ? activityOptions.indexOf(activityLevel!) : 0,
                  ),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      activityLevel = activityOptions[index];
                    });
                  },
                  children: activityOptions.map((activity) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            activityLevelDescriptions[activity]!,
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGoalPicker() {
    final goalOptions = ['Weight Loss', 'Maintenance', 'Muscle Gain'];
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground,
          child: Column(
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Select Goal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      child: Text('Done'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: CupertinoColors.systemBackground,
                  itemExtent: 50,
                  scrollController: FixedExtentScrollController(
                    initialItem: userGoal != null ? goalOptions.indexOf(userGoal!) : 0,
                  ),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      userGoal = goalOptions[index];
                    });
                  },
                  children: goalOptions.map((goalOption) {
                    return Center(
                      child: Text(
                        goalOption,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}