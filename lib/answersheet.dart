import 'package:flutter/material.dart';

class GenerateAnswerSheetPage extends StatelessWidget {
  final int numberOfQuestions;
  final int points;

  const GenerateAnswerSheetPage({super.key, 
    required this.numberOfQuestions,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Answer Sheet'),
        backgroundColor: const Color(0xFF800000), // Maroon background
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Answer Sheet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: numberOfQuestions,
                itemBuilder: (context, index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${index + 1}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text('Answer: ________________'),
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),
            ),
            Text(
              'Total Points: $points',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
