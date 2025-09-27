import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

import '../models/food_item.dart';
import 'gemini_service.dart';
import 'database_service.dart';

class FoodService {
  final GeminiService _geminiService = GeminiService();
  final DatabaseService _dbService = DatabaseService();

  // Load the API key from the environment
  String get _apiKey => dotenv.env['GOOGLE_AI_API_KEY'] ?? '';

  // Initialize Gemini in the constructor
  FoodService() {
    if (_apiKey.isEmpty) {
      throw Exception('Google AI API key not found in environment variables');
    }

    // Initialize the Gemini instance
    Gemini.init(apiKey: _apiKey);
  }
Future<Either<String, FoodItem>> detectFoodAndCalories(File imageFile) async {
  try {
    if (!imageFile.existsSync()) {
      return Left('File not found: ${imageFile.path}');
    }

    final response = await Gemini.instance.textAndImage(
      text: 'Analyze this image and identify the food. '
          'Estimate its calories, protein, carbs, and fat. '
          'IMPORTANT: Respond ONLY with a valid JSON object in this exact format: '
          '{"name": "food name", "calories": 100, "protein": 10, "carbs": 20, "fat": 5} '
          'Do not include any other text, explanations, code blocks, or formatting. '
          'Just return the raw JSON object without any markdown formatting.',
      images: [imageFile.readAsBytesSync()],
    );

    final output = response?.output;
    if (output == null || output.isEmpty) {
      return Left('No response output from Gemini API');
    }

    print('Raw Gemini response: $output');

    // Use robust JSON parsing that handles markdown code blocks
    final foodData = _parseJsonResponse(output);
    if (foodData == null) {
      return Left('No valid JSON found in output: $output');
    }

    return Right(FoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: foodData['name'] ?? 'Unknown Food',
      calories: (foodData['calories'] ?? 0).toDouble(),
      protein: (foodData['protein'] ?? 0).toDouble(),
      carbs: (foodData['carbs'] ?? 0).toDouble(),
      fat: (foodData['fat'] ?? 0).toDouble(),
      quantity: 100.0,
      timestamp: DateTime.now(),
    ));
  } catch (e) {
    print('Error in detectFoodAndCalories: $e');
    return Left('Failed to detect food: ${e.toString()}');
  }
}

  // Helper method to parse JSON from various formats (including markdown code blocks)
  Map<String, dynamic>? _parseJsonResponse(String response) {
    try {
      // Remove markdown code block markers if present
      String cleanResponse = response.trim();
      
      // Remove ```json and ``` markers
      cleanResponse = cleanResponse.replaceAll(RegExp(r'```json\s*'), '');
      cleanResponse = cleanResponse.replaceAll(RegExp(r'```\s*$'), '');
      cleanResponse = cleanResponse.trim();
      
      // Try to find JSON in curly braces
      int firstBrace = cleanResponse.indexOf('{');
      int lastBrace = cleanResponse.lastIndexOf('}');
      
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        try {
          String jsonString = cleanResponse.substring(firstBrace, lastBrace + 1);
          print('Extracted JSON: $jsonString');
          return Map<String, dynamic>.from(jsonDecode(jsonString));
        } catch (e) {
          print('JSON parsing failed, trying regex extraction: $e');
        }
      }
      
      // If JSON parsing fails, use regex to extract values
      Map<String, dynamic> result = {};
      
      // Extract name/title
      RegExp nameRegex = RegExp(r'"?(?:name|title|food)"?\s*[:=]\s*"([^"]+)"', caseSensitive: false);
      Match? nameMatch = nameRegex.firstMatch(response);
      if (nameMatch != null) {
        result['name'] = nameMatch.group(1)!.trim();
      }
      
      // Extract calories
      RegExp caloriesRegex = RegExp(r'"?calories"?\s*[:=]\s*(\d+)', caseSensitive: false);
      Match? caloriesMatch = caloriesRegex.firstMatch(response);
      if (caloriesMatch != null) {
        result['calories'] = int.parse(caloriesMatch.group(1)!);
      }
      
      // Extract protein
      RegExp proteinRegex = RegExp(r'"?protein"?\s*[:=]\s*(\d+)', caseSensitive: false);
      Match? proteinMatch = proteinRegex.firstMatch(response);
      if (proteinMatch != null) {
        result['protein'] = int.parse(proteinMatch.group(1)!);
      }
      
      // Extract carbs
      RegExp carbsRegex = RegExp(r'"?(?:carbs|carbohydrates)"?\s*[:=]\s*(\d+)', caseSensitive: false);
      Match? carbsMatch = carbsRegex.firstMatch(response);
      if (carbsMatch != null) {
        result['carbs'] = int.parse(carbsMatch.group(1)!);
      }
      
      // Extract fat
      RegExp fatRegex = RegExp(r'"?fat"?\s*[:=]\s*(\d+)', caseSensitive: false);
      Match? fatMatch = fatRegex.firstMatch(response);
      if (fatMatch != null) {
        result['fat'] = int.parse(fatMatch.group(1)!);
      }
      
      return result.isNotEmpty ? result : null;
    } catch (e) {
      print('Error parsing response: $e');
      return null;
    }
  }

  Future<Either<String, Map<String, dynamic>>> analyzeFoodAndGetSuggestions(String foodName) async {
    try {
      // Check cache first (with database error handling)
      Map<String, dynamic>? cachedAnalysis;
      try {
        cachedAnalysis = await _dbService.getCachedFoodAnalysis(foodName);
        if (cachedAnalysis != null) {
          return Right(cachedAnalysis);
        }
      } catch (dbError) {
        print('Database cache read failed: $dbError');
        // Continue without cache
      }

      // Get analysis from Gemini
      final analysis = await _geminiService.analyzeFoodAndSuggestAlternatives(foodName);
      
      // Cache the analysis (with database error handling)
      try {
        await _dbService.cacheFoodAnalysis(foodName, analysis);
      } catch (dbError) {
        print('Database cache write failed: $dbError');
        // Continue without caching - the analysis is still valid
      }
      
      return Right(analysis);
    } catch (e) {
      return Left('Failed to analyze food: ${e.toString()}');
    }
  }

  Future<Either<String, FoodItem>> createFoodItemWithAnalysis(
    String foodName,
    int calories, {
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    String mealType = 'Snack',
  }) async {
    try {
      // Get food analysis
      final analysisResult = await analyzeFoodAndGetSuggestions(foodName);
      
      Map<String, dynamic> analysis = {};
      analysisResult.fold(
        (error) => print('Analysis failed: $error'),
        (data) => analysis = data,
      );

      // Create food item
      final foodItem = FoodItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: foodName,
        calories: calories.toDouble(),
        protein: protein,
        carbs: carbs,
        fat: fat,
        quantity: 100.0,
        timestamp: DateTime.now(),
      );

      // Save to database with analysis data (with error handling)
      try {
        final now = DateTime.now();
        await _dbService.logFood({
          'food_name': foodName,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
          'meal_type': mealType,
          'logged_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          'is_healthy': analysis['isHealthy'] == true ? 1 : 0,
          'health_score': analysis['healthScore'] ?? 5,
          'food_category': analysis['category'] ?? 'moderate',
          'analysis_data': jsonEncode(analysis),
        });
        print('Food logged to database successfully');
      } catch (dbError) {
        print('Database logging failed: $dbError');
        // Continue - the food item is still valid even if DB logging fails
      }

      return Right(foodItem);
    } catch (e) {
      return Left('Failed to create food item: ${e.toString()}');
    }
  }

  Future<List<String>> getHealthierAlternatives(String foodName) async {
    try {
      final analysisResult = await analyzeFoodAndGetSuggestions(foodName);
      
      return analysisResult.fold(
        (error) => [],
        (analysis) => List<String>.from(analysis['alternatives'] ?? []),
      );
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getFoodRecommendation(String foodName) async {
    try {
      final analysisResult = await analyzeFoodAndGetSuggestions(foodName);
      
      return analysisResult.fold(
        (error) => {
          'recommendation': 'Unable to analyze this food item',
          'isHealthy': true,
          'healthScore': 5,
        },
        (analysis) => {
          'recommendation': analysis['recommendation'] ?? 'Enjoy in moderation',
          'isHealthy': analysis['isHealthy'] ?? true,
          'healthScore': analysis['healthScore'] ?? 5,
          'category': analysis['category'] ?? 'moderate',
          'concerns': analysis['concerns'] ?? [],
          'benefits': analysis['benefits'] ?? [],
        },
      );
    } catch (e) {
      return {
        'recommendation': 'Unable to analyze this food item',
        'isHealthy': true,
        'healthScore': 5,
      };
    }
  }
}