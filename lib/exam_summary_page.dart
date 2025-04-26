import 'package:flutter/material.dart';
import 'exam_model.dart'; // Make sure this import points to your Exam model

class ExamSummaryPage extends StatelessWidget {
  final Exam exam;

  const ExamSummaryPage({super.key, required this.exam});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Exam Summary')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Test Name: ${exam.testName}',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            Text('Total Number of Questions: ${exam.totalQuestions}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Text('Class Name: ${exam.className}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
