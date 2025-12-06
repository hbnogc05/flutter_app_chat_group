// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Mặc định theo hệ thống
  static const String _themeKey = 'theme_mode';

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme(); // Tải lại lựa chọn đã lưu khi khởi động
  }

  // Tải lựa chọn theme từ bộ nhớ
  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Mặc định là theme sáng (index 1) nếu chưa có lựa chọn nào
    final themeIndex = prefs.getInt(_themeKey) ?? 1; 
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  // Chuyển đổi và lưu theme
  void toggleTheme(bool isDarkMode) async {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeMode.index);
    notifyListeners(); // Thông báo cho các widget đang lắng nghe để chúng build lại
  }
}
