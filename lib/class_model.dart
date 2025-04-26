import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClassModel {
  String id;
  final String program;
  final String yearLevel;
  final String section;
  final String course;
  int totalStudents;

  ClassModel({
    required this.id,
    required this.program,
    required this.yearLevel,
    required this.section,
    required this.course,
    this.totalStudents = 0, // Default value of 0
  });

  Map<String, dynamic> toMap() {
    return {
      'program': program,
      'yearLevel': yearLevel,
      'section': section,
      'course': course,
      'totalStudents': totalStudents, // Include total students
    };
  }

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      program: data['program'] ?? '',
      yearLevel: data['yearLevel'] ?? '',
      section: data['section'] ?? '',
      course: data['course'] ?? '',
      totalStudents: data['totalStudents'] ?? 0, // Get total students
    );
  }

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] ?? '',
      program: map['program'] ?? '',
      yearLevel: map['yearLevel'] ?? '',
      section: map['section'] ?? '',
      course: map['course'] ?? '',
      totalStudents: map['totalStudents'] ?? 0,
    );
  }
}

class ClassProvider with ChangeNotifier {
  List<ClassModel> _classes = [];
  String _currentClassId = '';
  bool _isLoading = true; // Add loading state

  List<ClassModel> get classes => _classes;
  String get currentClassId => _currentClassId;
  bool get isLoading => _isLoading;

  Future<void> fetchClasses() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _isLoading = true;
      notifyListeners();

      try {
        // Introduce a 5-second delay to highlight shimmer
        await Future.delayed(Duration(seconds: 3));

        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('classes')
            .get();

        _classes = querySnapshot.docs
            .map((doc) => ClassModel.fromFirestore(doc))
            .toList();

        if (_classes.isNotEmpty && _currentClassId.isEmpty) {
          _currentClassId = _classes.first.id;
        }
      } catch (e) {
        print("Error fetching classes: $e");
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Add a new class to Firestore and local list
  Future<void> addClass(ClassModel newClass) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('classes')
            .add(newClass.toMap());

        newClass.id = docRef.id;
        _classes.add(newClass);

        if (_currentClassId.isEmpty) {
          _currentClassId = newClass.id;
        }

        notifyListeners();
      } catch (e) {
        print("Error adding class: $e");
      }
    }
  }

  Future<void> removeClass(String classId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Reference to the exams collection
        final examsCollection = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('classes')
            .doc(classId)
            .collection('exams');

        // Delete all exams under the class
        final examSnapshots = await examsCollection.get();
        for (var doc in examSnapshots.docs) {
          await doc.reference.delete();
        }

        // Delete the class document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('classes')
            .doc(classId)
            .delete();

        // Update local state
        _classes.removeWhere((classModel) => classModel.id == classId);

        // Update current class ID if necessary
        if (_currentClassId == classId && _classes.isNotEmpty) {
          _currentClassId = _classes.first.id;
        } else if (_classes.isEmpty) {
          _currentClassId = '';
        }

        notifyListeners();
      } catch (e) {
        print("Error removing class and exams: $e");
      }
    }
  }
}
