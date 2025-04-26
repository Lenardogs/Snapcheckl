import 'package:flutter/material.dart';

class AddStudentDialog extends StatelessWidget {
  final TextEditingController lastNameController;
  final TextEditingController firstNameController;
  final TextEditingController middleNameController;
  final void Function(String lastName, String firstName, String middleName)
      onAddStudent;
  final bool isEditing;

  const AddStudentDialog({
    super.key,
    required this.lastNameController,
    required this.firstNameController,
    required this.middleNameController,
    required this.onAddStudent,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isEditing ? 'Edit Student\'s Details' : 'Add Student',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              labelStyle: TextStyle(color: Colors.grey),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF800000)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
            cursorColor: const Color(0xFF800000),
          ),
          TextField(
            controller: firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name',
              labelStyle: TextStyle(color: Colors.grey),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF800000)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
            cursorColor: const Color(0xFF800000),
          ),
          TextField(
            controller: middleNameController,
            decoration: const InputDecoration(
              labelText: 'Middle Name',
              labelStyle: TextStyle(color: Colors.grey),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF800000)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
            cursorColor: const Color(0xFF800000),
          ),
        ],
      ),
      actions: [
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
          onPressed: () {
            final lastName = lastNameController.text.trim();
            final firstName = firstNameController.text.trim();

            if (lastName.isEmpty && firstName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Last Name and First Name are required'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (lastName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Last Name is required'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (firstName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('First Name is required'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (lastName.length < 2 && firstName.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid Last Name and First Name'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            
            if (firstName.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid First Name'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            } 

            if (lastName.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid Last Name'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            onAddStudent(
              lastName,
              firstName,
              middleNameController.text.trim(),
            );
            Navigator.of(context).pop();
          },
          child: Text(
            isEditing ? 'Update' : 'Add',
            style: const TextStyle(color: Color(0xFF800000)),
          ),
        ),
      ],
    );
  }
}
