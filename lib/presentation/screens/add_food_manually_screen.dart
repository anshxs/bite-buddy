import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/food_log_cubit.dart';
import '../widgets/food_alternatives_dialog.dart';

class AddFoodManuallyScreen extends StatefulWidget {
  @override
  _AddFoodManuallyScreenState createState() => _AddFoodManuallyScreenState();
}

class _AddFoodManuallyScreenState extends State<AddFoodManuallyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  
  String _selectedMealType = 'Breakfast';
  bool _isLoading = false;
  
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _estimateNutrition() async {
    if (_foodNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a food name first', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use simple estimation logic based on food name patterns
      final foodName = _foodNameController.text.trim().toLowerCase();
      Map<String, int> estimatedNutrition = _getEstimatedNutrition(foodName);
      
      _caloriesController.text = estimatedNutrition['calories'].toString();
      _proteinController.text = estimatedNutrition['protein'].toString();
      _carbsController.text = estimatedNutrition['carbs'].toString();
      _fatController.text = estimatedNutrition['fat'].toString();
      
      _showSnackBar('Estimated values filled based on food type. Please adjust as needed.');
    } catch (e) {
      _showSnackBar('Failed to estimate nutrition: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, int> _getEstimatedNutrition(String foodName) {
    // Simple pattern matching for common foods
    if (foodName.contains('chicken') || foodName.contains('beef') || foodName.contains('fish')) {
      return {'calories': 200, 'protein': 25, 'carbs': 0, 'fat': 8};
    } else if (foodName.contains('rice') || foodName.contains('pasta') || foodName.contains('bread')) {
      return {'calories': 150, 'protein': 5, 'carbs': 30, 'fat': 1};
    } else if (foodName.contains('salad') || foodName.contains('vegetable')) {
      return {'calories': 50, 'protein': 3, 'carbs': 8, 'fat': 0};
    } else if (foodName.contains('fruit') || foodName.contains('apple') || foodName.contains('banana')) {
      return {'calories': 80, 'protein': 1, 'carbs': 20, 'fat': 0};
    } else if (foodName.contains('egg')) {
      return {'calories': 140, 'protein': 12, 'carbs': 1, 'fat': 10};
    } else if (foodName.contains('milk') || foodName.contains('yogurt')) {
      return {'calories': 100, 'protein': 8, 'carbs': 12, 'fat': 3};
    } else if (foodName.contains('pizza') || foodName.contains('burger')) {
      return {'calories': 350, 'protein': 15, 'carbs': 40, 'fat': 15};
    } else {
      // Default estimation
      return {'calories': 150, 'protein': 8, 'carbs': 20, 'fat': 5};
    }
  }

  Future<void> _saveFoodItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final foodName = _foodNameController.text.trim();
      final calories = int.parse(_caloriesController.text);
      final protein = double.parse(_proteinController.text);
      final carbs = double.parse(_carbsController.text);
      final fat = double.parse(_fatController.text);

      // Show analyzing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing food healthiness and finding alternatives...'),
            ],
          ),
        ),
      );

      // Check if food is unhealthy and get alternatives
      final foodLogCubit = context.read<FoodLogCubit>();
      final analysis = await foodLogCubit.analyzeFoodHealthiness(foodName);
      
      // Close analyzing dialog
      Navigator.of(context).pop();
      
      setState(() {
        _isLoading = false;
      });

      if (analysis != null) {
        // Show alternatives dialog
        _showAlternativesDialog(
          analysis,
          () => _addFoodItem(foodName, calories.toDouble(), protein, carbs, fat),
          (alternativeName) => _addFoodItem(alternativeName, calories.toDouble(), protein, carbs, fat),
        );
      } else {
        // Food is healthy, add directly
        await _addFoodItem(foodName, calories.toDouble(), protein, carbs, fat);
      }
    } catch (e) {
      _showSnackBar('Failed to save food item: ${e.toString()}', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addFoodItem(String name, double calories, double protein, double carbs, double fat) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final foodLogCubit = context.read<FoodLogCubit>();
      await foodLogCubit.addMealManually(
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        mealType: _selectedMealType,
      );

      _showSnackBar('Food item "$name" added successfully!');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to add food item: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAlternativesDialog(
    Map<String, dynamic> analysis,
    VoidCallback onKeepOriginal,
    Function(String) onSelectAlternative,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FoodAlternativesDialog(
          originalFood: _foodNameController.text.trim(),
          analysis: analysis,
          onKeepOriginal: onKeepOriginal,
          onSelectAlternative: onSelectAlternative,
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Add Food Manually',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          if (_isLoading)
            Container(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Food Name Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Food Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _foodNameController,
                      decoration: InputDecoration(
                        labelText: 'Food Name',
                        hintText: 'e.g. Grilled Chicken Breast',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.restaurant),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a food name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _estimateNutrition,
                            icon: Icon(Icons.auto_awesome),
                            label: Text('AI Estimate'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedMealType,
                            decoration: InputDecoration(
                              labelText: 'Meal Type',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.schedule),
                            ),
                            items: _mealTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedMealType = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),

            // Nutrition Information Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _caloriesController,
                            decoration: InputDecoration(
                              labelText: 'Calories',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.local_fire_department),
                              suffixText: 'kcal',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final calories = int.tryParse(value);
                              if (calories == null || calories < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _proteinController,
                            decoration: InputDecoration(
                              labelText: 'Protein',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.fitness_center),
                              suffixText: 'g',
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final protein = double.tryParse(value);
                              if (protein == null || protein < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _carbsController,
                            decoration: InputDecoration(
                              labelText: 'Carbs',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.grain),
                              suffixText: 'g',
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final carbs = double.tryParse(value);
                              if (carbs == null || carbs < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _fatController,
                            decoration: InputDecoration(
                              labelText: 'Fat',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.opacity),
                              suffixText: 'g',
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final fat = double.tryParse(value);
                              if (fat == null || fat < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveFoodItem,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
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
                        SizedBox(width: 16),
                        Text('Saving...'),
                      ],
                    )
                  : Text(
                      'Add Food Item',
                      style: TextStyle(fontSize: 16),
                    ),
            ),

            SizedBox(height: 16),

            // Help Text
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Use the AI Estimate button to get suggested nutrition values\n'
                      '• Check food packaging labels for accurate nutrition info\n'
                      '• You can find nutrition facts on food databases online',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}