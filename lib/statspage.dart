import 'package:flutter/material.dart';
import 'exam_model.dart';

class StatisticsPage extends StatelessWidget {
  final Exam exam;

  const StatisticsPage({super.key, required this.exam});

  @override
  Widget build(BuildContext context) {
    // Dummy data for demonstration. Replace these with actual calculations later.
    double accuracyPercentage = 85.0;
    double passingRatePercentage = 75.0;
    int highestScore = 95;
    int lowestScore = 55;

    List<Map<String, dynamic>> itemAnalysis = [
      {
        "question": 1,
        "correct": 20,
        "incorrect": 5,
        "percentage": 80.0,
        "difficulty": "Average",
        "discrimination": "Good"
      },
      {
        "question": 2,
        "correct": 18,
        "incorrect": 7,
        "percentage": 72.0,
        "difficulty": "Difficult",
        "discrimination": "Marginal"
      },
      {
        "question": 3,
        "correct": 22,
        "incorrect": 3,
        "percentage": 88.0,
        "difficulty": "Easy",
        "discrimination": "Excellent"
      },
      // Add more questions as needed
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Colors.white), // White back button
          onPressed: () {
            Navigator.pop(context); // Navigate back
          },
        ),
        title: Text(
          'Statistics for ${exam.testName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ), // White title text color
        ),
        backgroundColor: const Color(0xFF800000), // Maroon background color
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWideScreen =
              constraints.maxWidth > 600; // Adjust the width as needed

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDashboardItem('Accuracy', '$accuracyPercentage%'),
                _buildDashboardItem('Passing Rate', '$passingRatePercentage%'),
                _buildDashboardItem('Highest Score', '$highestScore'),
                _buildDashboardItem('Lowest Score', '$lowestScore'),
                const SizedBox(height: 20),
                Text(
                  'Item Analysis',
                  style: TextStyle(
                    fontSize: isWideScreen ? 24 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildItemAnalysisTable(itemAnalysis, isWideScreen),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardItem(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, color: Color(0xFF800000)),
        ),
      ),
    );
  }

  Widget _buildItemAnalysisTable(
      List<Map<String, dynamic>> itemAnalysis, bool isWideScreen) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
              label: Text('Question No.',
                  style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
          DataColumn(
              label: Text('Correct',
                  style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
          DataColumn(
              label: Text('Incorrect',
                  style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
          DataColumn(
              label: Text('Percentage',
                  style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
          DataColumn(
              label: Text('Difficulty',
                  style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
          DataColumn(
              label: Text('Discrimination',
                  style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
        ],
        rows: itemAnalysis.map((item) {
          return DataRow(cells: [
            DataCell(Text('${item["question"]}',
                style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
            DataCell(Text('${item["correct"]}',
                style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
            DataCell(Text('${item["incorrect"]}',
                style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
            DataCell(Text('${item["percentage"]}%',
                style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
            DataCell(Text('${item["difficulty"]}',
                style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
            DataCell(Text('${item["discrimination"]}',
                style: TextStyle(fontSize: isWideScreen ? 16 : 14))),
          ]);
        }).toList(),
      ),
    );
  }
}
