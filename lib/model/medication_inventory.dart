class MedicationInventory {
  final String id;
  final String name;
  final int quantity;
  final DateTime expiryDate;
  final String description; // Added

  MedicationInventory({
    required this.id,
    required this.name,
    required this.quantity,
    required this.expiryDate,
    required this.description, // Added
  });

  factory MedicationInventory.fromMap(Map<dynamic, dynamic> map, String key) {
    return MedicationInventory(
      id: key,
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      expiryDate: DateTime.tryParse(map['expiryDate'] ?? '') ?? DateTime.now(),
      description: map['description'] ?? '', // Added
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'expiryDate': expiryDate.toIso8601String(),
      'description': description, // Added
    };
  }
}
