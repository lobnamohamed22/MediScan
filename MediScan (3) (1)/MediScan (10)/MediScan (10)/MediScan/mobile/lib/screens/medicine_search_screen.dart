import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/medicine.dart';
import '../services/api_service.dart';
import 'dart:async';
import 'cart_screen.dart';

class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Medicine> _filteredMedicines = [];
  bool _isLoading = false;
  String _errorMessage = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _searchMedicines(_searchController.text.trim());
      } else {
        setState(() {
          _filteredMedicines = [];
          _errorMessage = '';
        });
      }
    });
  }

  Future<void> _searchMedicines(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final response = await ApiService.searchMedicines(query);

    if (!mounted) return;

    if (response['success'] == true) {
      final List<dynamic> data = response['data'] ?? [];
      setState(() {
        _filteredMedicines =
            data.map((json) => Medicine.fromJson(json)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response['message'] ?? 'Failed to load medicines';
        _filteredMedicines = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Medicines'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          /// 🔍 Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search medicine...',
                hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                prefixIcon: Icon(Icons.search,
                    color: isDark ? Colors.white : Colors.black),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
          child: Text(
        _errorMessage,
        style: const TextStyle(color: Colors.red),
      ));
    }

    if (_filteredMedicines.isEmpty &&
        _searchController.text.trim().isNotEmpty) {
      return const Center(
        child: Text('No medicines found'),
      );
    }

    if (_filteredMedicines.isEmpty && _searchController.text.trim().isEmpty) {
      return const Center(
        child: Text('Type a medicine name to search',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _filteredMedicines.length,
      itemBuilder: (context, index) {
        return MedicineCard(medicine: _filteredMedicines[index]);
      },
    );
  }
}

class MedicineCard extends StatelessWidget {
  final Medicine medicine;

  const MedicineCard({super.key, required this.medicine});

  @override
  Widget build(BuildContext context) {
    final bool available = medicine.stock > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicineDetailsScreen(medicine: medicine),
          ),
        );
      },
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      medicine.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: available
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      available ? 'Available' : 'Out of Stock',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: available ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                medicine.description.isNotEmpty
                    ? medicine.description
                    : 'No description available',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${medicine.price.toStringAsFixed(2)} EGP',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MedicineDetailsScreen extends StatefulWidget {
  final Medicine medicine;

  const MedicineDetailsScreen({super.key, required this.medicine});

  @override
  State<MedicineDetailsScreen> createState() => _MedicineDetailsScreenState();
}

class _MedicineDetailsScreenState extends State<MedicineDetailsScreen> {
  bool _isAddingToCart = false;

  Future<void> _addToCart() async {
    setState(() => _isAddingToCart = true);
    final res = await ApiService.addToCart(widget.medicine.id, quantity: 1);

    if (mounted) {
      setState(() => _isAddingToCart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['success'] == true
              ? "Added to cart"
              : (res['message'] ?? "Failed to add to cart")),
          backgroundColor: res['success'] == true ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool available = widget.medicine.stock > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.medicine.imageUrl.isNotEmpty)
              Center(
                child: Image.network(widget.medicine.imageUrl,
                    height: 150,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.medication,
                        size: 100,
                        color: Colors.grey)),
              ),
            const SizedBox(height: 20),
            Text(
              widget.medicine.description.isNotEmpty
                  ? widget.medicine.description
                  : 'No description available',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),
            Text(
                "Brand: ${widget.medicine.brand.isNotEmpty ? widget.medicine.brand : 'N/A'}"),
            Text(
                "Type: ${widget.medicine.type.isNotEmpty ? widget.medicine.type : 'N/A'}"),
            Text(
                "Dosage: ${widget.medicine.dosage.isNotEmpty ? widget.medicine.dosage : 'N/A'}"),
            Text(
                "Form: ${widget.medicine.form.isNotEmpty ? widget.medicine.form : 'N/A'}"),
            Text("Price: ${widget.medicine.price.toStringAsFixed(2)} EGP"),
            Text("Stock: ${widget.medicine.stock}"),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: available && !_isAddingToCart ? _addToCart : null,
                child: _isAddingToCart
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("Add to Cart", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
