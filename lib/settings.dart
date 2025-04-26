import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'classpage.dart';
import 'add_test.dart';
import 'main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  String firstName = '';
  String lastName = '';
  String email = '';
  bool isLoading = true;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _loadUserData();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (!_isMounted) return; // Ensure the widget is still mounted

        setState(() {
          firstName = userDoc['firstName'] ?? 'Unknown';
          lastName = userDoc['lastName'] ?? 'User';
          email = currentUser!.email ?? 'No email';
          isLoading = false;
        });
      } catch (e) {
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading user data: $e")),
          );
        }
      }
    }
  }


  Route createLeftSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  Future<void> _logout() async {
    // Show confirmation dialog before logging out
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must choose an option
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.exit_to_app,
                  color: Colors.red[700],
                  size: 40,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Are you sure you want to log out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[
                            300], // Use backgroundColor instead of primary
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .pop(false); // Return false if canceled
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Logout Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .red[700], // Use backgroundColor instead of primary
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .pop(true); // Return true if confirmed
                      },
                      child: const Text(
                        'Log out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // If user confirmed logout, proceed with logout
    if (confirmLogout == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(color: Color(0xFF800000)),
                const SizedBox(width: 16),
                const Text("Logging out..."),
              ],
            ),
          );
        },
      );

      try {
        // Introduce a short delay for smoother UX
        await Future.delayed(const Duration(seconds: 2));

        // Perform sign-out
        await FirebaseAuth.instance.signOut();

        // Dismiss the dialog
        Navigator.of(context).pop();

        // Navigate to the login screen and clear navigation stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // Clear all routes
        );
      } catch (e) {
        Navigator.of(context).pop(); // Dismiss the dialog if an error occurs
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error during logout: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        backgroundColor: Color(0xFF800000), // Maroon background color
        foregroundColor: Colors.white, // Ensure icons and text are white
      ),
      body: ListView(
        children: [
          isLoading
              ? Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 10.0), // Adds padding to CircleAvatar and text
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 100,
                              height: 20,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 150,
                              height: 20,
                              color: Colors.grey[300],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ))
              : Padding(
                  padding: const EdgeInsets.only(
                      top: 20.0,
                      left: 10.0), // Adds padding to CircleAvatar and text
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.red[100],
                        child: Text(
                          (firstName.isNotEmpty ? firstName[0] : 'U') +
                              (lastName.isNotEmpty ? lastName[0] : 'U'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF800000),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$firstName $lastName',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(email),
                        ],
                      ),
                    ],
                  ),
                ),
          const SizedBox(height: 20),
          Divider(
            color: Colors.grey[300],
            thickness: 1.5,
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Tutorial'),
            onTap: () {
              // Navigation logic for Tutorial
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail),
            title: const Text('Contact Us'),
            onTap: () {
              Navigator.push(
                context,
                createLeftSlideRoute(const ContactUsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () {
              Navigator.push(
                context,
                createLeftSlideRoute(const PrivacyPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text('Terms of Service'),
            onTap: () {
              Navigator.push(
                context,
                createLeftSlideRoute(const TermsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: _logout,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: const Color(0xFF800000),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
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
        onTap: (int index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ClassesScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: Duration(milliseconds: 300),
              ),
            );
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ExamsPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: Duration(milliseconds: 300),
              ),
            );
          } else if (index == 2) {
            // Stay on the current Settings screen
          }
        },
      ),
    );
  }
}

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  // Function to launch email
  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      throw 'Could not launch $email';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us',
            style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            const Text(
              'If you have any questions, suggestions, or issues, please message us on',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.email, color: Color(0xFF800000), size: 28),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _launchEmail('snapccheck@gmail.com'),
                  child: RichText(
                    text: const TextSpan(
                      text: 'snapccheck@gmail.com',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF800000),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF800000), // Underline color
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: const [
                Icon(Icons.phone, color: Color(0xFF800000), size: 28),
                SizedBox(width: 10),
                Text(
                  '+63 918 462 4898',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Image.asset(
                'assets/images/logomar.png',
                height: 100,
                width: 100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
              fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        // Enable scrolling for long content
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Privacy Policy informs you of our policies regarding the collection, use, and disclosure of personal information when you use our App.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),

            // Information We Collect
            const Text(
              'Information We Collect',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'We may collect personally identifiable information, such as:',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 10),

            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'User Provided Information. ',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                  TextSpan(
                    text:
                        'When you create an account or use certain features of the App, we may collect information such as your name and email address.',
                    style: TextStyle(fontSize: 15, color: Colors.black),
                  ),
                ],
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 10), // Adds space between sections
            const SizedBox(height: 5),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Scanning Information. ',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                  TextSpan(
                    text:
                        'When you use the App to scan and grade answer sheets, we may collect and process the data present on the scanned sheets. This may include student answers and configurations provided by the user.',
                    style: TextStyle(fontSize: 15, color: Colors.black),
                  ),
                ],
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 18),
            // How We Use Your Information
            const Text(
              'How We Use Your Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'We use the collected information for various purposes, including but not limited to:',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const Text(
              '• Providing and maintaining the App.\n'
              '• Improving and customizing the App.\n'
              '• Communicating with you regarding updates or support.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 18),

            // Data Security
            const Text(
              'Data Security',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'We take appropriate measures to protect the security of your personal information. However, please be aware that no method of transmission over the internet or electronic storage is completely secure.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 18),

            const Text(
              'Disclosure of Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'We may disclose your personal information in the following circumstances:',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: Colors.black),
                children: [
                  TextSpan(
                    text: 'With Your Consent. ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        'We may share your information when you give us consent to do so.',
                  ),
                ],
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 10), // Adds space between sections
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: Colors.black),
                children: [
                  TextSpan(
                    text: 'Service Providers. ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        'We may engage third-party companies and individuals to facilitate our App, provide the App on our behalf, perform App-related services, or assist us in analyzing how the App is used.',
                  ),
                ],
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 10), // Adds space between sections
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: Colors.black),
                children: [
                  TextSpan(
                    text: 'Compliance with Laws. ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        'We may disclose information where required by law or to protect our rights or the rights of others.',
                  ),
                ],
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 18),

            // Changes to This Privacy Policy
            const Text(
              'Changes to This Privacy Policy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'We may update our Privacy Policy from time to time. You are advised to review this Privacy Policy periodically for any changes.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 22),
            const Text(
              'Contact Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'If you have any questions about our policies, please contact us at snapccheck@gmail.com.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            const Text(
              'By using the SnapCheck App, you agree to the terms outlined in this Privacy Policy.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms of Service',
          style: TextStyle(
              fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        // Added scrolling for long content
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please read these terms of service carefully before using the SnapCheck application.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              'Acceptance of Terms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'By accessing or using the SnapCheck App, you agree to be bound by these Terms. If you disagree with any part of the Terms, then you may not access the App.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15),
            const Text(
              'Use of the App',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'You agree to use the SnapCheck App only for its intended purpose. Any unauthorized use, modification, or distribution of the App is strictly prohibited.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15),
            const Text(
              'User Accounts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'To use certain features of the App, you may be required to create a user account. You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15),
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'Your use of the SnapCheck App is also governed by our Privacy Policy. Please review our Privacy Policy to understand how we collect, use, and disclose information.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15),
            const Text(
              'Modifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'We reserve the right to modify or replace these Terms at any time. Any changes will be effective immediately upon posting on the App. Your continued use of the App following the posting of any changes constitutes acceptance of those changes.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15),
            const Text(
              'Termination',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'We may terminate or suspend your access to the App immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach these Terms.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15),
            const Text(
              'Disclaimer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'The SnapCheck App is provided as is and as available without any warranties, express or implied. We do not guarantee the accuracy, completeness, or reliability of any content or features within the App for there are conditions that must be met.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15),
            const Text(
              'Limitation of Liability',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'In no event shall SnapCheck and its members be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15),
            const Text(
              'Contact Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'If you have any questions about these terms, please contact us at snapccheck@gmail.com.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }
}
