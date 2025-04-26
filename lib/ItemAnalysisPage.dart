import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'exam_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ItemAnalysisPage extends StatefulWidget {
  final Exam exam;
  final String classId;

  const ItemAnalysisPage({Key? key, required this.exam, required this.classId})
      : super(key: key);

  @override
  _ItemAnalysisPageState createState() => _ItemAnalysisPageState();
}

class _ItemAnalysisPageState extends State<ItemAnalysisPage> {
  late Future<int> _totalStudents;
  late Future<List<Map<String, dynamic>>> _scores;

  @override
  void initState() {
    super.initState();
    _totalStudents = _fetchTotalStudents();
    _scores = _fetchScores();
  }

  Future<int> _fetchTotalStudents() async {
    try {
      QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .get();

      int totalStudents = studentsSnapshot.docs.length; // Correct count

      print("Total Students in Class ${widget.classId}: $totalStudents");

      return totalStudents;
    } catch (e) {
      print("Error fetching total students: $e");
      return 0; // Return 0 to prevent crashes
    }
  }

  Future<List<Map<String, dynamic>>> _fetchScores() async {
    try {
      QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .get();

      List<Map<String, dynamic>> scoresList = [];

      for (var studentDoc in studentsSnapshot.docs) {
        QuerySnapshot examSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(studentDoc.id)
            .collection('exams')
            .doc(widget.exam.id)
            .collection('scanned_results')
            .get();

        for (var resultDoc in examSnapshot.docs) {
          var score = resultDoc['score'];
          scoresList.add({
            'studentId': studentDoc.id,
            'score': score,
          });
        }
      }

      // Create a mutable copy and sort
      List<Map<String, dynamic>> mutableScoresList =
          List<Map<String, dynamic>>.from(scoresList);
      mutableScoresList.sort((a, b) => b['score'].compareTo(a['score']));
      return mutableScoresList;
    } catch (e) {
      print('Error fetching scores: $e');
      return [];
    }
  }

  Future<List<String>> _fetchTopStudents(
    List<Map<String, dynamic>> scores) async {
  int totalStudents = await _fetchTotalStudents(); // Get actual count

  int count;
  if (totalStudents <= 30) {
    double rawCount = totalStudents * 0.50;
    count = rawCount % 1 == 0
        ? rawCount.toInt()
        : rawCount.floor(); // Floor if decimal
  } else {
    count = (totalStudents * 0.27).floor(); // Floor instead of rounding up
  }

  count = count.clamp(0, scores.length); // Prevent overflow

  print('Total Students: $totalStudents, Selected Count (Top): $count');

  return scores
      .take(count) // Select top `count` students
      .map((scoreEntry) => scoreEntry['studentId'] as String)
      .toList();
}

Future<List<String>> _fetchBottomStudents(
    List<Map<String, dynamic>> scores) async {
  int totalStudents = await _fetchTotalStudents(); // Get actual count

  int count;
  if (totalStudents <= 30) {
    double rawCount = totalStudents * 0.50;
    count = rawCount % 1 == 0
        ? rawCount.toInt()
        : rawCount.floor(); // Floor if decimal
  } else {
    count = (totalStudents * 0.27).floor(); // Floor instead of rounding up
  }

  count = count.clamp(0, scores.length); // Prevent overflow

  print('Total Students: $totalStudents, Selected Count (Bottom): $count');

  return scores
      .skip(scores.length - count) // Select bottom `count` students
      .map((scoreEntry) => scoreEntry['studentId'] as String)
      .toList();
}


  Future<Map<int, int>> _fetchCorrectAnswersForStudents(
      List<String> studentIds, int selectedCount) async {
    try {
      Map<int, int> correctAnswersCount = {};

      for (var studentId in studentIds.take(selectedCount)) {
        // Only process the selected number of students
        QuerySnapshot examSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(studentId)
            .collection('exams')
            .doc(widget.exam.id)
            .collection('scanned_results')
            .get();

        for (var resultDoc in examSnapshot.docs) {
          var results = List.from(resultDoc['results']);
          for (var item in results) {
            if (item['Result'] == 'Correct') {
              int itemIndex = int.parse(item['Question'].split(' ')[1]) - 1;
              correctAnswersCount[itemIndex] =
                  (correctAnswersCount[itemIndex] ?? 0) + 1;

              // Ensure we do not exceed the number of selected students
              if (correctAnswersCount[itemIndex]! > selectedCount) {
                correctAnswersCount[itemIndex] = selectedCount;
              }
            }
          }
        }
      }

      return correctAnswersCount;
    } catch (e) {
      print('Error fetching correct answers: $e');
      return {};
    }
  }

  String getRemarks(double difficultyIndex) {
    if (difficultyIndex >= 0 && difficultyIndex <= 0.2) {
      return 'Very Difficult';
    } else if (difficultyIndex > 0.2 && difficultyIndex <= 0.4) {
      return 'Difficult';
    } else if (difficultyIndex > 0.4 && difficultyIndex <= 0.6) {
      return 'Average';
    } else if (difficultyIndex > 0.6 && difficultyIndex <= 0.8) {
      return 'Easy';
    } else if (difficultyIndex > 0.8 && difficultyIndex <= 1) {
      return 'Very Easy';
    } else {
      return 'Unknown';
    }
  }

