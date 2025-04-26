import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'class_model.dart';

class AddClassScreen extends StatefulWidget {
  const AddClassScreen({super.key});

  @override
  _AddClassScreenState createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> {
  final _programController = TextEditingController();
  final _courseController = TextEditingController();
  final _sectionController = TextEditingController();
  final _yearLevelController = TextEditingController();

  final FocusNode _programFocusNode = FocusNode();
  final FocusNode _courseFocusNode = FocusNode();
  final FocusNode _sectionFocusNode = FocusNode();
  final FocusNode _yearLevelFocusNode = FocusNode();


  bool _isAdding = false; // To manage button state
  @override
  void initState() {
    super.initState();
    _programFocusNode.addListener(() {
    setState(() {}); // Rebuilds when focus changes
  });
    _courseFocusNode.addListener(() {
    setState(() {}); // Rebuilds when focus changes
  });
  _sectionFocusNode.addListener(() {
    setState(() {}); // Rebuilds when focus changes
  });
  _yearLevelFocusNode.addListener(() {
    setState(() {}); // Rebuilds when focus changes
  });
  }

  @override
  void dispose() {
    _programController.dispose();
    _courseController.dispose();
    _sectionController.dispose();
    _yearLevelController.dispose();
    _programFocusNode.dispose();
    _courseFocusNode.dispose();
    _sectionFocusNode.dispose();
    _yearLevelFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addClass() async {
    if (_isAdding) return; // Prevent multiple taps

    setState(() {
      _isAdding = true;
    });

    try {
      // Only add class if all fields are filled
      if (_programController.text.isNotEmpty &&
          _courseController.text.isNotEmpty &&
          _sectionController.text.isNotEmpty &&
          _yearLevelController.text.isNotEmpty) {
        final newClass = ClassModel(
          id: '',
          program: _programController.text,
          course: _courseController.text,
          section: _sectionController.text,
          yearLevel: _yearLevelController.text,
        );

        // Use ClassProvider to add the class
        await Provider.of<ClassProvider>(context, listen: false)
            .addClass(newClass);

        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class successfully created!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop(); // Close the modal after adding the class
      } else {
        // Show error snackbar if fields are empty
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all fields'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error adding class: $e");
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Set up Class",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _programController,
                      focusNode: _programFocusNode,
                      cursorColor: Color(0xFF800000),
                      decoration: InputDecoration(
                        labelText: 'Program',
                        labelStyle: TextStyle(
                            color: _programFocusNode.hasFocus
                                ? Color(0xFF800000)
                                : Colors.black54,
                          ),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                           borderSide: BorderSide(color: const Color(0xFF800000)), // Maroon border when focused
                          ),
                     ),
                  ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _courseController,
                      focusNode: _courseFocusNode,
                      cursorColor: Color(0xFF800000),
                      decoration: InputDecoration(
                        labelText: 'Course',
                        labelStyle: TextStyle(
                            color: _courseFocusNode.hasFocus
                                ? Color(0xFF800000)
                                : Colors.black54,
                          ),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                           borderSide: BorderSide(color: const Color(0xFF800000)), // Maroon border when focused
                          ),
                     ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sectionController,
                      focusNode: _sectionFocusNode,
                      cursorColor: Color(0xFF800000),
                       decoration: InputDecoration(
                        labelText: 'Section',
                        labelStyle: TextStyle(
                            color: _sectionFocusNode.hasFocus
                                ? Color(0xFF800000)
                                : Colors.black54,
                          ),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                           borderSide: BorderSide(color: const Color(0xFF800000)), // Maroon border when focused
                          ),
                     ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _yearLevelController,
                      focusNode: _yearLevelFocusNode,
                      cursorColor: Color(0xFF800000),
                      decoration: InputDecoration(
                        labelText: 'Year Level',
                        labelStyle: TextStyle(
                            color: _yearLevelFocusNode.hasFocus
                                ? Color(0xFF800000)
                                : Colors.black54,
                          ),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                           borderSide: BorderSide(color: const Color(0xFF800000)), // Maroon border when focused
                          ),
                     ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Color(0xFF800000)),
                          ),
                        ),
                        TextButton(
                          onPressed: _isAdding ? null : _addClass,
                          child: const Text(
                            'Add',
                            style: TextStyle(color: Color(0xFF800000)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF800000)),
        ),
      ),
    );
  }
}
