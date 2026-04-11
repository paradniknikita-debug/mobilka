class EquipmentCatalogItem {
  final int id;
  final String typeCode;
  final String brand;
  final String model;
  final String? fullName;
  final double? voltageKv;
  final double? currentA;
  final String? manufacturer;
  final String? country;
  final String? description;
  final String? attrsJson;
  final bool isActive;

  const EquipmentCatalogItem({
    required this.id,
    required this.typeCode,
    required this.brand,
    required this.model,
    this.fullName,
    this.voltageKv,
    this.currentA,
    this.manufacturer,
    this.country,
    this.description,
    this.attrsJson,
    required this.isActive,
  });

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory EquipmentCatalogItem.fromJson(Map<String, dynamic> json) {
    return EquipmentCatalogItem(
      id: _toInt(json['id']),
      typeCode: (json['type_code'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      fullName: json['full_name']?.toString(),
      voltageKv: _toDouble(json['voltage_kv']),
      currentA: _toDouble(json['current_a']),
      manufacturer: json['manufacturer']?.toString(),
      country: json['country']?.toString(),
      description: json['description']?.toString(),
      attrsJson: json['attrs_json']?.toString(),
      isActive: json['is_active'] == true,
    );
  }
}