  String getDiscriminationRemarks(double discriminationIndex) {
    if (discriminationIndex >= -0.5 && discriminationIndex <= 0.14) {
      return 'Poor';
    } else if (discriminationIndex > 0.14 && discriminationIndex <= 0.24) {
      return 'Marginal';
    } else if (discriminationIndex > 0.24 && discriminationIndex <= 0.34) {
      return 'Good';
    } else if (discriminationIndex > 0.34 && discriminationIndex <= 1) {
      return 'Excellent';
    } else {
      return 'Unknown';
    }
  }

  Future<void> exportToExcel() async {
    // Get raw count from Firebase
    int totalStudents = await _fetchTotalStudents();

    // Calculate selectedCount based on totalStudents
    int selectedCount;
    if (totalStudents <= 30) {
      selectedCount = totalStudents.isOdd
          ? (totalStudents * 0.50).toInt() // No rounding for odd
          : (totalStudents * 0.50).ceil(); // Round up for even
    } else {
      selectedCount = (totalStudents * 0.27).ceil(); // Always round up for >30
    }

    // Ensure selectedCount does not exceed total students available
    selectedCount = selectedCount.clamp(0, totalStudents);

    print("Exporting $selectedCount students out of $totalStudents to Excel.");

    // Fetch scores before using them
    final scores = await _scores;

    // Fetch top and bottom students using correct arguments
    final List<String> topStudents = await _fetchTopStudents(scores);
    final List<String> bottomStudents = await _fetchBottomStudents(scores);

    // Fetch correct answers for top and bottom students
    final Map<int, int> upperData =
        await _fetchCorrectAnswersForStudents(topStudents, selectedCount);
    final Map<int, int> lowerData =
        await _fetchCorrectAnswersForStudents(bottomStudents, selectedCount);

    int selectedPercentage = (totalStudents <= 30) ? 50 : 27;

    // Create a new Excel workbook
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];

    // Set Excel headers
    sheet.getRangeByName('A1').setText('Item Number');
    sheet
        .getRangeByName('B1')
        .setText('Upper ($selectedPercentage%) Correct Answers');
    sheet
        .getRangeByName('C1')
        .setText('Lower ($selectedPercentage%) Correct Answers');
    sheet.getRangeByName('D1').setText(
        'U (Upper Percentile Correct / $selectedPercentage% students)');
    sheet.getRangeByName('E1').setText(
        'L (Lower Percentile Correct / $selectedPercentage% students)');
    sheet.getRangeByName('F1').setText('Difficulty Index');
    sheet.getRangeByName('G1').setText('Remarks');
    sheet.getRangeByName('H1').setText('Discrimination Index');
    sheet.getRangeByName('I1').setText('Discrimination Index Remarks');

    // Get total number of questions
    int totalQuestions = widget.exam.parts
        .fold<int>(0, (prev, part) => prev + part.numberOfQuestions);

    // Populate Excel rows with data
    for (int i = 0; i < totalQuestions; i++) {
      int row = i + 2;
      double upperValue = ((upperData[i] ?? 0) / selectedCount).toDouble();
      double lowerValue = ((lowerData[i] ?? 0) / selectedCount).toDouble();
      double difficultyIndex = ((upperValue + lowerValue) / 2).toDouble();
      double discriminationIndex = (upperValue - lowerValue).toDouble();
      String remarks = getRemarks(difficultyIndex);
      String discriminationRemarks =
          getDiscriminationRemarks(discriminationIndex);

      sheet.getRangeByName('A$row').setText('Item ${i + 1}');
      sheet.getRangeByName('B$row').setNumber(upperData[i]?.toDouble() ?? 0.0);
      sheet.getRangeByName('C$row').setNumber(lowerData[i]?.toDouble() ?? 0.0);
      sheet.getRangeByName('D$row').setNumber(upperValue);
      sheet.getRangeByName('E$row').setNumber(lowerValue);
      sheet.getRangeByName('F$row').setNumber(difficultyIndex);
      sheet.getRangeByName('G$row').setText(remarks);
      sheet.getRangeByName('H$row').setNumber(discriminationIndex);
      sheet.getRangeByName('I$row').setText(discriminationRemarks);
    }

    // Save workbook as a file
    final List<int> bytes = workbook.saveAsStream();
    final Directory? directory = await getExternalStorageDirectory();
    final String downloadsPath = '${directory?.path}/Download';
    String sanitizedFileName =
        '${widget.exam.testName}_${widget.exam.subjectName}'
            .replaceAll(RegExp('[^A-Za-z0-9 ]'), '_')
            .replaceAll(' ', '_');
    final String fileName = '${sanitizedFileName}_item_analysis.xlsx';
    final File file = File('$downloadsPath/$fileName');

    bool isSaved = await saveFile(fileName, bytes);
    if (isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download successful: $fileName'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save the file: FILE ALREADY EXIST'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Open the saved file
    OpenFile.open(file.path);
  }

