import 'text_location.dart';
import 'image_placeholder_location.dart';

class QuoteTemplate {
  final String quotesId;
  final String title;
  final String assetsType;
  final String imageUrl;
  final List<TextLocation> txtLocation;
  final List<ImagePlaceholderLocation> imgPlaceholderLocation;
  final bool placeholderWithBackground;
  final bool isFree;
  final String accessLink;
  final List<String> hashtags;
  final String category;
  final String uploadedBy;
  final List<String> language;
  final List<String> religion;
  final List<String> state;
  final bool isUserCreated;

  QuoteTemplate({
    required this.quotesId,
    required this.title,
    required this.assetsType,
    required this.imageUrl,
    required this.txtLocation,
    required this.imgPlaceholderLocation,
    this.placeholderWithBackground = true,
    this.isFree = true,
    required this.accessLink,
    this.hashtags = const [],
    required this.category,
    required this.uploadedBy,
    this.language = const [],
    this.religion = const [],
    this.state = const [],
    this.isUserCreated = false,
  });

  factory QuoteTemplate.fromMap(Map<String, dynamic> map) {
    return QuoteTemplate(
      quotesId: map['quotesid'] ?? '',
      title: map['title'] ?? '',
      assetsType: map['assets_type'] ?? 'img',
      imageUrl: map['image_url'] ?? '',
      txtLocation: (map['txt_location'] as List<dynamic>?)
              ?.map((e) => TextLocation.fromMap(e))
              .toList() ??
          [],
      imgPlaceholderLocation: (map['img_placeholder_location'] as List<dynamic>?)
              ?.map((e) => ImagePlaceholderLocation.fromMap(e))
              .toList() ??
          [],
      placeholderWithBackground: map['placeholder_with_background'] ?? true,
      isFree: map['isFree'] ?? true,
      accessLink: map['access_link'] ?? '',
      hashtags: List<String>.from(map['hashtags'] ?? []),
      category: map['category'] ?? '',
      uploadedBy: map['uploaded_by'] ?? '',
      language: List<String>.from(map['language'] ?? []),
      religion: List<String>.from(map['religion'] ?? []),
      state: List<String>.from(map['state'] ?? []),
      isUserCreated: map['is_user_created'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quotesid': quotesId,
      'title': title,
      'assets_type': assetsType,
      'image_url': imageUrl,
      'txt_location': txtLocation.map((e) => e.toMap()).toList(),
      'img_placeholder_location': imgPlaceholderLocation.map((e) => e.toMap()).toList(),
      'placeholder_with_background': placeholderWithBackground,
      'isFree': isFree,
      'access_link': accessLink,
      'hashtags': hashtags,
      'category': category,
      'uploaded_by': uploadedBy,
      'language': language,
      'religion': religion,
      'state': state,
      'is_user_created': isUserCreated,
    };
  }
} 