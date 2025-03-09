import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facial Feature Extraction',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FacialAnalysisScreen(),
    );
  }
}

class FacialAnalysisScreen extends StatefulWidget {
  const FacialAnalysisScreen({super.key});
  @override
  State<FacialAnalysisScreen> createState() => _FacialAnalysisScreenState();
}

class _FacialAnalysisScreenState extends State<FacialAnalysisScreen> {
  File? _imageFile;
  bool _isLoading = false;
  String? _summary;
  final ImagePicker _picker = ImagePicker();

  // Method to pick image from gallery or camera.
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _summary = null;
      });
    }
  }

  // Method to send the image to your server and get a summary.
  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;
    setState(() {
      _isLoading = true;
      _summary = null;
    });

    try {
      // Replace the URL with your server's address.
      var uri = Uri.parse('http://192.168.1.8:5000/analyze');
      var request = http.MultipartRequest('POST', uri);
      request.files
          .add(await http.MultipartFile.fromPath('image', _imageFile!.path));
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          _summary = data['summary'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _summary = 'Error: Server returned ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _summary = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // Build UI with image display, buttons, and summary output.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facial Feature Extraction'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image display container.
            Container(
              margin: const EdgeInsets.all(16),
              width: double.infinity,
              height: 300,
              color: Colors.grey[300],
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.contain)
                  : const Center(child: Text("No image selected")),
            ),
            // Buttons for selecting image and analysis.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.analytics),
                  label: const Text("Analyze"),
                  onPressed: _analyzeImage,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Loading indicator.
            if (_isLoading) const CircularProgressIndicator(),
            // Display the summary text.
            if (_summary != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _summary!,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
