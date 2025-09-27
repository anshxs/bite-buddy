import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/preference_manager.dart';
import '../../data/models/user_data.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/database_service.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  double? weight;
  double? height; // Added height field
  int? age;
  String? activityLevel;
  String? gender;
  int estimatedCalories = 0;
  String? userGoal;

  // Activity level descriptions for better user understanding
  final Map<String, String> activityLevelDescriptions = {
    'Sedentary': 'Little or no exercise, desk job',
    'Light': '1-3 days/week of exercise',
    'Moderate': '3-5 days/week of moderate activity',
    'Active': '6-7 days/week of exercise',
    'Very Active': 'Very intense exercise/sports & physical job'
  };

  bool _isLoading = false;

  Future<void> _savePreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Starting to save user preferences...');

      // Import services
      final geminiService = GeminiService();
      final dbService = DatabaseService();

      print('Services initialized successfully');

      // First, let's try a fallback calculation to ensure we have something
      int optimalCalories = 2000; // Default fallback
      Map<String, int> macroBreakdown = {
        'protein': 150,
        'carbs': 200,
        'fat': 70,
        'fiber': 25,
        'sugar': 50,
      };

      // Try Gemini AI first, fallback if it fails
      try {
        print('Attempting Gemini AI calorie calculation...');
        // Get optimal calories from Gemini AI
        optimalCalories = await geminiService.calculateOptimalCalories(
          age: age!,
          weight: weight!,
          height: height!,
          gender: gender!,
          activityLevel: activityLevel!,
          goal: userGoal!,
        );
        print('Gemini AI calories: $optimalCalories');

        // Get macro breakdown from Gemini AI
        final macroResponse = await geminiService.getMacroBreakdown(
          calories: optimalCalories,
          goal: userGoal!,
        );

        // Convert dynamic values to integers
        macroBreakdown = {
          'protein': (macroResponse['protein'] as num).toInt(),
          'carbs': (macroResponse['carbs'] as num).toInt(),
          'fat': (macroResponse['fat'] as num).toInt(),
          'fiber': (macroResponse['fiber'] as num).toInt(),
          'sugar': (macroResponse['sugar'] as num).toInt(),
        };
        print('Gemini AI macros: $macroBreakdown');
      } catch (geminiError) {
        print('Gemini AI failed, using fallback calculation: $geminiError');
        // Use fallback calculation if Gemini fails
        optimalCalories = _calculateFallbackCalories();
        macroBreakdown = _calculateFallbackMacros(optimalCalories);
      }

      setState(() {
        estimatedCalories = optimalCalories;
      });

      print('Attempting to save to database...');

      try {
        // Save to database
        final userProfileData = {
          'weight': weight!,
          'height': height!,
          'age': age!,
          'gender': gender!,
          'activity_level': activityLevel!,
          'goal': userGoal!,
          'daily_calories': optimalCalories,
          'protein_goal': macroBreakdown['protein'] ?? 150,
          'carbs_goal': macroBreakdown['carbs'] ?? 200,
          'fat_goal': macroBreakdown['fat'] ?? 70,
          'fiber_goal': macroBreakdown['fiber'] ?? 25,
          'sugar_limit': macroBreakdown['sugar'] ?? 50,
        };

        await dbService.saveUserProfile(userProfileData);
        print('Database save successful!');
      } catch (dbError) {
        print('Database save failed: $dbError');
        // Continue to save to SharedPreferences as fallback
      }

      print('Attempting to save to SharedPreferences...');

      try {
        // Also save to SharedPreferences for backward compatibility
        final userData = UserData(
          weight: weight!,
          height: height!,
          age: age!,
          activityLevel: activityLevel!,
          gender: gender!,
          goal: userGoal!,
          estimatedCalories: optimalCalories,
          proteinGoal: macroBreakdown['protein'] ?? 150,
          fatGoal: macroBreakdown['fat'] ?? 70,
          carbsGoal: macroBreakdown['carbs'] ?? 200,
        );

        final prefManager =
            PreferenceManager(await SharedPreferences.getInstance());
        await prefManager.saveUserData(userData);

        // Mark onboarding as complete
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_complete', true);

        print('SharedPreferences save successful!');
      } catch (prefsError) {
        print('SharedPreferences save failed: $prefsError');
        throw Exception('Failed to save user data: $prefsError');
      }
    } catch (e) {
      print('Error saving preferences: $e');
      // Show error dialog with more specific information
      _showErrorDialog(
          'Failed to save your profile: ${e.toString()}\n\nPlease check your internet connection and try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _calculateFallbackCalories() {
    // Mifflin-St Jeor BMR calculation
    double bmr;
    if (gender!.toLowerCase() == 'male') {
      bmr = 10 * weight! + 6.25 * height! - 5 * age! + 5;
    } else {
      bmr = 10 * weight! + 6.25 * height! - 5 * age! - 161;
    }

    // Activity multipliers
    double activityMultiplier;
    switch (activityLevel!.toLowerCase()) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'light':
        activityMultiplier = 1.375;
        break;
      case 'moderate':
        activityMultiplier = 1.55;
        break;
      case 'active':
        activityMultiplier = 1.725;
        break;
      case 'very active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.55;
    }

    double tdee = bmr * activityMultiplier;

    // Goal adjustments
    switch (userGoal!.toLowerCase()) {
      case 'weight loss':
        return (tdee - 500).round();
      case 'muscle gain':
        return (tdee + 300).round();
      case 'maintenance':
      default:
        return tdee.round();
    }
  }

  Map<String, int> _calculateFallbackMacros(int calories) {
    double proteinPercent, carbPercent, fatPercent;

    switch (userGoal!.toLowerCase()) {
      case 'weight loss':
        proteinPercent = 0.30;
        carbPercent = 0.35;
        fatPercent = 0.35;
        break;
      case 'muscle gain':
        proteinPercent = 0.25;
        carbPercent = 0.45;
        fatPercent = 0.30;
        break;
      case 'maintenance':
      default:
        proteinPercent = 0.25;
        carbPercent = 0.45;
        fatPercent = 0.30;
    }

    return {
      'protein': ((calories * proteinPercent) / 4).round(),
      'carbs': ((calories * carbPercent) / 4).round(),
      'fat': ((calories * fatPercent) / 9).round(),
      'fiber': 25,
      'sugar': (calories * 0.1 / 4).round(),
    };
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    // Validate current page before proceeding
    String? validationError = _validateCurrentPage();
    if (validationError != null) {
      _showErrorDialog(validationError);
      return;
    }

    if (_currentPage < 6) {
      if (_currentPage == 5) {
        _savePreferences();
      }
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  String? _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        if (weight == null || weight! <= 0) {
          return 'Please enter a valid weight';
        }
        break;
      case 1:
        if (height == null || height! <= 0) {
          return 'Please enter a valid height';
        }
        break;
      case 2:
        if (age == null || age! <= 0 || age! > 120) {
          return 'Please enter a valid age';
        }
        break;
      case 3:
        if (activityLevel == null) {
          return 'Please select your activity level';
        }
        break;
      case 4:
        if (gender == null) {
          return 'Please select your gender';
        }
        break;
      case 5:
        if (userGoal == null) {
          return 'Please select your goal';
        }
        break;
    }
    return null;
  }

  void _skipToMain() {
    Navigator.pushReplacementNamed(context, '/main');
  }

  Widget _buildTextField({
    required String hintText,
    required TextInputType keyboardType,
    required Function(String) onChanged,
  }) {
    return TextField(
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        hintText: hintText,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      style: TextStyle(fontSize: 16),
    );
  }

  Widget _buildPage(
      String title, String assetPath, Widget inputField, String hintText) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 7,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                inputField,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onPressed: () {
          _showActivityLevelPicker();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activityLevel ?? 'Select Activity Level',
                    style: TextStyle(
                      color: activityLevel != null
                          ? CupertinoColors.label
                          : CupertinoColors.placeholderText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (activityLevel != null)
                    Text(
                      activityLevelDescriptions[activityLevel!] ?? '',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              color: CupertinoColors.secondaryLabel,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showActivityLevelPicker() {
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
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: CupertinoColors.activeBlue),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Activity Level',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          decoration: TextDecoration.none),
                    ),
                    CupertinoButton(
                      child: Text(
                        'Done',
                        style: TextStyle(color: CupertinoColors.activeBlue),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: CupertinoColors.systemBackground,
                  itemExtent: 60,
                  onSelectedItemChanged: (index) {
                    setState(() {
                      activityLevel =
                          activityLevelDescriptions.keys.elementAt(index);
                    });
                  },
                  children: activityLevelDescriptions.entries.map((entry) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            entry.value,
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

  Widget _buildGenderDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        onPressed: () {
          _showGenderPicker();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              gender ?? 'Select Your Gender',
              style: TextStyle(
                color: gender != null
                    ? CupertinoColors.label
                    : CupertinoColors.placeholderText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              color: CupertinoColors.secondaryLabel,
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
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: CupertinoColors.activeBlue),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Gender',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          decoration: TextDecoration.none),
                    ),
                    CupertinoButton(
                      child: Text(
                        'Done',
                        style: TextStyle(color: CupertinoColors.activeBlue),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: CupertinoColors.systemBackground,
                  itemExtent: 50,
                  scrollController: FixedExtentScrollController(initialItem: 0),
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

  Widget _buildGoalDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        onPressed: () {
          _showGoalPicker();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              userGoal ?? 'Select Your Goal',
              style: TextStyle(
                color: userGoal != null
                    ? CupertinoColors.label
                    : CupertinoColors.placeholderText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              color: CupertinoColors.secondaryLabel,
              size: 16,
            ),
          ],
        ),
      ),
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
                      child: Text('Cancel',style: TextStyle(color: CupertinoColors.activeBlue),),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Your Goal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    CupertinoButton(
                      child: Text('Done',style: TextStyle(color: CupertinoColors.activeBlue),),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: CupertinoColors.systemBackground,
                  itemExtent: 50,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset:
          false, // Prevents keyboard from pushing up content
      appBar: _currentPage == 0
          ? AppBar(
              backgroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                  onPressed: _skipToMain,
                  child: Text(
                    'Skip',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
              ],
            )
          : null,
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildPage(
            'Enter Your Weight',
            'assets/onboarding/onboarding_weight.png',
            _buildTextField(
              hintText: 'Weight in kg',
              keyboardType: TextInputType.number,
              onChanged: (value) => weight = double.tryParse(value),
            ),
            'Weight in kg',
          ),
          _buildPage(
            'Enter Your Height',
            'assets/onboarding/onboarding_height.png',
            _buildTextField(
              hintText: 'Height in cm',
              keyboardType: TextInputType.number,
              onChanged: (value) => height = double.tryParse(value),
            ),
            'Height in cm',
          ),
          _buildPage(
            'Enter Your Age',
            'assets/onboarding/onboarding_age.png',
            _buildTextField(
              hintText: 'Age in years',
              keyboardType: TextInputType.number,
              onChanged: (value) => age = int.tryParse(value),
            ),
            'Age in years',
          ),
          _buildPage(
            'Select Your Activity Level',
            'assets/onboarding/onboarding_activity_level.png',
            _buildActivityLevelDropdown(),
            'Select Activity Level',
          ),
          _buildPage(
            'Select Your Gender',
            'assets/onboarding/onboarding_gender.png',
            _buildGenderDropdown(),
            'Select Your Gender',
          ),
          _buildPage(
            'What is your goal?',
            'assets/onboarding/onboarding_goal.png',
            _buildGoalDropdown(),
            'Select Your Goal',
          ),
          _buildWelcomePage(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 48,
                width: 120,
                child: TextButton(
                  onPressed: _currentPage > 0
                      ? () => _pageController.previousPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  child: Text(
                    _currentPage > 0 ? 'Back' : '',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                width: 120,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _isLoading
                        ? Colors.grey[400]
                        : const Color.fromARGB(255, 0, 0, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _currentPage == 6 ? 'Finish' : 'Next',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 7,
            child: Image.asset(
              'assets/onboarding/onboarding_welcome.png',
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  'Welcome to Calorie Lens!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                if (_isLoading)
                  Column(
                    children: [
                      CupertinoActivityIndicator(),
                      SizedBox(height: 8),
                      Text(
                        'AI is calculating your optimal calorie target...',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                else
                  Card(
                    elevation: 0,
                    color: const Color.fromARGB(255, 235, 235, 235),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Your AI-Optimized Daily Target',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$estimatedCalories kcal',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 0, 174, 3),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Personalized by Gemini AI',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
