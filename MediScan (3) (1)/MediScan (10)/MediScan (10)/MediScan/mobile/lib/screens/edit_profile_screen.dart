import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../config.dart' as mediscan_config;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController dobCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController cityCtrl;
  late TextEditingController governorateCtrl;

  Map<String, dynamic>? initialData;
  bool _isInit = false;
  bool _isLoading = false;
  Uint8List? _imageBytes;
  String? _imageName;
  final ImagePicker _picker = ImagePicker();

  String gender = 'Male';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      initialData = args;

      nameCtrl = TextEditingController(text: args?['name']?.toString() ?? '');
      emailCtrl = TextEditingController(text: args?['email']?.toString() ?? '');
      phoneCtrl = TextEditingController(text: args?['phone']?.toString() ?? '');
      dobCtrl =
          TextEditingController(text: args?['date_of_birth']?.toString() ?? '');
      addressCtrl = TextEditingController(text: args?['address']?.toString() ?? '');
      cityCtrl = TextEditingController(text: args?['city']?.toString() ?? '');
      governorateCtrl = TextEditingController(text: args?['governorate']?.toString() ?? '');

      if (args?['gender'] != null && ['Male', 'Female'].contains(args!['gender'].toString())) {
        gender = args['gender'].toString();
      } else {
        gender = 'Male';
      }

      _isInit = true;
    }
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
      if (initialData?['profile_image'] != null) {
        setState(() {
          _isLoading = true;
        });
        final result = await ApiService.deleteProfileImage();
        setState(() {
          _isLoading = false;
        });
        if (result['success'] == true) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Profile picture removed successfully')),
          );
          setState(() {
            initialData?['profile_image'] = null;
          });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // avatar
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundImage: _imageBytes != null
                              ? MemoryImage(_imageBytes!) as ImageProvider
                              : (initialData?['profile_image'] != null
                                  ? NetworkImage(
                                      initialData!['profile_image'].toString().startsWith('http')
                                          ? initialData!['profile_image'].toString()
                                          : '${mediscan_config.Config.baseUrl}/${initialData!['profile_image']}'
                                    )
                                  : null),
                          child: _imageBytes == null &&
                                  initialData?['profile_image'] == null
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

                    if (_imageBytes != null || initialData?['profile_image'] != null) ...[
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

                    // gender
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

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: Text(
                          'Save Changes',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        readOnly: readOnly,
        // Removed strict validation to allow partial updates
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> updateData = {};
    if (nameCtrl.text.trim().isNotEmpty) {
      updateData['name'] = nameCtrl.text.trim();
    }
    if (phoneCtrl.text.trim().isNotEmpty) {
      updateData['phone'] = phoneCtrl.text.trim();
    }
    if (emailCtrl.text.trim().isNotEmpty) {
      updateData['email'] = emailCtrl.text.trim();
    }
    if (dobCtrl.text.trim().isNotEmpty) {
      updateData['date_of_birth'] = dobCtrl.text.trim();
    }
    updateData['gender'] = gender;
    updateData['address'] = addressCtrl.text.trim();
    updateData['city'] = cityCtrl.text.trim();
    updateData['governorate'] = governorateCtrl.text.trim();

    // First update the profile data
    final result = await ApiService.updateProfile(updateData);

    // Then upload the image if one was picked
    if (_imageBytes != null && result['success'] == true) {
      final uploadResult = await ApiService.uploadProfileImage(_imageBytes!, _imageName ?? 'profile.jpg');
      if (uploadResult['success'] == true) {
        // If image uploaded successfully, update local image URL
        if (uploadResult['data'] != null &&
            uploadResult['data']['profile_image'] != null) {
          if (result['data'] != null) {
            result['data']['profile_image'] =
                uploadResult['data']['profile_image'];
          } else {
            result['data'] = {
              'profile_image': uploadResult['data']['profile_image']
            };
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );

        final returnedData = Map<String, dynamic>.from(initialData ?? {});
        if (result['data'] != null) {
          returnedData.addAll(result['data']);
        } else {
          returnedData.addAll(updateData);
        }

        Navigator.pop(context, returnedData);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? 'Failed to update profile')),
        );
      }
    }
  }
}
