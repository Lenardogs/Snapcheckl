import 'package:flutter/material.dart';
import 'answer_sheet_page.dart'; // Import the answer sheet page
import 'class_model.dart';
import 'exam_model.dart';
import 'package:provider/provider.dart';


class AddTestPage extends StatefulWidget {
  final List<ClassModel> classes;
  final Exam? existingExam;

  AddTestPage({required this.classes, this.existingExam});

  @override
  _AddTestPageState createState() => _AddTestPageState();
}

class _AddTestPageState extends State<AddTestPage> {
  String? _selectedClassId;
  String? _selectedClassProgram;
  String? _selectedClassYearLevel;
  String? _selectedsubjectName;
  final TextEditingController _testNameController = TextEditingController();
  int totalscore = 0;
  final TextEditingController _subjectNameController = TextEditingController();
  final TextEditingController _partsController = TextEditingController();
  final TextEditingController _passingGradeController =
      TextEditingController(text: '50');

  int _numberOfParts = 0; // Number of parts in the exam
  List<TextEditingController> _partNameControllers = [];
  List<TextEditingController> _questionTypeControllers = [];
  List<int> _numberOfQuestions = []; // List of number of questions for each part
  List<TextEditingController> _pointsControllers = []; // Points for each part

  final FocusNode _testNameFocusNode = FocusNode();
  final FocusNode _subjectNameFocusNode = FocusNode();
  final FocusNode _partsFocusNode = FocusNode();
  final FocusNode _questionTypeFocusNode = FocusNode();
  final FocusNode _pointsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _testNameFocusNode.addListener(() {
    setState(() {}); // Rebuilds when focus changes
  });
    // Load existing exam data if available
    if (widget.existingExam != null) {
      _loadExistingExam(widget.existingExam!);
    }

