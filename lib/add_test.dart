import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'add_test_page.dart';
import 'exam_model.dart';
import 'class_model.dart';
import 'classpage.dart';
import 'settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'examdetailpage.dart';
import 'updateexampage.dart';

class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key});

  @override
  _ExamsPageState createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  bool _isRemovalMode = false; // Track whether we are in removal mode
  bool _isLoading = true; // Track loading state for shimmer effect

  @override
  void initState() {
    super.initState();
    _startLoading(); // Start shimmer loading
  }

  Future<void> _startLoading() async {
  await Future.delayed(
    const Duration(seconds: 3), // Simulate 3-second loading
  );

  // Only call setState if the widget is still mounted
  if (mounted) {
    setState(() {
      _isLoading = false; // Stop loading after 3 seconds
    });
  }
}

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    final examProvider = Provider.of<ExamProvider>(context, listen: true);

    // Fetch exams if the list is empty
    if (examProvider.exams.isEmpty) {
      examProvider.fetchAllExams(
        classProvider.classes.map((classModel) => classModel.id).toList(),
      );
    }

    Future<void> _refreshExams() async {
      await examProvider.fetchAllExams(
        classProvider.classes.map((classModel) => classModel.id).toList(),
      );
      print(
          "Exams refreshed: ${examProvider.exams.map((e) => e.testName).toList()}");
    }

    Future<void> _deleteExam(Exam exam) async {
  String? userId = await _getCurrentUserId();
  if (userId == null) {
    print("User is not logged in.");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You need to be logged in to delete exams.')),
    );
    return;
  }

  try {
    final examRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('classes')
        .doc(exam.classId) 
        .collection('exams')
        .doc(exam.id);

    print('Attempting to delete exam at path: ${examRef.path}');
    await examRef.delete();

    Provider.of<ExamProvider>(context, listen: false).removeExam(exam.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exam deleted: ${exam.testName}')),
    );
    print('Exam deleted successfully: ${exam.testName}');
  } catch (e) {
    print('Error deleting exam: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to delete exam. Please try again.')),
    );
  }
}


    Future<void> _removeSelectedExams(BuildContext context) async {
      final selectedExams =
          examProvider.exams.where((exam) => exam.isSelected).toList();

      if (selectedExams.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No exams selected for removal.')),
        );
        return;
      }

      final confirmDelete = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Deletion',),
            content: const Text(
                'Are you sure you want to delete the selected exams?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF800000)),),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('Delete', style: TextStyle(color: Color(0xFF800000)),),
              ),
            ],
          );
        },
      );

      if (confirmDelete == true) {
        for (var exam in selectedExams) {
          await _deleteExam(exam); // Call the delete method
        }
        examProvider.clearSelections(); // Clear selections after deletion
        await _refreshExams(); // Refresh the exam list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${selectedExams.length} exams deleted successfully.')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF800000),
        title: const Text("Exams",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 22)),
        actions: _isRemovalMode // Show different actions based on removal mode
            ? [
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isRemovalMode = false; // Exit removal mode
                      examProvider.clearSelections(); // Clear selections
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    _removeSelectedExams(context); // Remove selected exams
                  },
                ),
              ]
            : [
              TextButton(
            onPressed: () {
              Navigator.of(context)
                              .push(MaterialPageRoute(
                            builder: (context) => AddTestPage(classes: classProvider.classes),
                          ))
                              .then((_) async {
                            await _refreshExams(); // Refresh exams after adding a new exam
                           });
            },
            child: const Row(
              children: [
                Icon(Icons.add, color: Colors.white, size: 20), // Add Icon before text
                SizedBox(width: 5), // Spacing between icon and text
                Text(
                  "Add Exam",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: Colors.white, size: 28),
                  onSelected: (value) {
                    if (value == 'remove') {
                      setState(() {
                        _isRemovalMode = true; // Enter removal mode
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'remove', child: Text('Remove Exam')),
                  ],
                ),
              ],
      ),
      body: _isLoading
          ? _buildShimmerEffect() // Display shimmer while loading
          : RefreshIndicator(
            color: Color(0xFF800000),
              onRefresh: _refreshExams,
              child: examProvider.exams.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_add, size: 100, color: Colors.grey),
                          SizedBox(height: 20),
                          Text("No exam added.",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                          Text("Start adding exams.",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                          SizedBox(height:20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF800000),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(
                            builder: (context) => AddTestPage(classes: classProvider.classes),
                          ))
                              .then((_) async {
                            await _refreshExams(); // Refresh exams after adding a new exam
                           });
                        },
                        icon: Icon(Icons.add),
                        label: Text("Add Exam"),
                      ),
                        ],
                      ),
                    )
                  : ListView.builder(
  itemCount: examProvider.exams.length,
  itemBuilder: (context, index) {
    final exam = examProvider.exams[index];
    return Column(
  children: [
    ListTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exam.testName,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF707070)),
          ),
          Text(
            exam.subjectName,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF707070)),
          ),
        ],
      ),
      trailing: Wrap(
        spacing: 8, // Space between elements in trailing
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${exam.totalQuestions} items',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF707070),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6), // Space between rows
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person,
                      size: 18,
                      color: Color(0xFF800000)), // Person icon
                  const SizedBox(width: 4), // Space between icon and text
                  Text(
                    "${exam.className} - ${exam.classYearLevel}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF707070),
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => UpdateExamPage(exam: exam),
                    ),
                  )
                  .then((_) => _refreshExams());
            },
          ),
          if (_isRemovalMode)
            Checkbox(
              value: exam.isSelected,
              activeColor: const Color(0xFF800000),
              onChanged: (value) {
                setState(() {
                  exam.isSelected = value ?? false; // Toggle selection
                });
              },
            ),
        ],
      ),
      onTap: () async {
        String? userId = await _getCurrentUserId();
        if (userId != null) {
          final studentCollection = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('classes')
              .doc(exam.classId)
              .collection('students');

          final snapshot = await studentCollection.get();
          List<Map<String, String>> students = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'Last Name': (data['lastName'] ?? '').toString(),
              'First Name': (data['firstName'] ?? '').toString(),
              'Middle Name': (data['middleName'] ?? '').toString(),
            };
          }).toList();

          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ExamDetailPage(
              exam: exam,
              students: students,
            ),
          ));
        }
      },
    ),
    Divider(color: Colors.grey[300], thickness: 1.5),
  ],
);


  },
),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: const Color(0xFF800000),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ClassesScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Exams',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.builder(
      itemCount: 5, // Simulate 5 items for shimmer effect
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 80.0,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Future<String?> _getCurrentUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }
}

