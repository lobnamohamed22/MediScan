import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../models/pharmacy.dart';
import 'order_details_screen.dart';

class PharmacyMapScreen extends StatefulWidget {
  final String? medicineName;
  const PharmacyMapScreen({super.key, this.medicineName});

  @override
  State<PharmacyMapScreen> createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends State<PharmacyMapScreen> {
  final MapController _mapController = MapController();
  List<Pharmacy> _pharmacies = [];
  bool _isLoading = true;
  LatLng _currentLocation = const LatLng(29.8514, 31.3428); // Helwan University default

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _startListeningLocation() {
    _positionStream?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // Update when user moves 15 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position position) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation, 14);
      _fetchPharmacies();
    }, onError: (err) {
      debugPrint("Location stream error on map: $err");
    });
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _startListeningLocation();

        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 6),
        );
        if (!mounted) return;
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_currentLocation, 14);
        _fetchPharmacies();
      } else {
        if (!mounted) return;
        setState(() {
          _currentLocation = const LatLng(29.8514, 31.3428);
        });
        _mapController.move(_currentLocation, 14);
        _fetchPharmacies();
      }
    } catch (e) {
      debugPrint("Location error: $e");
      if (!mounted) return;
      setState(() {
        _currentLocation = const LatLng(29.8514, 31.3428);
      });
      _mapController.move(_currentLocation, 14);
      _fetchPharmacies();
    }
  }

  Future<void> _fetchPharmacies() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getNearbyPharmacies(
        _currentLocation.latitude,
        _currentLocation.longitude,
        radius: 10.0, // Enforce strict 10 km radius limit
        medicine: widget.medicineName,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final List data = res['data'] ?? [];
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

          // Compute distance client-side using geolocator for precise real-time values
          final double computedDistance = Geolocator.distanceBetween(
            _currentLocation.latitude,
            _currentLocation.longitude,
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

          // Apply strict 10 km radius filter
          if (computedDistance <= 10.0) {
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

        // Sort by distance (nearest first)
        uniquePharmacies.sort((a, b) {
          if (a.distance == null) return 1;
          if (b.distance == null) return -1;
          return a.distance!.compareTo(b.distance!);
        });

        if (!mounted) return;
        setState(() {
          _pharmacies = uniquePharmacies;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (_pharmacies.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to load pharmacies')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching pharmacies: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        if (_pharmacies.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Network or server error: $e')),
          );
        }
      }
    }
  }

  Future<void> _refreshLocationAndPharmacies() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(pos.latitude, pos.longitude);
          });
          _mapController.move(_currentLocation, 14.0);
        }
      }
    } catch (e) {
      debugPrint("Error getting current position: $e");
    }
    await _fetchPharmacies();
  }

  void _showPharmacyDetails(Pharmacy p) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name,
                  style:
                      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(p.address, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Distance: ${p.distance?.toStringAsFixed(2) ?? '0'} km"),
                  if (p.price != null && p.price! > 0)
                    Text("Price: ${p.price} EGP",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                  Text("Rating: ⭐ ${p.rating}"),
                ],
              ),
              const SizedBox(height: 8),
              Text("Delivery: ${p.hasDelivery ? 'Available' : 'Not Available'}",
                  style: TextStyle(
                      color: p.hasDelivery ? Colors.green : Colors.red)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(
                          orderId: 'RES-${p.id}',
                          pharmacy: p.name,
                          pharmacyId: p.id,
                          date: DateTime.now().toString().split(' ')[0],
                          status: 'pending',
                          medicines: p.availableMedicines,
                          total: p.price ?? 0.0,
                        ),
                      ),
                    );
                  },
                  child: const Text("Reserve Now"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicineName != null
            ? 'Pharmacies for ${widget.medicineName}'
            : 'Nearby Pharmacies'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 12.0,
              minZoom: 2.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mediscan',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.my_location,
                        color: Colors.blue, size: 30),
                  ),
                  ..._pharmacies.map((p) => Marker(
                        point: LatLng(p.lat, p.lng),
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => _showPharmacyDetails(p),
                          child: const Icon(Icons.local_pharmacy,
                              color: Colors.green, size: 40),
                        ),
                      )),
                ],
              ),
            ],
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshLocationAndPharmacies,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
