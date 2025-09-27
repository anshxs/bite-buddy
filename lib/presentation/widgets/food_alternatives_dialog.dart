import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FoodAlternativesDialog extends StatefulWidget {
  final String originalFood;
  final Map<String, dynamic> analysis;
  final VoidCallback onKeepOriginal;
  final Function(String) onSelectAlternative;

  const FoodAlternativesDialog({
    Key? key,
    required this.originalFood,
    required this.analysis,
    required this.onKeepOriginal,
    required this.onSelectAlternative,
  }) : super(key: key);

  @override
  _FoodAlternativesDialogState createState() => _FoodAlternativesDialogState();
}

class _FoodAlternativesDialogState extends State<FoodAlternativesDialog> {
  String? selectedAlternative;

  @override
  Widget build(BuildContext context) {
    final List<String> alternatives =
        List<String>.from(widget.analysis['alternatives'] ?? []);
    final List<String> concerns =
        List<String>.from(widget.analysis['concerns'] ?? []);
    final String recommendation =
        widget.analysis['recommendation'] ?? 'Consider healthier options';
    final int healthScore = widget.analysis['healthScore'] ?? 5;

    return Dialog(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: AlertDialog(
          backgroundColor: const Color.fromARGB(255, 242, 242, 242),
          titlePadding: EdgeInsets.symmetric(vertical: 10),
          contentPadding: EdgeInsets.zero,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: Colors.orange,
                size: 28,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Healthier Alternatives Available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current food health analysis
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.restaurant,
                                color: Colors.red[600], size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.originalFood,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.red[600],
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getHealthScoreColor(healthScore),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Text(
                                'Score: $healthScore/10',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (concerns.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'Health Concerns:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          ...concerns
                              .map((concern) => Padding(
                                    padding:
                                        EdgeInsets.only(left: 16, bottom: 2),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('• ',
                                            style: TextStyle(
                                                color: Colors.red[600])),
                                        Expanded(
                                          child: Text(
                                            concern,
                                            style: TextStyle(
                                                color: Colors.red[600]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // AI Recommendation
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb,
                            color: Colors.blue[600], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Recommendation:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                recommendation,
                                style: TextStyle(color: Colors.blue[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (alternatives.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Suggested Healthier Alternatives:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    SizedBox(height: 8),

                    // Alternatives list
                    ...alternatives.asMap().entries.map((entry) {
                      final index = entry.key;
                      final alternative = entry.value;
                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedAlternative = alternative;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selectedAlternative == alternative
                                  ? Colors.green[100]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: selectedAlternative == alternative
                                    ? Colors.green[400]!
                                    : Colors.grey[300]!,
                                width:
                                    selectedAlternative == alternative ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: selectedAlternative == alternative
                                        ? Colors.green[600]
                                        : Colors.grey[400],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    alternative,
                                    style: TextStyle(
                                      fontWeight:
                                          selectedAlternative == alternative
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      color: selectedAlternative == alternative
                                          ? Colors.green[800]
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (selectedAlternative == alternative)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green[600],
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onKeepOriginal();
              },
              child: Text(
                'Keep Original',
                style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
              ),
            ),
            ElevatedButton(
              
              onPressed: selectedAlternative != null
                  ? () {
                      Navigator.of(context).pop();
                      widget.onSelectAlternative(selectedAlternative!);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 0, 0),
              ),
              child: Text(
                'Choose Healthier Option',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 7) return Colors.green[600]!;
    if (score >= 4) return Colors.orange[600]!;
    return Colors.red[600]!;
  }
}
