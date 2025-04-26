import 'package:flutter/material.dart';
import 'class_model.dart';

class AddTestPage extends StatefulWidget {
  final List<ClassModel> classes;

  const AddTestPage({super.key, required this.classes});

  @override
  _AddTestPageState createState() => _AddTestPageState();
}

class _AddTestPageState extends State<AddTestPage> {
  String? _selectedClass;
  final TextEditingController _testNameController = TextEditingController();
  final TextEditingController _partsController = TextEditingController();
  final TextEditingController _passingGradeController =
      TextEditingController(text: '50');
  int _numberOfParts = 0;

  final FocusNode _classFocusNode = FocusNode();
  final FocusNode _testNameFocusNode = FocusNode();
  final FocusNode _partsFocusNode = FocusNode();
  final FocusNode _passingGradeFocusNode = FocusNode();

  List<TextEditingController> _questionTypeControllers = [];

  @override
  void initState() {
    super.initState();
    _classFocusNode.addListener(() => setState(() {}));
    _testNameFocusNode.addListener(() => setState(() {}));
    _partsFocusNode.addListener(() => setState(() {}));
    _passingGradeFocusNode.addListener(() => setState(() {}));
    _partsController.addListener(() {
      setState(() {
        _numberOfParts = int.tryParse(_partsController.text) ?? 0;
        _questionTypeControllers =
            List.generate(_numberOfParts, (index) => TextEditingController());
      });
    });
  }

  @override
  void dispose() {
    _classFocusNode.dispose();
    _testNameFocusNode.dispose();
    _partsFocusNode.dispose();
    _passingGradeFocusNode.dispose();
    _testNameController.dispose();
    _partsController.dispose();
    _passingGradeController.dispose();
    for (var controller in _questionTypeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showQuestionTypeDialog(TextEditingController controller, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Question Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Multiple Choice'),
                onTap: () {
                  setState(() {
                    _questionTypeControllers[index].text = 'Multiple Choice';
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('True or False'),
                onTap: () {
                  setState(() {
                    _questionTypeControllers[index].text = 'True or False';
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('Identification'),
                onTap: () {
                  setState(() {
                    _questionTypeControllers[index].text = 'Identification';
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('Enumeration'),
                onTap: () {
                  setState(() {
                    _questionTypeControllers[index].text = 'Enumeration';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Test"),
        backgroundColor: const Color(0xFF800000), // Maroon color
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align everything to the start
            children: [
              Focus(
                onFocusChange: (hasFocus) {
                  setState(() {});
                },
                child: DropdownButtonFormField<String>(
                  focusNode: _classFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Class Name',
                    labelStyle: TextStyle(
                      color: _classFocusNode.hasFocus
                          ? const Color(0xFF800000)
                          : Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _classFocusNode.hasFocus
                            ? const Color(0xFF800000)
                            : Colors.grey,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF800000)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _classFocusNode.hasFocus
                            ? const Color(0xFF800000)
                            : Colors.grey,
                      ),
                    ),
                  ),
                  items: widget.classes.map((classItem) {
                    return DropdownMenuItem<String>(
                      value: classItem.program,
                      child: Text(
                          '${classItem.program} ${classItem.yearLevel} - ${classItem.section}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedClass = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _testNameController,
                focusNode: _testNameFocusNode,
                cursorColor: const Color(0xFF800000),
                decoration: InputDecoration(
                  labelText: 'Test Name',
                  labelStyle: TextStyle(
                    color: _testNameFocusNode.hasFocus
                        ? const Color(0xFF800000)
                        : Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _testNameFocusNode.hasFocus
                          ? const Color(0xFF800000)
                          : Colors.grey,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF800000)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _testNameFocusNode.hasFocus
                          ? const Color(0xFF800000)
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _partsController,
                focusNode: _partsFocusNode,
                keyboardType: TextInputType.number,
                cursorColor: const Color(0xFF800000),
                decoration: InputDecoration(
                  labelText: 'Parts',
                  labelStyle: TextStyle(
                    color: _partsFocusNode.hasFocus
                        ? const Color(0xFF800000)
                        : Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _partsFocusNode.hasFocus
                          ? const Color(0xFF800000)
                          : Colors.grey,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF800000)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _partsFocusNode.hasFocus
                          ? const Color(0xFF800000)
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _numberOfParts,
                itemBuilder: (context, index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Part ${index + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const TextField(
                        cursorColor: Color(0xFF800000),
                        decoration: InputDecoration(
                          labelText: 'Number of Questions',
                          labelStyle: TextStyle(
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF800000)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _questionTypeControllers[index],
                        readOnly: true,
                        cursorColor: const Color(0xFF800000),
                        onTap: () {
                          _showQuestionTypeDialog(
                              _questionTypeControllers[index], index);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Question Type',
                          labelStyle: TextStyle(
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF800000)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const TextField(
                        cursorColor: Color(0xFF800000),
                        decoration: InputDecoration(
                          labelText: 'Points',
                          labelStyle: TextStyle(
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF800000)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passingGradeController,
                focusNode: _passingGradeFocusNode,
                keyboardType: TextInputType.number,
                cursorColor: const Color(0xFF800000),
                decoration: InputDecoration(
                  labelText: 'Passing Grade (Percentage)',
                  labelStyle: TextStyle(
                    color: _passingGradeFocusNode.hasFocus
                        ? const Color(0xFF800000)
                        : Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _passingGradeFocusNode.hasFocus
                          ? const Color(0xFF800000)
                          : Colors.grey,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF800000)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _passingGradeFocusNode.hasFocus
                          ? const Color(0xFF800000)
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
