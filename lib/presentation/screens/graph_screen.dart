import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/food_log_cubit.dart';
import '../../data/services/gemini_service.dart';

class GraphScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 235, 235, 235),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 234, 234, 234),
        title: Text('Weekly Progress',style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: BlocBuilder<FoodLogCubit, FoodLogState>(
          builder: (context, state) {
            if (state.isLoading) {
              return Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20,vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.grey.withOpacity(0.2),
                      //     spreadRadius: 2,
                      //     blurRadius: 5,
                      //     offset: Offset(0, 3),
                      //   ),
                      // ],
                    ),
                    height: 400,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 2500,
                      barGroups: state.weeklyData.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value,
                              color: const Color.fromARGB(255, 132, 248, 0),
                              // gradient: LinearGradient(colors: [Colors.red, Colors.yellow,Colors.green,Colors.yellow,Colors.red],transform: GradientRotation(3.14/4)),
                              width: 20,
                              fromY: 0,
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) =>
                              Text('${value.toInt()}',style: TextStyle(fontSize: 7,fontWeight: FontWeight.bold),),
                            interval: 500,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0: return Text('Mon',style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold),);
                                case 1: return Text('Tue',style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold),);
                                case 2: return Text('Wed',style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold),);
                                case 3: return Text('Thu',style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold),);
                                case 4: return Text('Fri',style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold),);
                                case 5: return Text('Sat',style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold),);
                                case 6: return Text('Sun',style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold),);
                                default: return Text('');
                              }
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 500,
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  ),
                  SizedBox(height: 16),
                  _buildAIAnalysisButton(context, state),
                 
                  SizedBox(height: 16),
                   _buildWeeklyStats(state),
                  
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeeklyStats(FoodLogState state) {
    final avgCalories = state.weeklyData.isEmpty 
      ? 0.0 
      : state.weeklyData.reduce((a, b) => a + b) / state.weeklyData.length;

    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  'Average',
                  '${avgCalories.toInt()} kcal',
                  CupertinoIcons.chart_bar,
                ),
                _buildStatItem(
                  'Highest',
                  '${state.weeklyData.isEmpty ? 0 : state.weeklyData.reduce((a, b) => a > b ? a : b).toInt()} kcal',
                  CupertinoIcons.arrow_up,
                ),
                _buildStatItem(
                  'Lowest',
                  '${state.weeklyData.isEmpty ? 0 : state.weeklyData.reduce((a, b) => a < b ? a : b).toInt()} kcal',
                  CupertinoIcons.arrow_down,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color.fromARGB(255, 0, 153, 255)),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAIAnalysisButton(BuildContext context, FoodLogState state) {
    return Container(
      width: double.infinity,
      height: 56,
      margin: EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.pink, Colors.purpleAccent, Colors.blue!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.blue.withOpacity(0.3),
        //     blurRadius: 8,
        //     offset: Offset(0, 4),
        //   ),
        // ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAIAnalysis(context, state),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon(
                //   Icons.psychology,
                //   color: Colors.white,
                //   size: 28,
                // ),
                // SizedBox(width: 12),
                Text(
                  'AI Progress Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 12),
                Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAIAnalysis(BuildContext context, FoodLogState state) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI is analyzing your progress...'),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );

    try {
      final analysis = await _getAIProgressAnalysis(state);
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show analysis dialog
      _showAnalysisDialog(context, analysis);
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get AI analysis: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _getAIProgressAnalysis(FoodLogState state) async {
    final geminiService = GeminiService();
    
    // Prepare progress data for analysis
    final avgCalories = state.weeklyData.isEmpty 
      ? 0.0 
      : state.weeklyData.reduce((a, b) => a + b) / state.weeklyData.length;
    
    final highestCalories = state.weeklyData.isEmpty 
      ? 0.0 
      : state.weeklyData.reduce((a, b) => a > b ? a : b);
    
    final lowestCalories = state.weeklyData.isEmpty 
      ? 0.0 
      : state.weeklyData.reduce((a, b) => a < b ? a : b);
    
    final totalCalories = state.totalCalories;
    final totalProtein = state.totalProtein;
    final totalCarbs = state.totalCarbs;
    final totalFat = state.totalFat;
    final mealsCount = state.meals.length;
    
    final prompt = '''You are a certified nutritionist and health coach. Analyze this user's weekly nutrition progress and provide comprehensive insights:

WEEKLY PROGRESS DATA:
- Average Daily Calories: ${avgCalories.round()}
- Highest Daily Calories: ${highestCalories.round()}  
- Lowest Daily Calories: ${lowestCalories.round()}
- Today's Total Calories: ${totalCalories.round()}
- Today's Protein: ${totalProtein.round()}g
- Today's Carbs: ${totalCarbs.round()}g
- Today's Fat: ${totalFat.round()}g
- Today's Meals Logged: $mealsCount
- Weekly Data: ${state.weeklyData.map((e) => e.round()).join(', ')} calories per day

ANALYSIS REQUEST:
Please provide a detailed analysis covering:
1. Weekly calorie consistency (are they maintaining steady intake?)
2. Current day's nutrition balance evaluation
3. Progress trends (improving, declining, or stable?)
4. Specific recommendations for better nutrition
5. Motivational feedback on positive aspects
6. Areas needing attention with actionable suggestions
7. Goal suggestions for next week

Please be encouraging, specific, and provide actionable advice. Aim for 300-400 words that are motivating and helpful. Use a friendly, professional tone.

IMPORTANT: Respond with ONLY the analysis text, no JSON formatting or code blocks.''';

    try {
      final response = await geminiService.getTextResponse(prompt);
      return response;
    } catch (e) {
      throw Exception('AI analysis failed: $e');
    }
  }

  void _showAnalysisDialog(BuildContext context, String analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[400]!, Colors.red[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.psychology,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'AI Progress Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.red[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    analysis,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This analysis is generated by AI and should not replace professional medical advice.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[800],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Keep up the great work! 💪'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
            ),
            child: Text(
              'Thanks!',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}