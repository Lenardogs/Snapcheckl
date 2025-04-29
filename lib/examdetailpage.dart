import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'exam_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'ItemAnalysisPage.dart';
import 'package:image/image.dart' as img;
import 'autocrop_util.dart';
import 'DownloadRatingSheetPage.dart';
import 'package:permission_handler/permission_handler.dart';

class ExamDetailPage extends StatefulWidget {
  final Exam exam;
  final List<Map<String, String>> students;

  const ExamDetailPage({super.key, required this.exam, required this.students});

  @override
  _ExamDetailPageState createState() => _ExamDetailPageState();
}

class BulkUploadDialog extends StatefulWidget {
  final List<XFile> files;
  final Future<void> Function(List<XFile>, void Function(int, int), void Function(String)) onProcess;
  const BulkUploadDialog({required this.files, required this.onProcess, super.key});

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog> {
  int current = 0;
  String status = '';
  bool done = false;

  @override
  void initState() {
    super.initState();
    _startUpload();
  }

  void _startUpload() async {
    await widget.onProcess(widget.files, (i, total) {
      setState(() {
        current = i;
      });
    }, (s) {
      setState(() {
        status = s;
      });
    });
    setState(() {
      done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bulk Upload Progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: widget.files.isEmpty ? 0 : current / widget.files.length,
          ),
          SizedBox(height: 16),
          Text('Uploading $current of ${widget.files.length} images'),
          SizedBox(height: 8),
          Text(status),
        ],
      ),
      actions: [
        if (done)
          TextButton(
            child: Text('Close', style: TextStyle(color: Color(0xFF800000))),
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }
}

class _ExamDetailPageState extends State<ExamDetailPage> {
  void _showBulkUploadDialog() async {
    List<XFile>? pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles == null || pickedFiles.isEmpty) {
      // User canceled or picked nothing
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BulkUploadDialog(
          files: pickedFiles,
          onProcess: _bulkUploadImages,
        );
      },
    );
  }

  Future<void> _bulkUploadImages(List<XFile> files, void Function(int, int) onProgress, void Function(String) onStatus) async {
    for (int i = 0; i < files.length; i++) {
      onProgress(i + 1, files.length);
      try {
        final file = File(files[i].path);
        // OCR: Get full text from image
        String ocrText = await _performOCR(file);
        if (ocrText.trim().isEmpty) {
          onStatus('No text found in ${files[i].name}');
          continue;
        }
        // Attempt to extract the student name (assume first non-empty line)
        List<String> lines = ocrText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        String? extractedName = lines.isNotEmpty ? lines[0] : null;
        if (extractedName == null || extractedName.length < 3) {
          onStatus('No valid name found in ${files[i].name}');
          continue;
        }
        // Try to match extracted name to a student
        Map<String, String>? matchedStudent;
        double highestScore = 0.0;
        for (var student in _students) {
          String fullName = ((student['First Name'] ?? '') + ' ' + (student['Last Name'] ?? '')).toLowerCase().trim();
          double score = _nameSimilarity(fullName, extractedName.toLowerCase());
          if (score > highestScore) {
            highestScore = score;
            matchedStudent = student;
          }
        }
        // Use a threshold for similarity
        if (matchedStudent != null && highestScore > 0.6) {
          onStatus('Matched: $extractedName → ${matchedStudent['First Name']} ${matchedStudent['Last Name']}');
          // Remove the name line for answer extraction
          String answerText = lines.skip(1).join('\n');
          await _processExtractedText(matchedStudent, answerText);
          onStatus('Graded: ${matchedStudent['First Name']} ${matchedStudent['Last Name']}');
        } else {
          onStatus('No matching student for "$extractedName" in ${files[i].name}');
        }
      } catch (e) {
        onStatus('Failed: ${files[i].name} ($e)');
      }
    }
    onStatus('All uploads complete!');
  }

