import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
  static final Set<String> _favoritePaths = {};
  static const String _prefsKey = 'favorite_paths';

  /// Call this before using favorites anywhere (e.g., in main)
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? [];
    _favoritePaths.addAll(saved);
  }

  static bool isFavorite(String path) => _favoritePaths.contains(path);

  static Future<void> toggleFavorite(String path) async {
    if (_favoritePaths.contains(path)) {
      _favoritePaths.remove(path);
    } else {
      _favoritePaths.add(path);
    }
    await _saveToPrefs();
  }

  static List<String> get favorites => _favoritePaths.toList();

  static Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _favoritePaths.toList());
  }
}
