import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'exam_model.dart';
import 'class_model.dart';


class ExamPage extends StatefulWidget {
  const ExamPage({Key? key}) : super(key: key);

  @override
  _ExamPageState createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  String? _selectedClassId; // Track selected class ID
  final TextEditingController _testNameController = TextEditingController();
  final TextEditingController _subjectNameController = TextEditingController();
  int _totalQuestions = 0; // Store total questions input
  int _parts = 1; // Default parts to 1 for now
  List<String> _questionTypes = []; // List to hold question types
  List<int> _numberOfQuestions = []; // List to hold number of questions
  int _totalScore = 0;
  List<int> _pointsPerPart = []; // List to hold points per part

  @override
  Widget build(BuildContext context) {
    // Get the ExamProvider and ClassProvider from the context
    final examProvider = Provider.of<ExamProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams'),
        centerTitle: false,
      ),
      body: ListView.builder(
        itemCount: examProvider.exams.length,
        itemBuilder: (context, index) {
          final exam = examProvider.exams[index];
          return ListTile(
            title: Text(exam.testName),
            subtitle: Text('${exam.className} - ${exam.totalQuestions} questions'),
            onTap: () {
              // Optionally navigate to exam details or perform other actions
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddExamDialog(context, classProvider.classes);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddExamDialog(BuildContext context, List<ClassModel> classes) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Exam'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ClassModel>(
                decoration: InputDecoration(
                  labelText: 'Select Class',
                  border: OutlineInputBorder(),
                ),
                items: classes.map((classItem) {
                  return DropdownMenuItem<ClassModel>(
                    value: classItem,
                    child: Text('${classItem.program} ${classItem.yearLevel} - ${classItem.section}'),
                  );
                }).toList(),
                onChanged: (ClassModel? selectedClass) {
                  setState(() {
                    _selectedClassId = selectedClass?.id; // Store the selected class ID
                  });
                },
              ),
              TextField(
                controller: _testNameController,
                decoration: InputDecoration(
                  labelText: 'Test Name',
                  border: OutlineInputBorder(),
                ),
              ),
              TextField(
                controller: _subjectNameController,
                decoration: InputDecoration(
                  labelText: 'Subject Name',
                  border: OutlineInputBorder(),
                ),
              ),
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _totalQuestions = int.tryParse(value) ?? 0;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Total Questions',
                  border: OutlineInputBorder(),
                ),
              ),
              // Add additional fields for parts, question types, and points
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _parts = int.tryParse(value) ?? 1;
                    _questionTypes = List.filled(_parts, 'Multiple Choice');
                    _numberOfQuestions = List.filled(_parts, 0);
                    _pointsPerPart = List.filled(_parts, 0);
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Number of Parts',
                  border: OutlineInputBorder(),
                ),
              ),
              for (int i = 0; i < _parts; i++) ...[
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _questionTypes[i] = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Question Type for Part ${i + 1}',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _numberOfQuestions[i] = int.tryParse(value) ?? 0;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Number of Questions for Part ${i + 1}',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _pointsPerPart[i] = int.tryParse(value) ?? 0;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Points for Part ${i + 1}',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_selectedClassId == null || 
                    _testNameController.text.isEmpty || 
                    _subjectNameController.text.isEmpty || 
                    _totalQuestions <= 0 || 
                    _numberOfQuestions.contains(0) || 
                    _pointsPerPart.contains(0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields correctly.')),
                  );
                  return;
                }

                // Create new exam object
                Exam newExam = Exam(
  id: '', // Firestore will generate the ID
  testName: _testNameController.text,
  className: classes.firstWhere((classItem) => classItem.id == _selectedClassId).program, // Get the program
  classYearLevel: classes.firstWhere((classItem) => classItem.id == _selectedClassId).yearLevel,
  classId: _selectedClassId!,
  subjectName: _subjectNameController.text,
  totalQuestions: _totalQuestions,
  totalScore: _totalScore,
  parts: [], // Provide an empty list if no parts are available initially
);


                // Add the exam using the ExamProvider
                await Provider.of<ExamProvider>(context, listen: false).addExam(newExam, _selectedClassId!);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exam added successfully!')),
                );

                Navigator.of(context).pop(); // Close the dialog
                setState(() {
                  _testNameController.clear();
                  _subjectNameController.clear();
                  _totalQuestions = 0; // Reset total questions
                  _parts = 1;
                  _questionTypes.clear();
                  _numberOfQuestions.clear();
                  _pointsPerPart.clear();
                });
              },
              child: const Text('Add Exam'),
            ),
          ],
        );
      },
    );
  }
}
