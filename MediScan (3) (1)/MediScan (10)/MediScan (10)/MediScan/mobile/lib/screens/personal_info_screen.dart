import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../config.dart' as mediscan_config;

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController dobCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController cityCtrl;
  late TextEditingController governorateCtrl;

  Map<String, dynamic>? userData;
  bool _isLoading = true;
  bool _isSaving = false;
  Uint8List? _imageBytes;
  String? _imageName;
  final ImagePicker _picker = ImagePicker();

  String gender = 'Male';

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    emailCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
    dobCtrl = TextEditingController();
    addressCtrl = TextEditingController();
    cityCtrl = TextEditingController();
    governorateCtrl = TextEditingController();
    loadData();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    dobCtrl.dispose();
    addressCtrl.dispose();
    cityCtrl.dispose();
    governorateCtrl.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      final data = await ApiService.getProfile();
      if (!mounted) return;
      
      final Map<String, dynamic> rawData = data.containsKey('data') ? data['data'] : data;
      
      setState(() {
        userData = rawData;
        nameCtrl.text = rawData['name']?.toString() ?? '';
        emailCtrl.text = rawData['email']?.toString() ?? '';
        phoneCtrl.text = rawData['phone']?.toString() ?? '';
        dobCtrl.text = rawData['date_of_birth']?.toString() ?? '';
        addressCtrl.text = rawData['address']?.toString() ?? '';
        cityCtrl.text = rawData['city']?.toString() ?? '';
        governorateCtrl.text = rawData['governorate']?.toString() ?? '';
        
        if (rawData['gender'] != null && ['Male', 'Female'].contains(rawData['gender'].toString())) {
          gender = rawData['gender'].toString();
        } else {
          gender = 'Male';
        }
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading personal information: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = pickedFile.name;
        });
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<void> _deletePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_imageBytes != null) {
        setState(() {
          _imageBytes = null;
          _imageName = null;
        });
      }
      if (userData?['profile_image'] != null) {
        setState(() {
          _isSaving = true;
        });
        final result = await ApiService.deleteProfileImage();
        setState(() {
          _isSaving = false;
        });
        if (result['success'] == true) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Profile picture removed successfully')),
          );
          loadData(); // Reload profile details instantly from database
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to remove profile picture')),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error removing profile picture')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    Map<String, dynamic> updateData = {
      'name': nameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'date_of_birth': dobCtrl.text.trim(),
      'gender': gender,
      'address': addressCtrl.text.trim(),
      'city': cityCtrl.text.trim(),
      'governorate': governorateCtrl.text.trim(),
    };

    // First update the profile data
    final result = await ApiService.updateProfile(updateData);

    // Then upload the image if one was picked
    if (_imageBytes != null && result['success'] == true) {
      final uploadResult = await ApiService.uploadProfileImage(_imageBytes!, _imageName ?? 'profile.jpg');
      if (uploadResult['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload profile image')),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personal Information updated successfully')),
        );
        loadData(); // Reload fresh values from server
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? 'Failed to update personal information')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Information'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSaving
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Saving updates...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Avatar Picker
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundImage: _imageBytes != null
                                  ? MemoryImage(_imageBytes!) as ImageProvider
                                  : (userData?['profile_image'] != null
                                      ? NetworkImage(
                                          userData!['profile_image'].toString().startsWith('http')
                                              ? userData!['profile_image'].toString()
                                              : '${mediscan_config.Config.baseUrl}/${userData!['profile_image']}'
                                        )
                                      : null),
                              child: _imageBytes == null &&
                                      userData?['profile_image'] == null
                                  ? const Icon(Icons.person, size: 55)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.blue,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt,
                                      size: 18, color: Colors.white),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_imageBytes != null || userData?['profile_image'] != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              'Remove Photo',
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: _deletePhoto,
                          ),
                        ],

                        const SizedBox(height: 24),

                        _field('Full Name', nameCtrl),
                        _field('Email', emailCtrl),
                        _field('Phone', phoneCtrl),
                        _field('Date of Birth', dobCtrl),
                        _field('Address', addressCtrl),
                        _field('City', cityCtrl),
                        _field('Governorate', governorateCtrl),

                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          initialValue: gender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                          ),
                          items: ['Male', 'Female']
                              .map(
                                  (e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => gender = v!),
                        ),

                        const SizedBox(height: 35),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _save,
                            child: Text(
                              'Save Changes',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
