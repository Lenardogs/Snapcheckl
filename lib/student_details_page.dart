import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'add_student_dialog.dart';
import 'class_model.dart';
import 'student_model.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class StudentDetailsPage extends StatefulWidget {
  final ClassModel classItem;

  const StudentDetailsPage({super.key, required this.classItem});

  @override
  _StudentDetailsPageState createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  bool _isLoading = false;
  bool _isSelectionMode = false;
  bool _isAllSelected = false; // Flag to track if all items are selected
  final List<int> _selectedStudents = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<String?> _getCurrentUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  void _loadInitialData() async {
    String? userId = await _getCurrentUserId();
    if (userId != null) {
      final studentCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(widget.classItem.id)
          .collection('students');

      final snapshot = await studentCollection.get();

      if (!mounted) return; // Check if the widget is still mounted

      List<Map<String, String>> loadedStudents = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'Last Name': (data['lastName'] ?? '').toString(),
          'First Name': (data['firstName'] ?? '').toString(),
          'Middle Name': (data['middleName'] ?? '').toString(),
        };
      }).toList();

      if (mounted) {
        // Check again before updating the provider
        Provider.of<StudentProvider>(context, listen: false)
            .loadStudents(loadedStudents);
      }
    }
  }

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddStudentDialog(
          lastNameController: TextEditingController(),
          firstNameController: TextEditingController(),
          middleNameController: TextEditingController(),
          onAddStudent: (lastName, firstName, middleName) async {
            String? userId = await _getCurrentUserId();
            if (userId != null) {
              // Add the student to Firestore
              Provider.of<StudentProvider>(context, listen: false).addStudent(
                  userId, widget.classItem.id, lastName, firstName, middleName);

              // Add the new student to the local state immediately
              setState(() {
                Provider.of<StudentProvider>(context, listen: false)
                    .students
                    .add({
                  'Last Name': lastName,
                  'First Name': firstName,
                  'Middle Name': middleName,
                });
              });

              _showSuccessSnackbar('Student added successfully');
              // Close the dialog
            }
          },
        );
      },
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Import Students',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.red[50], // Light red background
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF800000), // Maroon color
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'XLSX file must have column names LAST NAME, FIRST NAME, and MIDDLE NAME.',
                        style: TextStyle(
                          color: Color(0xFF800000), // Maroon color
                          fontWeight: FontWeight.normal, // Normal font weight
                        ),
                        textAlign:
                            TextAlign.justify, // Justified text alignment
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, // Ensure it takes the full width
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _downloadTemplate(context);
                  },
                  icon: const Icon(Icons.download, color: Colors.grey),
                  label: const Text(
                    'Download Template',
                    style: TextStyle(
                      color: Color(0xFF800000),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFF800000), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, // Ensure it takes the full width
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                    _pickFile(); // Open file manager after closing the dialog
                  },
                  icon: const Icon(
                    Icons.insert_drive_file,
                    color: Colors.grey, // Gray icon
                  ),
                  label: const Text(
                    'Click to upload',
                    style: TextStyle(
                      color: Color(0xFF800000), // Maroon text
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF800000), // Maroon border
                      width: 1.5, // Border width
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF800000)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
    });

    String? userId = await _getCurrentUserId();
    if (userId == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xls', 'xlsx'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;

      if (file.path != null) {
        try {
          var bytes = File(file.path!).readAsBytesSync();
          var excel = Excel.decodeBytes(bytes);

          List<Map<String, String>> importedStudents = [];

          for (var table in excel.tables.keys) {
            var sheet = excel.tables[table];
            if (sheet != null) {
              bool isFirstRow = true;
              for (var row in sheet.rows) {
                if (isFirstRow) {
                  isFirstRow = false;
                  continue;
                }

                if (row.isNotEmpty && row.length >= 3) {
                  var lastName = _getCellValue(row[0]);
                  var firstName = _getCellValue(row[1]);
                  var middleName = _getCellValue(row[2]);

                  if (lastName.isNotEmpty && firstName.isNotEmpty) {
                    var studentData = {
                      'Last Name': lastName,
                      'First Name': firstName,
                      'Middle Name': middleName,
                    };
                    importedStudents.add(studentData);

                    Provider.of<StudentProvider>(context, listen: false)
                        .addStudent(
                      userId,
                      widget.classItem.id,
                      lastName,
                      firstName,
                      middleName,
                    );
                  }
                }
              }
            }
          }

          Provider.of<StudentProvider>(context, listen: false)
              .addImportedStudents(importedStudents);
          _showSuccessSnackbar('Students imported successfully');
        } catch (e) {
          _showErrorSnackbar('Error importing file: $e');
        }
      }
    } else {
      print('File picking was canceled.');
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Helper function to safely extract cell values
  String _getCellValue(Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red, // Success color
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    try {
      // Load the Excel template from assets
      ByteData data = await rootBundle.load('assets/images/Format.xlsx');
      final buffer = data.buffer;

      // Get the Downloads directory
      Directory downloadsDirectory = Directory('/storage/emulated/0/Download');

      // Ensure the Downloads directory exists
      if (!downloadsDirectory.existsSync()) {
        throw Exception("Downloads directory not found");
      }

      // Construct the initial file path
      String filePath = '${downloadsDirectory.path}/STUDENTFORMAT.xlsx';

      // Create a unique filename if the file already exists
      int counter = 1;
      String newFilePath = filePath;
      while (File(newFilePath).existsSync()) {
        newFilePath = '${downloadsDirectory.path}/STUDENTFORMAT($counter).xlsx';
        counter++;
      }

      // Save the file
      File file = File(newFilePath);
      await file.writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true, // Ensures data is written immediately
      );

      // Show a success message
      _showSuccessSnackbar1(context, 'Template saved to: $newFilePath');
    } catch (e) {
      print('Error downloading template: $e');
      _showSuccessSnackbar1(context, 'Error downloading template');
    }
  }

  void _showSuccessSnackbar1(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _editStudent(int index) async {
    String? userId = await _getCurrentUserId();
    if (userId == null) return;

    final students =
        Provider.of<StudentProvider>(context, listen: false).students;
    if (index >= students.length) return;

    final student = students[index];
    TextEditingController lastNameController =
        TextEditingController(text: student['Last Name']);
    TextEditingController firstNameController =
        TextEditingController(text: student['First Name']);
    TextEditingController middleNameController =
        TextEditingController(text: student['Middle Name']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddStudentDialog(
          lastNameController: lastNameController,
          firstNameController: firstNameController,
          middleNameController: middleNameController,
          onAddStudent: (lastName, firstName, middleName) {
            Provider.of<StudentProvider>(context, listen: false).updateStudent(
                userId,
                widget.classItem.id,
                index,
                lastName,
                firstName,
                middleName);

            _showSuccessSnackbar('Student updated successfully');
          },
          isEditing: true,
        );
      },
    );
  }

  void _deleteStudent(int index) async {
    String? userId = await _getCurrentUserId();
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              )),
          content:
              const Text('Are you sure you want to delete selected student?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF800000))),
            ),
            TextButton(
              onPressed: () {
                Provider.of<StudentProvider>(context, listen: false)
                    .deleteStudent(userId, widget.classItem.id, index);
                Navigator.of(context).pop();
                _showSuccessSnackbar('Student deleted successfully');
              },
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFF800000))),
            ),
          ],
        );
      },
    );
  }

  void _deleteSelectedStudents() async {
    String? userId = await _getCurrentUserId();
    if (userId == null || _selectedStudents.isEmpty) return;

    // Store the current context in a local variable
    BuildContext dialogContext = context;

    showDialog(
      context: dialogContext, // Use the stored context
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Confirm Deletion',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content:
              const Text('Are you sure you want to delete selected students?'),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF800000)),
              ),
            ),
            // Delete button
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close dialog first

                setState(() {
                  _isLoading = true;
                });

                // Sort the selected indexes in descending order
                _selectedStudents.sort((a, b) => b.compareTo(a));

                try {
                  for (int index in _selectedStudents) {
                    await Provider.of<StudentProvider>(dialogContext,
                            listen: false)
                        .deleteStudent(userId, widget.classItem.id, index);
                  }
                  _showSuccessSnackbar(
                      'Selected students deleted successfully');
                } catch (e) {
                  _showErrorSnackbar(
                      'An error occurred while deleting students');
                  print(e);
                } finally {
                  _loadInitialData();
                  setState(() {
                    _isSelectionMode = false;
                    _selectedStudents.clear();
                    _isAllSelected = false;
                    _isLoading = false;
                  });
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFF800000)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedStudents.clear();
      _isAllSelected = false; // Reset select-all state
    });
  }

  void _selectAllStudents() {
    setState(() {
      if (_isAllSelected) {
        _selectedStudents.clear();
      } else {
        _selectedStudents.clear();
        for (int i = 0;
            i <
                Provider.of<StudentProvider>(context, listen: false)
                    .students
                    .length;
            i++) {
          _selectedStudents.add(i);
        }
      }
      _isAllSelected = !_isAllSelected; // Toggle select all state
    });
  }

  void _sortStudents(bool ascending) {
    final studentProvider =
        Provider.of<StudentProvider>(context, listen: false);
    studentProvider.sortStudentsByLastName(ascending);
  }

  @override
  Widget build(BuildContext context) {
    final students = Provider.of<StudentProvider>(context).students;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 35,
        titleSpacing:
            0, // Removes default spacing between back button and title
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Student Details',
            style: TextStyle(
              fontSize: 19,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF800000),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isSelectionMode) ...[
            TextButton(
              onPressed: _showAddStudentDialog,
              child: const Row(
                children: [
                  Icon(Icons.add,
                      color: Colors.white, size: 20), // Add Icon before text
                  SizedBox(width: 2), // Spacing between icon and text
                  Text(
                    "Add Student",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'remove') {
                  _toggleSelectionMode();
                } else if (value == 'ascending') {
                  _sortStudents(true);
                } else if (value == 'descending') {
                  _sortStudents(false);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove Students'),
                ),
                const PopupMenuItem(
                  value: 'ascending',
                  child: Text('Sort Ascending'),
                ),
                const PopupMenuItem(
                  value: 'descending',
                  child: Text('Sort Descending'),
                ),
              ],
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                _isAllSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: Colors.white,
              ),
              onPressed: _selectAllStudents,
              tooltip: "Select All",
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 5.0),
                child: Text(
                  "All",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF800000)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(top: 10.0, left: 20.0, right: 22.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment
                              .spaceBetween, // Space between text and icon
                          children: [
                            Text(
                              'Students (${students.length})',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF707070),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.upload_file,
                                  color: Color(0xFF800000)), // Maroon color
                              iconSize: 25.0,
                              onPressed: _showImportDialog,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outline,
                                  size: 100, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No student added.',
                                style:
                                    TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF800000),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                onPressed: _showAddStudentDialog,
                                icon: Icon(Icons.add),
                                label: Text("Add Student"),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final isSelected =
                                _selectedStudents.contains(index);
                            // Extract the first letter of the student's last name
                            String lastName = student['Last Name'] ?? '';
                            String initial = lastName.isNotEmpty
                                ? lastName[0].toUpperCase()
                                : '';

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 10.0, bottom: 10.0, right: 0.5),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 20.0,
                                      backgroundColor: Colors.red[100],
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: Color(0xFF800000),
                                          fontSize: 18.0,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      '${student['Last Name']}, ${student['First Name']} ${student['Middle Name']}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF707070)),
                                    ),
                                    trailing: _isSelectionMode
                                        ? Checkbox(
                                            value: isSelected,
                                            activeColor: Color(0xFF800000),
                                            onChanged: (bool? selected) {
                                              setState(() {
                                                if (selected == true) {
                                                  _selectedStudents.add(index);
                                                } else {
                                                  _selectedStudents
                                                      .remove(index);
                                                }
                                              });
                                            },
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () =>
                                                    _editStudent(index),
                                                color: Color(0xFF707070),
                                                iconSize: 20.0,
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: () =>
                                                    _deleteStudent(index),
                                                color: Color(0xFF707070),
                                                iconSize: 20.0,
                                              ),
                                            ],
                                          ),
                                    onTap: _isSelectionMode
                                        ? () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedStudents.remove(index);
                                              } else {
                                                _selectedStudents.add(index);
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                ),
                                Divider(
                                  color: Colors.grey[300],
                                  thickness: 1.5,
                                  height: 5.0,
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _isSelectionMode
          ? Padding(
              padding: const EdgeInsets.only(
                  bottom: 35), // Adjust to move buttons upward
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 120, // Adjust width
                    height: 50, // Adjust height
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedStudents.clear();
                          _isAllSelected = false;
                        });
                      },
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180, // Adjust width
                    height: 50, // Adjust height
                    child: FloatingActionButton.extended(
                      onPressed: _deleteSelectedStudents,
                      backgroundColor: const Color(0xFF800000),
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.delete),
                      label:
                          Text('Delete Selected (${_selectedStudents.length})'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            )
          : null,
    );
  }
}
