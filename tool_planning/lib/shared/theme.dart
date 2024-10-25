import 'package:flutter/material.dart';

const primaryColor = Color(0xFF104382);

final appLightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: primaryColor,
  primarySwatch: Colors.blue,
  scaffoldBackgroundColor: const Color(0xFFF0F0F0),
  appBarTheme: const AppBarTheme(
    backgroundColor: primaryColor,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(
      color: Colors.white,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryColor,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: primaryColor,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: primaryColor),
    ),
  ),
  iconTheme: const IconThemeData(
    color: primaryColor,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black87),
  ),
);

final appDarkTheme = ThemeData.dark().copyWith(
  primaryColor: primaryColor,
  scaffoldBackgroundColor: const Color(0xFF303030),
  appBarTheme: const AppBarTheme(
    backgroundColor: primaryColor,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(
      color: Colors.white,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: primaryColor,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white),
    ),
  ),
  iconTheme: const IconThemeData(
    color: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white70),
  ),
);
