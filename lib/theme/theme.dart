// lib/theme/theme.dart
import 'package:flutter/material.dart';

final glassTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5EEAD4), brightness: Brightness.dark),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFF071028),
  textTheme: Typography.whiteMountainView,
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
  ),
);
