// To parse this JSON data, do
//
//     final userResponse = userResponseFromJson(jsonString);

import 'dart:convert';

import 'common_responses.dart';

UserResponse userResponseFromJson(String str) =>
    UserResponse.fromJson(json.decode(str));

String userResponseToJson(UserResponse data) => json.encode(data.toJson());

class UserResponse {
  String? firstName;
  String? lastName;
  String? profileImage;
  String? bio;
  dynamic location;
  String? address;
  String? coverImage;
  SocialLinks? socialLinks;
  String? id;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? email;
  String? phone;
  bool? isVendor;
  dynamic gcMemberId;
  bool? isVerified;
  List<Skill>? skills;

  UserResponse({
    this.firstName,
    this.lastName,
    this.profileImage,
    this.bio,
    this.location,
    this.address,
    this.coverImage,
    this.socialLinks,
    this.id,
    this.createdAt,
    this.updatedAt,
    this.email,
    this.phone,
    this.isVendor,
    this.gcMemberId,
    this.isVerified,
    this.skills,
  });

  UserResponse copyWith({
    String? firstName,
    String? lastName,
    String? profileImage,
    String? bio,
    dynamic location,
    String? address,
    String? coverImage,
    SocialLinks? socialLinks,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? email,
    String? phone,
    bool? isVendor,
    dynamic gcMemberId,
    bool? isVerified,
    List<Skill>? skills,
  }) => UserResponse(
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    profileImage: profileImage ?? this.profileImage,
    bio: bio ?? this.bio,
    location: location ?? this.location,
    address: address ?? this.address,
    coverImage: coverImage ?? this.coverImage,
    socialLinks: socialLinks ?? this.socialLinks,
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    isVendor: isVendor ?? this.isVendor,
    gcMemberId: gcMemberId ?? this.gcMemberId,
    isVerified: isVerified ?? this.isVerified,
    skills: skills ?? this.skills,
  );

  factory UserResponse.fromJson(Map<String, dynamic> json) => UserResponse(
    firstName: json['first_name'],
    lastName: json['last_name'],
    profileImage: json['profile_image'],
    bio: json['bio'],
    location: json['location'],
    address: json['address'],
    coverImage: json['cover_image'],
    socialLinks: json['social_links'] == null
        ? null
        : SocialLinks.fromJson(json['social_links']),
    id: json['id'],
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at']),
    email: json['email'],
    phone: json['phone'],
    isVendor: json['is_vendor'],
    isVerified: json['is_verified'],
    skills: _parseSkills(json['skills']),
  );

  static List<Skill> _parseSkills(dynamic skillsData) {
    if (skillsData == null) return [];
    try {
      // API may return skills as a JSON string or as a List
      List<dynamic> skillsList;
      if (skillsData is String) {
        skillsList = json.decode(skillsData);
      } else if (skillsData is List) {
        skillsList = skillsData;
      } else {
        return [];
      }
      return skillsList.map((x) => Skill.fromJson(x)).toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'profile_image': profileImage,
    'bio': bio,
    'location': location,
    'address': address,
    'cover_image': coverImage,
    'social_links': socialLinks?.toJson(),
    'id': id,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'email': email,
    'phone': phone,
    'is_vendor': isVendor,
    'is_verified': isVerified,
    'skills': skills == null
        ? []
        : List<dynamic>.from(skills!.map((x) => x.toJson())),
  };
}
