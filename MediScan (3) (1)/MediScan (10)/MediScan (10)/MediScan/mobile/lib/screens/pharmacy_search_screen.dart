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

  // In-memory static cache to hold pharmacies across screen pushes/pops
  static List<Pharmacy> _cachedPharmacies = [];

  bool _loadingLocation = false;
  bool _isLoading = false;
  Position? _userPosition;

  bool _onlyOpen = false;
  bool _deliveryOnly = false;

  String _errorMessage = '';

  List<Pharmacy> _allPharmacies = [];
  List<Pharmacy> _filtered = [];
  Timer? _debounce;

  // Real-time GPS search radius (default 10 km, no UI slider as requested)
  final double _searchRadius = 10.0; 
  bool _isUsingGPS = false;
  StreamSubscription<Position>? _positionStream;

  double? _lastFetchedLat;
  double? _lastFetchedLng;
  String _lastFetchedQuery = '';

  @override
  void initState() {
    super.initState();
    // Instantly load from cache to ensure UI is responsive
    _allPharmacies = List<Pharmacy>.from(_cachedPharmacies);
    _filtered = List<Pharmacy>.from(_cachedPharmacies);
    _searchController.addListener(_onSearchChanged);
    
    // If cache is empty, load fallback pharmacies instantly in background
    if (_allPharmacies.isEmpty) {
      _applyFilters();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
  }

  Future<void> _requestLocationAndQuery() async {
    setState(() {
      _loadingLocation = true;
      _errorMessage = '';
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled on your device.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        setState(() {
          _loadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission was denied. Keeping database pharmacies.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        setState(() {
          _loadingLocation = false;
        });
        return;
      }

      // Fetch current position with a timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );

      setState(() {
        _userPosition = position;
        _isUsingGPS = true;
        _loadingLocation = false;
      });

      // Query nearby pharmacies based on GPS coordinates
      await _applyFilters(force: true);

      // Start listening to future position updates
      _startListeningLocation();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS Location obtained. Showing nearby pharmacies.'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      debugPrint("Error requesting location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not obtain GPS location: $e. Keeping database pharmacies.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      setState(() {
        _loadingLocation = false;
      });
    }
  }

  void _startListeningLocation() {
    _positionStream?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // 50 meters to reduce jitter and excessive API hits
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position position) {
      if (mounted) {
        setState(() {
          _userPosition = position;
          _isUsingGPS = true;
        });
        _applyFilters();
      }
    }, onError: (err) {
      debugPrint("Location stream error: $err");
    });
  }

  Future<void> _applyFilters({bool force = false}) async {
    final q = _searchController.text.trim();

    double? lat;
    double? lng;

    if (_isUsingGPS && _userPosition != null) {
      lat = _userPosition!.latitude;
      lng = _userPosition!.longitude;
    }

    final bool locationChanged = _lastFetchedLat == null ||
        _lastFetchedLng == null ||
        (lat != null &&
            _lastFetchedLat != null &&
            _lastFetchedLng != null &&
            Geolocator.distanceBetween(
              _lastFetchedLat!,
              _lastFetchedLng!,
              lat,
              lng!,
            ) >= 50.0);

    final bool queryChanged = _lastFetchedQuery != q;

    if (!force && !locationChanged && !queryChanged && _allPharmacies.isNotEmpty) {
      setState(() {
        _filtered = _allPharmacies.where((p) {
          final matchOpen = !_onlyOpen || p.isOpen;
          final matchDelivery = !_deliveryOnly || p.hasDelivery;
          return matchOpen && matchDelivery;
        }).toList();

        _filtered.sort((a, b) {
          if (a.distance == null) return 1;
          if (b.distance == null) return -1;
          return a.distance!.compareTo(b.distance!);
        });
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      Map<String, dynamic> result;

      if (lat == null || lng == null) {
        // Fallback/Database mode
        if (q.isNotEmpty) {
          result = await ApiService.searchPharmacies(q);
        } else {
          result = await ApiService.getFallbackPharmacies();
        }
      } else {
        // GPS mode
        if (q.isNotEmpty) {
          result = await ApiService.searchPharmacies(q, lat: lat, lng: lng);
        } else {
          result = await ApiService.getNearbyPharmacies(lat, lng, radius: _searchRadius);
        }
      }

      if (!mounted) return;

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _lastFetchedLat = lat;
          _lastFetchedLng = lng;
          _lastFetchedQuery = q;

          final Set<String> seenIds = {};
          final List<Pharmacy> uniquePharmacies = [];
          for (var json in data) {
            Pharmacy p;
            if (json.containsKey('pharmacy')) {
              final parsedP = Pharmacy.fromJson(json['pharmacy']);
              p = Pharmacy(
                id: parsedP.id,
                name: parsedP.name,
                address: parsedP.address,
                phone: parsedP.phone,
                rating: parsedP.rating,
                isOpen: parsedP.isOpen,
                hasDelivery: parsedP.hasDelivery,
                lat: parsedP.lat,
                lng: parsedP.lng,
                workingHours: parsedP.workingHours,
                availableMedicines: [json['medicine']['name'].toString()],
                distance: json['distance'] != null
                    ? double.tryParse(json['distance'].toString())
                    : null,
              );
            } else {
              p = Pharmacy.fromJson(json);
            }

            double? computedDistance;
            if (lat != null && lng != null) {
              computedDistance = Geolocator.distanceBetween(
                lat,
                lng,
                p.lat,
                p.lng,
              ) / 1000.0;
            } else {
              computedDistance = p.distance;
            }

            final Pharmacy updatedP = Pharmacy(
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
              availableMedicines: List<String>.from(p.availableMedicines),
              distance: computedDistance,
              price: p.price,
            );

            // Limit results to search radius if GPS is available
            if (lat != null && computedDistance != null && computedDistance > _searchRadius) {
              continue;
            }

            if (!seenIds.contains(updatedP.id)) {
              seenIds.add(updatedP.id);
              uniquePharmacies.add(updatedP);
            } else {
              final existing = uniquePharmacies.firstWhere((element) => element.id == updatedP.id);
              if (updatedP.availableMedicines.isNotEmpty) {
                for (var med in updatedP.availableMedicines) {
                  if (!existing.availableMedicines.contains(med)) {
                    existing.availableMedicines.add(med);
                  }
                }
              }
            }
          }
          _allPharmacies = uniquePharmacies;
          
          // Cache loaded pharmacies statically so they persist across screen transitions
          _cachedPharmacies = List<Pharmacy>.from(_allPharmacies);

          _filtered = _allPharmacies.where((p) {
            final matchOpen = !_onlyOpen || p.isOpen;
            final matchDelivery = !_deliveryOnly || p.hasDelivery;
            return matchOpen && matchDelivery;
          }).toList();

          _filtered.sort((a, b) {
            if (a.distance == null) return 1;
            if (b.distance == null) return -1;
            return a.distance!.compareTo(b.distance!);
          });

          _isLoading = false;
        });
      } else {
        final errorMsg = result['message'] ?? 'Failed to load pharmacies';
        if (mounted) {
          setState(() {
            _isLoading = false;
            // Prevent replacing loaded list with empty error view
            if (_allPharmacies.isEmpty) {
              _errorMessage = errorMsg;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading pharmacies: $e");
      const errorMsg = "Network or server error. Please check your connection.";
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Prevent replacing loaded list with empty error view
          if (_allPharmacies.isEmpty) {
            _errorMessage = errorMsg;
          }
        });
      }
    }
  }

  Widget _buildSearchListView() {
    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search pharmacy or medicine',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),

        // Filter Options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FilterChip(
                    label: const Text('Open Now'),
                    selected: _onlyOpen,
                    onSelected: (v) {
                      setState(() {
                        _onlyOpen = v;
                      });
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Delivery Only'),
                    selected: _deliveryOnly,
                    onSelected: (v) {
                      setState(() {
                        _deliveryOnly = v;
                      });
                      _applyFilters();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // List View / Loading / Error
        Expanded(
          child: (_isLoading && _filtered.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : (_errorMessage.isNotEmpty && _filtered.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red, fontSize: 15),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _applyFilters(force: true),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filtered.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No pharmacies found',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try searching for a different area or query.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _applyFilters(force: true),
                          child: ListView.builder(
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
        ),
      ],
    );
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
            onPressed: _loadingLocation ? null : _requestLocationAndQuery,
          ),
        ],
      ),
      body: _buildSearchListView(),
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
  Future<void> _previewOrder() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(
          orderId: 'PREVIEW',
          pharmacy: widget.pharmacy.name,
          pharmacyId: widget.pharmacy.id,
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                title: Text(
                  widget.pharmacy.name,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(widget.pharmacy.address.isNotEmpty
                        ? widget.pharmacy.address
                        : 'No address provided'),
                    const SizedBox(height: 2),
                    Text('Hours: ${widget.pharmacy.workingHours}'),
                    if (widget.pharmacy.availableMedicines.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Medicines: ${widget.pharmacy.availableMedicines.join(', ')}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('⭐ ${widget.pharmacy.rating}'),
                    const SizedBox(height: 4),
                    Text(
                      widget.distanceKm == null
                          ? '--'
                          : '${widget.distanceKm!.toStringAsFixed(2)} km',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w600, color: Colors.teal.shade800),
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
