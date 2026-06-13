import 'package:flutter/material.dart';

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
      return {
        'name': name,
        'controller': TextEditingController(text: name),
      };
    }).toList();
  }

  @override
  void dispose() {
    for (var m in _medicinesData) {
      final ctrl = m['controller'] as TextEditingController;
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addMedicine() {
    print("[DEBUG] _addMedicine called. Old length: ${_medicinesData.length}");
    try {
      setState(() {
        _medicinesData.add({
          'name': '',
          'controller': TextEditingController(),
        });
      });
      print("[DEBUG] _addMedicine done. New length: ${_medicinesData.length}");
    } catch (e, stack) {
      print("[DEBUG] _addMedicine error: $e");
      print(stack);
    }
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
    print("[DEBUG] build called. Medicines count: ${_medicinesData.length}");
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
                final controller = item['controller'] as TextEditingController;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          onChanged: (val) {
                            item['name'] = val;
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
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
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
