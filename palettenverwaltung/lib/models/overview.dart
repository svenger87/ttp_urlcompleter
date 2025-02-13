class Overview {
  final int totalPalettes;
  final int onSite;
  final int withCustomer;
  final int totalBookings;

  Overview({
    required this.totalPalettes,
    required this.onSite,
    required this.withCustomer,
    required this.totalBookings,
  });

  factory Overview.fromJson(Map<String, dynamic> json) {
    return Overview(
      totalPalettes: json['total_palettes'] ?? 0,
      onSite: json['on_site'] ?? 0,
      withCustomer: json['with_customer'] ?? 0,
      totalBookings: json['total_bookings'] ?? 0,
    );
  }
}
