import 'package:flutter/material.dart';
import 'answersheet.dart';

class CreateAnswerSheetPage extends StatefulWidget {
  final List<String> questionTypes; // Updated to accept question types

  const CreateAnswerSheetPage({super.key, required this.questionTypes});

  @override
  _CreateAnswerSheetPageState createState() => _CreateAnswerSheetPageState();
}

class _CreateAnswerSheetPageState extends State<CreateAnswerSheetPage> {
  final List<TextEditingController> _numberOfQuestionsControllers = [];
  final List<TextEditingController> _pointsControllers = [];
  final TextEditingController _passingGradeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers for each part based on question types
    for (int i = 0; i < widget.questionTypes.length; i++) {
      _numberOfQuestionsControllers.add(TextEditingController());
      _pointsControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    for (var controller in _numberOfQuestionsControllers) {
      controller.dispose();
    }
    for (var controller in _pointsControllers) {
      controller.dispose();
    }
    _passingGradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Answer Sheet'),
        backgroundColor: const Color(0xFF800000), // Maroon background
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ...List.generate(widget.questionTypes.length, (index) {
            final questionType = widget.questionTypes[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Part ${index + 1} ($questionType)', // Set title based on question type
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _numberOfQuestionsControllers[index],
                    decoration: const InputDecoration(
                      labelText: 'Number of Questions',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pointsControllers[index],
                    decoration: const InputDecoration(
                      labelText: 'Points',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }),
          TextField(
            controller: _passingGradeController,
            decoration: const InputDecoration(
              labelText: 'Passing Grade (percentage %)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Navigate to GenerateAnswerSheetPage with captured values
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenerateAnswerSheetPage(
                        numberOfQuestions:
                            int.parse(_numberOfQuestionsControllers[0].text),
                        points: int.parse(_pointsControllers[0].text),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF800000), // Maroon background
                  foregroundColor: Colors.white, // White text
                ),
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
