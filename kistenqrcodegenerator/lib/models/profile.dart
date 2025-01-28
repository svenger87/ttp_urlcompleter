// lib/models/profile.dart

class Profile {
  final String shortCode;
  final String shortUrl;
  final String longUrl;
  final String title;
  final DateTime dateCreated;
  final int visitsCount;

  Profile({
    required this.shortCode,
    required this.shortUrl,
    required this.longUrl,
    required this.title,
    required this.dateCreated,
    required this.visitsCount,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      shortCode: json['shortCode'] as String? ?? '',
      shortUrl: json['shortUrl'] as String? ?? '',
      longUrl: json['longUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      dateCreated: json['dateCreated'] != null
          ? DateTime.parse(json['dateCreated'])
          : DateTime.now(),
      visitsCount: json['visitsCount'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile &&
          runtimeType == other.runtimeType &&
          shortCode == other.shortCode &&
          shortUrl == other.shortUrl;

  @override
  int get hashCode => shortCode.hashCode ^ shortUrl.hashCode;
}
