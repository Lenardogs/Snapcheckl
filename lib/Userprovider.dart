import 'package:flutter/material.dart';

// Define your User class (you can expand this as needed)
class User {
  final String id;
  final String username;
  final String email;

  User({required this.id, required this.username, required this.email});
}

// The UserProvider class
class UserProvider with ChangeNotifier {
  // The current logged-in user
  User? _currentUser;

  // Getter to retrieve the current user
  User? get currentUser => _currentUser;

  // Method to log in the user
  void logIn(User user) {
    _currentUser = user;
    notifyListeners();  // Notify listeners (widgets) that the state has changed
  }

  // Method to log out the user
  void logOut() {
    _currentUser = null;
    notifyListeners();  // Notify listeners to rebuild widgets
  }
}