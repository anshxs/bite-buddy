import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/services/database_service.dart';
import '../../data/services/gemini_service.dart';
import 'package:fl_chart/fl_chart.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();
  
  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _foodLogs = [];
  Map<String, dynamic>? _nutritionalStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistoryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final weeklyProgress = await _dbService.getWeeklyProgress();
      final monthlyProgress = await _dbService.getMonthlyProgress();
      final nutritionalStats = await _dbService.getNutritionalStats();
      
      // Get recent food logs
      final now = DateTime.now();
      final weekAgo = now.subtract(Duration(days: 7));
      final startDate = weekAgo.toIso8601String().split('T')[0];
      final endDate = now.toIso8601String().split('T')[0];
      final recentFoodLogs = await _dbService.getFoodLogsByDateRange(startDate, endDate);

      setState(() {
        _weeklyData = weeklyProgress;
        _monthlyData = monthlyProgress;
        _foodLogs = recentFoodLogs;
        _nutritionalStats = nutritionalStats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Progress History',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: [
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Food Log'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your progress...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyTab(),
                _buildMonthlyTab(),
                _buildFoodLogTab(),
              ],
            ),
    );
  }

  Widget _buildWeeklyTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(),
          SizedBox(height: 16),
          _buildCalorieChart(_weeklyData, 'Weekly Calories'),
          SizedBox(height: 16),
          _buildMacroChart(),
          SizedBox(height: 16),
          // _buildAIAnalysisButton(),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(),
          SizedBox(height: 16),
          _buildCalorieChart(_monthlyData, 'Monthly Calories'),
          SizedBox(height: 16),
          _buildProgressSummary(),
          SizedBox(height: 16),
          // _buildAIAnalysisButton(),
        ],
      ),
    );
  }

  Widget _buildFoodLogTab() {
    return _foodLogs.isEmpty
        ? SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 100),
                Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No food logs yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Start logging your meals to see them here',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 40),
                // _buildAIAnalysisButton(),
              ],
            ),
          )
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _foodLogs.length,
                  itemBuilder: (context, index) {
                    final log = _foodLogs[index];
                    return _buildFoodLogCard(log);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: _buildAIAnalysisButton(),
              ),
            ],
          );
  }

  Widget _buildStatsCard() {
    if (_nutritionalStats == null) return SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutritional Averages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Avg Calories',
                    '${((_nutritionalStats?['avg_calories'] ?? 0) as num).round()}',
                    'kcal',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Protein',
                    '${((_nutritionalStats?['avg_protein'] ?? 0) as num).round()}g',
                    '/day',
                    Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Carbs',
                    '${((_nutritionalStats?['avg_carbs'] ?? 0) as num).round()}g',
                    '/day',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Fat',
                    '${((_nutritionalStats?['avg_fat'] ?? 0) as num).round()}g',
                    '/day',
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieChart(List<Map<String, dynamic>> data, String title) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('No data available', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length && i < 7; i++) {
      final calories = (data[i]['total_calories'] ?? 0) as num;
      spots.add(FlSpot(i.toDouble(), calories.toDouble()));
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
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

  Widget _buildMacroChart() {
    if (_nutritionalStats == null) return SizedBox.shrink();

    final protein = ((_nutritionalStats?['avg_protein'] ?? 0) as num).toDouble();
    final carbs = ((_nutritionalStats?['avg_carbs'] ?? 0) as num).toDouble();
    final fat = ((_nutritionalStats?['avg_fat'] ?? 0) as num).toDouble();
    final total = protein + carbs + fat;

    if (total == 0) return SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Macro Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: protein,
                      title: 'Protein\n${protein.round()}g',
                      color: Colors.red,
                      radius: 80,
                    ),
                    PieChartSectionData(
                      value: carbs,
                      title: 'Carbs\n${carbs.round()}g',
                      color: Colors.blue,
                      radius: 80,
                    ),
                    PieChartSectionData(
                      value: fat,
                      title: 'Fat\n${fat.round()}g',
                      color: Colors.green,
                      radius: 80,
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

  Widget _buildProgressSummary() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildProgressItem(
              'Days Logged',
              '${(_nutritionalStats?['days_logged'] ?? 0)}',
              Icons.calendar_today,
            ),
            _buildProgressItem(
              'Total Meals',
              '${_foodLogs.length}',
              Icons.restaurant,
            ),
            _buildProgressItem(
              'Avg Daily Calories',
              '${((_nutritionalStats?['avg_calories'] ?? 0) as num).round()} kcal',
              Icons.local_fire_department,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String title, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodLogCard(Map<String, dynamic> log) {
    final isHealthy = (log['is_healthy'] ?? 1) == 1;
    final healthScore = log['health_score'] ?? 5;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    log['food_name'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHealthy ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Score: $healthScore/10',
                    style: TextStyle(
                      fontSize: 12,
                      color: isHealthy ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '${log['calories']} kcal • ${log['meal_type']}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              '${log['logged_date']} at ${log['logged_time']}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (log['protein'] != null || log['carbs'] != null || log['fat'] != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (log['protein'] != null)
                      _buildMacroChip('P: ${log['protein'].round()}g', Colors.red),
                    if (log['carbs'] != null)
                      _buildMacroChip('C: ${log['carbs'].round()}g', Colors.blue),
                    if (log['fat'] != null)
                      _buildMacroChip('F: ${log['fat'].round()}g', Colors.green),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroChip(String text, Color color) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAIAnalysisButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue!,Colors.pink, Colors.red!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showAIAnalysis,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
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

  Future<void> _showAIAnalysis() async {
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
            Text('AI is analyzing your nutrition progress...'),
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
      final analysis = await _getAIProgressAnalysis();
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show analysis dialog
      _showAnalysisDialog(analysis);
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

  Future<String> _getAIProgressAnalysis() async {
    final geminiService = GeminiService();
    
    // Prepare progress data for analysis
    final stats = _nutritionalStats ?? {};
    final avgCalories = (stats['avg_calories'] ?? 0) as num;
    final avgProtein = (stats['avg_protein'] ?? 0) as num;
    final avgCarbs = (stats['avg_carbs'] ?? 0) as num;
    final avgFat = (stats['avg_fat'] ?? 0) as num;
    final daysLogged = (stats['days_logged'] ?? 0) as num;
    final totalMeals = _foodLogs.length;
    
    // Get recent food names for pattern analysis
    final recentFoods = _foodLogs.take(10).map((log) => log['food_name'] ?? 'Unknown').join(', ');
    
    final prompt = '''You are a certified nutritionist and health coach. Analyze this user's nutrition progress and provide comprehensive insights:

PROGRESS DATA:
- Days Logged: $daysLogged
- Total Meals: $totalMeals
- Average Daily Calories: ${avgCalories.round()}
- Average Protein: ${avgProtein.round()}g
- Average Carbs: ${avgCarbs.round()}g
- Average Fat: ${avgFat.round()}g
- Recent Foods: $recentFoods

ANALYSIS REQUEST:
Please provide a detailed analysis covering:
1. Overall nutrition balance assessment
2. Caloric intake evaluation (too high/low/appropriate)
3. Macronutrient ratios analysis
4. Food variety and quality insights
5. Specific recommendations for improvement
6. Congratulations on positive aspects
7. Areas of concern and suggestions

Please be encouraging, specific, and provide actionable advice. Aim for 300-400 words that are motivating and helpful. Use a friendly, professional tone.

IMPORTANT: Respond with ONLY the analysis text, no JSON formatting or code blocks.''';

    try {
      final response = await geminiService.getTextResponse(prompt);
      return response;
    } catch (e) {
      throw Exception('AI analysis failed: $e');
    }
  }

  void _showAnalysisDialog(String analysis) {
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