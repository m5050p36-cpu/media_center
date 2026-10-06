import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorite_tracks_v1';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }

  static Future<void> save(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, favorites.toList());
  }

  static Future<bool> toggle(String path) async {
    final favorites = await load();
    final added = !favorites.contains(path);
    if (added) {
      favorites.add(path);
    } else {
      favorites.remove(path);
    }
    await save(favorites);
    return added;
  }

  static Future<bool> isFavorite(String path) async {
    final favorites = await load();
    return favorites.contains(path);
  }
}
