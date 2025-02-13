class CustomerInventoryItem {
  final int paletteTypeId;
  final String paletteTypeName;
  final int totalQuantity;

  CustomerInventoryItem({
    required this.paletteTypeId,
    required this.paletteTypeName,
    required this.totalQuantity,
  });

  factory CustomerInventoryItem.fromJson(Map<String, dynamic> json) {
    return CustomerInventoryItem(
      paletteTypeId: json['palette_type_id'],
      paletteTypeName: json['palette_type_name'],
      totalQuantity: json['total_quantity'],
    );
  }
}
