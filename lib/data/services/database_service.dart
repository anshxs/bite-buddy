import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    try {
      print('Initializing database...');
      String path = join(await getDatabasesPath(), 'calorie_tracker.db');
      print('Database path: $path');
      
      final db = await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
        onOpen: (db) {
          print('Database opened successfully');
        },
      );
      
      return db;
    } catch (e) {
      print('Database initialization error: $e');
      rethrow;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // User profile table
    await db.execute('''
      CREATE TABLE user_profile(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight REAL NOT NULL,
        height REAL NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        activity_level TEXT NOT NULL,
        goal TEXT NOT NULL,
        daily_calories INTEGER NOT NULL,
        protein_goal INTEGER NOT NULL,
        carbs_goal INTEGER NOT NULL,
        fat_goal INTEGER NOT NULL,
        fiber_goal INTEGER NOT NULL,
        sugar_limit INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Food logs table
    await db.execute('''
      CREATE TABLE food_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL DEFAULT 0,
        carbs REAL DEFAULT 0,
        fat REAL DEFAULT 0,
        fiber REAL DEFAULT 0,
        sugar REAL DEFAULT 0,
        serving_size TEXT DEFAULT '',
        meal_type TEXT NOT NULL,
        logged_date TEXT NOT NULL,
        logged_time TEXT NOT NULL,
        is_healthy INTEGER DEFAULT 1,
        health_score INTEGER DEFAULT 5,
        food_category TEXT DEFAULT 'moderate',
        analysis_data TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // Food analysis cache table
    await db.execute('''
      CREATE TABLE food_analysis_cache(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_name TEXT UNIQUE NOT NULL,
        analysis_data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Daily summaries table
    await db.execute('''
      CREATE TABLE daily_summaries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        summary_date TEXT UNIQUE NOT NULL,
        total_calories INTEGER DEFAULT 0,
        total_protein REAL DEFAULT 0,
        total_carbs REAL DEFAULT 0,
        total_fat REAL DEFAULT 0,
        total_fiber REAL DEFAULT 0,
        total_sugar REAL DEFAULT 0,
        meals_count INTEGER DEFAULT 0,
        water_intake INTEGER DEFAULT 0,
        exercise_calories INTEGER DEFAULT 0,
        weight_entry REAL DEFAULT 0,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // User Profile Methods
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      print('Attempting to save user profile to database...');
      final db = await database;
      final now = DateTime.now().toIso8601String();
      
      profile['created_at'] = now;
      profile['updated_at'] = now;
      
      print('Profile data to save: $profile');
      
      final result = await db.insert(
        'user_profile', 
        profile, 
        conflictAlgorithm: ConflictAlgorithm.replace
      );
      
      print('User profile saved with ID: $result');
    } catch (e) {
      print('Error saving user profile: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final db = await database;
    final result = await db.query('user_profile', orderBy: 'id DESC', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    updates['updated_at'] = now;
    
    await db.update('user_profile', updates, where: 'id = (SELECT MAX(id) FROM user_profile)');
  }

  // Food Logging Methods
  Future<int> logFood(Map<String, dynamic> foodData) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    foodData['logged_date'] = today;
    foodData['created_at'] = now;
    
    final foodId = await db.insert('food_logs', foodData);
    
    // Update daily summary
    await _updateDailySummary(today);
    
    return foodId;
  }

  Future<List<Map<String, dynamic>>> getFoodLogsByDate(String date) async {
    final db = await database;
    return await db.query(
      'food_logs',
      where: 'logged_date = ?',
      whereArgs: [date],
      orderBy: 'logged_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getFoodLogsByDateRange(String startDate, String endDate) async {
    final db = await database;
    return await db.query(
      'food_logs',
      where: 'logged_date BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'logged_date DESC, logged_time DESC',
    );
  }

  Future<void> deleteFoodLog(int id) async {
    final db = await database;
    
    // Get the date of the food log before deleting
    final foodLog = await db.query('food_logs', where: 'id = ?', whereArgs: [id]);
    if (foodLog.isNotEmpty) {
      final date = foodLog.first['logged_date'] as String;
      
      await db.delete('food_logs', where: 'id = ?', whereArgs: [id]);
      
      // Update daily summary
      await _updateDailySummary(date);
    }
  }

  // Food Analysis Cache Methods
  Future<void> cacheFoodAnalysis(String foodName, Map<String, dynamic> analysis) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      'food_analysis_cache',
      {
        'food_name': foodName.toLowerCase(),
        'analysis_data': jsonEncode(analysis),
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCachedFoodAnalysis(String foodName) async {
    final db = await database;
    final result = await db.query(
      'food_analysis_cache',
      where: 'food_name = ?',
      whereArgs: [foodName.toLowerCase()],
    );
    
    if (result.isNotEmpty) {
      final analysisData = result.first['analysis_data'] as String;
      return jsonDecode(analysisData);
    }
    return null;
  }

  // Daily Summary Methods
  Future<void> _updateDailySummary(String date) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    // Calculate totals from food logs
    final foodLogs = await getFoodLogsByDate(date);
    
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;
    double totalSugar = 0;
    int mealsCount = foodLogs.length;
    
    for (final log in foodLogs) {
      totalCalories += (log['calories'] as int? ?? 0);
      totalProtein += (log['protein'] as double? ?? 0);
      totalCarbs += (log['carbs'] as double? ?? 0);
      totalFat += (log['fat'] as double? ?? 0);
      totalFiber += (log['fiber'] as double? ?? 0);
      totalSugar += (log['sugar'] as double? ?? 0);
    }
    
    // Check if summary exists for this date
    final existingSummary = await db.query(
      'daily_summaries',
      where: 'summary_date = ?',
      whereArgs: [date],
    );
    
    final summaryData = {
      'summary_date': date,
      'total_calories': totalCalories.round(),
      'total_protein': totalProtein,
      'total_carbs': totalCarbs,
      'total_fat': totalFat,
      'total_fiber': totalFiber,
      'total_sugar': totalSugar,
      'meals_count': mealsCount,
      'updated_at': now,
    };
    
    if (existingSummary.isNotEmpty) {
      await db.update(
        'daily_summaries',
        summaryData,
        where: 'summary_date = ?',
        whereArgs: [date],
      );
    } else {
      summaryData['created_at'] = now;
      await db.insert('daily_summaries', summaryData);
    }
  }

  Future<Map<String, dynamic>?> getDailySummary(String date) async {
    final db = await database;
    final result = await db.query(
      'daily_summaries',
      where: 'summary_date = ?',
      whereArgs: [date],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getDailySummariesByRange(String startDate, String endDate) async {
    final db = await database;
    return await db.query(
      'daily_summaries',
      where: 'summary_date BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'summary_date DESC',
    );
  }

  // Analytics and History Methods
  Future<List<Map<String, dynamic>>> getWeeklyProgress() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(Duration(days: 7));
    final endDate = now.toIso8601String().split('T')[0];
    final startDate = weekAgo.toIso8601String().split('T')[0];
    
    return await getDailySummariesByRange(startDate, endDate);
  }

  Future<List<Map<String, dynamic>>> getMonthlyProgress() async {
    final now = DateTime.now();
    final monthAgo = now.subtract(Duration(days: 30));
    final endDate = now.toIso8601String().split('T')[0];
    final startDate = monthAgo.toIso8601String().split('T')[0];
    
    return await getDailySummariesByRange(startDate, endDate);
  }

  Future<Map<String, dynamic>> getNutritionalStats() async {
    final db = await database;
    final now = DateTime.now();
    const startDate = '2024-01-01';
    final endDate = now.toIso8601String().split('T')[0];
    
    final result = await db.rawQuery('''
      SELECT 
        AVG(total_calories) as avg_calories,
        AVG(total_protein) as avg_protein,
        AVG(total_carbs) as avg_carbs,
        AVG(total_fat) as avg_fat,
        COUNT(*) as days_logged
      FROM daily_summaries 
      WHERE summary_date BETWEEN ? AND ?
    ''', [startDate, endDate]);
    
    return result.first;
  }

  // Utility Methods
  Future<void> clearAllData() async {
    try {
      final db = await database;
      
      // Execute in a transaction for consistency
      await db.transaction((txn) async {
        // Clear tables in the right order (considering any dependencies)
        await txn.delete('daily_summaries');
        await txn.delete('food_logs');
        await txn.delete('food_analysis_cache');
        await txn.delete('user_profile');
        
        print('All data cleared successfully');
      });
    } catch (e) {
      print('Error clearing data: $e');
      throw Exception('Failed to clear data: $e');
    }
  }

  Future<void> exportUserData() async {
    // This would export all user data for backup purposes
    // Implementation depends on specific requirements
    print('Export user data not implemented yet');
  }
}