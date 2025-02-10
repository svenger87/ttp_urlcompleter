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
  final int? freestatusId;

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
    this.freestatusId,
  });

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      toolNumber: json['tool_number'] ?? 'Unknown Tool Number',
      name: json['name'] ?? 'Unknown Name',
      storageLocationOne: json['storage_location_one'] as String?,
      storageLocationTwo: json['storage_location_two'] as String?,
      usedSpacePitchOne: json['used_space_pitch_one']?.toString() ?? '',
      usedSpacePitchTwo: json['used_space_pitch_two']?.toString() ?? '',
      storageStatus: json['storage_status'] ?? 'Out of stock',
      provided: json['provided'] ?? false,
      internalStatus: json['internalstatus'] ?? 'unbekannt',
      packagingtoolgroup: json['packagingtoolgroup'] ?? 'Ohne',
      freestatusId: json['freestatus_id'] as int?,
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
      'packagingtoolgroup': packagingtoolgroup,
      'freestatus_id': freestatusId,
    };
  }
}
