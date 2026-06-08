import '../config.dart';

class Medicine {
  final String id;
  final String name;
  final String brand;
  final String type;
  final String dosage;
  final String form;
  final double price;
  final String description;
  final List<String> sideEffects;
  final List<String> interactions;
  final List<String> contraindications;
  final bool requiresPrescription;
  final DateTime expiryDate;
  final int stock;
  final List<String> alternatives;
  final String manufacturer;
  final String barcode;
  final String imageUrl;

  Medicine({
    required this.id,
    required this.name,
    required this.brand,
    required this.type,
    required this.dosage,
    required this.form,
    required this.price,
    required this.description,
    required this.sideEffects,
    required this.interactions,
    required this.contraindications,
    required this.requiresPrescription,
    required this.expiryDate,
    required this.stock,
    required this.alternatives,
    required this.manufacturer,
    required this.barcode,
    required this.imageUrl,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic value) {
      if (value == null) return [];
      if (value is String) {
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    String imgUrl = json['medicine_image'] ?? json['imageUrl'] ?? '';
    if (imgUrl.startsWith('/')) {
      imgUrl = '${Config.baseUrl}$imgUrl';
    }

    return Medicine(
      id: json['id']?.toString() ?? '',
      name: json['medicine_name'] ?? json['name'] ?? '',
      brand: json['generic_name'] ?? json['brand'] ?? '',
      type: json['type'] ?? '',
      dosage: json['dosage_adult'] ?? json['dosage'] ?? '',
      form: json['form'] ?? '',
      price: json['price'] != null ? (double.tryParse(json['price'].toString()) ?? 0.0) : 0.0,
      description: json['uses'] ?? json['description'] ?? '',
      sideEffects: parseList(json['side_effects'] ?? json['sideEffects']),
      interactions: parseList(json['interactions']),
      contraindications: parseList(json['contraindications']),
      requiresPrescription: json['requiresPrescription'] ?? false,
      expiryDate: DateTime.tryParse(json['expiryDate']?.toString() ?? '') ?? DateTime.now(),
      stock: json['stock'] != null ? (int.tryParse(json['stock'].toString()) ?? 0) : 0,
      alternatives: parseList(json['alternatives']),
      manufacturer: json['manufacturer'] ?? '',
      barcode: json['barcode'] ?? '',
      imageUrl: imgUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'type': type,
      'dosage': dosage,
      'form': form,
      'price': price,
      'description': description,
      'sideEffects': sideEffects,
      'interactions': interactions,
      'contraindications': contraindications,
      'requiresPrescription': requiresPrescription,
      'expiryDate': expiryDate.toIso8601String(),
      'stock': stock,
      'alternatives': alternatives,
      'manufacturer': manufacturer,
      'barcode': barcode,
      'imageUrl': imageUrl,
    };
  }

  Medicine copyWith({
    String? id,
    String? name,
    String? brand,
    String? type,
    String? dosage,
    String? form,
    double? price,
    String? description,
    List<String>? sideEffects,
    List<String>? interactions,
    List<String>? contraindications,
    bool? requiresPrescription,
    DateTime? expiryDate,
    int? stock,
    List<String>? alternatives,
    String? manufacturer,
    String? barcode,
    String? imageUrl,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      type: type ?? this.type,
      dosage: dosage ?? this.dosage,
      form: form ?? this.form,
      price: price ?? this.price,
      description: description ?? this.description,
      sideEffects: sideEffects ?? this.sideEffects,
      interactions: interactions ?? this.interactions,
      contraindications: contraindications ?? this.contraindications,
      requiresPrescription: requiresPrescription ?? this.requiresPrescription,
      expiryDate: expiryDate ?? this.expiryDate,
      stock: stock ?? this.stock,
      alternatives: alternatives ?? this.alternatives,
      manufacturer: manufacturer ?? this.manufacturer,
      barcode: barcode ?? this.barcode,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
