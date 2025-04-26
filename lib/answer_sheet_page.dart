import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'exam_model.dart';
import 'add_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

class AnswerSheetPage extends StatefulWidget {
  final String testName;
  final String className;
  final String classYearLevel;
  final String subjectName;
  final int parts;
  final List<String> questionTypes;
  final List<int> numberOfQuestions;
  final int totalscore;
  final String classId;

  const AnswerSheetPage({
    super.key,
    required this.testName,
    required this.className,
    required this.classYearLevel,
    required this.subjectName,
    required this.parts,
    required this.questionTypes,
    required this.numberOfQuestions,
    required this.totalscore,
    required this.classId,
  });

  @override
  _AnswerSheetPageState createState() => _AnswerSheetPageState();
}

class _AnswerSheetPageState extends State<AnswerSheetPage> {
  String selectedPaperSize = 'A4';

  // Map for selecting the paper format
  Map<String, PdfPageFormat> paperFormats = {
    'Short': PdfPageFormat(612, 792), 
    'A4': PdfPageFormat.a4,
    'Long': PdfPageFormat(612, 936), 
  };

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    final pageFormat = paperFormats[selectedPaperSize] ?? PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              

              // Name and Score row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Name: ________________________________',
                      style: pw.TextStyle(fontSize: 7)),
                 
                ],
              ),
              pw.SizedBox(height: 6), // Increased spacing

              pw.Divider(
                thickness: 1, // Adjust thickness as needed
                height: 16, // Spacing between the divider and surrounding content
              ),

              // Question List Section
              pw.Expanded(
                child: _buildQuestionsList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${widget.testName} ${widget.subjectName}-AnswerSheet.pdf',
    );
  }

  pw.Widget _buildQuestionsList() {
    List<pw.Widget> leftColumn = [];
    List<pw.Widget> rightColumn = [];
    int totalQuestions = widget.numberOfQuestions.reduce((a, b) => a + b);

    // Font size and row height adjustments for compact layout
    double fontSize = 10; // Slightly reduced font size
    double rowHeight = 15.3;
    double lineWidth = 140; // Adjusted line width for left column answers
    double columnSpacing = 90; // Increased spacing to move the right column slightly

    // Divide questions into two sequential halves
    int halfway = (totalQuestions / 2).ceil();

    // Build the left column
    for (int i = 1; i <= halfway; i++) {
      leftColumn.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '$i.',
                style: pw.TextStyle(fontSize: fontSize),
              ),
              pw.SizedBox(width: 4),
              pw.Container(
                height: rowHeight,
                width: lineWidth,
              ),
            ],
          ),
        ),
      );
    }

    // Build the right column
    for (int i = halfway + 1; i <= totalQuestions; i++) {
      rightColumn.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '$i.',
                style: pw.TextStyle(fontSize: fontSize),
              ),
              pw.SizedBox(width: 4),
              pw.Container(
                height: rowHeight,
                width: lineWidth,
              ),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        // Left Column
        pw.Padding(
          padding: pw.EdgeInsets.only(right: columnSpacing / 2), // Keep left column stable
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: leftColumn,
          ),
        ),
        // Right Column
        pw.Padding(
          padding: pw.EdgeInsets.only(left: columnSpacing), // Move right column to the right
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: rightColumn,
          ),
        ),
      ],
    );
  }

  Future<Uint8List> _generatePdfBytes(String subjectName, String testName) async {
  final pdf = pw.Document();

  final pageFormat = paperFormats[selectedPaperSize] ?? PdfPageFormat.a4;

  pdf.addPage(
    pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(16),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header Section
            pw.Center(
              child: pw.Text(
                '$subjectName - $testName', // Use the passed values here
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 3),

            

            // Question List Section
            pw.Expanded(
              child: _buildQuestionsList(),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save(); // Return PDF bytes
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Answer Sheet', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF800000),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: () async {
              User? user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                print("User not logged in.");
                return;
              }

              int totalQuestions = widget.numberOfQuestions.reduce((a, b) => a + b);

              try {
                // Check if the exam already exists
                QuerySnapshot existingExamSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('classes')
                    .doc(widget.classId)
                    .collection('exams')
                    .where('testName', isEqualTo: widget.testName)
                    .where('subjectName', isEqualTo: widget.subjectName)
                    .get();

                if (existingExamSnapshot.docs.isNotEmpty) {
                  // If the exam exists, update it
                  print("Exam already exists. Updating details...");
                  await existingExamSnapshot.docs.first.reference.update({
                    'totalQuestions': totalQuestions,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Exam created successfully.")),
                  );
                } else {
                  // If the exam doesn't exist, add it
                  Exam newExam = Exam(
                    id: '',
                    testName: widget.testName,
                    className: widget.className,
                    classYearLevel: widget.classYearLevel,
                    classId: widget.classId,
                    subjectName: widget.subjectName,
                    totalQuestions: totalQuestions,
                    totalScore: widget.totalscore,
                    parts: [],
                  );

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('classes')
                      .doc(widget.classId)
                      .collection('exams')
                      .add(newExam.toMap());
                  print("New exam added successfully.");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("New exam added successfully.")),
                  );
                }
                // Navigate back to the ExamsPage
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => ExamsPage()),
                  (route) => false,
                );
              } catch (error) {
                print("Error saving exam: $error");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error saving exam: $error")),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          PdfPreview(
            build: (format) => _generatePdfBytes(widget.subjectName, widget.testName),
            allowPrinting: false,
            allowSharing: false,
            initialPageFormat: paperFormats[selectedPaperSize] ?? PdfPageFormat.a4,
            canChangePageFormat: false,
            canChangeOrientation: false,
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Paper Size Dropdown
                DropdownButton<String>(
                  value: selectedPaperSize,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedPaperSize = newValue!;
                    });
                  },
                  items: <String>['Short', 'A4', 'Long']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                SizedBox(width: 10), // Space between dropdown and button
                ElevatedButton(
                  onPressed: () {
                    _generatePdf();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF800000),
                  ),
                  child: const Text(
                    "Generate PDF",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
