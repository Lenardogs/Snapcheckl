import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'add_class_screen.dart';
import 'student_details_page.dart';
import 'add_test.dart';
import 'class_model.dart';
import 'settings.dart';

Route createSlideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  _ClassesScreenState createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  bool _isSelectionMode = false;
  final List<String> _selectedClassIds = [];

  @override
  void initState() {
    super.initState();

    // Defer fetching classes until the first frame has been rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      classProvider.fetchClasses();
    });

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF800000),
        title: const Text(
          "Classes",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        actions: [
          if (_isSelectionMode)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedClassIds.clear(); // Clear selected items
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    _confirmRemoveSelectedClasses(classProvider);
                  },
                ),
              ],
            )
          else
            Row(
        children: [
          TextButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (BuildContext context) {
                  return const AddClassScreen();
                },
              );
            },
            child: const Row(
              children: [
                Icon(Icons.add, color: Colors.white, size: 20), // Add Icon before text
                SizedBox(width: 5), // Spacing between icon and text
                Text(
                  "Add Class",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
              onSelected: (value) {
                if (value == 'remove') {
                  setState(() {
                    _isSelectionMode = true;
                  });
                } else if (value == 'sort_program') {
                  _sortClasses(classProvider, 'program');
                } else if (value == 'sort_course') {
                  _sortClasses(classProvider, 'course');
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'remove',
                    child: Text('Remove Classes'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'sort_program',
                    child: Text('Sort by Program'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'sort_course',
                    child: Text('Sort by Course'),
                  ),
                ];
              },
           ),
        ],
      ),
    ],
  ),
      body: classProvider.isLoading
          ? _buildShimmerLoading()
          : classProvider.classes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_, size: 100, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        "No class added.",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      Text(
                        "Start adding class.",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height:20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF800000),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context:context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (BuildContext context) {
                              return const AddClassScreen();
                            },
                          );
                        },
                        icon: Icon(Icons.add),
                        label: Text("Add Class"),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: classProvider.classes.length,
                  itemBuilder: (context, index) {
                    final classItem = classProvider.classes[index];
                    final isSelected = _selectedClassIds.contains(classItem.id);

                    return Column(
                      children: [
                        ListTile(
                          title: Text(
                            '${classItem.program} ${classItem.yearLevel} - ${classItem.section}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF707070)),
                          ),
                          subtitle: Text(
                            classItem.course,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF707070)),
                          ),
                          trailing: _isSelectionMode
                              ? Checkbox(
                                  activeColor: Color(0xFF800000),
                                  value: isSelected,
                                  onChanged: (bool? selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedClassIds.add(classItem.id);
                                      } else {
                                        _selectedClassIds.remove(classItem.id);
                                      }
                                    });
                                  },
                                )
                              : const Text(
                                  'View Students',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF707070)),
                                ),
                          onTap: _isSelectionMode
                              ? () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedClassIds.remove(classItem.id);
                                    } else {
                                      _selectedClassIds.add(classItem.id);
                                    }
                                  });
                                }
                              : () {
                                  Navigator.push(
                                    context,
                                    createSlideRoute(
                                      StudentDetailsPage(classItem: classItem),
                                    ),
                                  );
                                },
                        ),
                        Divider(
                          color: Colors.grey[300],
                          thickness: 1.5,
                        ),
                      ],
                    );
                  },
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Color(0xFF800000),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
        items: [
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
            // Stay on the current Classes screen
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
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ProfileScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 50.0,
                    height: 50.0,
                    color: Colors.white,
                  ),
                  title: Container(
                    height: 16.0,
                    color: Colors.white,
                  ),
                  subtitle: Container(
                    height: 14.0,
                    margin: const EdgeInsets.only(top: 4.0),
                    color: Colors.white,
                  ),
                ),
                Divider(
                  color: Colors.grey[300],
                  thickness: 1.5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveSelectedClasses(ClassProvider classProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content:
            const Text("Are you sure you want to remove selected classes?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF800000))),
          ),
          TextButton(
            onPressed: () {
              for (var classId in _selectedClassIds) {
                classProvider.removeClass(classId);
              }
              setState(() {
                _isSelectionMode = false;
                _selectedClassIds.clear();
              });
              Navigator.of(context).pop();
            },
            child: const Text("Remove",
                style: TextStyle(color: Color(0xFF800000))),
          ),
        ],
      ),
    );
  }

  void _sortClasses(ClassProvider classProvider, String field) {
    if (field == 'program') {
      classProvider.classes.sort((a, b) => a.program.compareTo(b.program));
    } else if (field == 'course') {
      classProvider.classes.sort((a, b) => a.course.compareTo(b.course));
    }
    classProvider.notifyListeners();
  }
}
