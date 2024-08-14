class Tool {
  final int id;
  final String toolNumber;
  final String name;
  final String storageLocation;

  Tool(
      {required this.id,
      required this.toolNumber,
      required this.name,
      required this.storageLocation});

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      id: json['id'],
      toolNumber: json['tool_number'],
      name: json['name'],
      storageLocation: json['storage_location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tool_number': toolNumber,
      'name': name,
      'storage_location': storageLocation,
    };
  }
}
