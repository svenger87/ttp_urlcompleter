class PaletteType {
  final int? id;
  final String lhmNummer;
  final String material;
  final String debitor;
  final String bezeichnung;
  final int hoeheMm;
  final String stapelfaehigkeit;
  final int breiteMm;
  final int laengeMm;
  final double platzbedarf;
  final double bruttogewicht;
  final String gewichtseinheit;
  final String buchungsKz;
  final String lhmKuehneNagel;
  final String photo;
  final int globalInventory;
  final int bookedQuantity;
  final int minAvailable; // New property

  PaletteType({
    this.id,
    required this.lhmNummer,
    required this.material,
    required this.debitor,
    required this.bezeichnung,
    required this.hoeheMm,
    required this.stapelfaehigkeit,
    required this.breiteMm,
    required this.laengeMm,
    required this.platzbedarf,
    required this.bruttogewicht,
    required this.gewichtseinheit,
    required this.buchungsKz,
    required this.lhmKuehneNagel,
    required this.photo,
    this.globalInventory = 0,
    this.bookedQuantity = 0,
    this.minAvailable = 0, // default to 0 if not set
  });

  factory PaletteType.fromJson(Map<String, dynamic> json) {
    return PaletteType(
      id: json['id'],
      lhmNummer: json['lhm_nummer'] ?? '',
      material: json['material'] ?? '',
      debitor: json['debitor'] ?? '',
      bezeichnung: json['bezeichnung'] ?? '',
      hoeheMm: json['hoehe_mm'] ?? 0,
      stapelfaehigkeit: json['stapelfaehigkeit'] ?? '',
      breiteMm: json['breite_mm'] ?? 0,
      laengeMm: json['laenge_mm'] ?? 0,
      platzbedarf: (json['platzbedarf'] is int)
          ? (json['platzbedarf']).toDouble()
          : json['platzbedarf'] ?? 0.0,
      bruttogewicht: (json['bruttogewicht'] is int)
          ? (json['bruttogewicht']).toDouble()
          : json['bruttogewicht'] ?? 0.0,
      gewichtseinheit: json['gewichtseinheit'] ?? '',
      buchungsKz: json['buchungs_kz'] ?? '',
      lhmKuehneNagel: json['lhm_kuehne_nagel'] ?? '',
      photo: json['photo'] ?? '',
      globalInventory: json['global_inventory'] ?? 0,
      bookedQuantity: json['booked_quantity'] ?? 0,
      minAvailable: json['min_available'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lhm_nummer': lhmNummer,
      'material': material,
      'debitor': debitor,
      'bezeichnung': bezeichnung,
      'hoehe_mm': hoeheMm,
      'stapelfaehigkeit': stapelfaehigkeit,
      'breite_mm': breiteMm,
      'laenge_mm': laengeMm,
      'platzbedarf': platzbedarf,
      'bruttogewicht': bruttogewicht,
      'gewichtseinheit': gewichtseinheit,
      'buchungs_kz': buchungsKz,
      'lhm_kuehne_nagel': lhmKuehneNagel,
      'photo': photo,
      'global_inventory': globalInventory,
      // Note: bookedQuantity is computed from bookings
      'min_available': minAvailable,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaletteType &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
