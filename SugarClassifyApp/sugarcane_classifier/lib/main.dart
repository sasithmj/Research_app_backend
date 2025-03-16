import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sugarcane_classifier/resultpage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sugar Cane Classifier',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 8, 255, 82),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      home: const SugarCaneClassifierPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SugarCaneClassifierPage extends StatefulWidget {
  const SugarCaneClassifierPage({super.key});

  @override
  State<SugarCaneClassifierPage> createState() =>
      _SugarCaneClassifierPageState();
}

class _SugarCaneClassifierPageState extends State<SugarCaneClassifierPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _budImageFile;
  bool _isLoading = false;

  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  }

  Future<void> _takePicture() async {
    bool hasPermission = await _requestCameraPermission();
    if (!hasPermission) {
      if (!mounted) return;
      _showSnackBar('Camera permission is required to take pictures');
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );

      if (photo != null && mounted) {
        setState(() {
          _budImageFile = photo;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Error picking image: $e');
      _showSnackBar('Error taking picture: $e');
    }
  }

  Future<void> _selectFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        setState(() {
          _budImageFile = image;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Error picking image from gallery: $e');
      _showSnackBar('Error selecting image: $e');
    }
  }

  Future<void> _classifySugarCane() async {
    if (_budImageFile == null) {
      _showSnackBar('Please take a bud image first');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://172.20.10.3:8000/api/predict/'),
      );

      // Add bud image to the request
      request.files.add(
        await http.MultipartFile.fromPath('bud_image', _budImageFile!.path),
      );

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        // Navigate to results page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsPage(
              imageFile: _budImageFile!,
              variety: data['variety'],
              confidence: data['confidence'],
            ),
          ),
        );
      } else {
        _showSnackBar(
            'Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugar Cane Classifier'),
        // centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Container(
        // decoration: BoxDecoration(
        //   gradient: LinearGradient(
        //     begin: Alignment.topCenter,
        //     end: Alignment.bottomCenter,
        //     colors: [
        //       Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        //       Theme.of(context).colorScheme.background,
        //     ],
        //   ),
        // ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Identify Sugar Cane Variety',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Take a clear photo of the sugar cane bud for accurate classification',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 36),

                // Bud Image Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    height: 320,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background: Show selected image or placeholder
                          _budImageFile == null
                              ? Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Text(
                                      'No image selected',
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.grey),
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(_budImageFile!.path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),

                          // Lottie animation overlay (Only when loading)
                          if (_isLoading)
                            Container(
                              color: Colors.black.withOpacity(
                                  0.7), // Optional: Adds a dark overlay
                              child: Center(
                                child: Lottie.network(
                                  'https://lottie.host/8b408051-6bb5-436f-b71b-194fa936dcf3/q2q5rJlo65.json',
                                  width: 300,
                                  height: 300,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Image Selection Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _takePicture,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _selectFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Classification Button
                FilledButton(
                  onPressed: _isLoading ? null : _classifySugarCane,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text('Analyzing...'),
                          ],
                        )
                      : const Text(
                          'CLASSIFY VARIETY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
