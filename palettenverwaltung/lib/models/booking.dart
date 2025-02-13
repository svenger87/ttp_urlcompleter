class Booking {
  final int? id;
  final int customerId;
  final int paletteTypeId;
  final int quantity;
  final DateTime bookingDate;
  // Optionally include joined fields like customer_name, palette_type if needed

  Booking({
    this.id,
    required this.customerId,
    required this.paletteTypeId,
    required this.quantity,
    required this.bookingDate,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final bookingDateValue = json['booking_date'];
    return Booking(
      id: json['id'],
      customerId: json['customer_id'],
      paletteTypeId: json['palette_type_id'],
      quantity: json['quantity'],
      bookingDate: bookingDateValue == null
          ? DateTime.now() // or some default
          : DateTime.parse(bookingDateValue as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'palette_type_id': paletteTypeId,
      'quantity': quantity,
    };
  }
}