  Future<bool> saveFile(String fileName, List<int> bytes) async {
    try {
      // Define the directory path for "Device storage/Download"
      final directory = Directory('/storage/emulated/0/Download');

      // Check if the directory exists; if not, create it
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create the file path
      final filePath = '${directory.path}/$fileName';

      // Write the file
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      print('File saved at: $filePath');
      return true; // Return true on success
    } catch (e) {
      print('Error saving file: File already exist. $e');
      return false; // Return false on failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Item Analysis'),
          backgroundColor: const Color(0xFF800000), // Maroon color
          foregroundColor: Colors.white, // Makes title and icons white
          actions: [
            IconButton(
              icon: Icon(Icons.save_alt),
              onPressed: () {
                exportToExcel();
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: FutureBuilder<int>(
            future: _totalStudents,
            builder: (context, totalStudentsSnapshot) {
              if (totalStudentsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: Color(0xFF800000)),
                );
              } else if (totalStudentsSnapshot.hasError) {
                return Center(
                  child: Text('Error: ${totalStudentsSnapshot.error}'),
                );
              } else if (totalStudentsSnapshot.hasData) {
                int totalStudents = totalStudentsSnapshot.data!;

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _scores,
                  builder: (context, scoresSnapshot) {
                    if (scoresSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF800000)),
                      );
                    } else if (scoresSnapshot.hasError) {
                      return Center(
                        child: Text('Error: ${scoresSnapshot.error}'),
                      );
                    } else if (scoresSnapshot.hasData) {
                      final scores = scoresSnapshot.data!;

                      int selectedPercentage = totalStudents <= 30 ? 50 : 27;
                      int selectedCount =
                          (totalStudents * (selectedPercentage / 100)).round();

                      return FutureBuilder<List<Map<int, int>>>(
                        future: Future.wait([
                          _fetchTopStudents(scores).then(
                            (topStudents) => _fetchCorrectAnswersForStudents(
                                topStudents, selectedCount),
                          ),
                          _fetchBottomStudents(scores).then(
                            (bottomStudents) => _fetchCorrectAnswersForStudents(
                                bottomStudents, selectedCount),
                          ),
                        ]),
                        builder: (context, answersSnapshot) {
                          if (answersSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF800000)),
                            );
                          } else if (answersSnapshot.hasError) {
                            return Center(
                              child: Text('Error: ${answersSnapshot.error}'),
                            );
                          } else if (answersSnapshot.hasData) {
                            final upperData = answersSnapshot.data![0];
                            final lowerData = answersSnapshot.data![1];

                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [
                                    DataColumn(label: Text('Item Number')),
                                    DataColumn(
                                        label: Text(
                                            'Upper ($selectedPercentage%) Correct Answers')),
                                    DataColumn(
                                        label: Text(
                                            'Lower ($selectedPercentage%) Correct Answers')),
                                    DataColumn(
                                        label: Text(
                                            'U (Upper Correct / $selectedCount students)')),
                                    DataColumn(
                                        label: Text(
                                            'L (Lower Correct / $selectedCount students)')),
                                    DataColumn(label: Text('Difficulty Index')),
                                    DataColumn(label: Text('Remarks')),
                                    DataColumn(
                                        label: Text('Discrimination Index')),
                                    DataColumn(
                                        label: Text(
                                            'Discrimination Index Remarks')),
                                  ],
                                  rows: List.generate(
                                    widget.exam.parts.fold<int>(
                                      0,
                                      (previousValue, element) =>
                                          previousValue +
                                          element.numberOfQuestions,
                                    ),
                                    (index) {
                                      int upperCorrect = upperData[index] ?? 0;
                                      int lowerCorrect = lowerData[index] ?? 0;

                                      double upperValue =
                                          upperCorrect / selectedCount;
                                      double lowerValue =
                                          lowerCorrect / selectedCount;
                                      double difficultyIndex =
                                          (upperValue + lowerValue) / 2;
                                      double discriminationIndex =
                                          upperValue - lowerValue;

                                      String remarks =
                                          getRemarks(difficultyIndex);
                                      String discriminationRemarks =
                                          getDiscriminationRemarks(
                                              discriminationIndex);

                                      return DataRow(cells: [
                                        DataCell(Text('Item ${index + 1}')),
                                        DataCell(Text(upperCorrect.toString())),
                                        DataCell(Text(lowerCorrect.toString())),
                                        DataCell(Text(
                                            upperValue.toStringAsFixed(2))),
                                        DataCell(Text(
                                            lowerValue.toStringAsFixed(2))),
                                        DataCell(Text(difficultyIndex
                                            .toStringAsFixed(2))),
                                        DataCell(Text(remarks)),
                                        DataCell(Text(discriminationIndex
                                            .toStringAsFixed(2))),
                                        DataCell(Text(discriminationRemarks)),
                                      ]);
                                    },
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return Center(child: Text('No data available'));
                          }
                        },
                      );
                    } else {
                      return Center(child: Text('No data available'));
                    }
                  },
                );
              } else {
                return Center(child: Text('No data available'));
              }
            },
          ),
        ));
  }
}
