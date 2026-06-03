import 'package:flutter/material.dart';
import 'pharmacy_map_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../models/pharmacy.dart';
import '../services/api_service.dart';
import 'order_details_screen.dart';
import 'pharmacy_detail_screen.dart';

class PharmacySearchScreen extends StatefulWidget {
  final bool fromPrescription;
  final List<String>? prescriptionMedicines;

  const PharmacySearchScreen({
    super.key,
    this.fromPrescription = false,
    this.prescriptionMedicines,
  });

  @override
  State<PharmacySearchScreen> createState() => _PharmacySearchScreenState();
}

class _PharmacySearchScreenState extends State<PharmacySearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _loadingLocation = false;
  bool _isLoading = false;
  Position? _userPosition;

  bool _onlyOpen = false;
  bool _deliveryOnly = false;

  String _errorMessage = '';

  List<Pharmacy> _allPharmacies = [];
  List<Pharmacy> _filtered = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _getLocation();
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
      _applyFilters();
    });
  }

  Future<void> _applyFilters() async {
    final q = _searchController.text.trim();

    if (q.isEmpty && _userPosition == null) {
      setState(() {
        _filtered = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    Map<String, dynamic> result;

    if (q.isNotEmpty) {
      result = await ApiService.searchPharmacies(q,
          lat: _userPosition?.latitude, lng: _userPosition?.longitude);
    } else {
      result = await ApiService.getNearbyPharmacies(
          _userPosition!.latitude, _userPosition!.longitude);
    }

    if (!mounted) return;

    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      setState(() {
        _allPharmacies = data.map((json) {
          if (json.containsKey('pharmacy')) {
            final p = Pharmacy.fromJson(json['pharmacy']);
            return Pharmacy(
              id: p.id,
              name: p.name,
              address: p.address,
              phone: p.phone,
              rating: p.rating,
              isOpen: p.isOpen,
              hasDelivery: p.hasDelivery,
              lat: p.lat,
              lng: p.lng,
              workingHours: p.workingHours,
              availableMedicines: [json['medicine']['name']],
              distance: json['distance'] != null
                  ? double.tryParse(json['distance'].toString())
                  : null,
            );
          }
          return Pharmacy.fromJson(json);
        }).toList();

        _filtered = _allPharmacies.where((p) {
          final matchOpen = !_onlyOpen || p.isOpen;
          final matchDelivery = !_deliveryOnly || p.hasDelivery;
          return matchOpen && matchDelivery;
        }).toList();

        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to load pharmacies';
        _filtered = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _getLocation() async {
    setState(() => _loadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        _userPosition = pos;
        await _applyFilters();
      } else {
        throw Exception("Permission denied");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to get location. Check permissions.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Pharmacies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PharmacyMapScreen()),
              );
            },
          ),
          IconButton(
            icon: _loadingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            onPressed: _loadingLocation ? null : _getLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search pharmacy or medicine',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Open Now'),
                  selected: _onlyOpen,
                  onSelected: (v) {
                    _onlyOpen = v;
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('Delivery'),
                  selected: _deliveryOnly,
                  onSelected: (v) {
                    _deliveryOnly = v;
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Text(_errorMessage,
                            style: const TextStyle(color: Colors.red)))
                    : _filtered.isEmpty
                        ? const Center(
                            child: Text(
                                'No pharmacies found or type a search query'))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final p = _filtered[i];
                                return PharmacyCard(
                                  pharmacy: p,
                                  distanceKm: p.distance,
                                  fromPrescription: widget.fromPrescription,
                                  prescriptionMedicines: widget.prescriptionMedicines,
                                );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class PharmacyCard extends StatefulWidget {
  final Pharmacy pharmacy;
  final double? distanceKm;
  final bool fromPrescription;
  final List<String>? prescriptionMedicines;

  const PharmacyCard({
    super.key,
    required this.pharmacy,
    required this.distanceKm,
    required this.fromPrescription,
    this.prescriptionMedicines,
  });

  @override
  State<PharmacyCard> createState() => _PharmacyCardState();
}

class _PharmacyCardState extends State<PharmacyCard> {
  final bool _isOrdering = false;

  Future<void> _previewOrder() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(
          orderId: 'PREVIEW',
          pharmacy: widget.pharmacy.name,
          date: DateTime.now().toString().split(' ')[0],
          status: 'preview',
          medicines: widget.prescriptionMedicines ?? widget.pharmacy.availableMedicines,
          total: widget.pharmacy.price ?? 0.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PharmacyDetailScreen(pharmacy: widget.pharmacy),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.pharmacy.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.pharmacy.address.isNotEmpty
                      ? widget.pharmacy.address
                      : 'No address provided'),
                  Text(widget.pharmacy.workingHours),
                  if (widget.pharmacy.availableMedicines.isNotEmpty)
                    Text(
                        'Medicines: ${widget.pharmacy.availableMedicines.join(', ')}',
                        style: const TextStyle(color: Colors.green)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⭐ ${widget.pharmacy.rating}'),
                  Text(
                    widget.distanceKm == null
                        ? '--'
                        : '${widget.distanceKm!.toStringAsFixed(1)} km',
                    style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (widget.fromPrescription) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _previewOrder,
                  child: const Text('Preview Order'),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
