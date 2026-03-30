//# Стили текстов (headline, body, caption и т.д.)
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Заголовки (Headlines)
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFamily: 'Instrument Sans',
    height: 0.61,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    fontFamily: 'Instrument Sans',
    height: 0.92,
  );
  
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: 'Instrument Sans',
    height: 1.2,
  );
  
  // Основной текст (Body)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    fontFamily: 'Roboto',
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontFamily: 'Roboto',
    height: 1.43,
    letterSpacing: 0.25,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textDisabled,
    fontFamily: 'Roboto',
    height: 1.33,
  );
  
  // Кнопки (Button)
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: AppColors.textLight,
    fontFamily: 'Instrument Sans',
    height: 0.92,
  );
  
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.textLight,
    fontFamily: 'Instrument Sans',
    height: 0.92,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
    fontFamily: 'Instrument Sans',
    height: 1.2,
  );
  
  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontFamily: 'Roboto',
    height: 1.33,
  );
  
  // Label
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    fontFamily: 'Roboto',
    height: 1.43,
  );
  
  // Для совместимости со старым кодом (если где-то используется)
  static const TextStyle headline1 = headlineLarge;
  static const TextStyle headline2 = headlineMedium;
  static const TextStyle headline3 = headlineSmall;
  static const TextStyle button = buttonMedium;
}