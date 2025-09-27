import 'dart:convert';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  late final Gemini _gemini;

  // Helper method to extract JSON from various formats
    Map<String, dynamic>? _parseAnyResponse(String response) {
    try {
      // First try to find JSON in curly braces
      int firstBrace = response.indexOf('{');
      int lastBrace = response.lastIndexOf('}');
      
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        try {
          String jsonString = response.substring(firstBrace, lastBrace + 1);
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

  void initialize() {
    try {
      final apiKey = dotenv.env['GOOGLE_AI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GOOGLE_AI_API_KEY not found in .env file');
      }
      print('Initializing Gemini with API key: ${apiKey.substring(0, 10)}...');
      Gemini.init(apiKey: apiKey);
      _gemini = Gemini.instance;
      print('Gemini initialized successfully');
    } catch (e) {
      print('Gemini initialization failed: $e');
      rethrow;
    }
  }

  Future<int> calculateOptimalCalories({
    required double weight,
    required double height,
    required int age,
    required String gender,
    required String activityLevel,
    required String goal,
  }) async {
    try {
      print('Sending calorie calculation request to Gemini...');
      final prompt = '''You are a certified nutritionist and fitness expert. Calculate the optimal daily calorie intake for a person with these details:

Personal Information:
- Weight: $weight kg
- Height: $height cm
- Age: $age years
- Gender: $gender
- Activity Level: $activityLevel
- Goal: $goal

Calculate using:
1. Basal Metabolic Rate (BMR) using Mifflin-St Jeor equation
2. Total Daily Energy Expenditure (TDEE) based on activity level
3. Caloric adjustment for the specific goal:
   - Weight Loss: 500-750 calorie deficit
   - Maintenance: TDEE calories
   - Muscle Gain: 300-500 calorie surplus

IMPORTANT: Respond ONLY with a valid JSON object in this exact format:
{
  "calories": 2000
}

Do not include any other text, explanations, code blocks, or formatting. Just return the raw JSON object without any markdown formatting.''';

      final response = await _gemini.text(prompt).timeout(
        Duration(seconds: 30), 
        onTimeout: () => throw Exception('Gemini API timeout')
      );
      
      final responseText = response?.output?.trim() ?? '';
      print('Gemini calorie response: $responseText');
      
      if (responseText.isEmpty) {
        throw Exception('Empty response from Gemini');
      }
      
      // Try to parse response
      try {
        // Parse response using robust parser
        final data = _parseAnyResponse(responseText);
        if (data != null && data['calories'] != null) {
          final calories = data['calories'] as int;
          print('Parsed calories: $calories');
          return calories;
        }
        
        // Fallback: try to extract any number from response
        final RegExp numberPattern = RegExp(r'\d+');
        final match = numberPattern.firstMatch(responseText);
        
        if (match != null) {
          final calories = int.parse(match.group(0)!);
          print('Parsed calories (fallback): $calories');
          return calories;
        }
      } catch (e) {
        print('JSON parsing failed: $e');
      }
      
      print('No valid calories found in Gemini response, using fallback');
      return _fallbackCalorieCalculation(weight, height, age, gender, activityLevel, goal);
    } catch (e) {
      print('Gemini API Error: $e');
      // Fallback calculation
      return _fallbackCalorieCalculation(weight, height, age, gender, activityLevel, goal);
    }
  }

  Future<Map<String, dynamic>> getMacroBreakdown({
    required int calories,
    required String goal,
  }) async {
    try {
      final prompt = '''You are a certified nutritionist. For a $calories calorie diet with the goal of $goal, provide the optimal macronutrient breakdown.

Consider these guidelines:
- Weight Loss: Higher protein (25-30%), moderate carbs (35-40%), moderate fat (25-35%)
- Maintenance: Balanced (20-25% protein, 45-50% carbs, 25-30% fat)  
- Muscle Gain: Higher protein (25-30%), higher carbs (40-50%), moderate fat (20-25%)

IMPORTANT: Respond ONLY with a valid JSON object in this exact format:
{
  "protein": 150,
  "carbs": 200,
  "fat": 70,
  "fiber": 25,
  "sugar": 50
}

Use only integer values for grams. Do not include any other text, explanations, code blocks, or formatting. Just return the raw JSON object without any markdown formatting.''';

      final response = await _gemini.text(prompt);
      final responseText = response?.output?.trim() ?? '';
      
      // Try to parse response
      try {
        print('Gemini macro response: $responseText');
        
        // Parse response using robust parser
        final data = _parseAnyResponse(responseText);
        
        if (data != null) {
          print('Extracted data: $data');
          
          final result = {
            'protein': data['protein'] ?? 0,
            'carbs': data['carbs'] ?? data['carbohydrates'] ?? 0,
            'fat': data['fat'] ?? 0,
            'fiber': data['fiber'] ?? 0,
            'sugar': data['sugar'] ?? 0,
          };
          
          print('Parsed macros: $result');
          return result;
        }
        
        // If no JSON found, try to extract individual values from text
        final protein = RegExp(r'"protein":\s*(\d+)').firstMatch(responseText)?.group(1);
        final carbs = RegExp(r'"carbs":\s*(\d+)').firstMatch(responseText)?.group(1);
        final fat = RegExp(r'"fat":\s*(\d+)').firstMatch(responseText)?.group(1);
        final fiber = RegExp(r'"fiber":\s*(\d+)').firstMatch(responseText)?.group(1);
        final sugar = RegExp(r'"sugar":\s*(\d+)').firstMatch(responseText)?.group(1);
        
        return {
          'protein': int.tryParse(protein ?? '0') ?? 0,
          'carbs': int.tryParse(carbs ?? '0') ?? 0,
          'fat': int.tryParse(fat ?? '0') ?? 0,
          'fiber': int.tryParse(fiber ?? '0') ?? 0,
          'sugar': int.tryParse(sugar ?? '0') ?? 0,
        };
      } catch (e) {
        print('JSON parsing error: $e');
        print('Response text: $responseText');
      }
      
      // Fallback macro calculation
      return _fallbackMacroCalculation(calories, goal);
    } catch (e) {
      print('Gemini Macro API Error: $e');
      return _fallbackMacroCalculation(calories, goal);
    }
  }

  Future<Map<String, dynamic>> analyzeFoodAndSuggestAlternatives(String foodName) async {
    try {
      final prompt = '''Analyze this food item: "$foodName"

Consider:
- Nutritional value, processing level, sugar/sodium content
- Rate healthScore: 1-3 (unhealthy), 4-6 (moderate), 7-10 (healthy)
- For unhealthy foods, suggest 3 better alternatives
- For healthy foods, suggest variations or preparation tips

IMPORTANT: Respond ONLY with a valid JSON object in this exact format:
{
  "isHealthy": true,
  "healthScore": 7,
  "category": "healthy",
  "concerns": ["concern1", "concern2"],
  "benefits": ["benefit1", "benefit2"],
  "alternatives": ["alternative1", "alternative2", "alternative3"],
  "recommendation": "brief recommendation text"
}

Use only boolean for isHealthy, integer for healthScore (1-10), string for category ("healthy"/"moderate"/"unhealthy"), arrays for concerns/benefits/alternatives, and string for recommendation. Do not include any other text, explanations, code blocks, or formatting. Just return the raw JSON object without any markdown formatting.''';

      final response = await _gemini.text(prompt);
      final responseText = response?.output?.trim() ?? '';
      
      // Simple JSON-like parsing for our specific format
      try {
        print('Gemini food analysis response: $responseText'); // Debug log
        
        final isHealthyMatch = RegExp(r'"isHealthy":\s*(true|false)', caseSensitive: false).firstMatch(responseText);
        final healthScoreMatch = RegExp(r'"healthScore":\s*(\d+)', caseSensitive: false).firstMatch(responseText);
        final categoryMatch = RegExp(r'"category":\s*"([^"]+)"', caseSensitive: false).firstMatch(responseText);
        final recommendationMatch = RegExp(r'"recommendation":\s*"([^"]*)"', caseSensitive: false).firstMatch(responseText);
        
        // Extract arrays with more flexible parsing
        final concernsMatch = RegExp(r'"concerns":\s*\[(.*?)\]', dotAll: true, caseSensitive: false).firstMatch(responseText);
        final benefitsMatch = RegExp(r'"benefits":\s*\[(.*?)\]', dotAll: true, caseSensitive: false).firstMatch(responseText);
        final alternativesMatch = RegExp(r'"alternatives":\s*\[(.*?)\]', dotAll: true, caseSensitive: false).firstMatch(responseText);
        
        List<String> parseArray(String? arrayContent) {
          if (arrayContent == null || arrayContent.trim().isEmpty) return [];
          return RegExp(r'"([^"]+)"').allMatches(arrayContent)
              .map((match) => match.group(1)!)
              .toList();
        }
        
        final result = {
          'isHealthy': isHealthyMatch?.group(1)?.toLowerCase() == 'true',
          'healthScore': int.tryParse(healthScoreMatch?.group(1) ?? '5') ?? 5,
          'category': categoryMatch?.group(1) ?? 'moderate',
          'concerns': parseArray(concernsMatch?.group(1)),
          'benefits': parseArray(benefitsMatch?.group(1)),
          'alternatives': parseArray(alternativesMatch?.group(1)),
          'recommendation': recommendationMatch?.group(1) ?? 'Enjoy in moderation',
        };
        
        print('Parsed food analysis: $result'); // Debug log
        return result;
      } catch (e) {
        print('Food analysis parsing error: $e');
        print('Response text: $responseText');
      }
      
      // Fallback analysis
      return _fallbackFoodAnalysis(foodName);
    } catch (e) {
      print('Gemini Food Analysis Error: $e');
      return _fallbackFoodAnalysis(foodName);
    }
  }

  int _fallbackCalorieCalculation(double weight, double height, int age, String gender, String activityLevel, String goal) {
    // Mifflin-St Jeor BMR calculation
    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }
    
    // Activity multipliers
    double activityMultiplier;
    switch (activityLevel.toLowerCase()) {
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
    switch (goal.toLowerCase()) {
      case 'weight loss':
        return (tdee - 500).round();
      case 'muscle gain':
        return (tdee + 300).round();
      case 'maintenance':
      default:
        return tdee.round();
    }
  }

  Map<String, dynamic> _fallbackMacroCalculation(int calories, String goal) {
    double proteinPercent, carbPercent, fatPercent;
    
    switch (goal.toLowerCase()) {
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

  Map<String, dynamic> _fallbackFoodAnalysis(String foodName) {
    final lowercaseFood = foodName.toLowerCase();
    
    // Simple keyword-based analysis
    bool isHealthy = true;
    int healthScore = 7;
    String category = 'healthy';
    List<String> concerns = [];
    List<String> benefits = [];
    List<String> alternatives = [];
    String recommendation = 'Enjoy as part of a balanced diet';
    
    if (lowercaseFood.contains('pizza') || lowercaseFood.contains('burger') || 
        lowercaseFood.contains('fries') || lowercaseFood.contains('soda') ||
        lowercaseFood.contains('candy') || lowercaseFood.contains('chips')) {
      isHealthy = false;
      healthScore = 2;
      category = 'unhealthy';
      concerns = ['High in calories', 'Processed ingredients', 'High sodium/sugar'];
      alternatives = ['Homemade version', 'Grilled alternative', 'Fresh fruit/vegetables'];
      recommendation = 'Consider healthier alternatives';
    } else if (lowercaseFood.contains('fruit') || lowercaseFood.contains('vegetable') ||
               lowercaseFood.contains('salad') || lowercaseFood.contains('lean')) {
      benefits = ['Rich in nutrients', 'Low calorie', 'High in vitamins'];
      recommendation = 'Excellent choice for your health goals';
    }
    
    return {
      'isHealthy': isHealthy,
      'healthScore': healthScore,
      'category': category,
      'concerns': concerns,
      'benefits': benefits,
      'alternatives': alternatives,
      'recommendation': recommendation,
    };
  }

  Future<String> getTextResponse(String prompt) async {
    try {
      print('Sending text request to Gemini...');
      final response = await _gemini.text(prompt).timeout(
        Duration(seconds: 60), 
        onTimeout: () => throw Exception('Gemini API timeout')
      );
      
      final responseText = response?.output?.trim() ?? '';
      print('Gemini text response length: ${responseText.length}');
      
      if (responseText.isEmpty) {
        throw Exception('Empty response from Gemini');
      }
      
      return responseText;
    } catch (e) {
      print('Gemini Text API Error: $e');
      throw Exception('Failed to get AI response: $e');
    }
  }
}