class Customer {
  final int? id;
  final String name;
  final String stadt;
  final String postleitzahl;
  final String strasse;
  final String bundesland;
  final String land;

  Customer({
    this.id,
    required this.name,
    required this.stadt,
    required this.postleitzahl,
    required this.strasse,
    required this.bundesland,
    required this.land,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'] ?? '',
      stadt: json['stadt'] ?? '',
      postleitzahl: json['postleitzahl'] ?? '',
      strasse: json['strasse'] ?? '',
      bundesland: json['bundesland'] ?? '',
      land: json['land'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'stadt': stadt,
      'postleitzahl': postleitzahl,
      'strasse': strasse,
      'bundesland': bundesland,
      'land': land,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