    // Listener for the parts controller to update parts and related fields
    _partsController.addListener(() {
      setState(() {
        // Parse the number of parts from the controller text
        _numberOfParts = int.tryParse(_partsController.text) ?? 0;

        // Limit the number of parts to 4
        if (_numberOfParts > 4) {
          _numberOfParts = 4;
          _partsController.text = '4'; // Reset the input text to 4
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Maximum 4 parts allowed')));
        }

        // Update the controllers and other lists based on the number of parts
        _partNameControllers =
            List.generate(_numberOfParts, (index) => TextEditingController());
        _questionTypeControllers =
            List.generate(_numberOfParts, (index) => TextEditingController());
        _numberOfQuestions = List.generate(_numberOfParts, (index) => 0);
        _pointsControllers =
            List.generate(_numberOfParts, (index) => TextEditingController());
      });
    });
  }

  // Load existing exam data into form fields
  void _loadExistingExam(Exam exam) {
    setState(() {
      _selectedClassId = exam.classId;
      _selectedClassProgram = exam.className;
      _selectedClassYearLevel = exam.classYearLevel;
      _selectedsubjectName = exam.subjectName;
      _testNameController.text = exam.testName;
      _subjectNameController.text = exam.subjectName;
      
      // Set number of parts
      _numberOfParts = exam.parts.length;
      _partsController.text = _numberOfParts.toString();

      // Initialize controllers for each part
      _partNameControllers = List.generate(_numberOfParts, (index) => TextEditingController());
      _questionTypeControllers = List.generate(_numberOfParts, (index) => TextEditingController(text: exam.parts[index].questionType));
      _numberOfQuestions = exam.parts.map((part) => part.numberOfQuestions).toList();
      _pointsControllers = List.generate(_numberOfParts, (index) => TextEditingController(text: exam.parts[index].points.toString()));
    });
  }

  void _showQuestionTypeDialog(TextEditingController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Question Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Multiple Choice'),
                onTap: () {
                  setState(() {
                    controller.text = 'Multiple Choice';
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('True or False'),
                onTap: () {
                  setState(() {
                    controller.text = 'True or False';
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Identification'),
                onTap: () {
                  setState(() {
                    controller.text = 'Identification';
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Enumeration'),
                onTap: () {
                  setState(() {
                    controller.text = 'Enumeration';
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _addExam() async {
    if (_selectedClassId == null || _testNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please select a class and enter a test name')));
      return;
    }

    if (_numberOfParts == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please specify the number of parts')));
      return;
    }

    // Validate that each part has required information
    for (int i = 0; i < _numberOfParts; i++) {
      if (_questionTypeControllers[i].text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please specify question type for part ${i + 1}')));
        return;
      }
      if (_numberOfQuestions[i] == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please specify number of questions for part ${i + 1}')));
        return;
      }
      if (_pointsControllers[i].text.isEmpty || int.tryParse(_pointsControllers[i].text) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please specify valid points for part ${i + 1}')));
        return;
      }
    }

    try {
      String classId = _selectedClassId!;
      String classProgram = _selectedClassProgram ?? '';
      String classYearLevel = _selectedClassYearLevel ?? '';
      String subjectName = _selectedsubjectName ?? '';
      int totalQuestions = _numberOfQuestions.fold(0, (a, b) => a + b);

      List<Part> parts = List.generate(_numberOfParts, (index) {
        return Part(
          questionType: _questionTypeControllers[index].text,
          numberOfQuestions: _numberOfQuestions[index],
          points: int.tryParse(_pointsControllers[index].text) ?? 0,
          
        );
      });

      if (parts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: No exam parts were created')));
        return;
      }

      if (totalQuestions > 80) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Only 80 items are allowed.'),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 3),
    ),
  );
  return; // Prevent further execution
}

      Exam exam = Exam(
        id: '', // Firestore will generate the ID
        testName: _testNameController.text,
        className: classProgram,
        classYearLevel: classYearLevel,
        classId: classId,
        subjectName: subjectName,
        totalQuestions: totalQuestions,
        totalScore: totalscore,
        parts: parts, // Include parts data
      );

      await Provider.of<ExamProvider>(context, listen: false)
          .addExam(exam, classId);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnswerSheetPage(
            testName: _testNameController.text,
            className: classProgram,
            classYearLevel: classYearLevel,
            subjectName: subjectName,
            parts: _numberOfParts,
            questionTypes: _questionTypeControllers.map((c) => c.text).toList(),
            numberOfQuestions: _numberOfQuestions,
            totalscore: totalscore,
            classId: classId,
          ),
        ),
      );
    } catch (e) {
      print('Error creating exam: $e'); // Add debug print
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error creating exam: $e')));
    }
  }

  @override
  void dispose() {
    _testNameController.dispose();
    _partsController.dispose();
    _passingGradeController.dispose();
    _subjectNameController.dispose();
    _partNameControllers.forEach((controller) => controller.dispose());
    _questionTypeControllers.forEach((controller) => controller.dispose());
    _pointsControllers.forEach((controller) => controller.dispose());
    _testNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF800000),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Text("Exam",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            Spacer(),
            ElevatedButton(
              onPressed: _addExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                side: BorderSide(color: Colors.white, width: 1.5),
                elevation: 0,
                foregroundColor: Colors.white,
              ),
              child: Text('Create Test'),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<ClassModel>(
              decoration: InputDecoration(
                labelText: 'Class Name and Course',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: const Color(0xFF800000)),
                ),
              ),
              value: _selectedClassId != null
                  ? widget.classes.firstWhere(
                      (classItem) => classItem.id == _selectedClassId,
                      orElse: () => widget.classes[0],
                    )
                  : null,
              items: widget.classes.map((classItem) {
                return DropdownMenuItem<ClassModel>(
                  value: classItem,
                  child: Text(
                      '${classItem.program} ${classItem.yearLevel} - ${classItem.section} | ${classItem.course}',
                      style: TextStyle(fontSize: 11), // Adjust font size
                      overflow: TextOverflow.ellipsis, // Add ellipsis if the text overflows),
                  ),
                );
              }).toList(),
              onChanged: (ClassModel? selectedClass) {
                setState(() {
                  _selectedClassId = selectedClass?.id;
                  _selectedClassProgram = selectedClass?.program;
                  _selectedClassYearLevel = selectedClass?.yearLevel;
                  _selectedsubjectName = selectedClass?.course;
                });
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: _testNameController,
              focusNode: _testNameFocusNode,
              cursorColor: Color(0xFF800000),
              decoration: InputDecoration(
                labelText: 'Test Name',
                labelStyle: TextStyle(
                  color: _testNameFocusNode.hasFocus
                      ? Color(0xFF800000)
                      : Colors.black54,
                ),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: const Color(0xFF800000)),
                ),
              ),
            ),
            SizedBox(height: 16),
        

            TextField(
              controller: _partsController,
              focusNode: _partsFocusNode,
              cursorColor: Color(0xFF800000),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Parts (Max 4)',
                labelStyle: TextStyle(
                  color: _partsFocusNode.hasFocus
                      ? Color(0xFF800000)
                      : Colors.black54,
                ),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: const Color(0xFF800000)),
                ),
              ),
            ),
            SizedBox(height: 16),
            if (_numberOfParts > 0) // Only show parts when they are added
              ListView.builder(
                itemCount: _numberOfParts,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return Card(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    elevation: 3,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Part ${index + 1}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 8),
                          TextField(
                            controller: _questionTypeControllers[index],
                            cursorColor: const Color(0xFF800000),
                            onTap: () => _showQuestionTypeDialog(
                                _questionTypeControllers[index]),
                            decoration: InputDecoration(
                              labelText: 'Question Type',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: const Color(0xFF800000)),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
  keyboardType: TextInputType.number,
  cursorColor: const Color(0xFF800000),
  onChanged: (value) {
    setState(() {
      _numberOfQuestions[index] = int.tryParse(value) ?? 0;
      // Removed the max 15 questions condition
    });
  },
  decoration: InputDecoration(
    labelText: 'Number of Questions',
    border: OutlineInputBorder(),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: const Color(0xFF800000)),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _pointsControllers[index],
                            cursorColor: const Color(0xFF800000),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Points for this part',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: const Color(0xFF800000)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
