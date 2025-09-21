import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  // Controllers for text input fields
  final TextEditingController _sunshineDaysController = TextEditingController();
  final TextEditingController _soilTempController = TextEditingController();
  final TextEditingController _tempMaxController = TextEditingController();

  // Loading and result state variables
  bool _isLoading = false;
  double? _predictedProduction;
  String? _unit;

  // Global form key for validation
  final _formKey = GlobalKey<FormState>();

  // Method to predict sugar harvest
  Future<void> _predictSugarHarvest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _predictedProduction = null;
      _unit = null;
    });

    try {
      final requestBody = {
        'sunshine': double.parse(_sunshineDaysController.text),
        'soil_temp': double.parse(_soilTempController.text),
        'temp_max': double.parse(_tempMaxController.text),
      };

      final response = await http.post(
        Uri.parse('http://172.20.10.3:8000/api/predict-sugar-production/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _predictedProduction = data['predicted_sugar_production'];
          _unit = data['unit'];
        });
      } else {
        _showSnackBar(
            'Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to show snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugar Harvest Prediction'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Predict Sugar Harvest',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter environmental conditions to estimate sugar production',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                _buildInputFieldWithHelp(
                  controller: _sunshineDaysController,
                  label: 'Average Sunshine hours a day',
                  hint: 'e.g., 8.5',
                  icon: Icons.wb_sunny,
                  helperText: 'Typical range: 5-9 hours',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter sunshine days';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildInputFieldWithHelp(
                  controller: _soilTempController,
                  label: 'Soil Temperature (°C)',
                  hint: 'e.g., 25.0',
                  icon: Icons.device_thermostat,
                  helperText: 'Typical range: 20-30°C',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter soil temperature';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildInputFieldWithHelp(
                  controller: _tempMaxController,
                  label: 'Maximum Temperature (°C)',
                  hint: 'e.g., 35.0',
                  icon: Icons.thermostat,
                  helperText: 'Typical range: 25-40°C',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter maximum temperature';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _predictSugarHarvest,
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
                            Text('Predicting...'),
                          ],
                        )
                      : const Text(
                          'PREDICT HARVEST',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 32),
                if (_predictedProduction != null)
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.agriculture,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Predicted Remdement',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${_predictedProduction?.toStringAsFixed(2)} %',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
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

  // Helper method to build input fields with help icon
  Widget _buildInputFieldWithHelp({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?)? validator,
    String? helperText,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              helperText: helperText,
              prefixIcon: Icon(icon),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            keyboardType: TextInputType.number,
            validator: validator,
          ),
        ),
        IconButton(
          icon: Icon(Icons.help_outline, color: Colors.grey[600]),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('About $label'),
                content: const Text(
                    'Enter the average value for the growing season.'),
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
    );
  }
}
