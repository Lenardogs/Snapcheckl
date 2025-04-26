import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'classpage.dart';
import 'class_model.dart';
import 'exam_model.dart';
import 'student_model.dart';
import 'forgotpassword.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ClassProvider()),
        ChangeNotifierProxyProvider<ClassProvider, ExamProvider>(
          create: (context) => ExamProvider(classId: ''),
          update: (context, classProvider, examProvider) {
            final classId = classProvider.currentClassId;
            final allClassIds = classProvider.classes
                .map((classModel) => classModel.id)
                .toList();
            return examProvider!..updateClassId(classId, allClassIds);
          },
        ),
        ChangeNotifierProvider(create: (context) => StudentProvider()),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AuthenticationWrapper(),
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData) {
          return const ClassesScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? errorMessage;
  bool isLoading = false;
  bool _obscurePassword = true;

  Future<void> loginUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Check Internet Connection
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("No internet connection. Please connect to the internet."),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!email.contains("@")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email address."),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ClassesScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          errorMessage = 'No user found with this email.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Incorrect password. Please try again.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email address format.';
        } else {
          errorMessage = 'Wrong email or password';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF800000),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: Image.asset(
                  'assets/images/logowhite.png',
                  height: 150.0,
                ),
              ),
              const SizedBox(height: 40.0),
              TextField(
                controller: _emailController,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email, color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              TextField(
                controller: _passwordController,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.white),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 20.0),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen()),
                  );
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20.0),
              isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : ElevatedButton(
                      onPressed: loginUser,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF800000),
                      ),
                      child: const Text('Log In'),
                    ),
              const SizedBox(height: 20.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Don\'t have an account?',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  String? errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> registerUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    // Validate first name
    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("First name is required."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate last name
    if (lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Last name is required."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate email format
    if (!email.contains("@")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email address."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate password confirmation
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate password length
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters long."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Register the user
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional user details to Firestore
      await saveUserDetails(userCredential.user!.uid);

      // Sign the user out after registration
      await _auth.signOut();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration successful. Please log in."),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to the login screen (do not log in the user)
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? "An error occurred. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> saveUserDetails(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
    });
  }

  bool _termsAccepted = false; // Track checkbox state

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents accidental closing
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Smooth rounded corners
          ),
          title: const Center(
            child: Text(
              "📜 Terms & Conditions",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF800000), // Matching theme color
              ),
            ),
          ),
          content: SizedBox(
            height: 280, // Adjusted height for content balance
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Welcome to our application! By signing up, you agree to the following terms:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "🔹 Eligibility: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                            text:
                                "You must be a registered instructor at PUP Lopez Branch to use this app.\n\n"),
                        TextSpan(
                          text: "🔹 Purpose & User Conduct: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                            text:
                                "This application is strictly for checking and grading examinations. Any unauthorized use is prohibited.\n\n"),
                        TextSpan(
                          text: "🔹 Account Security: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                            text:
                                "Keep your login details secure and do not share them.\n\n"),
                        TextSpan(
                          text: "🔹 Privacy Protection: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                            text:
                                "Your data is securely handled and will not be shared without consent.\n\n"),
                        TextSpan(
                          text: "🔹 Updates & Changes: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                            text:
                                "We may update these terms periodically, and continued use means acceptance.\n\n"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Color(0xFF800000), // Matching button color
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: const Text("Accept & Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF800000),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/logowhite.png',
                  height: 150.0,
                ),
              ),
              const SizedBox(height: 40.0),
              TextField(
                controller: _firstNameController,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              TextField(
                controller: _lastNameController,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              TextField(
                controller: _emailController,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email, color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              TextField(
                controller: _passwordController,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.white),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 20.0),
              TextField(
                controller: _confirmPasswordController,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: const TextStyle(color: Colors.white),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                obscureText: _obscureConfirmPassword,
              ),
              const SizedBox(height: 20.0),

              // Terms and Conditions Checkbox
              Row(
                children: [
                  Checkbox(
                    value: _termsAccepted,
                    activeColor: Colors.white,
                    checkColor: const Color(0xFF800000),
                    onChanged: (bool? newValue) {
                      setState(() {
                        _termsAccepted = newValue ?? false;
                      });
                    },
                  ),
                  const Text(
                    "I agree to the ",
                    style: TextStyle(color: Colors.white),
                  ),
                  GestureDetector(
                    onTap: _showTermsAndConditions,
                    child: const Text(
                      "Terms and Conditions",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20.0),

              // Sign Up Button (Disabled if Terms are not accepted)
              ElevatedButton(
                onPressed: _termsAccepted ? registerUser : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF800000),
                ),
                child: const Text('Sign Up'),
              ),

              const SizedBox(height: 20.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Log In',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

