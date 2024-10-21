class Tool {
  final String toolNumber;
  final String name;
  final String? storageLocationOne;
  final String? storageLocationTwo;
  final String? usedSpacePitchOne;
  final String? usedSpacePitchTwo;
  final String storageStatus;
  final bool provided;
  final String internalStatus;
  final String packagingtoolgroup;

  Tool({
    required this.toolNumber,
    required this.name,
    this.storageLocationOne,
    this.storageLocationTwo,
    this.usedSpacePitchOne,
    this.usedSpacePitchTwo,
    required this.storageStatus,
    required this.provided,
    required this.internalStatus,
    required this.packagingtoolgroup,
  });

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      toolNumber: json['tool_number'] ?? 'Unknown Tool Number',
      name: json['name'] ?? 'Unknown Name',
      storageLocationOne: json['storage_location_one'] as String?, // Nullable
      storageLocationTwo: json['storage_location_two'] as String?, // Nullable
      usedSpacePitchOne: json['used_space_pitch_one']?.toString() ??
          '', // Ensure non-null string
      usedSpacePitchTwo: json['used_space_pitch_two']?.toString() ??
          '', // Ensure non-null string
      storageStatus: json['storage_status'] ?? 'Out of stock',
      provided: json['provided'] ?? false,
      internalStatus: json['internalstatus'] ??
          'unbekannt', // Parse the internalstatus from the JSON
      packagingtoolgroup: json['packagingtoolgroup'] ?? 'Ohne',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tool_number': toolNumber,
      'name': name,
      'storage_location_one': storageLocationOne,
      'storage_location_two': storageLocationTwo,
      'used_space_pitch_one': usedSpacePitchOne,
      'used_space_pitch_two': usedSpacePitchTwo,
      'storage_status': storageStatus,
      'provided': provided,
      'internalstatus': internalStatus,
    };
  }
}
