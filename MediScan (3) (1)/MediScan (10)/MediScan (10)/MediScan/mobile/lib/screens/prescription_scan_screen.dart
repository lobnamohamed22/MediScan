import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'prescription_verification_screen.dart';
import 'pharmacy_search_screen.dart';

class PrescriptionScanScreen extends StatefulWidget {
  const PrescriptionScanScreen({super.key});

  @override
  State<PrescriptionScanScreen> createState() => _PrescriptionScanScreenState();
}

class _PrescriptionScanScreenState extends State<PrescriptionScanScreen> {
  bool _isProcessing = false;
  String _ocrResult = '';
  List<String> _medicines = [];
  List<dynamic> _resolvedMeds = [];
  String _prescriptionId = '';
  bool _showResult = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _showResult = false;
    });

    final bytes = await image.readAsBytes();
    final filename = image.name.isNotEmpty ? image.name : 'upload.jpg';
    final result = await ApiService.uploadPrescription(bytes, filename);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _prescriptionId = result['prescription_id']?.toString() ?? '';
        final List medicinesData = result['medicines'] ?? [];
        _resolvedMeds = medicinesData;
        _medicines = medicinesData
            .map((m) => m['medicine_name']?.toString() ?? 'Unknown')
            .toList();
        _ocrResult = "Extracted ${_resolvedMeds.length} medicines";
        _isProcessing = false;
        _showResult = true;
      });
    } else {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Upload failed')),
      );
    }
  }

  Future<void> _verifyFlow() async {
    final verifiedList = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => PrescriptionVerificationScreen(
          initialMedicines: _resolvedMeds.map<Map<String, dynamic>>((m) => {
            'name': m['medicine_name']?.toString() ?? '',
            'image': m['medicine_image']?.toString() ?? '',
          }).toList(),
        ),
      ),
    );

    if (verifiedList != null && verifiedList.isNotEmpty) {
      final result =
          await ApiService.verifyPrescription(_prescriptionId, verifiedList);

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pushReplacementNamed(context, '/history');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(result['message'] ?? 'Error verifying prescription')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prescription'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Scan Prescription'),
            ),
            const SizedBox(height: 30),
            if (_isProcessing)
              Column(
                children: [
                  Lottie.asset(
                    'assets/animations/Loading.json',
                    width: 120,
                  ),
                  const SizedBox(height: 16),
                  const Text('AI is reading your prescription...'),
                ],
              )
            else if (_showResult)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// OCR RESULT BOX
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _medicines.isNotEmpty ? '$_ocrResult:' : _ocrResult,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_medicines.isNotEmpty) const SizedBox(height: 8),
                          ..._medicines.map(
                            (medicine) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 4.0, left: 8.0),
                              child: Text(
                                '• $medicine',
                                style: GoogleFonts.poppins(fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// SEARCH PHARMACIES BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.local_pharmacy),
                      label: const Text('Search Available Pharmacies'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PharmacySearchScreen(
                              fromPrescription: true,
                              prescriptionMedicines: _medicines,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// VERIFY BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.verified),
                      label: const Text('Verify Medicines'),
                      onPressed: _verifyFlow,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
