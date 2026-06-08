import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import '../services/api_service.dart';
import 'order_chat_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String pharmacyName;
  final List<String> medicines;
  final String status;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.pharmacyName,
    required this.medicines,
    required this.status,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _timer;
  Map<String, dynamic>? _trackingData;
  bool _isLoading = true;
  String _currentStatus = '';

  // Status Steps
  final List<String> _statusSteps = [
    'assigned',
    'picked_up',
    'in_transit',
    'delivered'
  ];

  bool _isSimulating = false;
  LatLng _deviceLocation = const LatLng(30.0444, 31.2357);

  // Animation properties
  LatLng _oldDriverPos = const LatLng(30.0544, 31.2457); // default pharmacy location
  LatLng _currentDriverPos = const LatLng(30.0544, 31.2457);
  AnimationController? _animationController;
  Animation<double>? _animation;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Match the 2s poll rate for seamless sliding
      vsync: this,
    );
    _determinePosition().then((_) {
      _fetchTrackingData();
    });

    // Auto-refresh every 2 seconds for a responsive real-time experience
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentStatus.toLowerCase() == 'delivered') {
        _timer?.cancel();
      } else {
        _fetchTrackingData();
      }
    });
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );
      if (mounted) {
        setState(() {
          _deviceLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      debugPrint("Error determining device position: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  void _animateDriver(LatLng newPos) {
    if (!mounted) return;
    
    _animationController?.stop();
    _oldDriverPos = _currentDriverPos;
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut)
    )..addListener(() {
      if (mounted) {
        setState(() {
          _currentDriverPos = LatLng(
            _oldDriverPos.latitude + (newPos.latitude - _oldDriverPos.latitude) * _animation!.value,
            _oldDriverPos.longitude + (newPos.longitude - _oldDriverPos.longitude) * _animation!.value,
          );
          // Auto-center map on driver as they move
          _mapController.move(_currentDriverPos, _mapController.camera.zoom);
        });
      }
    });
    
    _animationController?.forward(from: 0.0);
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double r = 6371.0; // Earth radius in km
    final double dLat = _degToRad(p2.latitude - p1.latitude);
    final double dLng = _degToRad(p2.longitude - p1.longitude);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(p1.latitude)) *
            cos(_degToRad(p2.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _degToRad(double deg) {
    return deg * (pi / 180.0);
  }

  Future<void> _fetchTrackingData() async {
    final res = await ApiService.getDeliveryTracking(widget.orderId);
    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          _trackingData = res['data'];
          _currentStatus = _trackingData?['status'] ?? widget.status;
          
          final lat = _trackingData?['delivery_lat'] != null
              ? double.tryParse(_trackingData!['delivery_lat'].toString())
              : null;
          final lng = _trackingData?['delivery_lng'] != null
              ? double.tryParse(_trackingData!['delivery_lng'].toString())
              : null;
              
          if (lat != null && lng != null) {
            final newPos = LatLng(lat, lng);
            if (_isFirstLoad) {
              _currentDriverPos = newPos;
              _oldDriverPos = newPos;
              _isFirstLoad = false;
            } else if (newPos != _oldDriverPos) {
              _animateDriver(newPos);
            }
          }
        }
        _isLoading = false;
      });
    }
  }

  int _getStatusIndex() {
    int index = _statusSteps.indexOf(_currentStatus.toLowerCase());
    return index != -1 ? index : 0;
  }

  Future<void> _startSimulation() async {
    if (_isSimulating || _currentStatus.toLowerCase() == 'delivered') return;

    setState(() {
      _isSimulating = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Starting backend delivery simulation engine...')),
    );

    final res = await ApiService.simulateDelivery(
      widget.orderId,
      customerLat: _deviceLocation.latitude,
      customerLng: _deviceLocation.longitude,
    );

    if (res['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Failed to start simulation.')),
      );
      setState(() {
        _isSimulating = false;
      });
    }
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.blueAccent, size: 24),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusIndex = _getStatusIndex();
    final driverLat = _trackingData?['delivery_lat'] != null
        ? double.tryParse(_trackingData!['delivery_lat'].toString())
        : null;
    final driverLng = _trackingData?['delivery_lng'] != null
        ? double.tryParse(_trackingData!['delivery_lng'].toString())
        : null;

    final pharmacyLat = _trackingData?['pharmacy_lat'] != null
        ? double.tryParse(_trackingData!['pharmacy_lat'].toString())
        : null;
    final pharmacyLng = _trackingData?['pharmacy_lng'] != null
        ? double.tryParse(_trackingData!['pharmacy_lng'].toString())
        : null;
    final pharmacyPos = pharmacyLat != null && pharmacyLng != null
        ? LatLng(pharmacyLat, pharmacyLng)
        : const LatLng(30.0544, 31.2457);

    final customerLat = _trackingData?['customer_lat'] != null
        ? double.tryParse(_trackingData!['customer_lat'].toString())
        : null;
    final customerLng = _trackingData?['customer_lng'] != null
        ? double.tryParse(_trackingData!['customer_lng'].toString())
        : null;
    final customerPos = customerLat != null && customerLng != null
        ? LatLng(customerLat, customerLng)
        : _deviceLocation;

    // Initial center on customer home if driver isn't moving, or center on driver
    final initialMapCenter = _isFirstLoad ? customerPos : _currentDriverPos;

    // Calculate remaining distance and ETA
    final double remainingDistance = (_currentStatus.toLowerCase() == 'delivered')
        ? 0.0
        : _calculateDistance(
            (driverLat != null && driverLng != null) ? _currentDriverPos : pharmacyPos,
            customerPos,
          );
    final int etaMinutes = (_currentStatus.toLowerCase() == 'delivered')
        ? 0
        : (remainingDistance * 2.0).round();
    final String distanceText = "${remainingDistance.toStringAsFixed(1)} km";
    final String etaText = etaMinutes > 0 ? "$etaMinutes mins" : "Arrived";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        elevation: 0,
        actions: [
          if (_currentStatus.toLowerCase() != 'delivered')
            IconButton(
              icon: _isSimulating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.blue))
                  : const Icon(Icons.play_circle_fill,
                      color: Colors.blue, size: 28),
              tooltip: 'Simulate Live Delivery',
              onPressed: _isSimulating ? null : _startSimulation,
            ),
        ],
      ),
      body: Column(
        children: [
          // Top section - Status Progress
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    final isDone = index <= statusIndex;
                    final isCurrent = index == statusIndex;

                    return Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Container(
                                      height: 2,
                                      color: index == 0
                                          ? Colors.transparent
                                          : (isDone
                                              ? Colors.green
                                              : Colors.grey[300]))),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color:
                                      isDone ? Colors.green : Colors.grey[300],
                                  shape: BoxShape.circle,
                                  border: isCurrent
                                      ? Border.all(
                                          color: Colors.green
                                              .withValues(alpha: 0.3),
                                          width: 4)
                                      : null,
                                ),
                                child: Icon(Icons.check,
                                    size: 14,
                                    color: isDone ? Colors.white : Colors.grey),
                              ),
                              Expanded(
                                  child: Container(
                                      height: 2,
                                      color: index == 3
                                          ? Colors.transparent
                                          : (index < statusIndex
                                              ? Colors.green
                                              : Colors.grey[300]))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusSteps[index]
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isDone ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Middle section - Map (60%)
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialMapCenter,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mediscan',
                      tileProvider: CancellableNetworkTileProvider(),
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [pharmacyPos, _currentDriverPos, customerPos],
                          strokeWidth: 4.5,
                          color: Colors.blueAccent,
                          borderColor: Colors.blue.shade900,
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Pharmacy Marker (Green, Premium)
                        Marker(
                          point: pharmacyPos,
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_pharmacy,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        // Destination Marker (Home - Red, Premium)
                        Marker(
                          point: customerPos,
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.home,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        // Driver Marker (Blue, Animated, Premium)
                        if (driverLat != null && driverLng != null)
                          Marker(
                            point: _currentDriverPos,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.delivery_dining,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (driverLat == null || driverLng == null)
                  Container(
                    color: Colors.black.withValues(alpha: 0.1),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("Preparing your order..."),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom section - Driver Info (40%)
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5))
                ],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delivery_dining,
                                  color: Colors.blue, size: 30),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Your Delivery Driver",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 14)),
                                  Text(
                                      _trackingData?['driver_name'] ??
                                          'Waiting for assignment...',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "Status: ${_currentStatus.replaceAll('_', ' ').toUpperCase()}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              Icons.directions_bike,
                              "Distance",
                              distanceText,
                            ),
                            _buildStatItem(
                              Icons.access_time,
                              "ETA",
                              etaText,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _trackingData?['driver_phone'] != null
                                        ? () {
                                            final phone =
                                                _trackingData!['driver_phone'];
                                            launchUrl(Uri.parse('tel:$phone'));
                                          }
                                        : null,
                                icon: const Icon(Icons.call),
                                label: const Text("Call Driver"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _trackingData?['driver_name'] != null
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                OrderChatScreen(
                                              orderId: widget.orderId,
                                              driverName:
                                                  _trackingData!['driver_name'],
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.chat),
                                label: const Text("Chat"),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
