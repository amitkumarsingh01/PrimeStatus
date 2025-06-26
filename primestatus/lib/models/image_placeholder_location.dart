class ImagePlaceholderLocation {
  final double x;
  final double y;
  final String shape;
  final double size;
  final String placeholder;

  ImagePlaceholderLocation({
    required this.x,
    required this.y,
    required this.shape,
    required this.size,
    required this.placeholder,
  });

  factory ImagePlaceholderLocation.fromMap(Map<String, dynamic> map) {
    return ImagePlaceholderLocation(
      x: (map['x'] ?? 0).toDouble(),
      y: (map['y'] ?? 0).toDouble(),
      shape: map['shape'] ?? 'circle',
      size: (map['size'] ?? 100).toDouble(),
      placeholder: map['placeholder'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'shape': shape,
      'size': size,
      'placeholder': placeholder,
    };
  }
} 