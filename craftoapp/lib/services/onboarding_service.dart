class OnboardingService {
  // Private constructor
  OnboardingService._privateConstructor();

  // Singleton instance
  static final OnboardingService _instance = OnboardingService._privateConstructor();

  // Getter for the instance
  static OnboardingService get instance => _instance;

  // User data
  String? mobileNumber;
  String? language;
  String? usageType;
  String? name;
  String? profilePhotoUrl;
  String? religion;
  String? state;
  String? subscription;

  void reset() {
    mobileNumber = null;
    language = null;
    usageType = null;
    name = null;
    profilePhotoUrl = null;
    religion = null;
    state = null;
    subscription = null;
  }
} 