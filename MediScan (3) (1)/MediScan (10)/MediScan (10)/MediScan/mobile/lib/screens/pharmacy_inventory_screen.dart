import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class PharmacyInventoryScreen extends StatefulWidget {
  const PharmacyInventoryScreen({super.key});

  @override
  State<PharmacyInventoryScreen> createState() => _PharmacyInventoryScreenState();
}

class _PharmacyInventoryScreenState extends State<PharmacyInventoryScreen> {
  List<dynamic> _inventory = [];
  List<dynamic> _filteredInventory = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInventory();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInventory() async {
    try {
      final response = await ApiService.getPharmacyInventory();
      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _inventory = response['data'] ?? [];
          _onSearchChanged();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading inventory: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredInventory = List.from(_inventory);
      } else {
        _filteredInventory = _inventory.where((item) {
          final name = (item['medicine_name'] ?? '').toString().toLowerCase();
          final generic = (item['generic_name'] ?? '').toString().toLowerCase();
          return name.contains(query) || generic.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _deleteItem(String inventoryId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Are you sure you want to remove "$name" from your inventory completely?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isLoading = true);
      try {
        final result = await ApiService.deleteInventoryItem(inventoryId);
        if (result['success'] == true) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Medicine removed from inventory')),
          );
          _fetchInventory();
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to delete medicine')),
          );
          setState(() => _isLoading = false);
        }
      } catch (e) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Error communicating with server')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditStockPriceDialog(Map<String, dynamic> item) {
    final inventoryId = item['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(text: item['medicine_name'] ?? '');
    final genericCtrl = TextEditingController(text: item['generic_name'] ?? '');
    final batchCtrl = TextEditingController(text: item['batch_number'] ?? 'BATCH01');
    final expiryCtrl = TextEditingController(text: item['expiry_date'] ?? '2027-12-31');
    final stockCtrl = TextEditingController(text: item['stock_quantity']?.toString() ?? '0');
    final priceCtrl = TextEditingController(text: item['price']?.toString() ?? '0.0');
    bool reqPrescription = item['is_prescription_required'] == true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Stock Details'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Medicine Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: genericCtrl,
                    decoration: const InputDecoration(labelText: 'Generic Name / Category'),
                  ),
                  TextFormField(
                    controller: batchCtrl,
                    decoration: const InputDecoration(labelText: 'Batch Number'),
                  ),
                  TextFormField(
                    controller: expiryCtrl,
                    decoration: const InputDecoration(labelText: 'Expiry Date (YYYY-MM-DD)'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                      if (!regex.hasMatch(v)) return 'Use YYYY-MM-DD format';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock Quantity'),
                    validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter a valid number' : null,
                  ),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price (EGP)'),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid decimal price' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Prescription Required', style: TextStyle(fontSize: 14)),
                    value: reqPrescription,
                    onChanged: (val) {
                      setDialogState(() {
                        reqPrescription = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && mounted) {
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isLoading = true);
                  
                  final updateData = {
                    'id': inventoryId,
                    'medicine_name': nameCtrl.text.trim(),
                    'generic_name': genericCtrl.text.trim(),
                    'batch_number': batchCtrl.text.trim(),
                    'expiry_date': expiryCtrl.text.trim(),
                    'stock_quantity': int.parse(stockCtrl.text.trim()),
                    'price': double.parse(priceCtrl.text.trim()),
                    'is_prescription_required': reqPrescription,
                  };
                  
                  try {
                    final result = await ApiService.updateInventoryItem(updateData);
                    if (result['success'] == true) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Inventory updated successfully')),
                      );
                      _fetchInventory();
                    } else {
                      messenger.showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Update failed')),
                      );
                      setState(() => _isLoading = false);
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Error communicating with server')),
                    );
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMedicineDialog() {
    final nameCtrl = TextEditingController();
    final genericCtrl = TextEditingController();
    final batchCtrl = TextEditingController(text: 'BATCH01');
    final expiryCtrl = TextEditingController(text: '2027-12-31');
    final stockCtrl = TextEditingController(text: '10');
    final priceCtrl = TextEditingController(text: '25.0');
    bool reqPrescription = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Medicine to Inventory'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Medicine Name (e.g. Panadol)'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: genericCtrl,
                    decoration: const InputDecoration(labelText: 'Generic Name / Category'),
                  ),
                  TextFormField(
                    controller: batchCtrl,
                    decoration: const InputDecoration(labelText: 'Batch Number'),
                  ),
                  TextFormField(
                    controller: expiryCtrl,
                    decoration: const InputDecoration(labelText: 'Expiry Date (YYYY-MM-DD)'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                      if (!regex.hasMatch(v)) return 'Use YYYY-MM-DD format';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Initial Stock'),
                    validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter a number' : null,
                  ),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price (EGP)'),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a price' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Prescription Required', style: TextStyle(fontSize: 14)),
                    value: reqPrescription,
                    onChanged: (val) {
                      setDialogState(() {
                        reqPrescription = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && mounted) {
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isLoading = true);
                  
                  final addData = {
                    'medicine_name': nameCtrl.text.trim(),
                    'generic_name': genericCtrl.text.trim(),
                    'batch_number': batchCtrl.text.trim(),
                    'expiry_date': expiryCtrl.text.trim(),
                    'stock_quantity': int.parse(stockCtrl.text.trim()),
                    'price': double.parse(priceCtrl.text.trim()),
                    'is_prescription_required': reqPrescription,
                  };
                  
                  try {
                    final result = await ApiService.updateInventoryItem(addData);
                    if (result['success'] == true) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Medicine added successfully')),
                      );
                      _fetchInventory();
                    } else {
                      messenger.showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Failed to add medicine')),
                      );
                      setState(() => _isLoading = false);
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Error communicating with server')),
                    );
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Inventory'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: _showAddMedicineDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search medicine or generic name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading && _inventory.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchInventory,
                    child: _filteredInventory.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredInventory.length,
                            itemBuilder: (context, index) {
                              final item = _filteredInventory[index];
                              return _buildInventoryCard(item);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 85, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No Medicine Found',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the add icon on the top right\nto list a medicine in your pharmacy catalog.',
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final inventoryId = item['id']?.toString() ?? '';
    final name = item['medicine_name'] ?? 'Unknown Medicine';
    final generic = item['generic_name'] ?? 'No category';
    final stock = item['stock_quantity'] as int? ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final expiry = item['expiry_date']?.toString() ?? 'N/A';
    final batch = item['batch_number']?.toString() ?? 'N/A';
    final isRxRequired = item['is_prescription_required'] as bool? ?? false;
    final String? imageUrl = item['medicine_image']?.toString();

    final inStock = stock > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[200],
                    child: imageUrl != null && imageUrl.isNotEmpty
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: inStock ? Colors.white : Colors.white60),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: inStock ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              inStock ? 'IN STOCK' : 'OUT OF STOCK',
                              style: TextStyle(
                                color: inStock ? Colors.greenAccent : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        generic.isEmpty ? 'General Category' : generic,
                        style: GoogleFonts.roboto(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Grid metadata details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Expiry Date', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(expiry, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Batch Number', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(batch, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Rx Required', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Icon(
                      isRxRequired ? Icons.assignment : Icons.assignment_turned_in,
                      color: isRxRequired ? Colors.amber : Colors.green,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stock & Price Row
            Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.storage, size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Text(
                      'Stock: $stock units',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${price.toStringAsFixed(2)} EGP',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.greenAccent),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action row buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteItem(inventoryId, name),
                  tooltip: 'Delete Medicine',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit Stock/Price'),
                  onPressed: () => _showEditStockPriceDialog(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
