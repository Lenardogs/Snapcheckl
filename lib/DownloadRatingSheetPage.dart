import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class DownloadRatingSheetPage extends StatefulWidget {
  final String classId; // Class ID to identify the class
  final String examId; // Exam ID to identify the exam

  const DownloadRatingSheetPage({
    Key? key,
    required this.classId,
    required this.examId,
  }) : super(key: key);

  @override
  _DownloadRatingSheetPageState createState() =>
      _DownloadRatingSheetPageState();
}

class _DownloadRatingSheetPageState extends State<DownloadRatingSheetPage> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String _selectedBase = 'Base 50';
  int? _totalItems; // Changed from totalQuestions to totalItems

  @override
  void initState() {
    super.initState();
    _fetchExamDetails();
  }

  Future<void> _fetchExamDetails() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('User not logged in');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final examDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(widget.classId)
          .collection('exams')
          .doc(widget.examId)
          .get();

      if (examDoc.exists) {
        final examData = examDoc.data();
        final List<dynamic> parts = examData?['parts'] ?? [];
        int totalPoints = 0;

        // Calculate total items by summing the totalPoints of each part
        int totalItems = 0;
        for (var part in parts) {
          totalItems += (part['totalPoints'] as num).toInt();
        }

        // Store the totalItems in the exam for calculation purposes
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('classes')
            .doc(widget.classId)
            .collection('exams')
            .doc(widget.examId)
            .update({'totalItems': totalItems});

        setState(() {
          _totalItems = totalItems; // Store the calculated totalItems
        });
      }

      _fetchStudentScores();
    } catch (e) {
      print('Error fetching exam details: $e');
      setState(() => _isLoading = false);
    }
  }

  double calculateBaseScore(int score, String base) {
    final int totalItems =
        _totalItems ?? 1; // Use totalItems instead of totalQuestions
    if (base == 'Base 50') {
      return (score / totalItems) * 50 + 50;
    } else {
      return (score / totalItems) * 40 + 60;
    }
  }

  Future<void> _fetchStudentScores() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final studentCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(widget.classId)
          .collection('students');

      final snapshot = await studentCollection.get();
      List<Map<String, dynamic>> students = [];

      for (var studentDoc in snapshot.docs) {
        Map<String, dynamic> studentData = Map<String, dynamic>.from(
            studentDoc.data() as Map<String, dynamic>);
        final scannedResultsSnapshot = await studentDoc.reference
            .collection('exams')
            .doc(widget.examId)
            .collection('scanned_results')
            .get();

        int totalScore = scannedResultsSnapshot.docs.isNotEmpty
            ? scannedResultsSnapshot.docs.first.data()['score'] ?? 0
            : 0;

        students.add({
          'Student ID': studentDoc.id,
          'First Name': studentData['firstName'] ?? '',
          'Last Name': studentData['lastName'] ?? '',
          'Score': totalScore,
        });
      }

      students.sort((a, b) => a['Last Name']
          .toString()
          .toLowerCase()
          .compareTo(b['Last Name'].toString().toLowerCase()));

      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(students);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching student scores: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> generateExcel() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    String subjectName = '';
    String testName = '';

    try {
      final examDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(widget.classId)
          .collection('exams')
          .doc(widget.examId)
          .get();

      if (examDoc.exists) {
        final examData = examDoc.data();
        subjectName = examData?['subjectName'] ?? 'UnknownSubject';
        testName = examData?['testName'] ?? 'UnknownTest';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch exam details: $e')),
      );
      return;
    }

    _students.sort((a, b) => a['Last Name']
        .toString()
        .toLowerCase()
        .compareTo(b['Last Name'].toString().toLowerCase()));

    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.getRangeByName('A1').setText('Last Name');
    sheet.getRangeByName('B1').setText('First Name');
    sheet.getRangeByName('C1').setText('Score');
    sheet.getRangeByName('D1').setText('Percentage');

    for (int i = 0; i < _students.length; i++) {
      var student = _students[i];
      sheet.getRangeByName('A${i + 2}').setText(student['Last Name']);
      sheet.getRangeByName('B${i + 2}').setText(student['First Name']);
      sheet.getRangeByName('C${i + 2}').setNumber(student['Score'].toDouble());
      double percentage = calculateBaseScore(student['Score'], _selectedBase);
      sheet.getRangeByName('D${i + 2}').setNumber(percentage);
    }

    final List<int> bytes = workbook.saveAsStream();

    try {
      final directory = Directory('/storage/emulated/0/Download');
      if (!(await directory.exists())) {
        await directory.create(recursive: true);
      }

      final String fileName = '$subjectName-$testName-RATING SHEET.xlsx';
      final String path = '${directory.path}/$fileName';
      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File saved to $path'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(path);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rating Sheet',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF800000),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF800000)))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Student Scores:', style: TextStyle(fontSize: 18)),
                  DropdownButton<String>(
                    value: _selectedBase,
                    items: <String>['Base 50', 'Base 60']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedBase = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        double percentage =
                            calculateBaseScore(student['Score'], _selectedBase);
                        return ListTile(
                          title: Text(
                              '${student['Last Name']}, ${student['First Name']}'),
                          subtitle: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Score: ${student['Score']}'),
                              Text('${percentage.toStringAsFixed(2)}%'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: generateExcel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF800000),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Download Now'),
                  ),
                ],
              ),
            ),
    );
  }
}
