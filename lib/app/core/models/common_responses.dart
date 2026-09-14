/** Common Responses{Location, SocialLinks, Skill} */

/// Location
class Location {
  double? lat;
  double? lon;

  Location({this.lat, this.lon});

  Location copyWith({double? lat, double? lon}) =>
      Location(lat: lat ?? this.lat, lon: lon ?? this.lon);

  factory Location.fromJson(Map<String, dynamic> json) =>
      Location(lat: json["lat"]?.toDouble(), lon: json["lon"]?.toDouble());

  Map<String, dynamic> toJson() => {"lat": lat, "lon": lon};
}


/// Social Links
class SocialLinks {
  final String? website;
  final String? facebook;
  final String? linkedIn;
  final String? twitter;

  SocialLinks({
    this.website,
    this.facebook,
    this.linkedIn,
    this.twitter,
  });

  SocialLinks copyWith({
    String? website,
    String? facebook,
    String? linkedIn,
    String? twitter,
  }) {
    return SocialLinks(
      website: website ?? this.website,
      facebook: facebook ?? this.facebook,
      linkedIn: linkedIn ?? this.linkedIn,
      twitter: twitter ?? this.twitter,
    );
  }

  factory SocialLinks.fromJson(Map<String, dynamic> json) {
    return SocialLinks(
      website: json['website'],
      facebook: json['facebook'],
      linkedIn: json['linkedIn'],
      twitter: json['twitter'],
    );
  }

  Map<String, dynamic> toJson() => {
    'website': website,
    'facebook': facebook,
    'linkedIn': linkedIn,
    'twitter': twitter,
  };
}


/// Skill
class Skill {
  final String id;
  final String skillName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Skill({
    required this.id,
    required this.skillName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json["id"],
    skillName: json["skill_name"],
    createdAt: DateTime.parse(json["created_at"]),
    updatedAt: DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "skill_name": skillName,
    "created_at": createdAt.toIso8601String(),
    "updated_at": updatedAt.toIso8601String(),
  };
}
