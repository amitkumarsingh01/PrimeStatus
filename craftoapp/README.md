# QuoteCraft - Flutter Quote Design App

A beautiful Flutter application for creating and sharing inspirational quote designs with stunning backgrounds and customizable text styles.

## 🚀 Features

- **Quote Categories**: Browse quotes by categories (Motivational, Love, Success, etc.)
- **Quote Editor**: Create custom quote designs with:
  - Multiple font options
  - Adjustable font sizes
  - Color customization
  - Text alignment options
  - Beautiful gradient backgrounds
- **Favorites**: Save your favorite quotes
- **Share Functionality**: Share quotes on social media platforms
- **Download**: Save quote designs to gallery
- **User Authentication**: Basic login system
- **Modern UI**: Beautiful gradient backgrounds and modern design

## 📁 Project Structure

The project is organized into a clean, maintainable structure:

```
lib/
├── main.dart                 # App entry point and theme configuration
├── data/
│   └── quote_data.dart       # Quote categories and data
├── constants/
│   └── app_constants.dart    # App-wide constants (fonts, colors, backgrounds)
├── widgets/
│   └── common_widgets.dart   # Reusable UI components
└── screens/
    ├── home_screen.dart      # Main screen with bottom navigation
    └── quote_editor_screen.dart # Quote design editor
```

### File Descriptions

#### `main.dart`
- App entry point
- MaterialApp configuration
- Theme setup

#### `data/quote_data.dart`
- Static quote data organized by categories
- Categories list
- Quote collections for each category

#### `constants/app_constants.dart`
- Font options
- Text color options
- Background gradient definitions
- Category color schemes

#### `widgets/common_widgets.dart`
- Reusable UI components
- Action cards
- Category cards
- Profile options
- Share options
- Common utility functions

#### `screens/home_screen.dart`
- Main application screen
- Bottom navigation with 4 tabs:
  - Home: Quote of the day, quick actions, featured categories
  - Categories: Browse all quote categories
  - Favorites: Saved favorite quotes
  - Profile: User profile and settings
- Login/logout functionality
- Quote selection and creation

#### `screens/quote_editor_screen.dart`
- Quote design editor
- Text editing capabilities
- Font, size, color, and alignment controls
- Background selection
- Download and share functionality

## 🎨 Design Features

### Color Scheme
- Primary: Purple theme
- Secondary: Pink accents
- Beautiful gradient backgrounds
- Modern, clean UI

### Typography
- Multiple font options (Roboto, Arial, Times New Roman, Courier New)
- Adjustable font sizes (12-48px)
- Text alignment options (Left, Center, Right)

### Backgrounds
- 6 beautiful gradient backgrounds
- Purple-Pink, Blue-Purple, Orange-Red, Green-Blue, Pink-Purple, Indigo-Cyan

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd craftoapp
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## 📱 Usage

### Creating a Quote Design
1. Navigate to the Home tab
2. Tap "Create Quote" or select a category
3. Choose a quote from the category
4. Tap "Create" to open the editor
5. Customize the design:
   - Edit the text
   - Choose a background
   - Select font, size, color, and alignment
6. Download or share your design

### Adding to Favorites
- Tap the heart icon next to any quote to add/remove from favorites
- View all favorites in the Favorites tab

### User Authentication
- Tap the login icon in the app bar
- Enter email and password (demo login)
- Access profile features

## 🔧 Customization

### Adding New Quotes
Edit `lib/data/quote_data.dart`:
```dart
static const Map<String, List<String>> quotes = {
  'New Category': [
    'Your new quote here',
    'Another quote here',
  ],
  // ... existing categories
};
```

### Adding New Backgrounds
Edit `lib/constants/app_constants.dart`:
```dart
static const List<Gradient> backgrounds = [
  // ... existing backgrounds
  LinearGradient(
    colors: [Colors.yourColor1, Colors.yourColor2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
];
```

### Adding New Fonts
Edit `lib/constants/app_constants.dart`:
```dart
static const List<String> fonts = [
  // ... existing fonts
  'Your New Font',
];
```

## 📄 License

This project is developed with ❤️ using Flutter.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For support and questions, please open an issue in the repository.

---

**QuoteCraft v1.0** - Create beautiful quote designs with stunning backgrounds. Share your inspiration with the world.
