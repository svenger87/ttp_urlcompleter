class PaletteTypeInventoryItem {
  final int customerId;
  final String customerName;
  final int totalQuantity;

  PaletteTypeInventoryItem({
    required this.customerId,
    required this.customerName,
    required this.totalQuantity,
  });

  factory PaletteTypeInventoryItem.fromJson(Map<String, dynamic> json) {
    return PaletteTypeInventoryItem(
      customerId: json['customer_id'],
      customerName: json['customer_name'],
      totalQuantity: json['total_quantity'],
    );
  }
}
