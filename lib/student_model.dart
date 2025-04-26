import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentProvider with ChangeNotifier {
  List<Map<String, String>> _students = [];

  List<Map<String, String>> get students => _students;

  Future<void> addStudent(String userId, String classId, String lastName,
      String firstName, String middleName) async {
    final studentCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('classes')
        .doc(classId)
        .collection('students');

    // Add the student data to Firestore
    await studentCollection.add({
      'lastName': lastName,
      'firstName': firstName,
      'middleName': middleName,
    });

    // Update totalStudents in the class
    await _updateTotalStudents(userId, classId);

    // Add to local students list

    notifyListeners();
  }
// Add imported students to the existing list
void addImportedStudents(List<Map<String, String>> importedStudents) {
  _students.addAll(importedStudents); // Append imported students
  notifyListeners(); // Notify listeners to update the UI
}

  // Update an existing student in Firestore and the local list
  Future<void> updateStudent(String userId, String classId, int index,
      String lastName, String firstName, String middleName) async {
    final studentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('classes')
        .doc(classId)
        .collection('students')
        .where('lastName', isEqualTo: _students[index]['Last Name'])
        .where('firstName', isEqualTo: _students[index]['First Name'])
        .where('middleName', isEqualTo: _students[index]['Middle Name'])
        .get();

    if (studentDoc.docs.isNotEmpty) {
      await studentDoc.docs.first.reference.update({
        'lastName': lastName,
        'firstName': firstName,
        'middleName': middleName,
      });

      // Update the local list
      _students[index] = {
        'Last Name': lastName,
        'First Name': firstName,
        'Middle Name': middleName,
      };

      notifyListeners();
    }
  }

  Future<void> deleteStudent(String userId, String classId, int index) async {
    final studentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('classes')
        .doc(classId)
        .collection('students')
        .where('lastName', isEqualTo: _students[index]['Last Name'])
        .where('firstName', isEqualTo: _students[index]['First Name'])
        .where('middleName', isEqualTo: _students[index]['Middle Name'])
        .get();

    if (studentDoc.docs.isNotEmpty) {
      await studentDoc.docs.first.reference.delete();

      // Update totalStudents in the class after deletion
      await _updateTotalStudents(userId, classId);

      _students.removeAt(index);
      notifyListeners();
    }
  }

  // Load students into the provider state
  void loadStudents(List<Map<String, String>> students) {
    _students = students;
    notifyListeners();
  }

  // Sort students by last name in ascending or descending order
  void sortStudentsByLastName(bool ascending) {
    _students.sort((a, b) {
      final lastNameA = a['Last Name']?.toLowerCase() ?? '';
      final lastNameB = b['Last Name']?.toLowerCase() ?? '';
      return ascending
          ? lastNameA.compareTo(lastNameB)
          : lastNameB.compareTo(lastNameA);
    });
    notifyListeners(); // Ensure the UI updates after sorting
  }
}

Future<void> _updateTotalStudents(String userId, String classId) async {
  final classDoc = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('classes')
      .doc(classId);

  final studentCollection = classDoc.collection('students');
  final studentCount = (await studentCollection.get()).docs.length;

  // Update the class document with the new total number of students
  await classDoc.update({'totalStudents': studentCount});
}
