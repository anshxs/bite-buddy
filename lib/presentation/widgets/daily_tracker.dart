import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/preference_manager.dart';
import '../../data/models/user_data.dart';
import '../../data/services/database_service.dart';
import 'macro_indicator.dart';

class DailyTracker extends StatefulWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const DailyTracker({
    Key? key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  }) : super(key: key);

  @override
  State<DailyTracker> createState() => _DailyTrackerState();
}

// Add a key for the DailyTracker to force rebuild when needed
class DailyTrackerKey {
  static final GlobalKey<_DailyTrackerState> key = GlobalKey<_DailyTrackerState>();
}

class _DailyTrackerState extends State<DailyTracker> {
  UserData? userData;
  Map<String, dynamic>? userProfile;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload user data when widget dependencies change
    _loadUserData();
  }

  // Public method to refresh user data
  Future<void> refreshUserData() async {
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Load from database first (preferred)
    try {
      final profile = await _dbService.getUserProfile();
      if (profile != null) {
        setState(() {
          userProfile = profile;
        });
        return;
      }
    } catch (e) {
      print('Error loading user profile from database: $e');
    }
    
    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final prefManager = PreferenceManager(prefs);
    userData = prefManager.getUserData();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Get target calories from database profile or fallback to SharedPreferences
    final targetCalories = userProfile != null 
        ? (userProfile!['daily_calories'] as num?)?.toDouble() ?? 2000.0
        : userData?.estimatedCalories.toDouble() ?? 2000.0;
    
    final proteinGoal = userProfile != null
        ? (userProfile!['protein_goal'] as num?)?.toDouble() ?? 150.0
        : userData?.proteinGoal ?? 150.0;
    
    final carbsGoal = userProfile != null
        ? (userProfile!['carbs_goal'] as num?)?.toDouble() ?? 200.0
        : userData?.carbsGoal ?? 200.0;
    
    final fatGoal = userProfile != null
        ? (userProfile!['fat_goal'] as num?)?.toDouble() ?? 70.0
        : userData?.fatGoal ?? 70.0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(25),
        
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              'Daily Calorie Goal: ${targetCalories.toInt()} kcal',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 16),
          CircularPercentIndicator(
            radius: 80.0,
            lineWidth: 8.0,
            percent: (widget.calories / targetCalories).clamp(0.0, 1.0),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange),
                Text(
                  '${widget.calories.toInt()} kcal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            progressColor: const Color.fromARGB(255, 255, 94, 0),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MacroIndicator(
                label: 'Protein',
                value: widget.protein,
                goal: proteinGoal.toDouble(),
                color: const Color.fromARGB(255, 0, 189, 6),
              ),
              MacroIndicator(
                label: 'Fats',
                value: widget.fat,
                goal: fatGoal.toDouble(),
                color: const Color.fromARGB(255, 233, 97, 0),
              ),
              MacroIndicator(
                label: 'Carbs',
                value: widget.carbs,
                goal: carbsGoal.toDouble(),
                color: const Color.fromARGB(255, 255, 193, 7),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