  // Returns a similarity score between 0 and 1 (1 = identical)
  double _nameSimilarity(String a, String b) {
    a = a.replaceAll(RegExp(r'[^a-z ]'), '').trim();
    b = b.replaceAll(RegExp(r'[^a-z ]'), '').trim();
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    // Jaccard similarity on word sets (robust to OCR errors)
    final aSet = a.split(' ').toSet();
    final bSet = b.split(' ').toSet();
    final intersection = aSet.intersection(bSet).length;
    final union = aSet.union(bSet).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  File? _croppedImage; // Holds the currently cropped image, if any
  List<Map<String, String>> _students = [];
  List<String> _imagePaths = [];
  List<String?> _answers = [];
  List<List<String>> _answerKey = [];
  List<int> _pointsPerQuestion = [];
  List<String> _extractedAnswers = [];

  List<Map<String, String>> _filteredStudents = [];
  bool _isSearchMode = false;
  TextEditingController _searchController = TextEditingController();

  bool _isProcessing = false;
  bool _isLoading = true;

  int _totalNumberOfQuestions = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _filteredStudents = _students; // Default to show all students
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        // If the query is empty, show all students
        _filteredStudents = List.from(_students);
      } else {
        // Filter the students based on the search query
        _filteredStudents = _students
            .where((student) =>
                student['First Name']!
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                student['Last Name']!
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                student['Student ID']!
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _initializeData() async {
    await _loadStudentsFromClass();
    await _loadImagePaths();
    await _loadAnswerKeyFromFirestore();
    _generateDynamicAnswerKey();

    if (mounted) {
      // Sort students alphabetically by Last Name
    _students.sort((a, b) {
      return a['Last Name']!.toLowerCase().compareTo(b['Last Name']!.toLowerCase());
    });
      // Check if the widget is still mounted
      setState(() {
        _filteredStudents = List.from(_students);
        _isLoading = false;
      });
    }
  }

  Future<int> _getTotalNumberOfStudents() async {
    try {
      String? userId = await _getCurrentUserId();
      if (userId == null) {
        print('No user logged in');
        return 0;
      }

      final studentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(widget.exam.classId)
          .collection('students');

      final snapshot = await studentRef.get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching total number of students: $e');
      return 0;
    }
  }

  void _calculateTotalNumberOfQuestions() {
    int totalQuestions = 0;
    for (var part in widget.exam.parts) {
      totalQuestions += part.numberOfQuestions;
    }
    setState(() {
      _totalNumberOfQuestions = totalQuestions;
    });
    print('Total number of questions in the exam: $_totalNumberOfQuestions');
  }

  Future<String?> _getCurrentUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> _fetchStudentScores() async {
    if (!mounted) return; // Ensure the widget is still mounted

    List<Map<String, String>> updatedStudents =
        []; // Ensure this matches the expected type

    for (var student in _students) {
      List<Map<String, dynamic>> results = await _fetchStudentScore(student);
      // Convert all values in the student map to String
      var updatedStudent =
          student.map((key, value) => MapEntry(key, value.toString()));
      updatedStudent['score'] =
          results.isNotEmpty ? results.last['score'].toString() : '0';
      updatedStudents.add(updatedStudent as Map<String, String>);
    }

    if (!mounted) return; // Check again before updating the state
    setState(() {
      _students = updatedStudents; // Update the main student list
      _filteredStudents = List.from(_students); // Update the displayed list
    });
  }


  Future<void> _loadAnswerKeyFromFirestore() async {
  try {
    final examRef = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('classes')
        .doc(widget.exam.classId)
        .collection('exams')
        .doc(widget.exam.id)
        .collection('answerKey')
        .doc('answerKey_${widget.exam.id}');

    final snapshot = await examRef.get();

    if (snapshot.exists) {
      final data = snapshot.data();
      if (data != null) {
        Map<String, dynamic> answersMap = data['answerKey']['answers'] ?? {};
        Map<String, dynamic> pointsMap = data['answerKey']['points'] ?? {};

        List<List<String>> tempAnswerKey = [];
        List<int> tempPointsPerQuestion = [];

        int totalQuestions = widget.exam.parts.fold(0, (sum, part) => sum + part.numberOfQuestions);

        for (int i = 0; i < totalQuestions; i++) {
          var rawAnswer = answersMap[i.toString()];
          var rawPoints = pointsMap[i.toString()];

          List<String> answerList = [];
          if (rawAnswer is String) {
            answerList = rawAnswer.split(',').map((s) => s.trim()).toList();
          } else if (rawAnswer is List) {
            answerList = List<String>.from(rawAnswer);
          }

          int points = (rawPoints is int) ? rawPoints : 1;

          tempAnswerKey.add(answerList);
          tempPointsPerQuestion.add(points);
        }

        setState(() {
          _answerKey = tempAnswerKey;
          _pointsPerQuestion = tempPointsPerQuestion;
        });
      } else {
        print('No answer key data found.');
      }
    } else {
      print('Answer key document not found.');
    }
  } catch (e) {
    print('Error loading answer key: $e');
  }
}

void _generateDynamicAnswerKey() {
  if (_answerKey.isEmpty && widget.exam.parts.isNotEmpty) {
    if (mounted) {
      setState(() {
        _answerKey = [];
        _pointsPerQuestion = [];
        for (var part in widget.exam.parts) {
          _answerKey.addAll(List.generate(part.numberOfQuestions, (index) => <String>['']));
          _pointsPerQuestion.addAll(List.generate(part.numberOfQuestions, (index) => part.points));
        }
        print('Generated empty answer key: $_answerKey');
      });
    }
  }
}

// This version properly reads the Firestore maps and initializes the answer key correctly.
// Let me know if you want any adjustments! 🚀

  Future<void> _processExtractedText(Map<String, String> student, String extractedText) async {
  // Split the extracted text into lines
  List<String> lines = extractedText.split('\n');

  // Initialize lists to hold answers from left and right columns
  List<String> leftColumn = [];
  List<String> rightColumn = [];

  // Process each line to extract answers
  for (String line in lines) {
    // Split the line into columns based on large spaces
    List<String> columns =
        line.split(RegExp(r'\s{2,}')); // Split by double spaces or more
    if (columns.isNotEmpty) {
      // Add the left column answer
      leftColumn.add(columns[0].trim());
      // Add the right column answer if it exists
      if (columns.length > 1) {
        rightColumn.add(columns[1].trim());
      }
    }
  }

  // Merge left and right columns sequentially into a single list of answers
  List<String> answers = [...leftColumn, ...rightColumn];

  // Ensure the answers align with the number of questions in the exam
  if (_answerKey.isEmpty ||
      _pointsPerQuestion.isEmpty ||
      _pointsPerQuestion.length != _answerKey.length) {
    print('Answer key or points per question not loaded or mismatched.');
    return;
  }

  // Initialize variables for grading
  int correctCount = 0;
  int totalScore = 0;
  List<Map<String, String>> comparisonResults = [];

  // Iterate through the number of questions
  for (int i = 0; i < _answerKey.length; i++) {
    // Get the possible answers for the current question
    List<String> possibleAnswers = _answerKey[i];
    // Normalize the extracted answer (convert to lowercase)
    String extractedAnswer = (i < answers.length) ? answers[i].toLowerCase() : 'No answer';

    // Check if the extracted answer matches any of the possible answers (case-insensitive)
    bool isCorrect = isCorrectAnswer(extractedAnswer, possibleAnswers);

    // Determine the result for this question
    String result = isCorrect ? 'Correct' : 'Incorrect';

    // If correct, add the corresponding points to the total score
    if (isCorrect && i < _pointsPerQuestion.length) {
      correctCount++;
      totalScore += _pointsPerQuestion[i]; // Add points for correct answers
    }

    // Add the result to the comparisonResults list
    comparisonResults.add({
      'Question': 'Question ${i + 1}',
      'Extracted': extractedAnswer,
      'Correct': possibleAnswers.join(', '),
      'Result': result,
    });
  }

  // Trigger a state update to reflect the changes in the UI
  setState(() {
    _students = List.from(_students); // Force UI to update
    _filteredStudents = List.from(_students); // Update filtered students list
  });

  // Show comparison results for review
  _showComparisonResults(comparisonResults);

  // Save the scanned results to Firestore
  await _saveStudentScannedResults(student, comparisonResults, totalScore);
}

// Helper function to check if an extracted answer matches any of the possible answers
bool isCorrectAnswer(String extractedAnswer, List<String> possibleAnswers) {
  for (String answer in possibleAnswers) {
    if (extractedAnswer.trim().toLowerCase() == answer.trim().toLowerCase()) {
      return true; // Match found
    }
  }
  return false; // No match
}

  Future<void> _saveStudentScannedResults(Map<String, String> student,
      List<Map<String, String>> results, int score) async {
    try {
      String? userId = await _getCurrentUserId();
      if (userId == null) {
        print('No user logged in');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No user is logged in. Please log in first.')),
        );
        return;
      }

      final studentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(widget.exam.classId)
          .collection('students')
          .doc(student['Student ID']);

      final examRef = studentRef.collection('exams').doc(widget.exam.id);
      final sessionRef = examRef
          .collection('scanned_results')
          .doc('latest'); // Use a fixed ID, e.g., "latest"

      final snapshot = await sessionRef.get();

      if (snapshot.exists) {
        // If the document exists, update it
        await sessionRef.update({
          'score': score,
          'results': results,
          'scannedAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Updated scanned results for ${student['First Name']}')),
        );
        print('Updated scanned results for student: ${student['First Name']}');
      } else {
        // If the document does not exist, create it
        await sessionRef.set({
          'score': score,
          'results': results,
          'scannedAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Saved new scanned results for ${student['First Name']}')),
        );
        print(
            'Saved new scanned results for student: ${student['First Name']}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving scanned results: $e')),
      );
      print('Error saving scanned results: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStudentScore(
      Map<String, String> student) async {
    try {
      String? userId = await _getCurrentUserId();
      if (userId == null) {
        print('No user logged in');
        return [];
      }

      final studentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(widget.exam.classId)
          .collection('students')
          .doc(student['Student ID'])
          .collection('exams')
          .doc(widget.exam.id)
          .collection('scanned_results');

      final snapshot = await studentRef.get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          return {
            'score': doc.data()['score'] ?? 0,
            'results':
                List<Map<String, dynamic>>.from(doc.data()['results'] ?? []),
            'scannedAt': (doc.data()['scannedAt'] as Timestamp?)?.toDate(),
          };
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching student score: $e');
      return [];
    }
  }

