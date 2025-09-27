import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/food_item.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/services/gemini_service.dart';

class FoodLogState {
  final List<FoodItem> meals;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final List<double> weeklyData;
  final bool isLoading;
  final String? error;
  final String? successMessage; // New field for success messages

  const FoodLogState({
    this.meals = const [],
    this.totalCalories = 0,
    this.totalProtein = 0,
    this.totalCarbs = 0,
    this.totalFat = 0,
    this.weeklyData = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  FoodLogState copyWith({
    List<FoodItem>? meals,
    double? totalCalories,
    double? totalProtein,
    double? totalCarbs,
    double? totalFat,
    List<double>? weeklyData,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return FoodLogState(
      meals: meals ?? this.meals,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
      weeklyData: weeklyData ?? this.weeklyData,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

class FoodLogCubit extends Cubit<FoodLogState> {
  final FoodRepository _repository;

  FoodLogCubit(this._repository) : super(FoodLogState());

  Future<void> loadDailyLog() async {
    emit(state.copyWith(isLoading: true));
    try {
      final meals = await _repository.getDailyFoodLog(DateTime.now());
      final totals = _calculateTotals(meals);
      final weeklyData = await _loadWeeklyData();
      
      emit(state.copyWith(
        meals: meals,
        totalCalories: totals['calories'],
        totalProtein: totals['protein'],
        totalCarbs: totals['carbs'],
        totalFat: totals['fat'],
        weeklyData: weeklyData,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  Future<void> addMeal(FoodItem meal) async {
    try {
      await _repository.addFoodItem(meal);
      await loadDailyLog();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Map<String, double> _calculateTotals(List<FoodItem> meals) {
    return meals.fold({
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
    }, (totals, meal) {
      totals['calories'] = (totals['calories'] ?? 0) + meal.calories;
      totals['protein'] = (totals['protein'] ?? 0) + meal.protein;
      totals['carbs'] = (totals['carbs'] ?? 0) + meal.carbs;
      totals['fat'] = (totals['fat'] ?? 0) + meal.fat;
      return totals;
    });
  }

  Future<List<double>> _loadWeeklyData() async {
    final List<double> weeklyData = [];
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final meals = await _repository.getDailyFoodLog(date);
      final calories = meals.fold(0.0, (sum, meal) => sum + meal.calories);
      weeklyData.add(calories);
    }
    
    return weeklyData;
  }

  Future<void> addMealFromImage(File image) async {
    emit(state.copyWith(isLoading: true));
    final result = await _repository.detectFoodFromImage(image);
    result.fold(
      (failure) {
        // Emit error message
        emit(state.copyWith(error: failure, successMessage: null, isLoading: false));
      },
      (meal) async {
        await addMeal(meal);
        // Emit success message
        emit(state.copyWith(
          error: null,
          successMessage: 'Food "${meal.name}" detected successfully and added to the log.',
          isLoading: false,
        ));
      },
    );
  }

  Future<Map<String, dynamic>?> detectFoodFromImageWithAnalysis(File image) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      final result = await _repository.detectFoodFromImage(image);
      
      return result.fold(
        (failure) {
          emit(state.copyWith(error: failure, successMessage: null, isLoading: false));
          return null;
        },
        (meal) async {
          // Analyze the detected food for healthiness
          final analysis = await analyzeFoodHealthiness(meal.name);
          
          emit(state.copyWith(isLoading: false));
          
          return {
            'meal': meal,
            'analysis': analysis,
          };
        },
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
      return null;
    }
  }

  Future<void> addDetectedMeal(FoodItem meal, {String? alternativeName}) async {
    try {
      // If alternative name is provided, update the meal name
      if (alternativeName != null && alternativeName != meal.name) {
        meal = FoodItem(
          id: meal.id,
          name: alternativeName,
          calories: meal.calories,
          protein: meal.protein,
          carbs: meal.carbs,
          fat: meal.fat,
          quantity: meal.quantity,
          timestamp: meal.timestamp,
        );
      }

      await addMeal(meal);
      emit(state.copyWith(
        error: null,
        successMessage: 'Food "${meal.name}" added to your log.',
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: 'Failed to add food: ${e.toString()}',
        successMessage: null,
        isLoading: false,
      ));
    }
  }

  Future<void> addMealManually({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    String mealType = 'Snack',
  }) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      // Create food item directly
      final meal = FoodItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        quantity: 100.0,
        timestamp: DateTime.now(),
      );
      
      // Add the meal
      await addMeal(meal);
      
      // Emit success message
      emit(state.copyWith(
        error: null,
        successMessage: 'Food "$name" added successfully.',
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: 'Failed to add food: ${e.toString()}',
        successMessage: null,
        isLoading: false,
      ));
    }
  }

  void clearMessages() {
    emit(FoodLogState(
      meals: state.meals,
      totalCalories: state.totalCalories,
      totalProtein: state.totalProtein,
      totalCarbs: state.totalCarbs,
      totalFat: state.totalFat,
      weeklyData: state.weeklyData,
      isLoading: state.isLoading,
      error: null, // Explicitly clear error
      successMessage: null, // Explicitly clear success message
    ));
  }

    Future<void> deleteMeal(FoodItem meal) async {
    try {
      await _repository.deleteFoodItem(meal);
      await loadDailyLog();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> updateMeal(FoodItem meal) async {
    try {
      await _repository.updateFoodItem(meal);
      await loadDailyLog();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<Map<String, dynamic>?> analyzeFoodHealthiness(String foodName) async {
    try {
      final geminiService = GeminiService();
      final analysis = await geminiService.analyzeFoodAndSuggestAlternatives(foodName);
      
      // Check if food is unhealthy (health score < 6)
      final healthScore = analysis['healthScore'] ?? 5;
      final isHealthy = analysis['isHealthy'] ?? true;
      
      if (!isHealthy || healthScore < 6) {
        return analysis;
      }
      
      return null; // Food is healthy, no alternatives needed
    } catch (e) {
      print('Error analyzing food: $e');
      return null;
    }
  }

}