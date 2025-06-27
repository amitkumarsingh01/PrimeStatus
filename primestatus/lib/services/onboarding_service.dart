class OnboardingService {
  // Private constructor
  OnboardingService._privateConstructor();

  // Singleton instance
  static final OnboardingService _instance = OnboardingService._privateConstructor();

  // Getter for the instance
  static OnboardingService get instance => _instance;

  // User data
  String? language;
  String? usageType;
  String? name;
  String? profilePhotoUrl;
  String? religion;
  String? state;
  String? subscription;

  void reset() {
    language = null;
    usageType = null;
    name = null;
    profilePhotoUrl = null;
    religion = null;
    state = null;
    subscription = null;
  }
} 