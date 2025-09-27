import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/food_item.dart';
import '../cubit/food_log_cubit.dart';

class EditMealScreen extends StatefulWidget {
  final FoodItem meal;

  const EditMealScreen({
    Key? key,
    required this.meal,
  }) : super(key: key);

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  late FoodItem editableMeal;

  @override
  void initState() {
    super.initState();
    editableMeal = widget.meal;
  }

  void _saveMeal(BuildContext context) {
    context.read<FoodLogCubit>().updateMeal(editableMeal);
    Navigator.pop(context); // Close the edit screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 235, 235, 235),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 235, 235, 235),
        title: Text('Edit Meal',style: TextStyle(color: Colors.black,fontWeight: FontWeight.w600),),
        actions: [
          TextButton(
            onPressed: () => _saveMeal(context),
            child: Text('Save', style: TextStyle(color: const Color.fromARGB(255, 0, 121, 242))),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Meal Name',filled: true,fillColor: Colors.white,border: OutlineInputBorder(borderRadius: BorderRadius.circular(25),borderSide: BorderSide.none)),
              controller: TextEditingController(text: editableMeal.name),
              onChanged: (value) => editableMeal = editableMeal.copyWith(name: value),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Calories (kcal)',filled: true,fillColor: Colors.white,border: OutlineInputBorder(borderRadius: BorderRadius.circular(25),borderSide: BorderSide.none)),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: editableMeal.calories.toStringAsFixed(1)),
              onChanged: (value) =>
                  editableMeal = editableMeal.copyWith(calories: double.tryParse(value) ?? 0.0),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Protein (g)',filled: true,fillColor: Colors.white,border: OutlineInputBorder(borderRadius: BorderRadius.circular(25),borderSide: BorderSide.none)),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: editableMeal.protein.toStringAsFixed(1)),
              onChanged: (value) =>
                  editableMeal = editableMeal.copyWith(protein: double.tryParse(value) ?? 0.0),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Carbs (g)',filled: true,fillColor: Colors.white,border: OutlineInputBorder(borderRadius: BorderRadius.circular(25),borderSide: BorderSide.none)),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: editableMeal.carbs.toStringAsFixed(1)),
              onChanged: (value) =>
                  editableMeal = editableMeal.copyWith(carbs: double.tryParse(value) ?? 0.0),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Fat (g)',filled: true,fillColor: Colors.white,border: OutlineInputBorder(borderRadius: BorderRadius.circular(25),borderSide: BorderSide.none)),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: editableMeal.fat.toStringAsFixed(1)),
              onChanged: (value) =>
                  editableMeal = editableMeal.copyWith(fat: double.tryParse(value) ?? 0.0),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Quantity (g)',filled: true,fillColor: Colors.white,border: OutlineInputBorder(borderRadius: BorderRadius.circular(25),borderSide: BorderSide.none)),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: editableMeal.quantity.toStringAsFixed(1)),
              onChanged: (value) =>
                  editableMeal = editableMeal.copyWith(quantity: double.tryParse(value) ?? 0.0),
            ),
          ],
        ),
      ),
    );
  }
}