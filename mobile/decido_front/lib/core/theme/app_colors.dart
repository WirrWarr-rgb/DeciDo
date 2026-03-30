//# Цветовая палитра (статичные цвета)
import 'package:flutter/material.dart';

class AppColors {
  // Основные цвета из дизайна
  static const Color primary = Color(0xFF8DA249);      // Основной зеленый
  static const Color secondary = Color(0xFFF89254);     // Оранжевый акцент
  static const Color tertiary = Color(0xFF2E434F);      // Темно-синий/зеленый
  
  // Фоновые цвета
  static const Color background = Color(0xFFFBE1B5);    // Светло-бежевый
  static const Color surface = Colors.white;
  static const Color cardBackground = Color(0xFFFBE1B5); // Бежевый фон для карточек
  static const Color darkBackground = Color(0xFF2E434F);
  
  // Поля ввода
  static const Color inputBackground = Color(0xFF759DA9); // Серо-голубой для полей
  static const Color inputText = Color(0xFFFBE1B5);       // Светлый текст в полях
  
  // Текст
  static const Color textPrimary = Color(0xFF2E434F);   // Темный текст
  static const Color textSecondary = Color(0xFF759DA9); // Светло-синий
  static const Color textLight = Color(0xFFFBE1B5);     // Светлый текст
  static const Color textDisabled = Color(0xFFBDBDBD);
  
  // Статусные цвета
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF2196F3);
  
  // Дополнительные
  static const Color divider = Color(0xFFE0E0E0);
  static const Color camera = Color(0xFF2E2E2E);
  static const Color deviceFrame = Color(0x7F747775);
}