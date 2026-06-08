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

  // Real-time GPS search radius (default 5 km, no UI slider as requested)
  final double _searchRadius = 5.0; 
  bool _simulateCairo = false; // Simulated location toggle for testing Egypt mock data
  LocationPermission _permissionStatus = LocationPermission.denied;
  StreamSubscription<Position>? _positionStream;

  double? _lastFetchedLat;
  double? _lastFetchedLng;
  String _lastFetchedQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _checkLocationAndStart();
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

  Future<void> _checkLocationAndStart() async {
    setState(() {
      _loadingLocation = true;
      _errorMessage = '';
      _lastFetchedLat = null;
      _lastFetchedLng = null;
      _lastFetchedQuery = '';
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (mounted) {
        setState(() {
          _permissionStatus = permission;
          _simulateCairo = false; // Reset simulation when verifying real GPS
        });
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (!serviceEnabled) {
          if (mounted) {
            setState(() {
              _errorMessage = "Location services are disabled. Please enable location/GPS services on your device.";
              _isLoading = false;
            });
          }
          return;
        }
        _startListeningLocation();
      } else {
        _stopListeningLocation();
      }
    } catch (e) {
      debugPrint("Error checking location: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Location services error. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  void _startListeningLocation() {
    _positionStream?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // Update when user moves 15 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position position) {
      if (mounted) {
        setState(() {
          _userPosition = position;
        });
        _applyFilters();
      }
    }, onError: (err) {
      debugPrint("Location stream error: $err");
      if (mounted && _userPosition == null) {
        setState(() {
          _errorMessage = "Location stream error: $err";
        });
      }
    });

    // Get initial position immediately with a timeout limit of 6 seconds to prevent hanging
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 6),
    ).then((pos) {
      if (mounted) {
        setState(() {
          _userPosition = pos;
          _errorMessage = '';
        });
        _applyFilters();
      }
    }).catchError((err) {
      debugPrint("Error getting initial position: $err");
      // Fallback: Try to get last known position
      Geolocator.getLastKnownPosition().then((lastPos) {
        if (lastPos != null && mounted) {
          setState(() {
            _userPosition = lastPos;
            _errorMessage = '';
          });
          _applyFilters();
        } else {
          // If no last known position, fall back to Cairo simulation so screen doesn't block
          if (mounted) {
            setState(() {
              _simulateCairo = true;
              _errorMessage = '';
              _isLoading = false;
            });
            _applyFilters();
          }
        }
      }).catchError((_) {
        // Double fallback to Cairo simulation on any exception
        if (mounted) {
          setState(() {
            _simulateCairo = true;
            _errorMessage = '';
            _isLoading = false;
          });
          _applyFilters();
        }
      });
    });
  }

  void _stopListeningLocation() {
    _positionStream?.cancel();
    _positionStream = null;
    _userPosition = null;
    setState(() {
      _filtered = [];
    });
  }

  void _enableCairoSimulation() {
    _stopListeningLocation();
    setState(() {
      _simulateCairo = true;
      _permissionStatus = LocationPermission.always; // Bypass permission layout
      _errorMessage = '';
      _lastFetchedLat = null;
      _lastFetchedLng = null;
      _lastFetchedQuery = '';
    });
    _applyFilters();
  }

  void _disableCairoSimulation() {
    setState(() {
      _simulateCairo = false;
      _lastFetchedLat = null;
      _lastFetchedLng = null;
      _lastFetchedQuery = '';
    });
    _checkLocationAndStart();
  }

  Future<void> _applyFilters({bool force = false}) async {
    final q = _searchController.text.trim();

    double? lat;
    double? lng;

    if (_simulateCairo) {
      lat = 30.0444;
      lng = 31.2357;
    } else if (_userPosition != null) {
      lat = _userPosition!.latitude;
      lng = _userPosition!.longitude;
    }

    if (lat == null || lng == null) {
      setState(() {
        _filtered = [];
      });
      return;
    }

    final bool locationChanged = _lastFetchedLat == null ||
        _lastFetchedLng == null ||
        Geolocator.distanceBetween(
          _lastFetchedLat!,
          _lastFetchedLng!,
          lat,
          lng,
        ) >= 15.0;

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

      if (q.isNotEmpty) {
        result = await ApiService.searchPharmacies(q, lat: lat, lng: lng);
      } else {
        result = await ApiService.getNearbyPharmacies(lat, lng, radius: _searchRadius);
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

            final double computedDistance = Geolocator.distanceBetween(
              lat!,
              lng!,
              p.lat,
              p.lng,
            ) / 1000.0;

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

            if (computedDistance <= _searchRadius) {
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
          }
          _allPharmacies = uniquePharmacies;

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
            if (_filtered.isEmpty) {
              _errorMessage = errorMsg;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(errorMsg)),
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading pharmacies: $e");
      final errorMsg = "Network or server error: $e";
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_filtered.isEmpty) {
            _errorMessage = errorMsg;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg)),
            );
          }
        });
      }
    }
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_off_rounded,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Location Access Required',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'To find nearby pharmacies in real-time, MediScan needs access to your device\'s location. Please grant permission or enable location services.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _checkLocationAndStart,
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Grant Location Access'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Geolocator.openAppSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open App Settings'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Testing or running on emulator?',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _enableCairoSimulation,
                  icon: const Icon(Icons.developer_mode),
                  label: const Text('Simulate Cairo Location (Egypt demo)'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcquiringLocationView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.teal),
          const SizedBox(height: 20),
          Text(
            'Acquiring GPS location...',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Make sure location services are enabled on your device.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _enableCairoSimulation,
            icon: const Icon(Icons.developer_mode, size: 16),
            label: const Text('Simulate Cairo Location (Egypt demo)'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.teal,
            ),
          ),
        ],
      ),
    );
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

        // Filter Options & Simulation Badge
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
              if (_simulateCairo)
                GestureDetector(
                  onTap: _disableCairoSimulation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.gps_fixed, color: Colors.teal.shade700, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Simulated Cairo',
                          style: GoogleFonts.outfit(
                            color: Colors.teal.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                              onPressed: _checkLocationAndStart,
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
                                  'No pharmacies found nearby',
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
    final bool hasPermission = _simulateCairo ||
        (_permissionStatus == LocationPermission.whileInUse ||
            _permissionStatus == LocationPermission.always);

    final bool acquiringLocation = !_simulateCairo && _userPosition == null && _errorMessage.isEmpty;

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
            onPressed: _loadingLocation ? null : _checkLocationAndStart,
          ),
        ],
      ),
      body: !hasPermission
          ? _buildPermissionDeniedView()
          : acquiringLocation
              ? _buildAcquiringLocationView()
              : _buildSearchListView(),
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
