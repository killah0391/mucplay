import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mucplay/locator.dart';

class ThemeProvider extends ChangeNotifier {
  final Box _settingsBox = locator<Box>(instanceName: 'settings');

  static const String keyThemeMode = 'theme_mode';
  static const String keyAccentColor = 'accent_color';
  static const String keyForceBoldColors = 'force_bold_colors';
  static const String keyUseSystemColor = 'use_system_color';
  static const String keyIsMonochrome = 'is_monochrome'; // NEU
  static const String keyUseAccentColorPlayer = 'use_accent_color_player';
  static const String keyWidgetColorMode =
      'widget_color_mode'; // 'app', 'dark', 'custom'
  static const String keyWidgetCustomColor = 'widget_custom_color';

  late String _currentThemeMode;
  late Color _currentAccentColor;
  late bool _forceBoldColors;
  late bool _useSystemColor;
  late bool _isMonochrome; // NEU
  late bool _useAccentColorPlayer;
  late String _widgetColorMode;
  late Color _widgetCustomColor;

  ThemeProvider() {
    _loadSettings();
  }

  void _loadSettings() {
    _currentThemeMode = _settingsBox.get(keyThemeMode, defaultValue: 'system');
    final colorValue = _settingsBox.get(
      keyAccentColor,
      defaultValue: Colors.blueAccent.value,
    );
    _currentAccentColor = Color(colorValue);
    _forceBoldColors = _settingsBox.get(
      keyForceBoldColors,
      defaultValue: false,
    );
    _useSystemColor = _settingsBox.get(keyUseSystemColor, defaultValue: false);
    _isMonochrome = _settingsBox.get(
      keyIsMonochrome,
      defaultValue: false,
    ); // NEU
    _useAccentColorPlayer = _settingsBox.get(
      keyUseAccentColorPlayer,
      defaultValue: true,
    );
    _widgetColorMode = _settingsBox.get(
      keyWidgetColorMode,
      defaultValue: 'app',
    );
    final widgetColorVal = _settingsBox.get(
      keyWidgetCustomColor,
      defaultValue: 0xFF1E1E1E,
    );
    _widgetCustomColor = Color(widgetColorVal);
  }

  // --- Getters ---
  String get currentThemeMode => _currentThemeMode;
  Color get currentAccentColor => _currentAccentColor;
  bool get forceBoldColors => _forceBoldColors;
  bool get useSystemColor => _useSystemColor;
  bool get isMonochrome => _isMonochrome; // NEU
  bool get useAccentColorPlayer => _useAccentColorPlayer;
  String get widgetColorMode => _widgetColorMode;
  Color get widgetCustomColor => _widgetCustomColor;

  // --- Setters ---
  void setThemeMode(String mode) {
    _currentThemeMode = mode;
    _settingsBox.put(keyThemeMode, mode);
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _currentAccentColor = color;
    _settingsBox.put(keyAccentColor, color.value);
    notifyListeners();
  }

  void setForceBoldColors(bool value) {
    _forceBoldColors = value;
    _settingsBox.put(keyForceBoldColors, value);
    notifyListeners();
  }

  void setUseSystemColor(bool value) {
    _useSystemColor = value;
    // System und Monochrom schließen sich aus, aber wir lassen die UI das regeln
    _settingsBox.put(keyUseSystemColor, value);
    notifyListeners();
  }

  // NEU
  void setMonochrome(bool value) {
    _isMonochrome = value;
    _settingsBox.put(keyIsMonochrome, value);
    notifyListeners();
  }

  void setUseAccentColorPlayer(bool value) {
    _useAccentColorPlayer = value;
    _settingsBox.put(keyUseAccentColorPlayer, value);
    notifyListeners();
  }

  void setWidgetColorMode(String mode) {
    _widgetColorMode = mode;
    _settingsBox.put(keyWidgetColorMode, mode);
    notifyListeners();
  }

  void setWidgetCustomColor(Color color) {
    _widgetCustomColor = color;
    _settingsBox.put(keyWidgetCustomColor, color.value);
    notifyListeners();
  }

  ThemeMode get flutterThemeMode {
    switch (_currentThemeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'amoled':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  ThemeData getTheme(ColorScheme? systemScheme, bool isDark) {
    ColorScheme? scheme;

    // 1. Farbschema bestimmen
    if (_isMonochrome) {
      // A) MONOCHROM MODUS (Graustufen)
      scheme = ColorScheme.fromSeed(
        seedColor: Colors.grey, // Neutraler Seed
        brightness: isDark ? Brightness.dark : Brightness.light,
        // Optional: Dynamische Farbe fast komplett entsättigen
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      );
    } else if (_useSystemColor && systemScheme != null) {
      // B) SYSTEM (Material You)
      scheme = systemScheme;
    } else {
      // C) CUSTOM ACCENT
      scheme = ColorScheme.fromSeed(
        seedColor: _currentAccentColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
      );
    }

    // 2. Modifikationen für "Kräftige Farben" (Oder wenn Monochrom erzwungen wird)
    if (_forceBoldColors || _isMonochrome) {
      // Wenn Monochrom aktiv ist, erzwingen wir Schwarz/Weiß als Primary,
      // damit es wirklich "ohne Farbe" aussieht und nicht nur "Grau".
      if (_isMonochrome) {
        final monoColor = isDark ? Colors.white : Colors.black;
        final onMonoColor = isDark ? Colors.black : Colors.white;

        scheme = scheme.copyWith(
          primary: monoColor,
          onPrimary: onMonoColor,
          secondary: monoColor.withOpacity(0.7),
          onSecondary: onMonoColor,
          tertiary: Colors.grey,
        );
      } else if (!_useSystemColor) {
        // Normale "Kräftige Farben" Logik für Bunt
        scheme = scheme.copyWith(
          primary: _currentAccentColor,
          onPrimary: _currentAccentColor.computeLuminance() > 0.5
              ? Colors.black
              : Colors.white,
        );
      }
    }

    // 3. Hintergrundfarben
    final bool isAmoled = isDark && _currentThemeMode == 'amoled';

    final Color bgColor;
    final Color cardColor;

    if (isDark) {
      bgColor = isAmoled ? Colors.black : scheme.surface;
      cardColor = isAmoled ? const Color(0xFF101010) : const Color(0xFF1E1E1E);
    } else {
      bgColor = scheme.surface;
      cardColor = Colors.white;
    }

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,

      scaffoldBackgroundColor: bgColor,
      cardColor: cardColor,
      dialogBackgroundColor: cardColor,

      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        // Im Monochrom Modus Icons anpassen
        iconTheme: IconThemeData(
          color: _isMonochrome ? (isDark ? Colors.white : Colors.black) : null,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isAmoled
            ? Colors.black
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        selectedItemColor: scheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),

      drawerTheme: DrawerThemeData(backgroundColor: bgColor),
      popupMenuTheme: PopupMenuThemeData(color: cardColor),

      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white10 : Colors.black12,
      ),
    );
  }
}