  Future<void> _fetchScannedResults(Map<String, String> student) async {
    try {
      String? userId = await _getCurrentUserId();
      if (userId == null) {
        print('No user logged in');
        return;
      }

      final studentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(widget.exam.classId)
          .collection('students')
          .doc(student['Student ID'])
          .collection('exams')
          .doc(widget.exam.id)
          .collection('scanned_results');

      final snapshot = await studentRef.get();

      if (snapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> results = snapshot.docs.map((doc) {
          return {
            'score': doc.data()['score'] ?? 0,
            'results':
                List<Map<String, dynamic>>.from(doc.data()['results'] ?? []),
            'scannedAt': (doc.data()['scannedAt'] as Timestamp?)?.toDate(),
          };
        }).toList();

        _showScannedResults(student, results);
      } else {
        print('No scanned results found for this student.');
        _showNoResultsMessage();
      }
    } catch (e) {
      print('Error fetching scanned results: $e');
    }
  }

  void _showScannedResults(
      Map<String, String> student, List<Map<String, dynamic>> results) {
    // Track editing state for each question using a Set of indices
    final Set<int> editingQuestions = {};

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'Scanned Results for ${student['First Name']} ${student['Last Name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                final scannedAt = result['scannedAt'] ?? 'Unknown Date';
                final score = result['score'] ?? 0;
                final answers = result['results'] ?? [];

                return ExpansionTile(
                  
                  title: Text('Score: $score'),
                  children: [
                    ...answers.asMap().entries.map<Widget>((entry) {
                      final questionIndex = entry.key;
                      final answer = entry.value;
                      final TextEditingController controller =
                          TextEditingController(
                        text: answer[
                            'Extracted'], // Initialize with extracted answer
                      );

                      return ListTile(
                        title: Text(answer['Question'] ?? 'Unknown Question'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            editingQuestions.contains(questionIndex)
                                ? TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      labelText: 'Edit Answer',
                                      border: OutlineInputBorder(),
                                    ),
                                  )
                                : Text(
                                    'Extracted: ${answer['Extracted'] ?? 'N/A'}'),
                            Text('Correct: ${answer['Correct'] ?? 'N/A'}'),
                            Text(
                              'Result: ${answer['Result'] ?? 'Unknown'}',
                              style: TextStyle(
                                color: (answer['Result'] == 'Correct')
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: editingQuestions.contains(questionIndex)
                            ? IconButton(
                                icon:
                                    const Icon(Icons.save, color: Colors.blue),
                                onPressed: () async {
                                  // Save the updated answer
                                  answer['Extracted'] = controller.text;

                                  // Update Firestore
                                  await _updateAnswerInFirestore(
                                      student, questionIndex, answer, results);

                                  // Exit edit mode for this question
                                  editingQuestions.remove(questionIndex);

                                  // Rebuild to reflect changes
                                  (context as Element).markNeedsBuild();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Updated answer for ${answer['Question']} saved.'),
                                    ),
                                  );
                                },
                              )
                            : IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.orange),
                                onPressed: () {
                                  // Enter edit mode for this question
                                  editingQuestions.add(questionIndex);

                                  // Rebuild to reflect changes
                                  (context as Element).markNeedsBuild();
                                },
                              ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
              foregroundColor: Color(0xFF800000),),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateAnswerInFirestore(
    Map<String, String> student,
    int questionIndex,
    Map<String, dynamic> updatedAnswer,
    List<Map<String, dynamic>> allResults) async {
  try {
    String? userId = await _getCurrentUserId();
    if (userId == null) {
      print('No user logged in');
      return;
    }

    // Fetch the correct answers from _answerKey
    if (_answerKey.isEmpty || questionIndex >= _answerKey.length) {
      print('Answer key not loaded or index out of bounds.');
      return;
    }
    
    // Get the list of possible answers for the current question
    List<String> possibleAnswers = _answerKey[questionIndex];

    // Compare the updated answer with any of the correct answers in the list
    String extractedAnswer = updatedAnswer['Extracted'].trim().toLowerCase();
    bool isCorrect = possibleAnswers.any((correctAnswer) =>
        correctAnswer.trim().toLowerCase() == extractedAnswer);

    // Set the result based on the comparison
    String result = isCorrect ? 'Correct' : 'Incorrect';

    // Update the result for the specific question
    updatedAnswer['Result'] = result;

    // Fetch existing results from Firestore
    final studentRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('classes')
        .doc(widget.exam.classId)
        .collection('students')
        .doc(student['Student ID'])
        .collection('exams')
        .doc(widget.exam.id)
        .collection('scanned_results')
        .doc('latest');

    final snapshot = await studentRef.get();

    if (snapshot.exists) {
      // Get existing results from Firestore
      List<Map<String, dynamic>> existingResults =
          List<Map<String, dynamic>>.from(snapshot.data()?['results'] ?? []);

      // Merge updated answer into existing results
      if (questionIndex < existingResults.length) {
        existingResults[questionIndex] = updatedAnswer;
      } else if (questionIndex == existingResults.length) {
        existingResults.add(updatedAnswer);
      } else {
        print('Question index out of bounds in existing results.');
        return;
      }

      // Recalculate the score
      int updatedScore = 0;
      for (int i = 0; i < existingResults.length; i++) {
        if (existingResults[i]['Result'] == 'Correct') {
          updatedScore += _pointsPerQuestion[i];
        }
      }

      // Update Firestore with the full results and score
      await studentRef.update({
        'results': existingResults,
        'score': updatedScore,
      });

      // Refresh the student data to display the updated score right away
      await _fetchStudentScores(); // Re-fetch the scores
      setState(() {
        // Trigger a UI update to reflect the changes
        _filteredStudents = List.from(_students);
      });

      print('Firestore updated with new answer, result, and score for question $questionIndex.');
    } else {
      print('No existing results found in Firestore.');
    }
  } catch (e) {
    print('Error updating answer in Firestore: $e');
  }
}

  void _showNoResultsMessage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No Results Found'),
          content:
              const Text('This student does not have any scanned results yet.'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
              foregroundColor: Color(0xFF800000),),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _recognizeTextFromImage(
      Map<String, String> student, File imageFile) async {
    try {
      // Load the original image
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        print('Failed to decode image.');
        return;
      }

      // Auto-crop edges
      final croppedImage = autoCropEdges(originalImage);

      // Divide the image into left and right halves
      final int middle = (croppedImage.width / 2).round();
      final leftColumnImage = img.copyCrop(
        croppedImage,
        x: 0,
        y: 0,
        width: middle,
        height: originalImage.height,
      );
      final rightColumnImage = img.copyCrop(
        originalImage,
        x: middle,
        y: 0,
        width: middle,
        height: originalImage.height,
      );

      // Save the cropped images temporarily for OCR
      final leftColumnFile =
          await _saveTemporaryImage(leftColumnImage, 'left_column.jpg');
      final rightColumnFile =
          await _saveTemporaryImage(rightColumnImage, 'right_column.jpg');

      // Perform OCR for each column
      final leftColumnText = await _performOCR(leftColumnFile);
      final rightColumnText = await _performOCR(rightColumnFile);

      // Clean and split the recognized text into lines
      final List<String> leftColumnAnswers =
          _cleanRecognizedText(leftColumnText).split('\n');
      final List<String> rightColumnAnswers =
          _cleanRecognizedText(rightColumnText).split('\n');

      // Combine the answers into a single list for the dialog
      List<String> answers = [...leftColumnAnswers, ...rightColumnAnswers];

      // Show the editable text dialog with proper column mapping
      _showEditableTextDialog(student, answers);
    } catch (e) {
      print('Error during text recognition: $e');
    }
  }

// Helper function to save an image temporarily
  Future<File> _saveTemporaryImage(img.Image image, String fileName) async {
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(img.encodeJpg(image));
    return file;
  }

// Perform OCR using the API
  Future<String> _performOCR(File imageFile) async {
    final uri = Uri.parse(
        'https://pen-to-print-handwriting-ocr.p.rapidapi.com/recognize/');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'X-RapidAPI-Key': 'b9f52b34c7msh0c2b4ba0175752fp13681fjsn42356a801e0a',
        'X-RapidAPI-Host': 'pen-to-print-handwriting-ocr.p.rapidapi.com',
      })
      ..files.add(await http.MultipartFile.fromPath('srcImg', imageFile.path));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(responseData);
      return data['value'] ?? 'No text recognized';
    } else {
      throw Exception('OCR failed with status code ${response.statusCode}');
    }
  }

  String _cleanRecognizedText(String text) {
    // Split the text into lines
    List<String> lines = text.split('\n');

    // Initialize a list to hold answers without the question numbers
    List<String> cleanedAnswers = [];

    // Regex pattern to match question numbers (e.g., "1.", "2.", etc.)
    RegExp questionNumberPattern = RegExp(r'^\d+\.*');

    // Initialize variables to track the current answer being constructed
    String currentAnswer = '';
    bool expectingNewAnswer = true;

    for (String line in lines) {
      // Check if the line starts with a question number
      if (questionNumberPattern.hasMatch(line)) {
        // If we were building an answer, save it before starting a new one
        if (currentAnswer.isNotEmpty) {
          cleanedAnswers.add(currentAnswer.trim());
        }

        // Start a new answer and remove the question number
        currentAnswer = line.replaceFirst(questionNumberPattern, '').trim();
        expectingNewAnswer = false;
      } else {
        // If the line doesn't start with a number, assume it's a continuation of the current answer
        currentAnswer += ' ' + line.trim();
      }
    }

    // Add the last answer if there's any remaining
    if (currentAnswer.isNotEmpty) {
      cleanedAnswers.add(currentAnswer.trim());
    }

    // Return the cleaned answers as a string, joining by newline
    return cleanedAnswers.join('\n');
  }

  Future<int> _countUncheckedStudents() async {
    int unscannedCount = 0;

    try {
      for (var student in _students) {
        List<Map<String, dynamic>> scannedResults =
            await _fetchStudentScore(student);

        // If there are no scanned results, increment the unscanned count
        if (scannedResults.isEmpty) {
          unscannedCount++;
        }
      }
    } catch (e) {
      print('Error counting unchecked students: $e');
    }

    return unscannedCount;
  }

  Future<File?> _resizeImage(File imageFile) async {
    try {
      // Read image as bytes
      final imageBytes = await imageFile.readAsBytes();

      // Decode image to manipulate it
      final image = img.decodeImage(imageBytes);
if (image == null) {
  return null; // Return null if the image can't be decoded
}
// Auto-crop edges
final croppedImage = autoCropEdges(image);

      if (image == null) {
        return null; // Return null if the image can't be decoded
      }

      // Resize the image to a smaller resolution (e.g., width: 1080 pixels)
      final resizedImage = img.copyResize(image, width: 1080);

      // Encode the resized image back to bytes
      final resizedImageBytes = img.encodeJpg(resizedImage);

      // Save the resized image to the same file or a new one
      final resizedFile = File(imageFile.path);

      return resizedFile;
    } catch (e) {
      print('Error resizing image: $e');
      return null;
    }
  }

  final Color maroon = Color(0xFF800000); // Define maroon color

  Future<File?> _cropImage(File imageFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.red,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
        ],
      );
      if (croppedFile == null) {
        print("User canceled cropping.");
        return null;
      }
      print("Image cropped successfully: ${croppedFile.path}");
      return File(croppedFile.path);
    } catch (e) {
      print("Error during cropping: $e");
      return null;
    }
  }

  Future<void> _uploadImage(Map<String, String> student) async {
  setState(() {
    _croppedImage = null;
  });

  var cameraPermissionStatus = await Permission.camera.status;

  if (!cameraPermissionStatus.isGranted) {
    cameraPermissionStatus = await Permission.camera.request();
  }

  if (cameraPermissionStatus.isGranted) {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (mounted) {
        setState(() {
          _isProcessing = true;
        });
      }

      final imageFile = File(pickedFile.path);

      try {
        // Resize the image only (no more cropping)
        final resizedFile = await _resizeImage(imageFile);

        if (resizedFile != null) {
          await _recognizeTextFromImage(student, resizedFile);
        } else {
          print('Failed to resize the image');
        }
      } catch (e) {
        print('Error during image processing: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  } else {
    _showPermissionDialog(
        'Access to the camera is required to upload images from the gallery. Please enable camera permission in the app settings.');
  }
}


  Future<void> _scanImage(Map<String, String> student) async {
  setState(() {
    _croppedImage = null;
  });

  var permissionStatus = await Permission.camera.status;

  if (!permissionStatus.isGranted) {
    permissionStatus = await Permission.camera.request();
  }

  if (permissionStatus.isGranted) {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      if (mounted) {
        setState(() {
          _isProcessing = true;
        });
      }

      final imageFile = File(pickedFile.path);

      try {
        // Resize the image only (no more cropping)
        final resizedFile = await _resizeImage(imageFile);

        if (resizedFile != null) {
          await _recognizeTextFromImage(student, resizedFile);
        } else {
          print('Failed to resize the image');
        }
      } catch (e) {
        print('Error during image processing: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  } else if (permissionStatus.isPermanentlyDenied) {
    _showPermissionDialog(
        'Camera permission is permanently denied. Please enable it in the app settings.');
  } else {
    _showPermissionDialog(
        'Camera access is needed to capture images. Please grant camera permission.');
  }
}

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Camera Permission"),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings(); // Open app settings if permanently denied
            },
            child: Text('Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStudentsFromClass() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final studentCollection = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('classes')
            .doc(widget.exam.classId)
            .collection('students');

        final snapshot = await studentCollection.get();
        List<Map<String, String>> students = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'Student ID': doc.id,
            'Last Name': (data['lastName'] ?? '').toString(),
            'First Name': (data['firstName'] ?? '').toString(),
            'Middle Name': (data['middleName'] ?? '').toString(),
          };
        }).toList();

        setState(() {
          _students = students;
        });
      }
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  void _showEditableTextDialog(
      Map<String, String> student, List<String> answers) {
    // Get the total number of questions from the exam
    int totalQuestions =
        widget.exam.parts.fold(0, (sum, part) => sum + part.numberOfQuestions);

    // Ensure the number of answers matches the total number of questions
    if (answers.length > totalQuestions) {
      // Truncate extra answers
      answers = answers.sublist(0, totalQuestions);
    } else if (answers.length < totalQuestions) {
      // Pad missing answers with empty strings
      answers.addAll(
          List.generate(totalQuestions - answers.length, (index) => ''));
    }

    // Determine how many questions go into each column
    int middleIndex = (totalQuestions / 2).ceil();

    // Split answers into left and right columns
    List<String> leftColumnAnswers = answers.sublist(0, middleIndex);
    List<String> rightColumnAnswers = answers.sublist(middleIndex);

    // Create text controllers for each answer
    List<TextEditingController> leftControllers = leftColumnAnswers
        .map((answer) => TextEditingController(text: answer))
        .toList();
    List<TextEditingController> rightControllers = rightColumnAnswers
        .map((answer) => TextEditingController(text: answer))
        .toList();

    // Show the dialog
   showDialog(
  context: context,
  barrierDismissible: false, // Prevents closing when tapping outside
  builder: (BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevents back button from closing it
      child: AlertDialog(
        title: const Text('Edit Extracted Text by Columns'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column answers
                Expanded(
                  child: Column(
                    children: List.generate(leftControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: TextField(
                          controller: leftControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Q${index + 1} (Left)',
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 14),
                          maxLines: null,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                // Right column answers
                Expanded(
                  child: Column(
                    children: List.generate(rightControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: TextField(
                          controller: rightControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Q${middleIndex + index + 1} (Right)',
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 14),
                          maxLines: null,
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
            foregroundColor: Color(0xFF800000),), // Set text color to maroon),
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
          TextButton(
            style: TextButton.styleFrom(
            foregroundColor: Color(0xFF800000),),
            child: const Text('Save and Grade'),
            onPressed: () async {
              // Combine left and right controllers into a single list of answers
              String editedText = [
                ...leftControllers.map((controller) => controller.text),
                ...rightControllers.map((controller) => controller.text),
              ].join('\n');

              // Update extracted answers
              _extractedAnswers = [
                ...leftControllers.map((controller) => controller.text),
                ...rightControllers.map((controller) => controller.text),
              ];

              Navigator.of(context).pop(); // Close the dialog

              // Process the extracted text for grading
              await _processExtractedText(student, editedText);
            },
          ),
        ],
      ),
    );
  },
);
      }

  Future<void> _loadImagePaths() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
        '${directory.path}/${widget.exam.className}/${widget.exam.testName}/image_paths.txt');
    if (await file.exists()) {
      final content = await file.readAsString();
      setState(() {
        _imagePaths =
            content.split('\n').where((path) => path.isNotEmpty).toList();
      });
    }
  }

  void _showComparisonResults(List<Map<String, String>> results) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Answer Comparison Results'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return ListTile(
                  title: Text(result['Question']!),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Extracted: ${result['Extracted']}'),
                      Text('Correct: ${result['Correct']}'),
                      Text(
                        'Result: ${result['Result']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: result['Result'] == 'Correct'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
              foregroundColor: Color(0xFF800000),),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchMode
            ? TextField(
                cursorColor: Colors.white,
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search student...',
                  hintStyle: TextStyle(color: Colors.white),
                  border: InputBorder.none,
                ),
                onChanged: _filterStudents,
                style: const TextStyle(color: Colors.white),
              )
            : Text(
                widget.exam.testName,
                style: const TextStyle(color: Colors.white),
              ),
        backgroundColor: const Color(0xFF800000),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isSearchMode)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearchMode = true;
                });
              },
            ),
          if (_isSearchMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearchMode = false;
                  _searchController.clear();
                  _filterStudents('');
                });
              },
            ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'Create Answer Key') {
                _editAnswerKey();
              } else if (value == 'Generate Item Analysis') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItemAnalysisPage(
                      exam: widget.exam,
                      classId: widget.exam.classId,
                    ),
                  ),
                );
              } else if (value == 'Sort Students by Score') {
                _sortStudentsByScore();
              } else if (value == 'Download Rating Sheet') {
                // Ensure scores are fetched before navigating
                _fetchStudentScores().then((_) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DownloadRatingSheetPage(
                          classId: widget.exam.classId,
                          examId: widget.exam.id,
                        ),
                      )).then((_) {
                    if (!mounted) return;
                    _fetchStudentScores(); // Ensure data is refreshed upon return
                  });
                });
              } else if (value == 'Bulk Upload') {
                _showBulkUploadDialog();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'Create Answer Key',
                  child: Text('Create Answer Key'),
                ),
                PopupMenuItem<String>(
                  value: 'Generate Item Analysis',
                  child: Text('Generate Item Analysis'),
                ),
                PopupMenuItem<String>(
                  value: 'Sort Students by Score',
                  child: Text('Sort Students by Score'),
                ),
                PopupMenuItem<String>(
                  value: 'Download Rating Sheet',
                  child: Text('Download Rating Sheet'),
                ),
                PopupMenuItem<String>(
                  value: 'Bulk Upload',
                  child: Text('Bulk Upload'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              FutureBuilder<int>(
                future: _countUncheckedStudents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: Color(0xFF800000)),
                    );
                  } else if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Error: ${snapshot.error}'),
                    );
                  } else if (snapshot.hasData) {
                    int uncheckedCount = snapshot.data ?? 0;
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Unchecked Students: $uncheckedCount out of ${_students.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF800000),
                        ),
                      ),
                    );
                  } else {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No students found'),
                    );
                  }
                },
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = _filteredStudents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 12),
                      color: const Color(0xFFF5F5F5),
                      child: ListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${student['Last Name']}, ${student['First Name']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black),
                            ),
                           FutureBuilder<List<Map<String, dynamic>>>(
  future: _fetchStudentScore(student),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Text('Loading...');
    } else if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
      final lastResult = snapshot.data!.last;
      final score = lastResult['score'] ?? 0;
      final totalPointsSum = widget.exam.totalPointsSum;

      return Text('Score: $score / $totalPointsSum');
    } else {
      return Text('Not Checked');
    }
  },
),

                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Color(0xFF800000)),
                              onPressed: () => _scanImage(student),
                            ),
                            IconButton(
                              icon: const Icon(Icons.upload_file,
                                  color: Color(0xFF800000)),
                              onPressed: () => _uploadImage(student),
                            ),
                            IconButton(
                              icon: const Icon(Icons.assessment,
                                  color: Color(0xFF800000)),
                              onPressed: () => _fetchScannedResults(student),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const Center(child: CircularProgressIndicator(color: Color(0xFF800000))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _refreshStudentScores() async {
    setState(() {
      _isProcessing = true; // Show processing indicator
    });
    await _fetchStudentScores(); // Fetch updated scores
    setState(() {
      _isProcessing = false; // Hide processing indicator
    });
  }

  void _sortStudentsByScore() async {
    if (!mounted) return; // Check if the widget is still mounted
    setState(() {
      _isProcessing = true; // Indicate loading
    });

    // Fetch the latest scores for all students before sorting
    await _fetchStudentScores(); // Ensure all scores are up-to-date

    if (!mounted) return; // Check again before updating the state
    setState(() {
      _students.sort((a, b) {
        int scoreA = int.parse(a['score'] ?? '0');
        int scoreB = int.parse(b['score'] ?? '0');
        return scoreB.compareTo(scoreA); // Sort descending by score
      });
      _filteredStudents = List.from(_students); // Update the displayed list
      _isProcessing = false; // Turn off loading indicator
    });
  }

// Add a placeholder for the _generateItemAnalysis function
  void _generateItemAnalysis() {
    // Logic for generating item analysis goes here
    print('Item Analysis generated.');
  }

void _editAnswerKey() async {
  if (!mounted) return;

  List<TextEditingController> controllers = [];

  Map<String, dynamic>? existingAnswerKey;

  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('No user logged in');
    return;
  }

  String answerKeyDocId = 'answerKey_${widget.exam.id}';

  final answerKeyRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('classes')
      .doc(widget.exam.classId)
      .collection('exams')
      .doc(widget.exam.id)
      .collection('answerKey')
      .doc(answerKeyDocId);

  final answerKeySnapshot = await answerKeyRef.get();
  if (answerKeySnapshot.exists) {
    existingAnswerKey = answerKeySnapshot.data()?['answerKey'];
    if (existingAnswerKey is! Map<String, dynamic>) {
      print('Unexpected answerKey format');
      return;
    }
  }

  _answerKey ??= List.generate(widget.exam.parts.fold(0, (sum, part) => sum + part.numberOfQuestions), (index) => []);

  for (int questionNumber = 0; questionNumber < _answerKey.length; questionNumber++) {
    String key = questionNumber.toString();
    String existingAnswer = existingAnswerKey?['answers'][key]?.join(', ') ?? '';
    controllers.add(TextEditingController(text: existingAnswer));
  }

  if (!mounted) return;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Edit Answer Key'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int questionNumber = 1; questionNumber <= controllers.length; questionNumber++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: TextField(
                    controller: controllers[questionNumber - 1],
                    decoration: InputDecoration(
                      labelText: 'Answer for Question $questionNumber',
                    ),
                    onChanged: (value) {
                      _answerKey[questionNumber - 1] = value.split(',').map((e) => e.trim()).toList();
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              await _saveAnswerKeyToFirestore(existingAnswerKey != null, answerKeyDocId);
              if (mounted) {
                setState(() {});
                Navigator.of(context).pop();
              }
            },
          ),
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      );
    },
  );
}


