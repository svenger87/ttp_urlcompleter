//

class Tool {
  final int id;
  final String toolNumber;
  final String name;
  final String storageLocation;
  final String storageStatus;
  final bool doNotUpdate;

  Tool({
    required this.id,
    required this.toolNumber,
    required this.name,
    required this.storageLocation,
    required this.storageStatus,
    required this.doNotUpdate,
  });

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      id: json['id'],
      toolNumber: json['tool_number'],
      name: json['name'],
      storageLocation: json['storage_location'],
      storageStatus: json['storage_status'],
      doNotUpdate:
          json['do_not_update'] == 1, // Convert DB boolean to Dart bool
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tool_number': toolNumber,
      'name': name,
      'storage_location': storageLocation,
      'storage_status': storageStatus,
      'do_not_update': doNotUpdate ? 1 : 0, // Convert Dart bool to DB boolean
    };
  }
}
