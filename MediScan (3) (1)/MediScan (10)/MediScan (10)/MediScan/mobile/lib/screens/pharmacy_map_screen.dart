import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
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
  LatLng _currentLocation = const LatLng(30.0444, 31.2357); // Cairo default

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      LatLng userLoc = const LatLng(30.0444, 31.2357);
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        userLoc = LatLng(pos.latitude, pos.longitude);
        
        // If coordinate is outside Egypt boundaries, default to Cairo so they can view the pharmacies
        if (userLoc.latitude < 22.0 || userLoc.latitude > 32.0 || userLoc.longitude < 25.0 || userLoc.longitude > 37.0) {
          userLoc = const LatLng(30.0444, 31.2357);
        }
      }
      setState(() {
        _currentLocation = userLoc;
      });
      _mapController.move(_currentLocation, 14);
    } catch (e) {
      debugPrint("Location error: $e");
      setState(() {
        _currentLocation = const LatLng(30.0444, 31.2357);
      });
      _mapController.move(_currentLocation, 14);
    } finally {
      _fetchPharmacies();
    }
  }

  Future<void> _fetchPharmacies() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getNearbyPharmacies(
      _currentLocation.latitude,
      _currentLocation.longitude,
      medicine: widget.medicineName,
    );

    if (res['success'] == true) {
      final List data = res['data'] ?? [];
      setState(() {
        _pharmacies = data.map((j) => Pharmacy.fromJson(j)).where((p) {
          return p.lat >= 22.0 &&
              p.lat <= 32.0 &&
              p.lng >= 25.0 &&
              p.lng <= 37.0;
        }).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
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
              minZoom: 6.0,
              maxZoom: 18.0,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(22.0, 25.0),
                  const LatLng(31.5, 37.0),
                ),
              ),
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
        onPressed: _fetchPharmacies,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
