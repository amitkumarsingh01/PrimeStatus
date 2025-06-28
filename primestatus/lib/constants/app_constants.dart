import 'package:flutter/material.dart';

class AppConstants {
  static const List<String> fonts = ['Roboto', 'Arial', 'Times New Roman', 'Courier New'];
  
  static const List<Color> textColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.deepOrange,
    Colors.orange,
    Colors.pink,
  ];

  static const List<Gradient> backgrounds = [
    LinearGradient(
      colors: [Colors.deepOrange, Colors.red],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Colors.deepOrange, Colors.red],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    LinearGradient(
      colors: [Colors.deepOrange, Colors.red],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Colors.deepOrange, Colors.red],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    LinearGradient(
      colors: [Colors.deepOrange, Colors.red],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    LinearGradient(
      colors: [Colors.deepOrange, Colors.red],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  static const List<List<Color>> categoryColors = [
    [Colors.purple, Colors.pink],
    [Colors.blue, Colors.purple],
    [Colors.pink, Colors.red],
    [Colors.orange, Colors.pink],
  ];
} 