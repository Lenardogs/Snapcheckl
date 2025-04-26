import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'exam_model.dart';
import 'add_test.dart';

class UpdateExamPage extends StatefulWidget {
  final Exam exam;
  const UpdateExamPage({Key? key, required this.exam}) : super(key: key);

  @override
  _UpdateExamPageState createState() => _UpdateExamPageState();
}

class _UpdateExamPageState extends State<UpdateExamPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _classNameController;
  late TextEditingController _testNameController;
  final FocusNode _testNameFocusNode = FocusNode();
  bool _isUpdating = false; // To track loading state

  @override
  void initState() {
    super.initState();
    _classNameController = TextEditingController(
        text:
            '${widget.exam.className} ${widget.exam.classYearLevel} | ${widget.exam.subjectName}');
    _testNameController = TextEditingController(text: widget.exam.testName);
    _testNameFocusNode.addListener(() {
      setState(() {}); // Rebuilds when focus changes
    });
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _testNameController.dispose();
    _testNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Update Exam',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF800000),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Class Name and Course',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _classNameController,
                  enabled: false, // Disable the class name field
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[200], // Light gray background
                    border: const OutlineInputBorder(),
                    disabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Test Name',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _testNameController,
                  focusNode: _testNameFocusNode,
                  cursorColor: Color(0xFF800000),
                  decoration: InputDecoration(
                    labelText: 'Enter test name',
                    labelStyle: TextStyle(
                      color: _testNameFocusNode.hasFocus
                          ? Color(0xFF800000)
                          : Colors.black54,
                    ),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Color(0xFF800000),
                          width: 2.0), // Maroon border when focused
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the test name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUpdating
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _updateExam();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF800000),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isUpdating
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            'Update Exam',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateExam() async {
    setState(() {
      _isUpdating = true; // Show loading indicator
    });

    try {
      List<Part> updatedParts = widget.exam.parts;

      Exam updatedExam = Exam(
        id: widget.exam.id,
        className: widget.exam.className,
        classYearLevel: widget.exam.classYearLevel,
        subjectName: widget.exam.subjectName,
        testName: _testNameController.text,
        classId: widget.exam.classId,
        totalQuestions: widget.exam.totalQuestions,
        totalScore: widget.exam.totalScore,
        parts: updatedParts,
      );

      await Provider.of<ExamProvider>(context, listen: false)
          .updateExam(updatedExam);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam updated successfully!'),
            backgroundColor: Colors.green, // Set background color to green
            behavior: SnackBarBehavior.floating, // Optional: Floating style
          ),
        );

        // Refresh exams in ExamsPage and navigate to AddTestPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ExamsPage()),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating exam: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
}
