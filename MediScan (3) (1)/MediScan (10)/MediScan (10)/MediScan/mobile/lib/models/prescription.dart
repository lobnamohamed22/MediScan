class Prescription {
  final String id;
  final String date;
  final String status;
  final List<String> medications;
  final String? imageUrl;

  Prescription({
    required this.id,
    required this.date,
    required this.status,
    required this.medications,
    this.imageUrl,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    List<String> meds = [];
    if (json['medicines'] != null) {
      if (json['medicines'] is String) {
        meds = (json['medicines'] as String)
            .split('\n')
            .where((m) => m.trim().isNotEmpty)
            .toList();
      } else if (json['medicines'] is List) {
        meds = (json['medicines'] as List).map((m) {
          if (m is Map) return m['medicine_name']?.toString() ?? 'Unknown';
          return m.toString();
        }).toList();
      }
    }
    return Prescription(
      id: json['id']?.toString() ?? '',
      date: json['created_at']?.toString().split('T').first ?? 'Unknown Date',
      status: json['status']?.toString() ?? 'Unknown',
      medications: meds,
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': date,
      'status': status,
      'medicines': medications,
      'image_url': imageUrl,
    };
  }

  Prescription copyWith({
    String? id,
    String? date,
    String? status,
    List<String>? medications,
    String? imageUrl,
  }) {
    return Prescription(
      id: id ?? this.id,
      date: date ?? this.date,
      status: status ?? this.status,
      medications: medications ?? this.medications,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
