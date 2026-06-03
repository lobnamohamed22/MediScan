class Pharmacy {
  final String id;
  final String name;
  final String address;
  final String phone;
  final double rating;
  final bool isOpen;
  final bool hasDelivery;
  final double lat;
  final double lng;
  final String workingHours;
  final List<String> availableMedicines;
  final double? distance;
  final double? price;

  Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.rating,
    required this.isOpen,
    required this.hasDelivery,
    required this.lat,
    required this.lng,
    required this.workingHours,
    required this.availableMedicines,
    this.distance,
    this.price,
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    String hours = '8AM - 12AM';
    if (json['opening_time'] != null && json['closing_time'] != null) {
      hours = "${json['opening_time']} - ${json['closing_time']}";
    }

    return Pharmacy(
      id: json['pharmacy_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString()) ?? 0.0
          : 0.0,
      isOpen: true,
      hasDelivery: json['delivery_available'] ?? false,
      lat: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString()) ?? 0.0
          : 0.0,
      lng: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString()) ?? 0.0
          : 0.0,
      workingHours: hours,
      availableMedicines: [],
      distance: json['distance'] != null
          ? double.tryParse(json['distance'].toString())
          : null,
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
    );
  }
}
