import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sugarcane_classifier/resultpage.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _budImageFile;
  XFile? _stemImageFile;
  bool _isLoading = false;

  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  }
  
  Future<void> _takeBudPicture() async {
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
      print('Error picking bud image: $e');
      _showSnackBar('Error taking bud picture: $e');
    }
  }

  Future<void> _takeStemPicture() async {
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
          _stemImageFile = photo;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Error picking stem image: $e');
      _showSnackBar('Error taking stem picture: $e');
    }
  }

  Future<void> _selectBudFromGallery() async {
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
      print('Error picking bud image from gallery: $e');
      _showSnackBar('Error selecting bud image: $e');
    }
  }

  Future<void> _selectStemFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        setState(() {
          _stemImageFile = image;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Error picking stem image from gallery: $e');
      _showSnackBar('Error selecting stem image: $e');
    }
  }

  Future<void> _classifySugarCane() async {
    if (_budImageFile == null || _stemImageFile == null) {
      _showSnackBar('Please take both bud and stem images');
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

      // Add bud and stem images to the request
      request.files.add(
        await http.MultipartFile.fromPath('bud_image', _budImageFile!.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath('stem_image', _stemImageFile!.path),
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

        // Navigate to results page with the cropped images
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsPage(
              originalBudImageFile: _budImageFile!,
              originalStemImageFile: _stemImageFile!,
              croppedBudImageBase64: data['cropped_bud_image'],
              croppedStemImageBase64: data['cropped_stem_image'],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.redAccent,
        action: message.contains('permission')
            ? SnackBarAction(
                label: 'Grant',
                onPressed: () => openAppSettings(),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Predict Sugar Cane Variety'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Identify Sugar Cane Variety',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Take clear photos of the sugar cane bud and stem for accurate classification',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  _buildImageSection('Bud Image', _budImageFile,
                      _takeBudPicture, _selectBudFromGallery),
                  const Divider(height: 48, thickness: 1),
                  _buildImageSection('Stem Image', _stemImageFile,
                      _takeStemPicture, _selectStemFromGallery),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isLoading ? null : _classifySugarCane,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSection(String title, XFile? imageFile,
      VoidCallback onTakePicture, VoidCallback onSelectFromGallery) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.help_outline, color: Colors.grey[600]),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('How to Take $title Photos'),
                    content: const Text(
                        'Ensure the image is clear, well-lit, and focused.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.4,
            width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageFile == null
                  ? Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.image,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                  : FadeInImage(
                      placeholder: MemoryImage(Uint8List(0)),
                      image: FileImage(File(imageFile.path)),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      fadeInDuration: const Duration(milliseconds: 300),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : onTakePicture,
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : onSelectFromGallery,
                icon: const Icon(Icons.photo_library, size: 20),
                label: const Text('Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
