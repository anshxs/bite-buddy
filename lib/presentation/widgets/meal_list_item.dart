import 'package:flutter/material.dart';
import '../../data/models/food_item.dart';

class MealListItem extends StatelessWidget {
  final FoodItem meal;
  final String timeAgo;

  const MealListItem({
    Key? key,
    required this.meal,
    required this.timeAgo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        title: Text(meal.name,style: TextStyle(color: Colors.black,fontWeight: FontWeight.w600),),
        subtitle: Text('$timeAgo\n${meal.calories.toStringAsFixed(1)} kcal',style: TextStyle(color: const Color.fromARGB(255, 68, 68, 68),fontWeight: FontWeight.w400,fontSize: 12),),
        trailing: Icon(Icons.arrow_forward_ios, size: 12),
      ),
    );
  }
}