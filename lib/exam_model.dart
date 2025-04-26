import 'dart:async'; // Import for managing Firestore subscriptions
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:async/async.dart';

class Part {
  final String questionType;
  final int numberOfQuestions;
  final int points;

  Part({
    required this.questionType,
    required this.numberOfQuestions,
    required this.points,
  });

 
  int get totalPoints => points * numberOfQuestions;

  Map<String, dynamic> toMap() {
    return {
      'questionType': questionType,
      'numberOfQuestions': numberOfQuestions,
      'points': points,
      'totalPoints': totalPoints,
    };
  }

  factory Part.fromMap(Map<String, dynamic> map) {
    return Part(
      questionType: map['questionType'],
      numberOfQuestions: map['numberOfQuestions'],
      points: map['points'],
    );
  }
}

class Exam {
  final String id;
  final String testName;
  final String className;
  final String classYearLevel;
  final String classId;
  final String subjectName;
  final int totalQuestions;
   final int totalScore;
  final List<Part> parts; // Add the list of parts
  bool isSelected;

  Exam({
    required this.id,
    required this.testName,
    required this.className,
    required this.classYearLevel,
    required this.classId,
    required this.subjectName,
    required this.totalQuestions,
    required this.totalScore,
    required this.parts, // Initialize parts
    this.isSelected = false,
  });

   int get totalPointsSum {
    int sum = 0;

    // Sum up the total points from each part
    for (var part in parts) {
      sum += part.totalPoints;
    }

    return sum;
  }

  Map<String, dynamic> toMap() {
    return {
      'testName': testName,
      'className': className,
      'classYearLevel': classYearLevel,
      'classId': classId,
      'subjectName': subjectName,
      'totalQuestions': totalQuestions,
      'parts': parts.map((part) => part.toMap()).toList(), // Store parts as a list of maps
    };
  }

  factory Exam.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    var partsData = data['parts'] as List;
    List<Part> parts = partsData.map((partMap) => Part.fromMap(partMap)).toList();

    return Exam(
      id: doc.id,
      testName: data['testName'] ?? '',
      className: data['className'] ?? '',
      classYearLevel: data['classYearLevel'] ?? '',
      classId: data['classId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      totalQuestions: data['totalQuestions'] ?? '',
      totalScore: data['totalscore'] ?? 0,
      parts: parts,
    );
  }
}


class ExamProvider extends ChangeNotifier {
  String _classId;
  List<Exam> _exams = []; // Store exams
  StreamSubscription? _examsSubscription;
  bool _isAddingExam = false;

   ExamProvider({required String classId}) : _classId = classId;

  // Getter for exams
  List<Exam> get exams => _exams;

 // Fetch all exams across multiple classes
 
Future<void> fetchAllExams(List<String> classIds) async  {
  List<Exam> allExams = [];
  User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print("User not logged in.");
    _exams = allExams;
    notifyListeners();
    return;
  }

  // Cancel the previous subscription if it exists
  _examsSubscription?.cancel();

  StreamGroup<QuerySnapshot> streamGroup = StreamGroup<QuerySnapshot>();

  for (String classId in classIds) {
    Stream<QuerySnapshot> classStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('classes')
        .doc(classId)
        .collection('exams')
        .snapshots();

    streamGroup.add(classStream);
  }

  _examsSubscription = streamGroup.stream.listen((QuerySnapshot snapshot) {
    for (var document in snapshot.docs) {
      Exam exam = Exam.fromFirestore(document);
      allExams.add(exam);
    }
    // Make sure to remove duplicate exams if IDs are the same or any other condition
    _exams = allExams.toSet().toList();
    notifyListeners();
  });

  streamGroup.close();
}


  Future<void> addExam(Exam exam, String classId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User not logged in.");
      return;
    }

    try {
      // Check if the exam already exists in the specified class
      QuerySnapshot existingExams = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('classes')
          .doc(classId)
          .collection('exams')
          .where('testName', isEqualTo: exam.testName)
          .where('subjectName', isEqualTo: exam.subjectName)
          .get();

      if (existingExams.docs.isNotEmpty) {
        print("Exam already exists. Not adding again.");
        return;
      }

      // Add the new exam
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('classes')
          .doc(classId)
          .collection('exams')
          .add(exam.toMap());

      print("Exam added successfully.");
    } catch (error) {
      print("Error adding exam: $error");
    }
  }

  // Remove an existing exam from Firestore by exam ID
  Future<void> removeExam(String examId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('classes')
            .doc(_classId) // Ensure this is the correct class
            .collection('exams')
            .doc(examId)
            .delete();

        // Optionally remove from local exams list if needed
        _exams.removeWhere((exam) => exam.id == examId);
        notifyListeners(); // Notify listeners to refresh the UI
      } catch (error) {
        print("Error removing exam: $error");
      }
    } else {
      print("User not logged in.");
    }
  }

   Future<void> updateExam(Exam updatedExam) async {
  User? user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    try {
      final examRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('classes')
          .doc(updatedExam.classId) // Make sure classId is correct
          .collection('exams')
          .doc(updatedExam.id);

      await examRef.update(updatedExam.toMap());
      print('Exam updated successfully in Firestore: ${updatedExam.toMap()}');

      // Update local list and notify listeners
      final index = _exams.indexWhere((exam) => exam.id == updatedExam.id);
      if (index != -1) {
        _exams[index] = updatedExam;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating exam: $e');
    }
  } else {
    print('No user logged in.');
  }
}


  void sortExamsByClass() {
    _exams.sort((a, b) => a.className.compareTo(b.className)); // Sort by class name
    notifyListeners(); // Notify listeners about the change
  }

  void toggleExamSelection(String examId) {
    final exam = _exams.firstWhere((exam) => exam.id == examId);
    exam.isSelected = !exam.isSelected; // Toggle selection state
    notifyListeners(); // Notify listeners to refresh the UI
  }

  void clearSelections() {
    for (var exam in _exams) {
      exam.isSelected = false; // Clear selection
    }
    notifyListeners(); // Notify listeners to refresh the UI
  }

  void updateClassId(String newClassId, List<String> allClassIds) {
  if (_classId != newClassId) {
    _classId = newClassId;
    fetchAllExams(allClassIds); // Pass the list of class IDs to fetchAllExams
  }
}

  @override
  void dispose() {
    _examsSubscription?.cancel();
    super.dispose();
  }
}
