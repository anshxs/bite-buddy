import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../cubit/food_log_cubit.dart';
import '../widgets/daily_tracker.dart';
import '../widgets/meal_list.dart';
import '../widgets/alert_message_widget.dart';
import '../widgets/food_alternatives_dialog.dart';
import '../../data/models/food_item.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final picker = ImagePicker();
  File? _image;

  Future<void> getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 600,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      scanImage();
    }
  }

  void scanImage() async {
    final foodLogCubit = context.read<FoodLogCubit>();
    
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
            Text('Analyzing food and checking for healthier alternatives...'),
          ],
        ),
      ),
    );
    
    final result = await foodLogCubit.detectFoodFromImageWithAnalysis(_image!);
    
    // Close analyzing dialog
    Navigator.of(context).pop();
    
    if (result != null) {
      final meal = result['meal'] as FoodItem;
      final analysis = result['analysis'] as Map<String, dynamic>?;
      
      if (analysis != null) {
        // Show alternatives dialog
        _showAlternativesDialog(
          meal,
          analysis,
          () => foodLogCubit.addDetectedMeal(meal),
          (alternativeName) => foodLogCubit.addDetectedMeal(meal, alternativeName: alternativeName),
        );
      } else {
        // Food is healthy, add directly
        await foodLogCubit.addDetectedMeal(meal);
      }
    }
  }

  void _showAlternativesDialog(
    FoodItem meal,
    Map<String, dynamic> analysis,
    VoidCallback onKeepOriginal,
    Function(String) onSelectAlternative,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FoodAlternativesDialog(
          originalFood: meal.name,
          analysis: analysis,
          onKeepOriginal: onKeepOriginal,
          onSelectAlternative: onSelectAlternative,
        );
      },
    );
  }

  void showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: const Color.fromARGB(255, 236, 236, 236),
      context: context,
      builder: (context) => Wrap(
        children: <Widget>[
          ListTile(
            leading: Icon(CupertinoIcons.camera_fill),
            title: Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              getImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: Icon(CupertinoIcons.photo),
            title: Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              getImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 235, 235, 235),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 234, 234, 234),
        title: Text(
          'Calorie Tracker',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's trackers",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                BlocBuilder<FoodLogCubit, FoodLogState>(
                  builder: (context, state) {
                    if (state.isLoading) {
                      return Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      children: [
                        // Tracker Section
                        DailyTracker(
                          key: UniqueKey(), // Force rebuild every time
                          calories: state.totalCalories,
                          protein: state.totalProtein,
                          carbs: state.totalCarbs,
                          fat: state.totalFat,
                        ),
                        SizedBox(height: 24),

                        // Inline Alert Section for Success or Error
                        if (state.successMessage != null || state.error != null)
                          AlertMessageWidget(
                            errorMessage: state.error,
                            successMessage: state.successMessage,
                            onClose: () =>
                                context.read<FoodLogCubit>().clearMessages(),
                          ),

                        // Meals Section
                        Text('Meals',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 16),
                        MealList(meals: state.meals),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
        onPressed: () {
          showImageSourceActionSheet(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            'Add',
            style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white),
          ),
        ),
          ),
        ),
      ),
    );
  }
}
