import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PrescriptionVerificationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialMedicines;

  const PrescriptionVerificationScreen({
    super.key,
    required this.initialMedicines,
  });

  @override
  State<PrescriptionVerificationScreen> createState() =>
      _PrescriptionVerificationScreenState();
}

class _PrescriptionVerificationScreenState
    extends State<PrescriptionVerificationScreen> {
  late List<Map<String, dynamic>> _medicinesData;

  @override
  void initState() {
    super.initState();
    _medicinesData = widget.initialMedicines.map((m) {
      final name = m['name']?.toString() ?? '';
      final image = m['image']?.toString() ?? '';
      return {
        'name': name,
        'image': image,
        'controller': TextEditingController(text: name),
      };
    }).toList();

    // Proactively query images for medicines that have missing/empty images initially
    for (int i = 0; i < _medicinesData.length; i++) {
      if (_medicinesData[i]['image'].toString().isEmpty) {
        _fetchImageForName(i, _medicinesData[i]['name']);
      }
    }
  }

  @override
  void dispose() {
    for (var m in _medicinesData) {
      final ctrl = m['controller'] as TextEditingController;
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchImageForName(int index, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _medicinesData[index]['image'] = '';
        });
      }
      return;
    }

    try {
      final res = await ApiService.searchMedicines(trimmed);
      if (res['success'] == true && mounted) {
        final List data = res['data'] ?? [];
        if (data.isNotEmpty) {
          Map<String, dynamic>? match;
          // First, try exact case-insensitive match
          for (var m in data) {
            final dbName = m['medicine_name'].toString().toLowerCase().trim();
            final searchName = trimmed.toLowerCase();
            if (dbName == searchName) {
              match = Map<String, dynamic>.from(m);
              break;
            }
          }
          // If no exact match, try high-confidence substring match
          if (match == null) {
            for (var m in data) {
              final dbName = m['medicine_name'].toString().toLowerCase().trim();
              final searchName = trimmed.toLowerCase();
              if (dbName.contains(searchName) || searchName.contains(dbName)) {
                match = Map<String, dynamic>.from(m);
                break;
              }
            }
          }
          
          if (match != null) {
            final imgUrl = match['medicine_image']?.toString() ?? '';
            setState(() {
              _medicinesData[index]['image'] = imgUrl;
            });
          } else {
            setState(() {
              _medicinesData[index]['image'] = '';
            });
          }
        } else {
          setState(() {
            _medicinesData[index]['image'] = '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching medicine image dynamically: $e");
    }
  }

  void _addMedicine() {
    setState(() {
      _medicinesData.add({
        'name': '',
        'image': '',
        'controller': TextEditingController(),
      });
    });
  }

  void _removeMedicine(int index) {
    setState(() {
      final ctrl = _medicinesData[index]['controller'] as TextEditingController;
      ctrl.dispose();
      _medicinesData.removeAt(index);
    });
  }

  void _confirm() {
    final result = _medicinesData
        .map((m) {
          final ctrl = m['controller'] as TextEditingController;
          return ctrl.text.trim();
        })
        .where((e) => e.isNotEmpty)
        .toList();

    if (result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one medicine')),
      );
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Prescription'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Review detected medicines and edit if needed',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _medicinesData.length,
              itemBuilder: (context, index) {
                final item = _medicinesData[index];
                final String imageUrl = item['image'] ?? '';
                final controller = item['controller'] as TextEditingController;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // ClipRRect rounded medicine thumbnail next to name
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[200],
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.medication, color: Colors.grey),
                                )
                              : const Icon(Icons.medication, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          onChanged: (val) {
                            item['name'] = val;
                            _fetchImageForName(index, val);
                          },
                          decoration: InputDecoration(
                            labelText: 'Medicine ${index + 1}',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeMedicine(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addMedicine,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
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
