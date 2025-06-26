class TextLocation {
  final double x;
  final double y;
  final String placeholder;
  final double fontSize;
  final String color;

  TextLocation({
    required this.x,
    required this.y,
    required this.placeholder,
    required this.fontSize,
    required this.color,
  });

  factory TextLocation.fromMap(Map<String, dynamic> map) {
    return TextLocation(
      x: (map['x'] ?? 0).toDouble(),
      y: (map['y'] ?? 0).toDouble(),
      placeholder: map['placeholder'] ?? '',
      fontSize: (map['fontSize'] ?? 16).toDouble(),
      color: map['color'] ?? '#000000',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'placeholder': placeholder,
      'fontSize': fontSize,
      'color': color,
    };
  }
} 