Future<void> _saveAnswerKeyToFirestore(bool isUpdate, String answerKeyDocId) async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      return;
    }

    if (widget.exam.parts.isEmpty) {
      print('No parts found in the exam');
      return;
    }

    final answerKeyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('classes')
        .doc(widget.exam.classId)
        .collection('exams')
        .doc(widget.exam.id)
        .collection('answerKey')
        .doc(answerKeyDocId);

    Map<String, dynamic> answersMap = {};
    Map<String, int> pointsMap = {};
    int globalIndex = 0;

    int totalQuestions = 0;
    for (var part in widget.exam.parts) {
      totalQuestions += part.numberOfQuestions;
    }

    if (_answerKey.length != totalQuestions || _pointsPerQuestion.length != totalQuestions) {
      print('Mismatch between the number of questions and the answer key/points data.');
      return;
    }

    for (int partIndex = 0; partIndex < widget.exam.parts.length; partIndex++) {
      var part = widget.exam.parts[partIndex];
      for (int questionIndex = 0; questionIndex < part.numberOfQuestions; questionIndex++) {
        if (globalIndex >= _answerKey.length || globalIndex >= _pointsPerQuestion.length) {
          print('Index out of bounds: $globalIndex');
          return;
        }

        answersMap[globalIndex.toString()] = _answerKey[globalIndex];
        pointsMap[globalIndex.toString()] = _pointsPerQuestion[globalIndex];
        globalIndex++;
      }
    }

    Map<String, dynamic> answerKeyData = {
      'answers': answersMap,
      'points': pointsMap,
    };

    if (isUpdate) {
      await answerKeyRef.update({'answerKey': answerKeyData});
      print('Answer key updated successfully!');
    } else {
      await answerKeyRef.set({'answerKey': answerKeyData});
      print('Answer key saved successfully!');
    }
  } catch (e) {
    print('Error saving answer key: $e');
  }
}

}



