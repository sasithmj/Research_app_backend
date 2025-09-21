import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share/share.dart';
import 'dart:typed_data';

class ResultsPage extends StatelessWidget {
  final XFile originalBudImageFile;
  final XFile originalStemImageFile;
  final String croppedBudImageBase64;
  final String croppedStemImageBase64;

  final String variety;
  final num confidence;

  const ResultsPage({
    super.key,
    required this.originalBudImageFile,
    required this.originalStemImageFile,
    required this.croppedBudImageBase64,
    required this.croppedStemImageBase64,
    required this.variety,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    // Decode the base64 cropped images
    final croppedBudImageBytes = base64Decode(croppedBudImageBase64);
    final croppedStemImageBytes = base64Decode(croppedStemImageBase64);

    // Show snackbar when the page is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analysis Completed'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classification Results'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16), // Space after Snackbar

              // Images Display
              _buildImagesSection(originalBudImageFile, originalStemImageFile,
                  croppedBudImageBytes, croppedStemImageBytes),

              const SizedBox(height: 32),

              // Variety Result
              _buildVarietyResultCard(context),

              const SizedBox(height: 32),

              // Action Buttons
              _buildActionButtons(context),

              const SizedBox(height: 24),

              // Information Card
              _buildInformationCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagesSection(XFile originalBudImage, XFile originalStemImage,
      Uint8List croppedBudImageBytes, Uint8List croppedStemImageBytes) {
    return Column(
      children: [
        // Original Images Row
        Row(
          children: [
            // Original Bud Image
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Original Bud Image',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildImageCard(File(originalBudImage.path)),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Original Stem Image
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Original Stem Image',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildImageCard(File(originalStemImage.path)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Cropped Images Row
        Row(
          children: [
            // Cropped Bud Image
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Detected Bud',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCroppedImageCard(croppedBudImageBytes),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Cropped Stem Image
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Detected Stem',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCroppedImageCard(croppedStemImageBytes),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageCard(File imageFile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            imageFile,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildCroppedImageCard(Uint8List imageBytes) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            imageBytes,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildVarietyResultCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identified Variety',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              variety,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confidence Score',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: MediaQuery.of(context).size.width * (confidence / 100),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(confidence),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${confidence.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getConfidenceColor(confidence),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Another'),
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
            onPressed: () {
              // Share functionality
              Share.share(
                  'I identified a $variety with ${confidence.toStringAsFixed(1)}% confidence using the Plant Classifier app!');
            },
            icon: const Icon(Icons.share),
            label: const Text('Share Results'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInformationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About This Classification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This classification is based on machine learning analysis of the detected bud and stem. The system first identifies the bud and stem in your images, then analyzes specific features to determine the sugarcane variety.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get color based on confidence level
  Color _getConfidenceColor(num confidence) {
    if (confidence >= 90) {
      return Colors.green;
    } else if (confidence >= 70) {
      return Colors.lime;
    } else if (confidence >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
