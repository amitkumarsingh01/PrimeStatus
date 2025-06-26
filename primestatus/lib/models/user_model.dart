import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String? mobileNumber;
  final String language;
  final String usageType;
  final String name;
  final String? profilePhotoUrl;
  final String religion;
  final String state;
  final String subscription;
  final bool isActive;
  final bool isAdmin;
  final String? miss1;
  final List<String> createQuotesId;
  final List<String> savedQuotesId;
  final String? fcmToken;

  UserModel({
    required this.id,
    this.mobileNumber,
    required this.language,
    required this.usageType,
    required this.name,
    this.profilePhotoUrl,
    required this.religion,
    required this.state,
    this.subscription = 'free',
    this.isActive = true,
    this.isAdmin = false,
    this.miss1,
    this.createQuotesId = const [],
    this.savedQuotesId = const [],
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      mobileNumber: map['mobile_number'],
      language: map['language'] ?? 'English',
      usageType: map['usage_type'] ?? 'personal',
      name: map['name'] ?? '',
      profilePhotoUrl: map['profile_photo_url'],
      religion: map['religion'] ?? '',
      state: map['state'] ?? '',
      subscription: map['subscription'] ?? 'free',
      isActive: map['isActive'] ?? true,
      isAdmin: map['isAdmin'] ?? false,
      miss1: map['miss1'],
      createQuotesId: List<String>.from(map['createquotesid'] ?? []),
      savedQuotesId: List<String>.from(map['savedquotesid'] ?? []),
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mobile_number': mobileNumber,
      'language': language,
      'usage_type': usageType,
      'name': name,
      'profile_photo_url': profilePhotoUrl,
      'religion': religion,
      'state': state,
      'subscription': subscription,
      'isActive': isActive,
      'isAdmin': isAdmin,
      'miss1': miss1,
      'createquotesid': createQuotesId,
      'savedquotesid': savedQuotesId,
      'fcmToken': fcmToken,
    };
  }
} 